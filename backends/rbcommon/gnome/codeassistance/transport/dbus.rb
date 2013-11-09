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

module Gnome; end

module Gnome::CodeAssistance
    class Service
        class << self; attr_reader :language; end
        @language = nil

        def initialize(id, name, document)
            @id = id
            @name = name
            @document = document
        end

        def data_path(path, unsaved)
            unsaved.each do |u|
                return u.data_path if u.path == path
            end

            return path
        end

        def new_document(*args)
            @document.call(*args)
        end

        def parse(path, cursor, unsaved, options, doc)
            return doc
        end

        def dispose(doc)
        end
    end

    class Document < DBus::Object
        dbus_interface 'org.gnome.CodeAssist.Document' do
        end

        def self.extended_modules
            (class << self; self end).included_modules
        end

        def initialize(*args)
        end

        def self.new(path, *args)
            obj = self.allocate

            DBus::Object.instance_method(:initialize).bind(obj).call(path)
            self.instance_method(:initialize).bind(obj).call(*args)

            obj
        end
    end

    module Services
        module Diagnostics
            def self.extended(base)
                base.instance_eval do
                    dbus_interface 'org.gnome.CodeAssist.Diagnostics' do
                        dbus_method :Diagnostics, "out diagnostics:a(ua((x(xx)(xx))s)a(x(xx)(xx))s)" do
                            return [diagnostics.collect { |d| d.to_tuple }]
                        end
                    end
                end
            end
        end
    end

    class Server < DBus::Object
        class App
            attr_accessor :id, :name, :docs, :ids, :nextid, :service

            def initialize
                @id = 0
                @name = ''
                @docs = {}
                @ids = {}
                @nextid = 0
                @service = nil
            end
        end

        dbus_interface 'org.gnome.CodeAssist.Service' do
            dbus_method :SupportedServices, "out services:as" do
                app(@sender)

                [@services]
            end

            dbus_method :Parse, "in path:s, in cursor:x, in unsaved:a(ss), in options:a{sv}, out document:o" do |path, cursor, unsaved, options|
                begin
                    return parse(path, cursor, unsaved, options)
                rescue Exception => e
                    p e
                    raise
                end
            end

            dbus_method :Dispose, "in path:s" do |path|
                a = app(@sender)

                if a.ids.include?(path)
                    id = a.ids[path]
                    dispose_document(a.docs[id])

                    a.docs.delete(id)
                    a.ids.delete(path)

                    if a.ids.length == 0
                        dispose_app(@sender)
                    end
                end
            end
        end

        def initialize(bus, name, path, service, document)
            super(path)

            @apps = {}
            @nextid = 0

            @bus = bus
            @server = @bus.request_service(name)
            @appservice = service
            @document = document

            extract_services

            @server.export(self)

            dbus_service = @bus.service('org.freedesktop.DBus')
            dbus = dbus_service.object('/org/freedesktop/DBus')
            dbus.default_iface = 'org.freedesktop.DBus'
            dbus.introspect

            dbus.on_signal('NameOwnerChanged') do |_, oldname, newname|
                if newname.empty?
                    dispose_app(oldname)
                end
            end
        end

        def parse(path, cursor, unsaved, options)
            a = app(@sender)
            doc = nil

            if a.ids.include?(path)
                docid = a.ids[path]
                doc = a.docs[docid]
            end

            unsaved = unsaved.collect{ |u| UnsavedDocument.new(u[0], u[1]) }
            doc = a.service.parse(path, cursor, unsaved, options, doc)

            if doc == nil
                raise DBus::Error.new("Failed to parse document")
            end

            unless a.ids.include?(path)
                docid = a.nextid

                a.ids[path] = docid
                a.docs[docid] = doc

                @server.export(doc)
                a.nextid += 1
            end

            return [doc.path]
        end

        def document_path(a, docid)
            "#{@path}/#{a.id}/documents/#{docid}"
        end

        def dispose_document(a, doc)
            a.service.dispose(doc)
            @server.unexport(doc)
        end

        def dispose_app(appid)
            if @apps.include?(appid)
                a = @apps[appid]

                a.docs.each do |docid, doc|
                    dispose_document(a, doc)
                end

                @apps.delete(appid)

                if @apps.length == 0
                    exit(0)
                end
            end
        end

        def app(appid)
            unless @apps.include?(appid)
                a = App.new()
                a.id = @nextid
                a.name = appid

                a.service = @appservice.new(a.id, a.name, Proc.new do |*args|
                    @document.new(document_path(a, a.nextid), *args)
                end)

                @apps[a.name] = a
                @nextid += 1

                return a
            end

            return @apps[appid]
        end

        def dispatch(msg)
            @sender = msg.sender
            super(msg)
        end

        def extract_services
            @services = ['org.gnome.CodeAssist.Document']

            ex = @document.extended_modules

            Services.constants.each do |s|
                if ex.include?(Services.const_get(s))
                    @services << 'org.gnome.CodeAssist.' + s.to_s()
                end
            end
        end
    end

    class Transport
        def initialize(service, document)
            @bus = DBus::SessionBus.instance

            name = 'org.gnome.CodeAssist.' + service.language
            path = '/org/gnome/CodeAssist/' + service.language

            @server = Server.new(@bus, name, path, service, document)
        end

        def run
            main = DBus::Main.new
            main << @bus
            main.run
        end
    end
end

# vi:ts=4:et
