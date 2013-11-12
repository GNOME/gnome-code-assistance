package main

import (
	"github.com/guelfey/go.dbus"
	"github.com/guelfey/go.dbus/introspect"
)

type ServiceDbus struct {
	Server *ServerDbus
}

type DocumentDbus struct {
	Document *Document
}

type OpenDocument struct {
	Path     string
	DataPath string
}

type RemoteDocument struct {
	Path       string
	ObjectPath dbus.ObjectPath
}

func (s *ServiceDbus) Introspect() *introspect.Node {
	n := &introspect.Node{
		Interfaces: []introspect.Interface{
			{
				Name: "org.gnome.CodeAssist.v1.Service",
				Methods: []introspect.Method{
					{
						Name: "Parse",
						Args: []introspect.Arg{
							{"path", "s", "in"},
							{"data_path", "s", "in"},
							{"cursor", "(xx)", "in"},
							{"options", "a{sv}", "in"},
							{"result", "o", "out"},
						},
					},
					{
						Name: "Dispose",
						Args: []introspect.Arg{
							{"path", "s", "in"},
						},
					},
				},
			},

			introspect.Interface{
				Name: "org.gnome.CodeAssist.v1.Project",
				Methods: []introspect.Method{
					{
						Name: "ParseAll",
						Args: []introspect.Arg{
							{"path", "s", "in"},
							{"documents", "a(ss)", "in"},
							{"cursor", "(xx)", "in"},
							{"options", "a{sv}", "in"},
							{"result", "a(so)", "out"},
						},
					},
				},
			},
		},
	}

	return n
}

func (d *DocumentDbus) Introspect() *introspect.Node {
	return &introspect.Node{
		Interfaces: []introspect.Interface{
			introspect.Interface{
				Name: "org.gnome.CodeAssist.v1.Document",
			},

			introspect.Interface{
				Name: "org.gnome.CodeAssist.v1.Diagnostics",
				Methods: []introspect.Method{
					{
						Name: "Diagnostics",
						Args: []introspect.Arg{
							{"result", "a(ua((x(xx)(xx))s)a(x(xx)(xx))s)", "out"},
						},
					},
				},
			},
		},
	}
}

func (s *ServiceDbus) Parse(path string, dataPath string, cursor SourceLocation, options map[string]dbus.Variant, sender dbus.Sender) (dbus.ObjectPath, *dbus.Error) {
	return s.Server.Parse(string(sender), path, dataPath, cursor, options)
}

func (s *ServiceDbus) Dispose(path string, sender dbus.Sender) *dbus.Error {
	return s.Server.Dispose(string(sender), path)
}

func (s *ServiceDbus) ParseAll(path string, documents []OpenDocument, cursor SourceLocation, options map[string]dbus.Variant, sender dbus.Sender) ([]RemoteDocument, *dbus.Error) {
	return s.Server.ParseAll(string(sender), path, documents, cursor, options)
}

func (d *DocumentDbus) Diagnostics() ([]Diagnostic, *dbus.Error) {
	return d.Document.Diagnostics, nil
}
