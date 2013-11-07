# gnome code assistance css backend
# Copyright (C) 2013  Ignacio Casal Quinteiro <icq@gnome.org>
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

import tinycss

from gnome.codeassistance import transport, types

class Service(transport.Service):
    language = 'css'

    def __init__(self):
        self.parser = tinycss.make_parser('page3')

    def parse(self, path, cursor, unsaved, options, doc):
        path = self.data_path(path, unsaved)

        errors = []

        stylesheet = self.parser.parse_stylesheet_file(path)
        for e in stylesheet.errors:
            loc = types.SourceLocation(line=e.line, column=e.column)
            severity = types.Diagnostic.Severity.ERROR

            errors.append(types.Diagnostic(severity=severity, locations=[loc.to_range()], message=e.reason))

        if doc is None:
            doc = self.document()

        doc.errors = errors

        return doc

    def dispose(self, doc):
        pass

class Document(transport.Document, transport.Diagnostics):
    errors = None

    def diagnostics(self):
        return self.errors

def run():
    transport.Transport(Service, Document).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
