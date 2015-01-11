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

from gi.repository import GLib

import dbus, dbus.service, dbus.mainloop.glib
import inspect, sys, os

from gnome.codeassistance import types

class Document(dbus.service.Object):
    """Base Document interface.

    Implementations should inherit from this base class which implements the
    org.gnome.CodeAssist.v1.Document interface.
    """

    interface = 'org.gnome.CodeAssist.v1.Document'

    def __init__(self):
        super(Document, self).__init__()

        self.id = 0
        self.path = ''
        self.client_path = ''
        self.data_path = ''
        self.cursor = types.SourceLocation()

    def Introspect(self, object_path, connection):
        ret = super(Document, self).Introspect(object_path, connection)

        # This is so nasty, I don't have words for it. I'm sincerely sorry!
        # If the Document interface gets any methods, please remove this
        # atrocity!!
        if not 'org.gnome.CodeAssist.v1.Document' in ret:
            find = "<interface name=\"org.gnome.CodeAssist.v1.Diagnostics\">"
            ret = ret.replace(find, "<interface name=\"org.gnome.CodeAssist.v1.Document\"/>\n  " + find)

        return ret

class Diagnostics(dbus.service.Object):
    """Diagnostics interface.

    Implementations can inherit from this class to implement the
    org.gnome.CodeAssist.v1.Diagnostics interface. Diagnostics are served from
    the .diagnostics field which should be set to a list of types.Diagnostic
    objects.
    """

    interface = 'org.gnome.CodeAssist.v1.Diagnostics'

    def __init__(self):
        super(Diagnostics, self).__init__()
        self.diagnostics = []

    @dbus.service.method(interface,
                         in_signature='', out_signature='a(ua((x(xx)(xx))s)a(x(xx)(xx))s)')
    def Diagnostics(self):
        return [d.to_tuple() for d in self.diagnostics]

class Service:
    language = None

    def parse(self, doc, options):
        """parse a single document.

        parse should be implemented to parse the file located at @path
        into the provided @doc. @data_path contains the path of the actual data
        needed to be parsed. If the document is in an unmodified state, then
        @data_path will be equal to @path. However, if the document is being
        edited, then @data_path will be a temporary file containing the modified
        document. @cursor is the current location of the cursor in the document
        being edited. The @cursor can be used to gather autocompletion
        information. Finally @options contains backend specific options provided
        by a client.

        doc: the document needing to be parsed.

        options: an implementation specific set of options passed by the client

        """
        pass

    def dispose(self, doc):
        pass

class Project:
    def parse_all(self, doc, docs, options):
        """parse multiple documents.

        parse_all potentially parses multiple documents at the same time.
        This can be implemented by backends which parse multiple documents at
        the same time to complete a parse. This is useful for example for
        parsers that can provide semantic diagnostics based on types of a
        complete unit instead of only providing syntactic analysis. Examples of
        languages that should support this are C, Vala or Go (i.e. languages
        with static typing).

        doc: the primary document needing to be parsed. This is the document
        requesting analysis and can be used as the starting point for
        analysis.

        docs: a list of documents which the client is interested in (i.e.
        these are usually the documents open in the client). An implementation
        can provide information for the subset of these docs that were analysed
        in the process of analysing doc. Note that docs always includes at
        least doc.

        options: an implementation specific set of options passed by the client

        Implementations should do the following steps:
          1) Determine all the documents belonging to the project of doc
          2) Parse and analyse these documents in the context of doc
          3) Gather and supply information to the intersection between documents
             in docs and the project documents that were processed.
          4) Return the subset of documents which have newly processed information

        """
        pass

class Completion:
    def complete(self, doc, options):
        """compute completions at the cursor of a document.

        @doc is an object of the register document type and should be populated
        by the implementation.
        """
        pass

class ProjectCompletion:
    def complete_all(self, doc, docs, options):
        """compute completions at the cursor of a document.

        @doc is an object of the register document type and should be populated
        by the implementation.
        """
        pass

class Server(dbus.service.Object):
    class App:
        def __init__(self):
            self.id = 0
            self.name = ''

            self.docs = {}
            self.nextid = 0
            self.service = None

    def __init__(self, bus, path):
        super(Server, self).__init__(bus, path)

        self.apps = {}
        self.nextid = 0

        bus.add_signal_receiver(self.on_name_lost,
                                signal_name='NameOwnerChanged',
                                dbus_interface='org.freedesktop.DBus',
                                path='/org/freedesktop/DBus')

    def run(self, service, document):
        self.service = service
        self.document = document

        # Export dummy document for introspection purposes
        self.dummy = self.document()
        self.dummy.add_to_connection(self._connection, self._object_path + '/document')

        ml = GLib.MainLoop()
        ml.run()

    def on_name_lost(self, name, oldowner, newowner):
        if newowner != '':
            return

        try:
            app = self.apps[oldowner]
        except KeyError:
            return

        self.dispose_app(app)

    def make_app(self, appid):
        app = Server.App()

        app.id = self.nextid
        app.name = appid
        app.service = self.service()

        self.apps[appid] = app
        self.nextid += 1

        return app

    def ensure_app(self, appid):
        try:
            return self.apps[appid]
        except KeyError:
            return self.make_app(appid)

    def make_document(self, app, path, client_path):
        doc = self.document()

        doc.id = app.nextid
        doc.client_path = client_path
        doc.path = path

        app.nextid += 1
        app.docs[path] = doc

        objpath = self._object_path + '/' + str(app.id) + '/documents/' + str(doc.id)
        doc.add_to_connection(self._connection, objpath)

        return doc

    def ensure_document(self, app, path, data_path, cursor=None):
        npath = (path and os.path.normpath(path))

        try:
            doc = app.docs[npath]
        except KeyError:
            doc = self.make_document(app, npath, path)

        doc.data_path = (data_path or path)
        doc.cursor = cursor or types.SourceLocation()

        return doc

    def dispose(self, app, path):
        try:
            doc = app.docs[path]
        except KeyError:
            return

        self.dispose_document(app, doc)
        del app.docs[path]

        if len(app.docs) == 0:
            self.dispose_app(app)

    def dispose_document(self, app, doc):
        app.service.dispose(doc)
        doc.remove_from_connection()

    def dispose_app(self, app):
        for doc in app.docs:
            self.dispose_document(app, app.docs[doc])

        del self.apps[app.name]

        if len(self.apps) == 0:
            GLib.idle_add(lambda: sys.exit(0))

class ServeService(dbus.service.Object):
    @dbus.service.method('org.gnome.CodeAssist.v1.Service',
                         in_signature='ss(xx)a{sv}', out_signature='o',
                         sender_keyword='sender')
    def Parse(self, path, data_path, cursor, options, sender=None):
        app = self.ensure_app(sender)
        doc = self.ensure_document(app, path, data_path, types.SourceLocation.from_tuple(cursor))

        app.service.parse(doc, options)

        return doc._object_path

    @dbus.service.method('org.gnome.CodeAssist.v1.Service',
                         in_signature='s', out_signature='',
                         sender_keyword='sender')
    def Dispose(self, path, sender=None):
        path = os.path.normpath(path)

        try:
            app = self.apps[sender]
        except KeyError:
            return

        self.dispose(app, path)

class ServeProject(dbus.service.Object):
    @dbus.service.method('org.gnome.CodeAssist.v1.Project',
                         in_signature='sa(ss)(xx)a{sv}', out_signature='a(so)',
                         sender_keyword='sender')
    def ParseAll(self, path, documents, cursor, options, sender=None):
        app = self.ensure_app(sender)
        doc = self.ensure_document(app, path, '', types.SourceLocation.from_tuple(cursor))

        opendocs = [types.OpenDocument.from_tuple(d) for d in documents]
        docs = [self.ensure_document(app, d.path, d.data_path) for d in opendocs]

        parsed = app.service.parse_all(doc, docs, options)

        return [types.RemoteDocument(d.client_path, d._object_path).to_tuple() for d in parsed]

class ServeCompletion(dbus.service.Object):
    @dbus.service.method('org.gnome.CodeAssist.v1.Completion',
                         in_signature='ss(xx)a{sv}', out_signature='a' + types.Completion.signature,
                         sender_keyword='sender')
    def Complete(self, path, data_path, cursor, options, sender=None):
        app = self.ensure_app(sender)
        doc = self.ensure_document(app, path, data_path, types.SourceLocation.from_tuple(cursor))

        return [x.to_tuple() for x in app.service.complete(doc, options)]

class ServeProjectCompletion(dbus.service.Object):
    @dbus.service.method('org.gnome.CodeAssist.v1.ProjectCompletion',
                         in_signature='sa(ss)(xx)a{sv}', out_signature='a' + types.Completion.signature,
                         sender_keyword='sender')
    def CompleteAll(self, path, documents, cursor, options, sender=None):
        app = self.ensure_app(sender)
        doc = self.ensure_document(app, path, '', types.SourceLocation.from_tuple(cursor))

        opendocs = [types.OpenDocument.from_tuple(d) for d in documents]
        docs = [self.ensure_document(app, d.path, d.data_path) for d in opendocs]

        return [x.to_tuple() for x in app.service.complete_all(doc, docs, options)]

class Transport():
    def __init__(self, service, document, srvtype=Server):
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

        name = 'org.gnome.CodeAssist.v1.' + service.language
        path = '/org/gnome/CodeAssist/v1/' + service.language

        bus = dbus.SessionBus()
        servercls = self.make_server_cls(service)

        self.name = dbus.service.BusName(name, bus)
        self.server = servercls(bus, path)
        self.service = service
        self.document = document

    def make_server_cls(self, service):
        types = {
            Service: ServeService,
            Project: ServeProject,
            Completion: ServeCompletion,
            ProjectCompletion: ServeProjectCompletion
        }

        bases = inspect.getmro(service)[1:]
        sb = []

        for b in bases:
            try:
                sb.append(types[b])
            except KeyError:
                pass

        if not ServeService in sb:
            raise ValueError("service should at least inherit from transport.Service")

        sb.append(Server)

        return type('TheServerType', tuple(sb), {})

    def run(self):
        self.server.run(self.service, self.document)

# ex:ts=4:et:
