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

module Gnome::CodeAssistance
    module Ruby
        class Service < Service
            @@language = 'ruby'

            def parse(doc, options)
                doc.diagnostics = []

                f = File.new(doc.data_path, 'r')

                begin
                    Parser.parse(f, doc.path)
                rescue Parser::ParseError => e
                    doc.diagnostics = e.errors.collect { |e| make_diagnostic(e) }
                end

                f.close
            end

            def make_diagnostic(e)
                loc = SourceLocation.new(e.line, e.column)
                Diagnostic.new(Diagnostic::Severity::ERROR, [], [loc.to_range], e.message)
            end
        end

        class Document < Document
            include Services::Diagnostics
        end

        class Application
            def self.run()
                Transport.new(Service, Document).run()
            end
        end
    end
end

# ex:ts=4:et:
