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

import sys

class DynamicImporter(object):
    def find_module(self, fullname, path=None):
        if fullname == 'clang' or fullname.startswith('clang.'):
            return self

    def load_module(self, fullname):
        import sys, importlib

        if fullname in sys.modules:
            return sys.modules[fullname]

        mod = importlib.import_module('gnome.codeassistance.c.' + fullname)
        sys.modules[fullname] = mod

        return mod

sys.meta_path.append(DynamicImporter())

del sys
del DynamicImporter

# ex:ts=4:et:
