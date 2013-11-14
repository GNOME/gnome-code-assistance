pythonbackenddir = $(GCA_PYBACKENDS_DIR)/python
pythonbackend_PYTHON = 				\
	backends/python/__init__.py

pythonbackendexecdir = $(GCA_BACKENDS_EXEC_DIR)
pythonbackendexec_SCRIPTS = \
	backends/python/python

pythonbackendservicedir = $(datadir)/dbus-1/services
pythonbackendservice_DATA = \
	backends/python/org.gnome.CodeAssist.v1.python.service

EXTRA_DIST += $(pythonbackendservice_DATA)

GITIGNOREDEPS += backends/python/Makefile.am
