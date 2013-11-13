# gnome code assistance common ruby
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

require 'dbus'
require 'gnome/codeassistance/types'
require 'pathname'

module DBus
    class ErrorMessage
        # Override this so that we get meaningful dbus error replies. glib
        # expects a simple string, while the ruby dbus bindings give the
        # backtrace as an array of strings. Doing so prevents GDBus from
        # converting the error message to a nice GError, which is what vala
        # uses.
        def self.from_exception(ex)
            name = if ex.is_a? DBus::Error
                ex.name
            else
                "org.freedesktop.DBus.Error.Failed"
            end

            bt = ex.backtrace.collect { |x| "\tfrom #{x}" }.join("\n")
            description = "#{ex.message}\n#{bt}"

            if not ex.is_a?(DBus::Error)
                puts description
                puts
            end

            self.new(name, description)
        end
    end
end

module Gnome; end
module Gnome::CodeAssistance; end

class Module
    def dbus_interface(name, &b)
        metaclass = class << self; self; end

        metaclass.send(:define_method, :included) do |base|
            base.instance_eval do
                dbus_interface(name) do
                    base.instance_eval(&b)
                end
            end
        end
    end
end

# Dbus interfaces for documents and servers
module Gnome::CodeAssistance::DBus
    class Document < DBus::Object
        def initialize(path, doc)
            super(path)
            @_doc = doc
        end
    end

    module Diagnostics
        dbus_interface 'org.gnome.CodeAssist.v1.Diagnostics' do
            dbus_method :Diagnostics, "out diagnostics:a(ua((x(xx)(xx))s)a(x(xx)(xx))s)" do
                return [@_doc.diagnostics.collect { |d| d.to_tuple }]
            end
        end
    end

    module Service
        dbus_interface 'org.gnome.CodeAssist.v1.Service' do
            dbus_method :Parse, "in path:s, in data_path:s, in cursor:(xx), in options:a{sv}, out document:o" do |path, data_path, cursor, options|
                app = ensure_app(@sender)
                doc = ensure_document(app, path, data_path, Gnome::CodeAssistance::SourceLocation.from_tuple(cursor))

                app.service.parse(doc, options)

                return doc._dbus.path
            end

            dbus_method :Dispose, "in path:s" do |path|
                app = @apps[@sender]

                dispose(app, normpath(path)) if app
            end
        end
    end

    module Project
        dbus_interface 'org.gnome.CodeAssist.v1.Project' do
            dbus_method :ParseAll, "in path:s, in docs:a(ss), in cursor:(xx), in options:a{sv}, out documents:a(so)" do |path, cursor, documents, options|
                app = ensure_app(@sender)
                doc = ensure_document(app, path, '', Gnome::CodeAssistance::SourceLocation.from_tuple(cursor))

                opendocs = documents.collect { |d| Gnome::CodeAssistance::OpenDocument.from_tuple(d) }
                docs = opendocs.collect { |d| ensure_document(app, d.path, d.data_path) }

                parsed = app.service.parse_all(doc, docs, options)

                return parsed.collect { |d| Gnome::CodeAssistance::RemoteDocument.new(d.client_path, d._dbus.path).to_tuple }
            end
        end
    end
end

# Services to be implemented by documents
module Gnome::CodeAssistance::Services
    module Diagnostics
        def diagnostics
            @diagnostics || []
        end

        def diagnostics=(val)
            @diagnostics = val
        end

        def self.included(base)
            base._dbus.send(:include, Gnome::CodeAssistance::DBus::Diagnostics)
        end
    end
end

# Classes to be subclassed or modules to be included
module Gnome::CodeAssistance
    class Service
        @@language = nil

        def self.language
            @@language
        end

        def parse(doc, options)
        end

        def dispose(doc)
        end
    end

    module Project
        def parse_all(doc, docs, options)
        end
    end

    class Document
        attr_accessor :id, :path, :data_path, :client_path, :cursor, :_dbus

        @@_dbus = Gnome::CodeAssistance::DBus::Document

        def self._dbus
            @@_dbus
        end

        def self.new(path)
            obj = self.allocate
            obj._initialize_dbus(path)

            obj.send(:initialize)

            obj
        end

        def _initialize_dbus(path)
            @_dbus = @@_dbus.new(path, self)
        end
    end

    class Server < ::DBus::Object
        include DBus::Service

        class App
            attr_accessor :id, :name, :docs, :nextid, :service

            def initialize
                @id = 0
                @name = ''

                @docs = {}
                @nextid = 0
                @service = nil
            end
        end

        def initialize(name, path, service, document)
            super(path)

            @apps = {}
            @nextid = 0

            bus = ::DBus::SessionBus.instance

            @server = bus.request_service(name)

            @appservice = service
            @document = document

            @server.export(self)

            # Export dummy document
            @dummy = document.new(path + '/document')
            @server.export(@dummy._dbus)

            dbus_service = bus.service('org.freedesktop.DBus')
            dbus = dbus_service.object('/org/freedesktop/DBus')
            dbus.default_iface = 'org.freedesktop.DBus'
            dbus.introspect

            dbus.on_signal('NameOwnerChanged') do |_, oldname, newname|
                if newname.empty?
                    app = @apps[oldname]
                    dispose_app(app) if app
                end
            end
        end

        def make_app(appid)
            app = App.new
            app.id = @nextid
            app.name = appid
            app.service = @appservice.new

            @apps[appid] = app
            @nextid += 1

            app
        end

        def ensure_app(appid)
            @apps[appid] or make_app(appid)
        end

        def make_document(app, path, client_path)
            docid = app.nextid
            docpath = "#{@path}/#{app.id}/documents/#{docid}"

            doc = @document.new(docpath)
            doc.id = docid
            doc.client_path = client_path
            doc.path = path

            app.nextid += 1
            app.docs[path] = doc

            @server.export(doc._dbus)

            doc
        end

        def ensure_document(app, path, data_path, cursor=nil)
            npath = normpath(path)

            doc = app.docs[npath] || make_document(app, npath, path)

            doc.data_path = data_path || path
            doc.cursor = cursor || SourceLocation()

            doc
        end

        def dispose(app, path)
            doc = app.docs[path]

            if doc
                dispose_document(app, doc)
                app.docs.delete(path)

                dispose_app(app) if app.docs.empty?
            end
        end

        def dispose_document(app, doc)
            app.service.dispose(doc)
            @server.unexport(doc._dbus)
        end

        def dispose_app(app)
            app.docs.each do |_, doc|
                dispose_document(app, doc)
            end

            @apps.delete(app.name)

            if @apps.empty?
                exit(0)
            end
        end

        def normpath(path)
            return Pathname.new(path).cleanpath.to_s if path
            path
        end

        def dispatch(msg)
            @sender = msg.sender
            super(msg)
        end
    end

    class Transport
        def initialize(service, document)
            name = 'org.gnome.CodeAssist.v1.' + service.language
            path = '/org/gnome/CodeAssist/v1/' + service.language

            allmods = Gnome::CodeAssistance.constants.collect { |x| Gnome::CodeAssistance.const_get(x) }

            # Mixin relevant dbus services into the server class
            service.included_modules.each do |mod|
                next unless allmods.include?(mod)

                Server.send(:include, DBus.const_get(mod.to_s.split('::').last))
            end

            @server = Server.new(name, path, service, document)
        end

        def run
            main = ::DBus::Main.new
            main << ::DBus::SessionBus.instance
            main.run
        end
    end
end

# vi:ts=4:et
