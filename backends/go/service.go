package main

import (
	"io"
	"sync"
)

type Severity uint32

const (
	SeverityNone Severity = iota
	SeverityInfo
	SeverityWarning
	SeverityDeprecated
	SeverityError
	SeverityFatal
)

type SourceLocation struct {
	Line   int64
	Column int64
}

type SourceRange struct {
	File  int64
	Start SourceLocation
	End   SourceLocation
}

type UnsavedDocument struct {
	Path string
	Data io.ReadCloser
}

type Fixit struct {
	Location    SourceRange
	Replacement string
}

type Diagnostic struct {
	Severity  Severity
	Fixits    []Fixit
	Locations []SourceRange
	Message   string
}

type Document struct {
	Id         uint64
	Path       string
	DataPath   string
	ClientPath string
	Cursor     SourceLocation

	Diagnostics []Diagnostic

	parsed *Parsed
	mutex  sync.Mutex
}

type Service struct {
}

func NewService() *Service {
	return &Service{}
}

func (d *Document) process(parsed *Parsed) error {
	var diagnostics []Diagnostic

	if parsed != nil {
		diagnostics = make([]Diagnostic, len(parsed.Errors))

		for i, err := range parsed.Errors {
			diagnostics[i] = Diagnostic{
				Severity: SeverityError,
				Locations: []SourceRange{
					SourceRange{
						Start: SourceLocation{
							Line:   int64(err.Pos.Line),
							Column: int64(err.Pos.Column),
						},
						End: SourceLocation{
							Line:   int64(err.Pos.Line),
							Column: int64(err.Pos.Column),
						},
					},
				},
				Message: err.Msg,
				Fixits:  []Fixit{},
			}
		}
	}

	d.mutex.Lock()
	d.parsed = parsed
	d.Diagnostics = diagnostics
	d.mutex.Unlock()

	return nil
}

func (s *Service) Parse(doc *Document, unsaved []UnsavedDocument, options Options) error {
	parsed, err := TheParser.Parse(doc.Path, doc.Cursor, unsaved, options)

	if err != nil {
		return err
	}

	return doc.process(parsed)
}

func (s *Service) Dispose(doc *Document) error {
	return nil
}
