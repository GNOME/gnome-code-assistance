# gnome code assistance python backend
# Copyright (C) 2013  Jesse van den Kieboom <jessevdk@gnome.org>
# Copyright (C) 2014  Elad Alfassa <elad@fedoraproject.org>
# Copyright (C) 2015  Igor Gnatenko <ignatenko@src.gnome.org>
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

try:
    from pylint import lint
    from pylint.reporters.text import TextReporter
    HAS_PYLINT = True
except ImportError:
    HAS_PYLINT = False

from gnome.codeassistance import transport, types

class PyLint(object):
    def __init__(self, data_path):
        self.diagnostics = []
        self.data_path = data_path

    def write(self, st):
        if st != "\n" and not st.startswith("*"):
            result = st.split(":")
            col = int(result[1]) + 1
            loc = types.SourceLocation(line=result[0], column=col)

            """
            * (C) convention, for programming standard violation
            * (R) refactor, for bad code smell
            * (W) warning, for python specific problems
            * (E) error, for much probably bugs in the code
            * (F) fatal, if an error occurred which prevented pylint from doing
            further processing.
            """
            if result[2] == "C" or result[2] == "R" or result[2] == "W":
                severity = types.Diagnostic.Severity.INFO
            else:
                severity = types.Diagnostic.Severity.ERROR

            self.diagnostics.append(
                types.Diagnostic(severity=severity,
                                 locations=[loc.to_range()],
                                 message=result[3]))

    def run(self):
        args = [self.data_path, "-r", "n",
                "--msg-template='{line}:{column}:{C}:{msg_id} {msg}'"]
        lint.Run(args, reporter=TextReporter(self), exit=False)
        return self.diagnostics


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

        if HAS_PYLINT and "pylint" in options and options["pylint"]:
            pylint = PyLint(doc.data_path)
            diagnostics = pylint.run()

            for diag in diagnostics:
                doc.diagnostics.append(diag)


class Document(transport.Document, transport.Diagnostics):
    pass

def run():
    transport.Transport(Service, Document).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
