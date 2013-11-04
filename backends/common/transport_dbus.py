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

from gi.repository import GObject

import dbus
import dbus.service
import dbus.mainloop.glib

class App:
    id = 0
    name = ''

    docs = {}
    ids = {}
    nextid = 0

class Document(dbus.service.Object):
    interface = 'org.gnome.CodeAssist.Document'

    def paths(self, ids):
        return []

    @dbus.service.method(interface,
                         in_signature='ax', out_signature='as')
    def Paths(self, ids):
        return self.paths(ids)

class Diagnostics(dbus.service.Object):
    interface = 'org.gnome.CodeAssist.Diagnostics'

    def diagnostics(self):
        return []

    @dbus.service.method(interface,
                         in_signature='', out_signature='a(ua((x(xxx)(xxx))s)a(x(xxx)(xxx))s)')
    def Diagnostics(self):
        return [d.to_tuple() for d in self.diagnostics()]

DocumentInterfaces = [Document, Diagnostics]

class Service(dbus.service.Object):
    apps = {}
    nextid = 0

    def __init__(self, service, bus, path):
        dbus.service.Object.__init__(self, bus, path)
        self.service = service

    def app(self, appid):
        if not appid in self.apps:
            app = App()
            app.id = self.nextid
            app.name = appid

            self.apps[appid] = app
            self.nextid += 1

            return app
        else:
            return self.apps[appid]

    @dbus.service.method('org.gnome.CodeAssist.Service',
                         in_signature='', out_signature='as')
    def SupportedServices(self):
        doc = self.service.document()
        ret = []

        for i in DocumentInterfaces:
            if isinstance(doc, i):
                ret.append(i.interface)

        print(ret)
        return ret

    @dbus.service.method('org.gnome.CodeAssist.Service',
                         in_signature='ssta(ssh)a{sv}', out_signature='o')
    def Parse(self, appid, path, cursor, unsaved, options):
        app = self.app(appid)
        doc = None

        if path in app.ids:
            doc = app.docs[app.ids[path]]

        doc = self.service.parse(appid, path, cursor, unsaved, options, doc)

        if not path in app.ids:
            doc.add_to_connection(self._connection, self._object_path + '/' + str(app.id) + '/documents/' + str(app.nextid))

            app.ids[path] = app.nextid
            app.docs[app.nextid] = doc

            app.nextid += 1

        return doc._object_path

    @dbus.service.method('org.gnome.CodeAssist.Service',
                         in_signature='ss', out_signature='')
    def Dispose(self, appid, path):
        self.service.dispose(appid, path)

        if appid in self.apps:
            app = self.apps[appid]

            if path in app.ids:
                id = app.ids[path]
                doc = app.docs[id]

                doc.remove_from_connection()

                del app.docs[id]
                del app.ids[path]

                if len(app.ids) == 0:
                    del self.apps[appid]

class Transport():
    def __init__(self, service):
        name = 'org.gnome.CodeAssist.' + service.language
        path = '/org/gnome/CodeAssist/' + service.language

        bus = dbus.SessionBus()

        self.name = dbus.service.BusName(name, bus)
        self.service = Service(service, bus, path)

    def run(self):
        ml = GObject.MainLoop()
        ml.run()

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

# ex:ts=4:et:
