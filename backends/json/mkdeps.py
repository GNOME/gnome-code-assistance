#!/usr/bin/env python

import subprocess, os, re

perdir = {}

rethead = subprocess.check_output(['git', 'ls-tree', 'HEAD', '--name-only', '-r', '--', 'deps']).decode('utf-8').splitlines()
retindex = subprocess.check_output(['git', 'ls-files', '--', 'deps']).decode('utf-8').splitlines()

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

print('if PYTHON_SIMPLEJSON')
print('else')

for dname in perdir:
    vname = 'json_{0}'.format(re.sub('[/.-]', '_', dname))

    print('{0}dir = $(GCA_PYBACKENDS_DIR)/json/{1}'.format(vname, dname))
    print('{0}_DATA = \\'.format(vname))
    print("\tbackends/json/{0}".format(" \\\n\tbackends/json/".join(perdir[dname])))
    print('')

    datas.append('$({0}_DATA)'.format(vname))

print('endif\n')
print('EXTRA_DIST += \\\n\t{0}'.format(' \\\n\t'.join(datas)))

# vi:ts=4:et
