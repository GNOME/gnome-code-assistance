package main

import (
	"fmt"
	"github.com/guelfey/go.dbus"
	"github.com/guelfey/go.dbus/introspect"
)

type DocumentDbus struct {
	id          uint64
	document    *Document
	diagnostics *DiagnosticDbus

	apppath dbus.ObjectPath
}

type UnsavedDocumentDbus struct {
	Path     string
	DataPath string
}

func NewDocumentDbus(apppath dbus.ObjectPath, document *Document) *DocumentDbus {
	ret := &DocumentDbus{
		document: document,
		apppath:  apppath,
	}

	ret.diagnostics = NewDiagnosticDbus(ret)
	return ret
}

func (d *DocumentDbus) Path() dbus.ObjectPath {
	return dbus.ObjectPath(fmt.Sprintf("%v/documents/%v", d.apppath, d.id))
}

func (d *DocumentDbus) Introspect() *introspect.Node {
	return &introspect.Node{
		Interfaces: []introspect.Interface{
			introspect.Interface{
				Name:    "org.gnome.CodeAssist.Document",
				Methods: introspect.Methods(d),
			},
		},
	}
}
