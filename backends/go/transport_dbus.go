package main

import (
	"errors"
	"fmt"
	"github.com/guelfey/go.dbus"
	"github.com/guelfey/go.dbus/introspect"
)

type TransportDbus struct {
	conn   *dbus.Conn
	server *ServerDbus
}

type ObjectDbus interface {
	Introspect() *introspect.Node
}

func NewDbusError(name string, format string, args ...interface{}) *dbus.Error {
	return &dbus.Error{
		Name: "org.gnome.CodeAssist.Error." + name,
		Body: []interface{}{
			fmt.Sprintf(format, args...),
		},
	}
}

func (t *TransportDbus) unexport(obj ObjectDbus, p dbus.ObjectPath) {
	n := obj.Introspect()

	for _, i := range n.Interfaces {
		t.conn.Unexport(p, i.Name)
	}

	t.conn.Unexport(p, "org.freedesktop.DBus.Introspectable")
}

func (t *TransportDbus) export(obj ObjectDbus, p dbus.ObjectPath) error {
	n := obj.Introspect()

	for _, i := range n.Interfaces {
		if err := t.conn.Export(obj, p, i.Name); err != nil {
			return err
		}
	}

	if err := t.conn.Export(introspect.NewIntrospectable(n), p, "org.freedesktop.DBus.Introspectable"); err != nil {
		return err
	}

	return nil
}

func NewTransportDbus() (Transport, error) {
	conn, err := dbus.SessionBus()

	if err != nil {
		return nil, err
	}

	reply, err := conn.RequestName("org.gnome.CodeAssist.go", dbus.NameFlagDoNotQueue)

	if err != nil {
		return nil, err
	}

	if reply != dbus.RequestNameReplyPrimaryOwner {
		return nil, errors.New("org.gnome.CodeAssist.go already taken")
	}

	t := &TransportDbus{
		conn: conn,
	}

	server, err := NewServerDbus(t)

	if err != nil {
		return nil, err
	}

	t.server = server
	return t, nil
}

func (t *TransportDbus) Run() {
	select {}
}

func init() {
	RegisterTransport("dbus", NewTransportDbus)
}
