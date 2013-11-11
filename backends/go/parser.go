package main

import (
	"code.google.com/p/go.tools/go/types"
	"go/ast"
	"go/build"
	"go/parser"
	"go/scanner"
	"go/token"
	"os"
	"path"
	"path/filepath"
	"sync"
	"time"
)

type cachedAst struct {
	Mtime time.Time
	File  *ast.File
}

type Parsed struct {
	Info     *types.Info
	Package  *types.Package
	FileSet  *token.FileSet
	Ast      []*ast.File
	File     *ast.File
	Errors   scanner.ErrorList
	Duration time.Duration
}

type Parser struct {
	cache     map[string]*cachedAst
	cacheLock sync.Mutex
}

var TheParser Parser

func CanonicalPath(path string) string {
	path = filepath.Clean(path)

	if ret, err := filepath.EvalSymlinks(path); err == nil {
		return ret
	}

	return path
}

func (p *Parser) canonicalPaths(path string, unsaved []UnsavedDocument) (string, map[string]UnsavedDocument) {
	uns := make(map[string]UnsavedDocument)

	for _, v := range unsaved {
		uns[CanonicalPath(v.Path)] = v
	}

	path = CanonicalPath(path)
	return path, uns
}

func (p *Parser) tryCache(f string) (*ast.File, os.FileInfo) {
	p.cacheLock.Lock()
	a := p.cache[f]
	p.cacheLock.Unlock()

	if a != nil {
		fi, err := os.Stat(f)

		if err == nil {
			if !fi.ModTime().After(a.Mtime) {
				return a.File, nil
			} else {
				return nil, fi
			}
		}
	}

	return nil, nil
}

func (p *Parser) fromCache(fs *token.FileSet, f string) (*ast.File, error) {
	a, fi := p.tryCache(f)

	if a != nil {
		return a, nil
	}

	a, err := parser.ParseFile(fs, f, nil, 0)

	if err != nil {
		return nil, err
	}

	if fi != nil {
		p.cacheLock.Lock()

		p.cache[f] = &cachedAst{
			Mtime: fi.ModTime(),
			File:  a,
		}

		p.cacheLock.Unlock()
	}

	return a, nil
}

func (p *Parser) Ast(fs *token.FileSet, path string, files []string, unsaved map[string]UnsavedDocument) (*ast.File, []*ast.File, error) {
	ret := make([]*ast.File, len(files))
	var retf *ast.File

	var errors scanner.ErrorList

	for i, f := range files {
		f = CanonicalPath(f)

		var v *ast.File
		var err error

		if uns, ok := unsaved[f]; ok {
			v, err = parser.ParseFile(fs, f, uns.Data, parser.AllErrors)
		} else {
			v, err = p.fromCache(fs, f)
		}

		if v == nil {
			return nil, nil, err
		}

		ret[i] = v

		if path == f {
			retf = ret[i]

			if perr, ok := err.(scanner.ErrorList); ok {
				for _, e := range perr {
					errors.Add(e.Pos, e.Msg)
				}
			}
		}
	}

	errors.RemoveMultiples()
	errors.Sort()

	var err error

	if len(errors) != 0 {
		err = errors
	}

	return retf, ret, err
}

func (p *Parser) importSourcePackage(fs *token.FileSet, path string, importPath string, unsaved map[string]UnsavedDocument, options Options, info *types.Info) (*ast.File, []*ast.File, *types.Package, error) {
	ctx := build.Default

	if len(options.GoPath) > 0 {
		ctx.GOPATH = options.GoPath
	}

	ctx.BuildTags = options.BuildConstraints

	var pkg *build.Package
	var err error

	if filepath.IsAbs(importPath) {
		pkg, err = ctx.ImportDir(importPath, 0)
	} else {
		pkg, err = ctx.Import(importPath, "", 0)
	}

	if err != nil {
		return nil, nil, nil, err
	}

	files := make([]string, len(pkg.GoFiles))

	for i, v := range pkg.GoFiles {
		files[i] = filepath.Join(pkg.Dir, v)
	}

	f, astf, err := p.Ast(fs, path, files, unsaved)

	if len(astf) == 0 {
		return nil, nil, nil, err
	}

	errors, _ := err.(scanner.ErrorList)

	c := types.Config{
		Error: func(err error) {
			if e, ok := err.(types.Error); ok && len(path) != 0 {
				pos := e.Fset.Position(e.Pos)

				if pos.Filename == path {
					errors.Add(pos, e.Msg)
				}
			}
		},

		Import: func(imports map[string]*types.Package, path string) (*types.Package, error) {
			return p.importSourceFirst(imports, fs, path, unsaved, options, info)
		},
	}

	tpkg, _ := c.Check(filepath.Base(importPath), fs, astf, info)

	errors.RemoveMultiples()
	errors.Sort()

	if len(errors) == 0 {
		err = nil
	} else {
		err = errors
	}

	return f, astf, tpkg, err
}

func (p *Parser) tryImportSource(fs *token.FileSet, imports map[string]*types.Package, importPath string, unsaved map[string]UnsavedDocument, options Options, info *types.Info) (*types.Package, error) {
	paths := filepath.SplitList(options.GoPath)

	for _, pp := range paths {
		src := path.Join(pp, "src", importPath)

		if _, err := os.Stat(src); err != nil {
			continue
		}

		_, _, pkg, err := p.importSourcePackage(fs, "", importPath, unsaved, options, info)

		if pkg != nil {
			imports[importPath] = pkg
			return pkg, err
		}
	}

	return nil, nil
}

func (p *Parser) importSourceFirst(imports map[string]*types.Package, fs *token.FileSet, importPath string, unsaved map[string]UnsavedDocument, options Options, info *types.Info) (*types.Package, error) {
	if pkg := imports[importPath]; pkg != nil && pkg.Complete() {
		return pkg, nil
	}

	pkg, err := p.tryImportSource(fs, imports, importPath, unsaved, options, info)

	if pkg == nil {
		pkg, err = types.GcImport(imports, importPath)
	}

	return pkg, err
}

func (p *Parser) Parse(path string, cursor SourceLocation, unsaved []UnsavedDocument, options Options) (*Parsed, error) {
	if len(options.GoPath) == 0 {
		options.GoPath = os.Getenv("GOPATH")
	}

	path, uns := p.canonicalPaths(path, unsaved)

	var info types.Info

	info.Types = make(map[ast.Expr]types.Type)
	info.Objects = make(map[*ast.Ident]types.Object)

	fs := token.NewFileSet()

	started := time.Now()

	dname := filepath.Dir(path)
	f, astf, tpkg, err := p.importSourcePackage(fs, path, dname, uns, options, &info)

	errors, _ := err.(scanner.ErrorList)

	return &Parsed{
		Info:     &info,
		Package:  tpkg,
		FileSet:  fs,
		Ast:      astf,
		File:     f,
		Errors:   errors,
		Duration: time.Now().Sub(started),
	}, nil
}
