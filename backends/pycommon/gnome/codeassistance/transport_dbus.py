# gnome code assistance common
# Copyright (C) 2013  Jesse van den Kieboom <jessevdk@gnome.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

from gi.repository import GObject, GLib

import dbus, dbus.service, dbus.mainloop.glib
import inspect, sys, os

from gnome.codeassistance import types

class Document(dbus.service.Object):
    interface = 'org.gnome.CodeAssist.Document'

class Diagnostics(dbus.service.Object):
    interface = 'org.gnome.CodeAssist.Diagnostics'

    def diagnostics(self):
        return []

    @dbus.service.method(interface,
                         in_signature='', out_signature='a(ua((x(xx)(xx))s)a(x(xx)(xx))s)')
    def Diagnostics(self):
        return [d.to_tuple() for d in self.diagnostics()]

DocumentInterfaces = [Document, Diagnostics]

class Service:
    language = None
    services = []

    def __init__(self, id, name, document):
        self.id = id
        self.document = document

    def data_path(self, path, unsaved):
        for u in unsaved:
            if u.path == path:
                return u.data_path

        return path

class Server(dbus.service.Object):
    apps = {}
    nextid = 0

    class App:
        id = 0
        name = ''

        docs = {}
        ids = {}
        nextid = 0

    def __init__(self, bus, path, service, document):
        dbus.service.Object.__init__(self, bus, path)
        self.service = service
        self.document = document

        bus.add_signal_receiver(self.on_name_lost,
                                signal_name='NameOwnerChanged',
                                dbus_interface='org.freedesktop.DBus',
                                path='/org/freedesktop/DBus')

    def on_name_lost(self, name, oldowner, newowner):
        if newowner == '' and oldowner in self.apps:
            app = self.apps[oldowner]
            self.dispose(app)

            if len(self.apps) == 0:
                GLib.idle_add(self.do_exit)

    def do_exit(self):
        sys.exit(0)

    def app(self, appid):
        if not appid in self.apps:
            app = Server.App()

            app.id = self.nextid
            app.name = appid
            app.service = self.service(app.id, app.name, self.document)

            self.apps[appid] = app
            self.nextid += 1

            return app
        else:
            return self.apps[appid]

    @dbus.service.method('org.gnome.CodeAssist.Service',
                         in_signature='', out_signature='as',
                         sender_keyword='sender')
    def SupportedServices(self, sender=None):
        app = self.app(sender)
        ret = []

        bases = inspect.getmro(self.document)

        for i in DocumentInterfaces:
            if i in bases:
                ret.append(i.interface)

        ret += self.service.services
        return ret

    @dbus.service.method('org.gnome.CodeAssist.Service',
                         in_signature='sxa(ss)a{sv}', out_signature='o',
                         sender_keyword='sender')
    def Parse(self, path, cursor, unsaved, options, sender=None):
        path = os.path.normpath(path)

        app = self.app(sender)
        doc = None

        if path in app.ids:
            doc = app.docs[app.ids[path]]

        unsaved = [types.UnsavedDocument(os.path.normpath(u[0]), os.path.normpath(u[1])) for u in unsaved]

        doc = app.service.parse(path, cursor, unsaved, options, doc)

        if not path in app.ids:
            doc.add_to_connection(self._connection, self._object_path + '/' + str(app.id) + '/documents/' + str(app.nextid))

            app.ids[path] = app.nextid
            app.docs[app.nextid] = doc

            app.nextid += 1

        return doc._object_path

    def dispose(self, app, path=None):
        if path is None:
            path = list(app.ids)
        else:
            if path in app.ids:
                path = [path]
            else:
                return

        for p in path:
            id = app.ids[p]
            doc = app.docs[id]

            app.service.dispose(doc)

            doc.remove_from_connection()

            del app.docs[id]
            del app.ids[p]

        if len(app.ids) == 0:
            del self.apps[app.name]

    @dbus.service.method('org.gnome.CodeAssist.Service',
                         in_signature='s', out_signature='',
                         sender_keyword='sender')
    def Dispose(self, path, sender=None):
        path = os.path.normpath(path)

        if sender in self.apps:
            app = self.apps[sender]
            self.dispose(app, path)

class Transport():
    def __init__(self, service, document):
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

        name = 'org.gnome.CodeAssist.' + service.language
        path = '/org/gnome/CodeAssist/' + service.language

        bus = dbus.SessionBus()

        self.name = dbus.service.BusName(name, bus)
        self.server = Server(bus, path, service, document)

    def run(self):
        ml = GObject.MainLoop()
        ml.run()

# ex:ts=4:et:
