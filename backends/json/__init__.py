# gnome code assistance json backend
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

from gnome.codeassistance import transport, types

try:
    import simplejson as json
except ImportError:
    import sys, os

    sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'deps'))
    import simplejson as json
    sys.path = sys.path[1:]

class Service(transport.Service):
    language = 'json'

    def parse(self, doc, options):
        doc.diagnostics = []

        try:
            with open(doc.data_path) as f:
                json.load(f)

        except json.JSONDecodeError as e:
            start = types.SourceLocation(line=e.lineno, column=e.colno)

            if not e.endlineno is None:
                end = types.SourceLocation(line=e.endlineno, column=e.endcolno)
            else:
                end = None

            severity = types.Diagnostic.Severity.ERROR
            doc.diagnostics = [types.Diagnostic(severity=severity, locations=[types.SourceRange(start=start, end=end)], message=e.msg)]

class Document(transport.Document, transport.Diagnostics):
    pass

def run():
    transport.Transport(Service, Document).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
