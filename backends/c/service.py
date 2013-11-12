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

_did_libclang_config = False

def config_libclang():
    global _did_libclang_config

    if _did_libclang_config:
        return

    _did_libclang_config = True

    libdir = config.llvm_libdir
    cindex.Config.set_library_path(libdir)

    files = glob.glob(os.path.join(libdir, 'libclang.so*'))

    if len(files) != 0:
        cindex.Config.set_library_file(files[0])

class Service(transport.Service, transport.Project):
    language = 'c'

    def __init__(self):
        super(Service, self).__init__()

        config_libclang()

        self.index = cindex.Index.create(True)
        self.makefile = makefileintegration.MakefileIntegration()

    def _parse(self, doc, docs, unsaved, options):
        if (not doc.tu is None) and not self.makefile.changed_for_file(doc.path):
            print('reparse')
            doc.tu.reparse(unsaved)
        else:
            args = self.makefile.flags_for_file(doc.path)
            print(doc.path, args)

            doc.tu = cindex.TranslationUnit.from_source(doc.path,
                                                        args=args,
                                                        unsaved_files=unsaved,
                                                        index=self.index)

        for u in unsaved:
            u[1].close()

        return self._process(doc, docs)

    def parse_all(self, doc, docs, options):
        unsaved = [(d.path, open(d.data_path, 'rb')) for d in docs if d.data_path != d.path]
        return self._parse(doc, docs, unsaved, options)

    def parse(self, doc, options):
        if doc.data_path != doc.path:
            unsaved = [(doc.path, open(doc.data_path, 'rb'))]
        else:
            unsaved = []

        self._parse(doc, unsaved, options)

    def _included_docs(self, doc, docmap):
        includes = doc.tu.get_includes()
        retmap = {}

        for i in includes:
            p = os.path.realpath(i.include.name).decode('utf-8')

            if p in docmap:
                retmap[p] = docmap[p]
                del docmap[p]

        return retmap

    def _process(self, doc, docs):
        # Create a mapping from doc path to doc
        docmap = {os.path.realpath(d.path): d for d in docs}

        # Get the set of docs that were included during the processing
        incdocs = self._included_docs(doc, docmap)

        # Add also our own doc
        incdocs[os.path.realpath(doc.path)] = doc

        self._process_diagnostics(doc.tu, incdocs)

        return list(incdocs.values())

    def _process_diagnostics(self, tu, docmap):
        for k, v in docmap.items():
            v.diagnostics = []

        resolved = {}

        for d in tu.diagnostics:
            if d.location is None or d.location.file is None:
                continue

            f = d.location.file.name.decode('utf-8')

            try:
                rf = resolved[f]
            except KeyError:
                rf = os.path.realpath(f)
                resolved[f] = rf

            try:
                rdoc = docmap[rf]
            except KeyError:
                continue

            rdoc.diagnostics.append(self._map_cdiagnostic(d))

        for d in docmap:
            print(d, docmap[d].diagnostics)

    def dispose(self, doc):
        doc.tu = None

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
        return types.SourceLocation(line=location.line,
                                    column=location.column)

    def _map_csource_range(self, range):
        start = self._map_csource_location(range.start)
        end = self._map_csource_location(range.end)

        return types.SourceRange(start=start, end=end)

    def _map_cfixit(self, fixit):
        range = self._map_csource_range(fixit.range)
        return types.Fixit(location=range, replacement=fixit.value)

    def _map_cdiagnostic(self, d):
        loc = self._map_csource_location(d.location)
        severity = self._map_cseverity(d.severity)

        ranges = [self._map_csource_range(r) for r in d.ranges]
        ranges = list(filter(lambda x: not x is None, ranges))
        ranges.insert(0, loc.to_range())

        fixits = [self._map_cfixit(f) for f in d.fixits]
        fixits = list(filter(lambda x: not x is None, fixits))

        message = d.spelling

        return types.Diagnostic(severity=severity,
                                locations=ranges,
                                fixits=fixits,
                                message=message)

class Document(transport.Document, transport.Diagnostics):
    def __init__(self):
        super(Document, self).__init__()
        self.tu = None

    def process(self):
        self._process_diagnostics()

if __name__ == '__main__':
    import sys

    s = Service()
    d = Document()

    docs = [Document() for x in sys.argv[1:]]

    for i, v in enumerate(sys.argv[1:]):
        docs[i].path = os.path.abspath(v)
        docs[i].data_path = docs[i].path

    print(s.parse_all(docs[0], docs, {}))

# ex:ts=4:et:
