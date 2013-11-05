package main

import (
	"io"
	"sync"
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

type Document struct {
	Path  string
	paths map[int64]string

	parsed *Parsed
	mutex  sync.Mutex
}

func NewDocument(path string) *Document {
	return &Document{
		Path: path,
	}
}
