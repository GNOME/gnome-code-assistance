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

oursass = File.join(File.dirname(__FILE__), 'gems', 'sass-3.2.12', 'init.rb')

if FileTest.exist?(oursass)
    require oursass
else
    require 'sass'
end

class CssParser < Sass::SCSS::CssParser
    def self.expected(scanner, expected, line)
        pos = scanner.pos
        nlpos = scanner.string.rindex("\n", pos)

        begin
            super(scanner, expected, line)
        rescue Sass::SyntaxError => e
            e.modify_backtrace({:column => pos - nlpos})
            raise e
        end
    end

    @sass_script_parser = Class.new(Sass::Script::CssParser)
    @sass_script_parser.send(:include, Sass::SCSS::ScriptParser)
end

module Gnome::CodeAssistance
    module Css
        class Service < Service
            @@language = 'css'

            def parse(doc, options)
                doc.diagnostics = []

                f = File.new(doc.data_path, 'r')

                begin
                    parser = CssParser.new(f.read(), doc.path)
                    parser.parse()
                rescue Sass::SyntaxError => e
                    doc.diagnostics = [make_diagnostic(e)]
                end

                f.close
            end

            def make_diagnostic(e)
                loc = SourceLocation.new(e.sass_line, e.sass_backtrace.first[:column] || 0)
                Diagnostic.new(Diagnostic::Severity::ERROR, [], [loc.to_range], e.to_s)
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
