package main

import (
	"fmt"
	"github.com/guelfey/go.dbus"
	"os"
	"path/filepath"
	"sync"
)

type App struct {
	id   uint64
	name string

	docs   map[string]*DocumentDbus

	service *Service

	nextid uint64
	mutex  sync.Mutex
}

type ServerDbus struct {
	transport *TransportDbus
	service   *ServiceDbus
	apps      map[string]*App
	nextid    uint64
	mutex     sync.Mutex
}

func NewServerDbus(transport *TransportDbus) (*ServerDbus, error) {
	ret := &ServerDbus{
		transport: transport,
		apps:      make(map[string]*App),
	}

	ret.service = &ServiceDbus{
		Server: ret,
	}

	transport.export(ret.service, ret.dbusPath())
	transport.export(new(DocumentDbus), dbus.ObjectPath(fmt.Sprintf("%s/document", ret.dbusPath())))

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

			ret.mutex.Lock()
			defer ret.mutex.Unlock()

			if app := ret.apps[oldname]; app != nil {
				app.mutex.Lock()
				defer app.mutex.Unlock()

				ret.disposeApp(app)
			}
		}
	}()

	transport.conn.BusObject().Call("org.freedesktop.DBus.AddMatch", 0,
		"type='signal',path='/org/freedesktop/DBus',interface='org.freedesktop.DBus',sender='org.freedesktop.DBus',member='NameOwnerChanged'")

	return ret, nil
}

func (s *ServerDbus) dbusPath() dbus.ObjectPath {
	return "/org/gnome/CodeAssist/v1/go"
}

func (s *ServerDbus) documentDbusPath(app *App, doc *DocumentDbus) dbus.ObjectPath {
	return dbus.ObjectPath(fmt.Sprintf("%s/%v/documents/%v", s.dbusPath(), app.id, doc.Document.Id))
}

func (s *ServerDbus) makeApp(name string) *App {
	app := &App{
		id: s.nextid,
		name: name,
		docs: make(map[string]*DocumentDbus),
		service: NewService(),
	}

	s.nextid++
	s.apps[name] = app

	return app
}

func (s *ServerDbus) ensureApp(name string) *App {
	if app := s.apps[name]; app != nil {
		return app
	}

	return s.makeApp(name)
}

func (s *ServerDbus) makeDocument(app *App, path string, clientPath string) *DocumentDbus {
	doc := &Document{
		Id: app.nextid,
		Path: path,
		ClientPath: clientPath,
	}

	ddoc := &DocumentDbus{
		Document: doc,
	}

	s.transport.export(ddoc, s.documentDbusPath(app, ddoc))

	app.nextid++
	app.docs[path] = ddoc

	return ddoc
}

func (s *ServerDbus) ensureDocument(app *App, path string, dataPath string, cursor int64) *DocumentDbus {
	npath := filepath.Clean(path)

	doc := app.docs[npath]

	if doc == nil {
		doc = s.makeDocument(app, npath, path)
	}

	doc.Document.DataPath = dataPath
	doc.Document.Cursor = cursor

	return doc
}

func (s *ServerDbus) parseOptions(options map[string]dbus.Variant) (Options, error) {
	opts := make(map[string]interface{})

	for k, v := range options {
		opts[k] = v.Value()
	}

	var o Options
	err := o.Parse(opts)

	return o, err
}

func (s *ServerDbus) parse(appid string, path string, cursor int64, documents []OpenDocument, options map[string]dbus.Variant) ([]RemoteDocument, *dbus.Error) {
	s.mutex.Lock()
	app := s.ensureApp(appid)
	s.mutex.Unlock()

	o, err := s.parseOptions(options)

	if err != nil {
		return nil, NewDbusError("InvalidOptions", "%v", err)
	}

	app.mutex.Lock()
	doc := s.ensureDocument(app, path, "", cursor)

	unsaved := make([]UnsavedDocument, 0, len(documents))

	for _, d := range documents {
		cpath := filepath.Clean(d.Path)

		if len(d.DataPath) != 0 && d.DataPath != d.Path {
			f, err := os.Open(d.DataPath)

			if err != nil {
				return nil, NewDbusError("ParseError", "%v", err)
			}

			defer f.Close()

			unsaved = append(unsaved, UnsavedDocument{
				Path: d.Path,
				Data: f,
			})
		}

		if doc := app.docs[cpath]; doc != nil {
			doc.Document.DataPath = d.DataPath
		}
	}

	app.mutex.Unlock()

	if err := app.service.Parse(doc.Document, unsaved, o); err != nil {
		return nil, NewDbusError("ParseError", "%v", err)
	}

	return []RemoteDocument{
		{path, s.documentDbusPath(app, doc)},
	}, nil
}

func (s *ServerDbus) Parse(appid string, path string, cursor int64, dataPath string, options map[string]dbus.Variant) (dbus.ObjectPath, *dbus.Error) {
	documents := []OpenDocument{
		{path, dataPath},
	}

	ret, err := s.parse(appid, path, cursor, documents, options)

	if err != nil {
		return "", err
	}

	for _, v := range ret {
		if v.Path == path {
			return v.ObjectPath, nil
		}
	}

	return "", nil
}

func (s *ServerDbus) ParseAll(appid string, path string, cursor int64, documents []OpenDocument, options map[string]dbus.Variant) ([]RemoteDocument, *dbus.Error) {
	return s.parse(appid, path, cursor, documents, options)
}

func (s *ServerDbus) disposeApp(app *App) {
	for _, doc := range app.docs {
		s.disposeDocument(app, doc)
	}

	app.docs = nil
	delete(s.apps, app.name)

	if len(s.apps) == 0 {
		os.Exit(0)
	}
}

func (s *ServerDbus) disposeDocument(app *App, doc *DocumentDbus) {
	p := s.documentDbusPath(app, doc)
	s.transport.unexport(doc, p)
}

func (s *ServerDbus) Dispose(appid string, path string) *dbus.Error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	if app := s.apps[appid]; app != nil {
		app.mutex.Lock()
		defer app.mutex.Unlock()

		cpath := filepath.Clean(path)

		if doc := app.docs[cpath]; doc != nil {
			s.disposeDocument(app, doc)
			delete(app.docs, cpath)

			if len(app.docs) == 0 {
				s.disposeApp(app)
			}
		}
	}

	return nil
}
