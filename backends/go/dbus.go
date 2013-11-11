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
				Name:    "org.gnome.CodeAssist.Service",
				Methods: []introspect.Method{
					{
						Name: "Parse",
						Args: []introspect.Arg{
							{"path", "s", "in"},
							{"cursor", "x", "in"},
							{"data_path", "s", "in"},
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
				Name:    "org.gnome.CodeAssist.Project",
				Methods: []introspect.Method{
					{
						Name: "ParseAll",
						Args: []introspect.Arg{
							{"path", "s", "in"},
							{"cursor", "x", "in"},
							{"documents", "a(ss)", "in"},
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
				Name:    "org.gnome.CodeAssist.Document",
			},

			introspect.Interface{
				Name:    "org.gnome.CodeAssist.Diagnostics",
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

func (s *ServiceDbus) Parse(path string, cursor int64, dataPath string, options map[string]dbus.Variant, sender dbus.Sender) (dbus.ObjectPath, *dbus.Error) {
	return s.Server.Parse(string(sender), path, cursor, dataPath, options)
}

func (s *ServiceDbus) Dispose(path string, sender dbus.Sender) *dbus.Error {
	return s.Server.Dispose(string(sender), path)
}

func (s *ServiceDbus) ParseAll(path string, cursor int64, documents []OpenDocument, options map[string]dbus.Variant, sender dbus.Sender) ([]RemoteDocument, *dbus.Error) {
	return s.Server.ParseAll(string(sender), path, cursor, documents, options)
}

func (d *DocumentDbus) Diagnostics() ([]Diagnostic, *dbus.Error) {
	return d.Document.Diagnostics, nil
}