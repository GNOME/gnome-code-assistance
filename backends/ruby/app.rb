# gnome code assistance ruby backend
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

require 'gnome/codeassistance/transport'
require 'gnome/codeassistance/ruby/parser'

module Gnome::CodeAssistance::Ruby
    class Service < Gnome::CodeAssistance::Service
        @language = 'ruby'

        def parse(path, cursor, unsaved, options, doc)
            dp = data_path(path, unsaved)

            f = File.new(dp, 'r')

            if doc == nil
                doc = new_document
            end

            begin
                Parser.parse(f, path)
            rescue Parser::ParseError => e
                doc.errors = e.errors.collect { |e| make_diagnostic(e) }
            end

            return doc
        end

        def make_diagnostic(e)
            loc = Gnome::CodeAssistance::SourceLocation.new(e.line, e.column)
            Gnome::CodeAssistance::Diagnostic.new(Gnome::CodeAssistance::Diagnostic::Severity::ERROR, [], [loc.to_range], e.message)
        end
    end

    class Document < Gnome::CodeAssistance::Document
        extend Gnome::CodeAssistance::Services::Diagnostics

        attr_accessor :errors

        def initialize
            @errors = []
        end

        def diagnostics
            @errors
        end
    end

    class Application
        def self.run()
            Gnome::CodeAssistance::Transport.new(Service, Document).run()
        end
    end
end

# ex:ts=4:et:
