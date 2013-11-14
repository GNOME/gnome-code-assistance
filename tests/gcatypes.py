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

class OpenDocument:
    def __init__(self, path='', data_path=''):
        self.path = path
        self.data_path = data_path

    @classmethod
    def from_tuple(cls, tp):
        return cls(tp[0], tp[1])

    def to_tuple(self):
        return (self.path, self.data_path)

    def __repr__(self):
        return '<OpenDocument: {0}, {1}>'.format(self.path, self.data_path)

class RemoteDocument:
    def __init__(self, path='', remote_path=''):
        self.path = path
        self.remote_path = remote_path

    def __repr__(self):
        return '<RemoteDocument: {0}, {1}>'.format(self.path, self.remote_path)

    def to_tuple(self):
        return (self.path, self.remote_path)

class SourceLocation:
    def __init__(self, line=0, column=0):
        self.line = line
        self.column = column

    def __repr__(self):
        return '{0}.{1}'.format(self.line, self.column)

    def to_range(self, file=0):
        start = SourceLocation(line=self.line, column=self.column)
        end = SourceLocation(line=self.line, column=self.column)
        return SourceRange(file=file, start=start, end=end)

    def to_tuple(self):
        return (self.line, self.column)

    @classmethod
    def from_tuple(cls, tp):
        return cls(line=tp[0], column=tp[1])

    @classmethod
    def from_json(cls, js):
        line = 0
        column = 0

        if 'line' in js:
            line = js['line']

        if 'column' in js:
            column = js['column']

        return cls(line=line, column=column)

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

    @classmethod
    def from_tuple(cls, tp):
        return cls(file=tp[0], start=SourceLocation.from_tuple(tp[1]), end=SourceLocation.from_tuple(tp[2]))

    @classmethod
    def from_json(cls, js):
        file = 0
        start = SourceLocation()

        if 'file' in js:
            file = js['file']

        if 'start' in js:
            start = SourceLocation.from_json(js['start'])

        if 'end' in js:
            end = SourceLocation.from_json(js['end'])
        else:
            end = SourceLocation(line=start.line, column=start.column)

        return cls(file=file, start=start, end=end)

class Fixit:
    def __init__(self, location=SourceRange(), replacement=''):
        self.location = location
        self.replacement = replacement

    def __repr__(self):
        return '<Fixit: {0}: {1}>'.format(self.location, self.replacement)

    def to_tuple(self):
        return (self.location.to_tuple(), self.replacement)

    @classmethod
    def from_tuple(cls, tp):
        return cls(location=SourceRange.from_tuple(tp[0]), replacement=tp[1])

    @classmethod
    def from_json(cls, js):
        return cls(location=SourceRange.from_json(js['location']), replacement=js['replacement'])

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

    @classmethod
    def from_tuple(cls, tp):
        return cls(severity=tp[0], fixits=[Fixit.from_tuple(f) for f in tp[1]], locations=[SourceRange.from_tuple(l) for l in tp[2]], message=tp[3])

    @classmethod
    def from_json(cls, js):
        severity = 0
        fixits = []
        locations = []
        message = ''

        if 'severity' in js:
            severity = js['severity']

        if 'fixits' in js:
            fixits = [Fixit.from_json(f) for f in js['fixits']]

        if 'locations' in js:
            locations = [SourceRange.from_json(l) for l in js['locations']]

        if 'message' in js:
            message = js['message']

        return cls(severity=severity, fixits=fixits, locations=locations, message=message)

# ex:ts=4:et:
