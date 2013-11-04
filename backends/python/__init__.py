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

from codeassist.common import cassist

class Service:
    language = 'python'

    def __init__(self, documentcls):
        self.documentcls = documentcls

    def document(self):
        return self.documentcls()

    def parse(self, appid, path, cursor, unsaved, options, doc):
        for u in unsaved:
            if u.path == path:
                path = u.data_path
                break

        errors = []
        ret = None

        try:
            with open(path) as f:
                source = f.read()

            ret = ast.parse(source, path)
        except SyntaxError as e:
            errors = [e]

        if doc is None:
            doc = self.document()

        doc.ast = ret
        doc.errors = errors

        return doc

    def dispose(self, appid, path):
        pass

def run():
    from codeassist.common import app

    transport = app.transport(Service)

    class Document(transport.Document, transport.Diagnostics):
        ast = None
        errors = None
        path = None

        def paths(self, ids):
            myids = {0: self.path}
            return [myids[id] for id in ids]

        def diagnostics(self):
            ret = []

            for e in self.errors:
                locations = [cassist.SourceRange(start=cassist.SourceLocation(line=e.lineno, column=e.offset))]
                ret.append(cassist.Diagnostic(severity=cassist.Severity.ERROR, message=e.msg, locations=locations))

            return ret

    transport.Transport(Service(Document)).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
