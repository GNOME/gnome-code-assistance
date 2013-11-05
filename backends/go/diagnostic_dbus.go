package main

import (
	"github.com/guelfey/go.dbus"
	"github.com/guelfey/go.dbus/introspect"
)

type DiagnosticDbus struct {
	document *DocumentDbus
}

func NewDiagnosticDbus(document *DocumentDbus) *DiagnosticDbus {
	return &DiagnosticDbus{
		document: document,
	}
}

func (d *DiagnosticDbus) Path() dbus.ObjectPath {
	return d.document.Path()
}

func (d *DiagnosticDbus) Introspect() *introspect.Node {
	return &introspect.Node{
		Interfaces: []introspect.Interface{
			introspect.Interface{
				Name:    "org.gnome.CodeAssist.Diagnostics",
				Methods: introspect.Methods(d),
			},
		},
	}
}

func (d *DiagnosticDbus) Diagnostics() ([]Diagnostic, *dbus.Error) {
	return d.document.document.Diagnostics(), nil
}
