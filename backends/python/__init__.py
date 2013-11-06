# gnome code assistance python backend
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

import ast

from gnome.codeassistance import transport, types

class Service(transport.Service):
    language = 'python'

    def parse(self, path, cursor, unsaved, options, doc):
        path = self.data_path(path, unsaved)

        errors = []
        ret = None

        try:
            with open(path) as f:
                source = f.read()

            ret = ast.parse(source, path)
        except SyntaxError as e:
            loc = types.SourceLocation(line=e.lineno, column=e.offset)
            severity = types.Diagnostic.Severity.ERROR

            errors = [types.Diagnostic(severity=severity, locations=[loc.to_range()], message=e.msg)]

        if doc is None:
            doc = self.document()

        doc.ast = ret
        doc.errors = errors

        return doc

    def dispose(self, path):
        pass

class Document(transport.Document, transport.Diagnostics):
    ast = None
    errors = None

    def diagnostics(self):
        return self.errors

def run():
    transport.Transport(Service, Document).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
