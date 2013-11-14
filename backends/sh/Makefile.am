shbackenddir = $(GCA_PYBACKENDS_DIR)/sh
shbackend_PYTHON = 				\
	backends/sh/__init__.py

shbackendexecdir = $(GCA_BACKENDS_EXEC_DIR)
shbackendexec_SCRIPTS = \
	backends/sh/sh

shbackendservicedir = $(datadir)/dbus-1/services
shbackendservice_DATA = \
	backends/sh/org.gnome.CodeAssist.v1.sh.service

EXTRA_DIST += $(shbackendservice_DATA)

GITIGNOREDEPS += backends/sh/Makefile.am
