package main

import (
	"fmt"
	"github.com/guelfey/go.dbus"
	"github.com/guelfey/go.dbus/introspect"
	"os"
	"sync"
)

type ServiceDbus struct {
	transport *TransportDbus
	apps      map[string]*App
	nextid    uint64
	mutex     sync.Mutex
}

func NewServiceDbus(transport *TransportDbus) *ServiceDbus {
	ret := &ServiceDbus{
		transport: transport,
		apps:      make(map[string]*App),
	}

	go func() {
		c := make(chan *dbus.Signal, 30)
		transport.conn.Signal(c)

		for v := range c {
			if len(v.Body) != 3 {
				continue
			}

			oldname := v.Body[1].(string)
			newname := v.Body[2].(string)

			if len(newname) != 0 {
				continue
			}

			ret.disposeApp(oldname)
		}
	}()

	transport.conn.BusObject().Call("org.freedesktop.DBus.AddMatch", 0,
		"type='signal',path='/org/freedesktop/DBus',interface='org.freedesktop.DBus',sender='org.freedesktop.DBus',member='NameOwnerChanged'")

	return ret
}

func (s *ServiceDbus) Introspect() *introspect.Node {
	n := &introspect.Node{
		Interfaces: []introspect.Interface{
			introspect.Interface{
				Name:    "org.gnome.CodeAssist.Service",
				Methods: introspect.Methods(s),
			},
		},
	}

	return n
}

func (s *ServiceDbus) Path() dbus.ObjectPath {
	return "/org/gnome/CodeAssist/go"
}

func (s *ServiceDbus) app(name string) *App {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	if app := s.apps[name]; app != nil {
		return app
	}

	app := NewApp(s.nextid, name)

	s.nextid++
	s.apps[name] = app

	return app
}

func (s *ServiceDbus) parseUnsavedDocuments(unsaved []UnsavedDocumentDbus) ([]UnsavedDocument, error) {
	uns := make([]UnsavedDocument, len(unsaved))

	for i, v := range unsaved {
		uns[i].Path = v.Path

		f, err := os.Open(v.DataPath)

		if err != nil {
			return nil, fmt.Errorf("Failed to open file %s: %v", v.DataPath, err)
		}

		uns[i].Data = f
	}

	return uns, nil
}

func (s *ServiceDbus) disposeLocked(app *App, path string) {
	if id, ok := app.documentIds[path]; ok {
		ddoc := app.documents[id].(*DocumentDbus)

		delete(app.documentIds, path)
		delete(app.documents, id)

		s.transport.conn.Unexport(ddoc.Path(), "org.gnome.CodeAssist.Document")
		s.transport.conn.Unexport(ddoc.Path(), "org.gnome.CodeAssist.Diagnostics")
	}

	if len(app.documents) == 0 {
		s.mutex.Lock()
		delete(s.apps, app.name)
		s.mutex.Unlock()
	}
}

func (s *ServiceDbus) parseOptions(options map[string]dbus.Variant) (Options, error) {
	opts := make(map[string]interface{})

	for k, v := range options {
		opts[k] = v.Value()
	}

	var o Options
	err := o.Parse(opts)

	return o, err
}

func (s *ServiceDbus) document(app *App, path string) (*DocumentDbus, *Document) {
	doc := app.document(path)

	if doc == nil {
		return nil, nil
	}

	ret := doc.(*DocumentDbus)
	return ret, ret.document
}

func (s *ServiceDbus) appPath(a *App) dbus.ObjectPath {
	return dbus.ObjectPath(fmt.Sprintf("/org/gnome/CodeAssist/go/%v", a.id))
}

func (s *ServiceDbus) Parse(path string, cursor int64, unsaved []UnsavedDocumentDbus, options map[string]dbus.Variant, sender dbus.Sender) (dbus.ObjectPath, *dbus.Error) {
	app := s.app(string(sender))

	uns, err := s.parseUnsavedDocuments(unsaved)

	if err != nil {
		return "", NewDbusError("UnsavedDocument", "%v", err)
	}

	o, err := s.parseOptions(options)

	if err != nil {
		return "", NewDbusError("InvalidOptions", "%v", err)
	}

	doc, nativedoc := s.document(app, path)
	nativedoc, err = app.service.Parse(path, cursor, uns, o, nativedoc)

	if err != nil {
		return "", NewDbusError("ParseError", "%v", err)
	}

	if doc != nil {
		return doc.Path(), nil
	}

	doc = NewDocumentDbus(s.appPath(app), nativedoc)
	doc.id = app.insertDocument(path, doc)

	s.transport.export(doc)
	s.transport.export(doc.diagnostics)

	return doc.Path(), nil
}

func (s *ServiceDbus) disposeApp(name string) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	app := s.apps[name]

	if app == nil {
		return
	}

	app.mutex.Lock()
	defer app.mutex.Unlock()

	for _, doc := range app.documents {
		ddoc := doc.(*DocumentDbus)
		app.service.Dispose(ddoc.document)

		s.transport.conn.Unexport(ddoc.Path(), "org.gnome.CodeAssist.Document")
		s.transport.conn.Unexport(ddoc.Path(), "org.gnome.CodeAssist.Diagnostics")
	}

	app.documents = nil
	app.documentIds = nil

	delete(s.apps, name)

	if len(s.apps) == 0 {
		os.Exit(0)
	}
}

func (s *ServiceDbus) Dispose(path string, sender dbus.Sender) *dbus.Error {
	app := s.app(string(sender))
	doc, _ := s.document(app, path)

	if doc == nil {
		return NewDbusError("DisposeError", "Invalid document")
	}

	if err := app.service.Dispose(doc.document); err != nil {
		return NewDbusError("DisposeError", "%v", err)
	}

	s.disposeLocked(app, path)
	return nil
}

func (s *ServiceDbus) SupportedServices(sender dbus.Sender) ([]string, *dbus.Error) {
	s.app(string(sender))

	return []string{
		"org.gnome.CodeAssist.Document",
		"org.gnome.CodeAssist.Diagnostics",
	}, nil
}
