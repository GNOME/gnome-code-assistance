#!/usr/bin/env python

import subprocess, os, re

perdir = {}

rethead = subprocess.check_output(['git', 'ls-tree', 'HEAD', '--name-only', '-r', '--', 'deps']).decode('utf-8').splitlines()
retindex = subprocess.check_output(['git', 'ls-files', '--', 'gems']).decode('utf-8').splitlines()

ret = rethead + retindex
seen = {}

for r in ret:
    if r in seen:
        continue

    seen[r] = True
    dname = os.path.dirname(r)

    if dname in perdir:
        perdir[dname].append(r)
    else:
        perdir[dname] = [r]

datas = []

for dname in perdir:
    vname = 'godeps_{0}'.format(re.sub('[/.-]', '_', dname))

    print('{0} = \\'.format(vname))
    print("\tbackends/go/{0}".format(" \\\n\tbackends/go/".join(perdir[dname])))
    print('')

    datas.append('$({0})'.format(vname))

print('EXTRA_DIST += \\\n\t{0}'.format(' \\\n\t'.join(datas)))

# vi:ts=4:et
