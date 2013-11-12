# gnome code assistance common
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
    def __init__(self, path):
        self.path = path

    def find_module(self, fullname, path=None):
        if fullname == 'gnome.codeassistance.transport':
            return self

    def load_module(self, fullname):
        import sys

        if fullname in sys.modules:
            return sys.modules[fullname]

        import argparse, importlib
        parser = argparse.ArgumentParser(description='gnome code assistance daemon')

        parser.add_argument('--transport', metavar='TRANSPORT', type=str,
                            help='the transport (dbus or http)', default='dbus')

        parser.add_argument('--address', metavar='ADDRESS', type=str,
                            help='the http address to listen on', default=':0')

        parser.add_argument('args', metavar='ARG', type=str, nargs='*',
                            help='other arguments...')

        args = parser.parse_args()

        transport = importlib.import_module('gnome.codeassistance.transport_' + args.transport)
        transport.address = args.address

        sys.modules[fullname] = transport
        return transport

sys.meta_path.append(DynamicImporter('gnome.codeassistance'))

del sys
del DynamicImporter

# ex:ts=4:et:
