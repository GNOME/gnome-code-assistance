package main

import (
	"sync"
)

type App struct {
	id   uint64
	name string

	documentIds map[string]uint64
	documents   map[uint64]interface{}

	service *Service

	nextid uint64
	mutex  sync.Mutex
}

func NewApp(id uint64, name string) *App {
	return &App{
		id:          id,
		name:        name,
		documentIds: make(map[string]uint64),
		documents:   make(map[uint64]interface{}),
		service:     NewService(),
	}
}

func (a *App) document(path string) interface{} {
	a.mutex.Lock()
	defer a.mutex.Unlock()

	if id, ok := a.documentIds[path]; ok {
		return a.documents[id]
	}

	return nil
}

func (a *App) insertDocument(path string, doc interface{}) uint64 {
	a.mutex.Lock()
	defer a.mutex.Unlock()

	for a.documents[a.nextid] != nil {
		a.nextid++
	}

	id := a.nextid
	a.nextid++

	a.documentIds[path] = id
	a.documents[id] = doc

	return id
}
