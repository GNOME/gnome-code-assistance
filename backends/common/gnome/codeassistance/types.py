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

class UnsavedDocument:
    def __init__(self, path='', data_path=''):
        self.path = path
        self.data_path = data_path

    def __repr__(self):
        return '<UnsavedDocument: {0}, {1}>'.format(self.path, self.data_path)

class SourceLocation:
    def __init__(self, line=0, column=0):
        self.line = line
        self.column = column

    def __repr__(self):
        return '{0}.{1}'.format(self.line, self.column)

    def to_range(self, file=0):
        return SourceRange(file, self)

    def to_tuple(self):
        return (self.line, self.column)

class SourceRange:
    def __init__(self, file=0, start=SourceLocation(), end=None):
        self.file = file
        self.start = start

        if end is None:
            end = start

        self.end = end

    def __repr__(self):
        return '{0}-{1}'.format(self.start, self.end)

    def to_range(self):
        return self

    def to_tuple(self):
        return (self.file, self.start.to_tuple(), self.end.to_tuple())

class Fixit:
    def __init__(self, location=SourceRange(), replacement=''):
        self.location = location
        self.replacement = replacement

    def __repr__(self):
        return '<Fixit: {0}: {1}>'.format(self.location, self.replacement)

    def to_tuple(self):
        return (self.location.to_tuple(), self.replacement)

class Diagnostic:
    class Severity:
        NONE = 0
        INFO = 1
        WARNING = 2
        DEPRECATED = 3
        ERROR = 4
        FATAL = 5

    def __init__(self, severity=Severity.NONE, fixits=[], locations=[], message=''):
        self.severity = severity
        self.fixits = fixits
        self.locations = locations
        self.message = message

    def __repr__(self):
        return '<Diagnostic: {0}, {1}, {2}, {3}>'.format(self.severity, self.fixits, self.locations, self.message)

    def to_tuple(self):
        return (self.severity, [f.to_tuple() for f in self.fixits], [l.to_tuple() for l in self.locations], self.message)

# ex:ts=4:et:
