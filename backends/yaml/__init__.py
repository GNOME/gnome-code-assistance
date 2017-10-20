# gnome code assistance yaml backend
# Copyright (C) 2017  Elad Alfassa <elad@fedoraproject.org>
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

import os
import os.path

from gnome.codeassistance import transport, types

from yamllint.config import YamlLintConfig
from yamllint.linter import PROBLEM_LEVELS
from yamllint import linter


def get_yamllint_config(doc_path):
    """ Look for yamllint config files and return a YamlLintConfig object """

    # try .yamlllint first
    doc_dir = os.path.dirname(doc_path)
    dotfile = os.path.join(doc_dir, '.yamllint')
    if os.path.isfile(dotfile):
        return YamlLintConfig(file=dotfile)

    # try the global user config file second

    if 'XDG_CONFIG_HOME' in os.environ:
        configfile = os.path.join(os.environ['XDG_CONFIG_HOME'], 'yamllint', 'config')
    else:
        configfile = os.path.expanduser('~/.config/yamllint/config')

    if os.path.isfile(configfile):
        return YamlLintConfig(file=configfile)

    # use default config if no config file exists
    return YamlLintConfig('extends: default')


class Service(transport.Service):
    language = 'yaml'

    def parse(self, doc, options):
        doc.diagnostics = []

        # load the yamllint config file, if exists
        config = get_yamllint_config(doc.path)

        with open(doc.data_path) as f:
            for problem in linter.run(f, config, doc.data_path):
                loc = types.SourceLocation(line=problem.line, column=problem.column)

                severity = types.Diagnostic.Severity.INFO
                if problem.level == 'warning':
                    severity = types.Diagnostic.Severity.WARNING
                elif problem.level == 'error':
                    severity = types.Diagnostic.Severity.ERROR

                doc.diagnostics.append(types.Diagnostic(severity=severity,
                                                        locations=[loc.to_range()],
                                                        message=problem.message))


class Document(transport.Document, transport.Diagnostics):
    pass


def run():
    transport.Transport(Service, Document).run()

if __name__ == '__main__':
    run()

# ex:ts=4:et:
