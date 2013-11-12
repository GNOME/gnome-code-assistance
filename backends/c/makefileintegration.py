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

class MakefileIntegration:
    class Makefile:
        def __init__(self, path):
            self.path = path

            try:
                st = os.stat(self.path)
                self._mtime = st.st_mtime
            except:
                self._mtime = 0

            self._sources = {}

        def add(self, source, flags):
            self._sources[source] = flags

        def up_to_date_for(self, source):
            if not source in self._sources:
                return False

            try:
                st = os.stat(self.path)
            except:
                return False

            return st.st_mtime <= self._mtime

        def flags_for_file(self, source):
            try:
                return self._sources[source]
            except KeyError:
                return []

    def __init__(self):
        self._cache = {}

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

    def flags_for_file(self, path):
        path = self._file_as_abs(path)
        makefile = self._makefile_for(path)

        if makefile is None:
            return []

        try:
            m = self._cache[makefile]

            if m.up_to_date_for(path):
                return m.flags_for_file(path)
        except KeyError:
            pass

        targets = self._targets_from_make(makefile, path)
        flags = self._flags_from_targets(makefile, path, targets)

        return self._update_cache(makefile, path, flags)

    def _update_cache(self, makefile, path, flags):
        try:
            m = self._cache[makefile]
        except KeyError:
            m = MakefileIntegration.Makefile(makefile)
            self._cache[makefile] = m

        m.add(path, flags)
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
        parent = os.path.dirname(path)

        while True:
            makefile = os.path.join(parent, 'Makefile')

            if os.path.isfile(makefile):
                return makefile

            if tryac:
                configureac = os.path.join(parent, 'configure.ac')

                if os.path.isfile(configureac):
                    ret = self._subdir_makefile_for(path, parent)

                    if not ret is None:
                        return ret

            parent = os.path.dirname(parent)

            if parent == '/':
                break

        return None

    def _targets_from_make(self, makefile, source):
        try:
            m = self._cache[makefile]

            if m.up_to_date_for(source):
                return m.flags_for_file(source)
        except KeyError:
            pass

        wd = os.path.dirname(makefile)

        lookfor = [
            os.path.relpath(source, wd),
            os.path.basename(source)
        ]

        noext = [os.path.splitext(x)[0] for x in lookfor]
        args = ['make', '-p', '-n']

        try:
            with open(os.devnull, 'w') as stderr:
                outstr = str(subprocess.check_output(args, cwd=wd, stderr=stderr), 'utf-8')
        except:
            return []

        relookfor = [re.escape(x) for x in lookfor]
        reg = re.compile('^([^:\n]+):.*({0})'.format('|'.join(relookfor)), re.M)

        fnames = [re.escape(x) for x in noext]

        targetregs = [
            re.compile('^([^:]*(({0})\\.(o|lo)))$'.format('|'.join(fnames))),
            re.compile('^[a-z]+$')
        ]

        targets = {}

        for match in reg.finditer(outstr):
            target = match.group(1)

            if target[0] == '#':
                continue

            for i, r in enumerate(targetregs):
                if r.match(target):
                    try:
                        ic = targets[target]

                        if i < ic:
                            targets[target] = i
                    except KeyError:
                        targets[target] = i

                    break

        ret = list(targets.keys())
        ret.sort(key=lambda x: targets[x])

        return ret

    def _flags_from_targets(self, makefile, source, targets):
        if len(targets) == 0:
            return []

        fakecc = '__GCA_C_COMPILE_FLAGS__'

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
            'CXX=' + fakecc,
        ]

        args += targets

        try:
            with open(os.devnull, 'w') as stderr:
                outstr = str(subprocess.check_output(args, cwd=wd, stderr=stderr), 'utf-8')
        except:
            return []

        try:
            pos = outstr.rindex(fakecc)
        except ValueError:
            return []

        try:
            epos = outstr.index(os.linesep, pos)
        except ValueError:
            epos = len(outstr)

        pargs = outstr[pos + len(fakecc):epos]
        return self._filter_flags(makefile, shlex.split(pargs))

    def _filter_flags(self, makefile, flags):
        # Keep only interesting flags:
        # -I: include paths
        # -D: defines
        # -W: warnings
        # -f: compiler flags

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
            elif v == 'D' or v == 'f' or v == 'W':
                # pass defines, compiler flags and warnings
                ret.append(flag)

                # Also add the argument if its not embedded
                if v == 'D' and len(flag) == 2 and i < len(flags):
                    ret.append(flags[i])
                    i += 1

        return ret

if __name__ == '__main__':
    m = MakefileIntegration()
    print(m.flags_for_file('../../clients/gedit/gca-plugin.c'))

# ex:ts=4:et:
