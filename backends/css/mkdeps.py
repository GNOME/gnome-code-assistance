#!/usr/bin/env python

import subprocess, os, re

perdir = {}

ret = subprocess.check_output(['git', 'ls-files', '--', 'gems']).decode('utf-8').splitlines()
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

print('if RUBY_SASS')
print('else')

for dname in perdir:
    vname = 'csssass_{0}'.format(re.sub('[/.-]', '_', dname))

    print('{0}dir = $(GCA_RBBACKENDS_DIR)/css/{1}'.format(vname, dname))
    print('{0}_DATA = \\'.format(vname))
    print("\tbackends/css/{0}".format(" \\\n\tbackends/css/".join(perdir[dname])))
    print('')

    datas.append('$({0}_DATA)'.format(vname))

print('endif\n')

print('EXTRA_DIST += \\\n\t{0}'.format(' \\\n\t'.join(datas)))

# vi:ts=4:et
