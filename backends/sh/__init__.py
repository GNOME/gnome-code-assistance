# gnome code assistance sh backend
# Copyright (C) 2013  Paolo Borelli <pborelli@gnome.org>
# Copyright (C) 2016  Elad Alfassa <elad@fedoraproject.org>
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

import re
import subprocess

try:
    from subprocess import DEVNULL # py3k
except ImportError:
    import os
    DEVNULL = open(os.devnull, 'wb')

from gnome.codeassistance import transport, types

class Service(transport.Service):
    language = 'sh'

    pattern = re.compile("^.*line ([0-9]+).*: (.*)$")

    def parse(self, doc, options):
        doc.diagnostics = []

        try:
            p = subprocess.Popen(['shellcheck', '-f', 'gcc', doc.data_path],
                                 stdout=subprocess.PIPE)
            for line in iter(p.stdout.readline, ''):
                if not line:
                    break
                line = line.decode()
                result = re.search(':(\d*):(\d*): (\w*):(.*)', line).groups()
                loc = types.SourceLocation(line=result[0], column=result[1])
                if result[2] == 'error':
                    severity = types.Diagnostic.Severity.ERROR
                elif result[2] == 'warning':
                    severity = types.Diagnostic.Severity.WARNING
                else:
                    severity = types.Diagnostic.Severity.INFO
                doc.diagnostics.append(types.Diagnostic(severity=severity,
                                                        locations=[loc.to_range()],
                                                        message=result[3]))
        except FileNotFoundError:
            # shellcheck is not installed. Check with bash dry run mode instead.
            try:
                p = subprocess.Popen(["/bin/bash", "-n", doc.data_path],
                                     stdout=DEVNULL, stderr=subprocess.PIPE)

                for l in iter(p.stderr.readline, ''):
                    if not l:
                        break

                    m = Service.pattern.match(l.decode())
                    if m:
                        loc = types.SourceLocation(line=m.group(1))

                        doc.diagnostics.append(types.Diagnostic(severity=types.Diagnostic.Severity.ERROR,
                                                                locations=[loc.to_range()],
                                                                message=m.group(2)))
            except Exception as e:
                pass

    def dispose(self, doc):
        pass

class Document(transport.Document, transport.Diagnostics):
    pass

def run():
    transport.Transport(Service, Document).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
