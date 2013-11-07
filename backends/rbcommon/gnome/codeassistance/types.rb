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

module Gnome; end

module Gnome::CodeAssistance
    class UnsavedDocument
        attr_accessor :path, :data_path

        def initialize(path='', data_path='')
            @path = path
            @data_path = data_path
        end

        def to_s
            "<UnsavedDocument: #{@path}, #{@data_path}>"
        end
    end

    class SourceLocation
        attr_accessor :line, :column

        def initialize(line=0, column=0)
            @line = line
            @column = column
        end

        def to_s
            "#{@line}.#{@column}"
        end

        def to_range(file=0)
            s = SourceLocation.new(@line, @column)
            e = SourceLocation.new(@line, @column + 1)

            SourceRange.new(file, s, e)
        end

        def to_tuple
            return [@line, @column]
        end
    end

    class SourceRange
        attr_accessor :file, :start, :end

        def initialize(file=0, s=SourceLocation.new(), e=None)
            @file = file
            @start = s
            @end = e

            if e == nil
                @end = s
            end
        end

        def to_s
            "#{@start}-#{@end}"
        end

        def to_range
            self
        end

        def to_tuple
            return [@file, @start.to_tuple, @end.to_tuple]
        end
    end

    class Fixit
        attr_accessor :location, :replacement

        def initialize(location=SourceRange.new, replacement='')
            @location = location
            @replacement = replacement
        end

        def to_s
            "<Fixit: #{@location}: #{@replacement}"
        end

        def to_tuple
            return [@location.to_tuple(), @replacement]
        end
    end

    class Diagnostic
        module Severity
            NONE = 0
            INFO = 1
            WARNING = 2
            DEPRECATED = 3
            ERROR = 4
            FATAL = 5
        end

        def initialize(severity=Severity::NONE, fixits=[], locations=[], message='')
            @severity = severity
            @fixits = fixits
            @locations = locations
            @message = message
        end

        def to_s
            "<Diagnostic: #{@severity}, #{@fixits}, #{@locations}, #{@message}>"
        end

        def to_tuple
            fixits = @fixits.collect { |f| f.to_tuple }
            locations = @locations.collect { |l| l.to_tuple }

            return [@severity, fixits, locations, @message]
        end
    end
end

# ex:ts=4:et:
