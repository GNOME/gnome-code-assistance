#!/usr/bin/env python

import subprocess, os, re

perdir = {}

ret = subprocess.check_output(['git', 'ls-tree', 'HEAD', '--name-only', '-r', '--', 'gems']).splitlines()

for r in ret:
    dname = os.path.dirname(r)

    if dname in perdir:
        perdir[dname].append(r)
    else:
        perdir[dname] = [r]

for dname in perdir:
    vname = 'csssass_{0}'.format(re.sub('[/.-]', '_', dname))

    print('{0}dir = $(GCA_RBBACKENDS_DIR)/css/{1}'.format(vname, dname))
    print('{0}_DATA = \\'.format(vname))
    print("\tbackends/css/{0}".format(" \\\n\tbackends/css/".join(perdir[dname])))
    print('')

# vi:ts=4:et
