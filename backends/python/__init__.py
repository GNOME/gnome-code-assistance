# gnome code assistance python backend
# Copyright (C) 2013  Jesse van den Kieboom <jessevdk@gnome.org>
# Copyright (C) 2014, 2017  Elad Alfassa <elad@fedoraproject.org>
# Copyright (C) 2015  Igor Gnatenko <ignatenko@src.gnome.org>
# Copyright (C) 2017  Luke Benstead <kazade@gmail.com>
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

try:
    import pycodestyle
    HAS_PYCODESTYLE = True
except ImportError:
    try:
        # pep8 has been renamed to "pycodestyle". Maybe the user only has
        # the old version installed, so let's try loading it before we give up
        import pep8 as pycodestyle
        HAS_PYCODESTYLE = True
    except ImportError:
        # No pep8 or pycodestyle installed
        HAS_PYCODESTYLE = False

try:
    from pylint import lint
    from pylint.reporters.text import TextReporter
    HAS_PYLINT = True
except ImportError:
    HAS_PYLINT = False

try:
    from pyflakes.api import checkPath as pyflakes_check
    from pyflakes.reporter import Reporter
    HAS_PYFLAKES = True
except ImportError:
    HAS_PYFLAKES = False

from gnome.codeassistance import transport, types

class PyLint(object):
    def __init__(self, data_path):
        self.diagnostics = []
        self.data_path = data_path

    def write(self, st):
        if st != "\n" and not st.startswith("*") and ":" in st:
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


class Pyflakes(object):
    def __init__(self, data_path):
        self.data_path = data_path

    def run(self):

        class PyflakesReporter(Reporter):
            """
                Custom reporter, nested as parent class will not have been imported
                if pyflakes wasn't available
            """
            def __init__(self):
                self.diagnostics = []

            def unexpectedError(self, filename, msg):
                loc = types.SourceLocation(line=0, column=0)
                severity = types.Diagnostic.Severity.ERROR
                self.diagnostics.append(
                    types.Diagnostic(severity=severity,
                                     locations=[loc.to_range()],
                                     message=str(msg)))

            def syntaxError(self, filename, msg, lineno, offset, text):
                severity = types.Diagnostic.Severity.ERROR
                col = int(offset) + 1
                loc = types.SourceLocation(line=lineno, column=col)
                self.diagnostics.append(
                    types.Diagnostic(severity=severity,
                                     locations=[loc.to_range()],
                                     message=str(msg)))

            def flake(self, message):
                loc = types.SourceLocation(line=message.lineno,
                                           column=int(message.col) + 1)
                severity = types.Diagnostic.Severity.WARNING
                text = message.message % message.message_args
                self.diagnostics.append(
                    types.Diagnostic(severity=severity,
                                     locations=[loc.to_range()],
                                     message=text))

        reporter = PyflakesReporter()
        pyflakes_check(self.data_path, reporter=reporter)
        return reporter.diagnostics


class PyCodeStyle(object):
    """ PyCodeStyle / PEP8 backend """
    def __init__(self, source, path):
        self.source = source
        self.path = path

    def run(self):
        class PyCodeStyleReporter(pycodestyle.BaseReport):
            """
                Custom reporter, nested as parent class will not have been imported
                if pycodestyle/pep8 wasn't available
            """
            def __init__(self, *args):
                super().__init__(*args)
                self.diagnostics = []

            def error(self, line_number, offset, text, check):
                errorcode = super().error(line_number, offset, text, check)
                if errorcode:
                    loc = types.SourceLocation(line=line_number, column=offset + 1)
                    severity = types.Diagnostic.Severity.INFO
                    self.diagnostics.append(types.Diagnostic(severity=severity,
                                                             locations=[loc.to_range()],
                                                             message=text))

        style_guide = pycodestyle.StyleGuide(reporter=PyCodeStyleReporter)
        reporter = style_guide.options.report
        style_guide.input_file(self.path, lines=self.source.splitlines(True))
        return reporter.diagnostics


class Service(transport.Service):
    language = 'python'

    def parse(self, doc, options):
        doc.diagnostics = []
        use_pylint = HAS_PYLINT and "pylint" in options and options["pylint"]

        with open(doc.data_path) as f:
            source = f.read()

        if not use_pylint and not HAS_PYFLAKES:
            # both pylint and pyflakes warn about syntax errors, so only need
            # ast.parse() if we can't use either of them
            try:
                ast.parse(source, doc.path)
            except SyntaxError as e:
                loc = types.SourceLocation(line=e.lineno, column=e.offset)
                severity = types.Diagnostic.Severity.ERROR

                doc.diagnostics.append(types.Diagnostic(severity=severity, locations=[loc.to_range()], message=e.msg))

        # Pycodestyle / PEP8 checks
        if HAS_PYCODESTYLE or True:
            pycodestyle_checker = PyCodeStyle(source, doc.path)
            for diagnostic in pycodestyle_checker.run():
                doc.diagnostics.append(diagnostic)

        # Pylint checks (if present and enabled)
        if use_pylint:
            pylint = PyLint(doc.data_path)
            diagnostics = pylint.run()

            for diag in diagnostics:
                doc.diagnostics.append(diag)

        # Pyflakes check (if present)
        if HAS_PYFLAKES:
            pyflakes = Pyflakes(doc.data_path)
            diagnostics = pyflakes.run()
            for diag in diagnostics:
                doc.diagnostics.append(diag)

class Document(transport.Document, transport.Diagnostics):
    pass


def run():
    transport.Transport(Service, Document).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
