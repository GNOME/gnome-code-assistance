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

require 'ripper'

module Gnome::CodeAssistance::Ruby
    class Parser < Ripper
        class Error
            attr_accessor :line, :column, :message

            def initialize(line, column, message)
                @line = line
                @column = column
                @message = message
            end

            def to_s
                "#{line}.#{column}: #{message}"
            end
        end

        class ParseError < StandardError
            attr_accessor :errors

            def initialize(errors)
                @errors = errors

                super(to_s)
            end

            def to_s
                @errors.collect { |x| x.to_s }.join("\n")
            end
        end

        attr_reader :errors

        def initialize(*args)
            super

            @errors = []
        end

        def parse(*args)
            ret = super

            if @errors.length != 0
                raise ParseError.new(@errors)
            end

            return ret
        end

        def add_error(message)
            @errors << Error.new(lineno, column, message)
        end

        def on_alias_error(varname)
            # Happens when you try to alias towards a $n variable (e.g. alias $FOO = $1)
            add_error("cannot alias #{varname} to number variables")
            super
        end

        def on_assign_error(varname)
            # Happens when assignment cannot happen (e.g. $` = 1)
            add_error("cannot assign to #{varname}")
            super
        end

        def on_class_name_error(classname)
            # Happens when a class name is invalid (e.g. class foo; end)
            add_error("invalid class name #{classname}")
            super
        end

        def on_param_error(name)
            # Happens when a parameter name is invalid (e.g. def foo(A); end)
            add_error("invalid parameter name #{name}")
            super
        end

        def on_parse_error(message)
            add_error(message)
            super
        end
    end
end

# vi:ts=4:et
