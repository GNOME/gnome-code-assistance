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

import os, subprocess, re, shlex
from gi.repository import Gio

class MakefileIntegration:
    debug = False

    class Makefile:
        class Source:
            mtime = 0
            flags = []

        def __init__(self, path):
            self.path = path
            self._sources = {}

            self._update_mtime()

            f = Gio.file_new_for_path(path)

            try:
                self._monitor = f.monitor(Gio.FileMonitorFlags.NONE, None)
                self._monitor.connect('changed', self._on_changed)
            except:
                self._monitor = None

        def _update_mtime(self):
            try:
                self._mtime = os.stat(self.path).st_mtime
            except:
                self._mtime = 0

        def _on_changed(self, *args):
            self._update_mtime()

        def dispose(self):
            if not self._monitor is None:
                self._monitor.cancel()
                self._monitor = None

        def make_source(self, flags):
            ret = MakefileIntegration.Makefile.Source()
            ret.flags = flags
            ret.mtime = self._mtime

            return ret

        def add(self, source, flags):
            self._sources[source] = self.make_source(flags)

        def remove(self, source):
            try:
                del self._sources[source]

                if len(self._sources) == 0:
                    self.dispose()
                    return True
            except:
                pass

            return False

        def up_to_date_for(self, source):
            if not source in self._sources:
                return False

            return self._mtime <= self._sources[source].mtime

        def flags_for_file(self, source):
            try:
                return self._sources[source].flags
            except KeyError:
                return []

    def __init__(self):
        self._cache = {}
        self._file_to_makefile = {}

    def _file_as_abs(self, path):
        if not os.path.isabs(path):
            try:
                path = os.path.join(os.getcwd(), path)
            except:
                pass

        return os.path.normpath(path)

    def changed_for_file(self, path):
        path = self._file_as_abs(path)
        makefile = self._makefile_for(path)

        if makefile is None:
            return False

        try:
            m = self._cache[makefile]
            return not m.up_to_date_for(path)
        except KeyError:
            return True

    def dispose(self, path):
        try:
            makefile = self._file_to_makefile[path]

            if makefile.remove(path):
                del self._cache[makefile.path]

            del self._file_to_makefile[path]
        except:
            pass

    def flags_for_file(self, path):
        path = self._file_as_abs(path)
        makefile = self._makefile_for(path)

        if self.debug:
            print('Scanning for {0}'.format(path))
            print('  Makefile: {0}'.format(makefile))

        if makefile is None:
            return []

        try:
            m = self._cache[makefile]

            if m.up_to_date_for(path):
                flags = m.flags_for_file(path)

                if self.debug:
                    print('  From cache: {0}'.format(', '.join(flags)))

                return flags
        except KeyError:
            pass

        targets = self._targets_from_make(makefile, path)

        if self.debug:
            print('  Targets: [{0}]'.format(', '.join(targets)))

        flags = self._flags_from_targets(makefile, path, targets)

        if self.debug:
            print('  Flags: [{0}]'.format(', '.join(flags)))

        return self._update_cache(makefile, path, flags)

    def _update_cache(self, makefile, path, flags):
        try:
            m = self._cache[makefile]
        except KeyError:
            m = MakefileIntegration.Makefile(makefile)
            self._cache[makefile] = m

        m.add(path, flags)
        self._file_to_makefile[path] = m

        return flags

    def _find_subdir_with_path(self, parent, path):
        dname = os.path.dirname(path)
        bname = os.path.basename(path)

        for dirname, dirnames, filenames in os.walk(parent):
            for s in dirnames:
                tpath = os.path.join(dirname, s, dname)

                if os.path.isdir(tpath):
                    mf = self._makefile_for(os.path.join(tpath, bname), False)

                    if not mf is None:
                        return mf

        return None

    def _subdir_makefile_for(self, path, parent):
        relpath = os.path.relpath(path, parent)

        # Find subdirectory of parent which contains relpath
        return self._find_subdir_with_path(parent, relpath)

    def _makefile_for(self, path, tryac=True):
        if self.debug:
            print('  Find makefile')

        try:
            fromcache =  self._file_to_makefile[path].path

            if self.debug:
                print('  From cache: {0}'.format(fromcache))

            return fromcache
        except KeyError:
            pass

        parent = os.path.dirname(path)

        while True:
            makefile = os.path.join(parent, 'Makefile')

            if os.path.isfile(makefile):
                return makefile

            if tryac:
                tocheck = ['configure.ac', 'configure.in', 'configure']

                for f in tocheck:
                    configuref = os.path.join(parent, f)

                    if os.path.isfile(configuref):
                        ret = self._subdir_makefile_for(path, parent)

                        if not ret is None:
                            return ret

                        break

            parent = os.path.dirname(parent)

            if parent == '/':
                break

        return None

    def _sort_target(self, target, regs):
        for i, reg in enumerate(regs):
            if reg.match(target):
                return i

        return len(regs)

    def _targets_from_make(self, makefile, source):
        wd = os.path.dirname(makefile)

        lookfor = [
            os.path.relpath(source, wd)
        ]

        bname = os.path.basename(source)

        if lookfor[0] != bname:
            lookfor.append(bname)

        origlookfor = lookfor

        if self.debug:
            print('  Looking for: [{0}]'.format(', '.join(lookfor)))

        args = ['make', '-p', '-n', '-s', '.']

        try:
            with open(os.devnull, 'w') as stderr:
                outstr = subprocess.check_output(args, cwd=wd, stderr=stderr).decode('utf-8')
        except StandardError as e:
            if self.debug:
                print('  Failed to run make: {0}'.format(e))

            return []

        targets = []
        found = {}

        while len(lookfor) > 0:
            # Make a regular expression which will match all printed targets that
            # depend on the file we are looking for
            if self.debug:
                print('  looking for: [{0}]'.format(', '.join(lookfor)))

            relookfor = [re.escape(x) for x in lookfor]
            reg = re.compile('^([^:\n ]+):.*\\b({0})\\b'.format('|'.join(relookfor)), re.M)
            lookfor = []

            for match in reg.finditer(outstr):
                target = match.group(1)

                if target[0] == '#' or '-am' in target:
                    continue

                if target in found:
                    continue

                targets.append(target)
                found[target] = True
                lookfor.append(target)

        noext = [re.escape(os.path.splitext(x)[0]) for x in origlookfor]

        targetregs = [
            # Targets that are object or libtool object files are good
            re.compile('^(.*(({0})\\.(o|lo)))$'.format('|'.join(noext))),

            # Any object or libtool object file
            re.compile('^(.*\\.(o|lo))$')
        ]

        targets.sort(key=lambda x: self._sort_target(x, targetregs))
        return targets

    def _flags_from_targets(self, makefile, source, targets):
        if len(targets) == 0:
            return []

        fakecc = '__GCA_C_COMPILE_FLAGS__'
        fakecxx = '__GCA_CXX_COMPILE_FLAGS__'

        wd = os.path.dirname(makefile)
        relsource = os.path.relpath(source, wd)

        args = [
            'make',
            '-s',
            '-i',
            '-n',
            '-W',
            relsource,
            'V=1',
            'CC=' + fakecc,
            'CXX=' + fakecxx,
        ]

        args += targets

        try:
            with open(os.devnull, 'w') as stderr:
                outstr = subprocess.check_output(args, cwd=wd, stderr=stderr).decode('utf-8')
        except Exception as e:
            if self.debug:
                print('  Failed to run make: {0}'.format(e))

            return []

        regfind = re.compile('({0}|{1})([^\n]*)$'.format(fakecc, fakecxx), re.M)

        for m in regfind.finditer(outstr):
            flags = self._filter_flags(makefile, shlex.split(m.group(2)))

            if m.group(1) == fakecxx:
                flags = self._force_cxx_if_needed(flags)

            return flags

        return []

    def _force_cxx_if_needed(self, flags):
        for f in flags:
            if f.startswith('-x'):
                return flags

        flags.append('-xc++')
        return flags

    def _filter_flags(self, makefile, flags):
        # Keep only interesting flags:
        # -I: include paths
        # -D: defines
        # -W: warnings
        # -f: compiler flags
        # -x: language
        # -std=<std>: standard

        i = 0
        inexpand = False
        ret = []

        wd = os.path.dirname(makefile)

        while i < len(flags):
            flag = flags[i]
            i += 1

            if '`' in flag:
                inexpand = not inexpand

            if inexpand or len(flag) < 2:
                continue

            if flag[0] != '-':
                continue

            v = flag[1]

            if v == 'I':
                if len(flag) > 2:
                    ipath = flag[2:]
                elif i < len(flags):
                    ipath = flags[i]
                    i += 1
                else:
                    continue

                if not os.path.isabs(ipath):
                    ipath = os.path.normpath(os.path.join(wd, ipath))

                ret.append('-I')
                ret.append(ipath)
            elif v == 'D' or v == 'f' or v == 'W' or v == 'x':
                # pass defines, compiler flags and warnings
                ret.append(flag)

                # Also add the argument if its not embedded
                if (v == 'D' or v == 'x') and len(flag) == 2 and i < len(flags):
                    ret.append(flags[i])
                    i += 1
            elif flag.startswith('-std='):
                ret.append(flag)

        return ret

if __name__ == '__main__':
    import sys

    m = MakefileIntegration()
    m.debug = True
    m.flags_for_file(sys.argv[1])

# ex:ts=4:et:
