# gnome code assistance c backend
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

from gnome.codeassistance.c import clangimporter, makefileintegration, config
from gnome.codeassistance import transport, types

import clang.cindex as cindex

import glob, os

def config_libclang():
    libdir = config.llvm_libdir
    cindex.Config.set_library_path(libdir)

    files = glob.glob(os.path.join(libdir, 'libclang.so*'))

    if len(files) != 0:
        cindex.Config.set_library_file(files[0])

class Service(transport.Service):
    language = 'c'
    services = [
        'org.gnome.CodeAssist.MultiDoc'
    ]

    def __init__(self, *args):
        transport.Service.__init__(self, *args)

        self.index = cindex.Index.create(True)
        self.makefile = makefileintegration.MakefileIntegration()

    def parse(self, path, cursor, unsaved, options, doc):
        if doc is None:
            doc = self.document(path)

        unsaved = [(x.path, open(x.data_path)) for x in unsaved]

        if not doc.tu is None:
            doc.tu.reparse(unsaved)
        else:
            args = self.makefile.flags_for_file(path)

            doc.tu = cindex.TranslationUnit.from_source(path,
                                                        args=args,
                                                        unsaved_files=unsaved,
                                                        index=self.index)

        for u in unsaved:
            u[1].close()

        doc.process()
        return doc

    def dispose(self, doc):
        doc.tu = None

class Document(transport.Document, transport.Diagnostics):
    def __init__(self, path):
        transport.Document.__init__(self)
        transport.Diagnostics.__init__(self)

        self.tu = None
        self.path = path
        self._diagnostics = []

    def process(self):
        self._process_diagnostics()

    def diagnostics(self):
        return self._diagnostics

    def _map_cseverity(self, severity):
        s = types.Diagnostic.Severity

        if severity == cindex.Diagnostic.Note:
            return s.INFO
        elif severity == cindex.Diagnostic.Warning:
            return s.WARNING
        elif severity == cindex.Diagnostic.Error:
            return s.ERROR
        elif severity == cindex.Diagnostic.Fatal:
            return s.FATAL

        return s.NONE

    def _map_csource_location(self, location):
        if location.file is None:
            return None

        if not os.path.samefile(self.path, location.file.name):
            return None

        return types.SourceLocation(line=location.line,
                                    column=location.column)

    def _map_csource_range(self, range):
        start = self._map_csource_location(range.start)

        if start is None:
            return None

        end = self._map_csource_location(range.end)

        if end is None:
            return None

        return types.SourceRange(start=start, end=end)

    def _map_cfixit(self, fixit):
        range = self._map_csource_range(fixit.range)

        if range is None:
            return None

        return types.Fixit(location=range, replacement=fixit.value)

    def _map_cdiagnostic(self, d):
        loc = self._map_csource_location(d.location)

        if loc is None:
            return None

        severity = self._map_cseverity(d.severity)

        ranges = [self._map_csource_range(r) for r in d.ranges]
        ranges = list(filter(lambda x: not x is None, ranges))
        ranges.insert(0, loc.to_range())

        fixits = [self._map_cfixit(f) for f in d.fixits]
        fixits = filter(lambda x: not x is None, fixits)

        message = d.spelling

        return types.Diagnostic(severity=severity,
                                locations=ranges,
                                fixits=fixits,
                                message=message)

    def _process_diagnostics(self):
        self._diagnostics = [self._map_cdiagnostic(d) for d in self.tu.diagnostics]
        self._diagnostics = filter(lambda x: not x is None, self._diagnostics)

def run():
    config_libclang()
    transport.Transport(Service, Document).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
