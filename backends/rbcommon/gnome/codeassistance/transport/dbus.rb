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

module Gnome; end
module Gnome::CodeAssistance; end


class Gnome::CodeAssistance::Service
    class << self; attr_reader :language; end
    @language = nil

    def parse(doc, options)
    end

    def dispose(doc)
    end
end

module Gnome::CodeAssistance::DBus
    class Document < DBus::Object
        def initialize(path, doc)
            super(path)
            @_doc = doc
        end
    end

    module Diagnostics
        def self.included(base)
            base.instance_eval do
                dbus_interface 'org.gnome.CodeAssist.Diagnostics' do
                    dbus_method :Diagnostics, "out diagnostics:a(ua((x(xx)(xx))s)a(x(xx)(xx))s)" do
                        return [@_doc.diagnostics.collect { |d| d.to_tuple }]
                    end
                end
            end
        end
    end
end

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

module Gnome::CodeAssistance::Servers
    module Service
        def dispose
            a = app(@sender)

            if path.length != 0
                path = Pathname.new(path).cleanpath.to_s
            end

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

        def self.included(base)
            base.instance_eval do
                dbus_interface 'org.gnome.CodeAssist.Service' do
                    dbus_method :Parse, "in path:s, in cursor:x, in data_path:s, in options:a{sv}, out document:o" do |path, cursor, data_path, options|
                        app = ensure_app(@sender)
                        doc = ensure_document(app, path, data_path, cursor)

                        app.service.parse(doc, options)

                        return doc.path
                    end

                    dbus_method :Dispose, "in path:s" do |path|
                        if @apps.include?(@sender)
                            dispose(@apps[@sender], Pathname.new(path).cleanpath.to_s)
                        end
                    end
                end
            end
        end
    end

    module Project
        def self.included(base)
            base.instance_eval do
                dbus_interface 'org.gnome.CodeAssist.Project' do
                    dbus_method :ParseProject, "in path:s, in cursor:x, in docs:a(ss), in options:a{sv}, out documents:a(so)" do |path, cursor, docs, options|
                        begin
                            return parse_project(path, cursor, docs, options)
                        rescue Exception => e
                            p e
                            raise
                        end
                    end
                end
            end
        end
    end
end

module Gnome::CodeAssistance
    class Service
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
        @@_dbus = Gnome::CodeAssistance::DBus::Document

        def self._dbus
            @@_dbus
        end

        def initialize(path)
            @_dbus = @@_dbus.new(path, self)
        end
    end
end

class Gnome::CodeAssistance::Server < DBus::Object
    class App
        attr_accessor :id, :name, :docs, :ids, :nextid, :service

        def initialize
            @id = 0
            @name = ''
            @docs = {}
            @nextid = 0
            @service = nil
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

            a.service = @appservice.new

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
end

class Gnome::CodeAssistance::Transport
    def initialize(service, document)
        @bus = DBus::SessionBus.instance

        name = 'org.gnome.CodeAssist.' + service.language
        path = '/org/gnome/CodeAssist/' + service.language

        @server = srvtype.new(@bus, name, path, service, document)
    end

    def run
        main = DBus::Main.new
        main << @bus
        main.run
    end
end

# vi:ts=4:et
