# gnome code assistance python backend
# Copyright (C) 2013  Jesse van den Kieboom <jessevdk@gnome.org>
# Copyright (C) 2014  Elad Alfassa <elad@fedoraproject.org>
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
import subprocess
import re

from gnome.codeassistance import transport, types

class Service(transport.Service):
    language = 'python'

    def parse(self, doc, options):
        doc.diagnostics = []

        try:
            with open(doc.data_path) as f:
                source = f.read()

            ast.parse(source, doc.path)
        except SyntaxError as e:
            loc = types.SourceLocation(line=e.lineno, column=e.offset)
            severity = types.Diagnostic.Severity.ERROR

            doc.diagnostics.append(types.Diagnostic(severity=severity, locations=[loc.to_range()], message=e.msg))

        # PEP8 checks
        try:
            p = subprocess.Popen(['pep8', doc.data_path], stdout=subprocess.PIPE)
            for line in iter(p.stdout.readline, ''):
                if not line:
                    break
                line = line.decode()
                result = re.search(':(\d*):(\d*): (.*)', line).groups()
                loc = types.SourceLocation(line=result[0], column=result[1])
                severity = types.Diagnostic.Severity.INFO
                doc.diagnostics.append(types.Diagnostic(severity=severity, locations=[loc.to_range()], message=result[2]))
        except FileNotFoundError:
            # PEP8 is not installed. Do nothing.
            pass

class Document(transport.Document, transport.Diagnostics):
    pass

def run():
    transport.Transport(Service, Document).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
