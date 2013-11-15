jsonbackenddir = $(GCA_PYBACKENDS_DIR)/json
jsonbackend_PYTHON = 				\
	backends/json/__init__.py

jsonbackendexecdir = $(GCA_BACKENDS_EXEC_DIR)
jsonbackendexec_SCRIPTS = \
	backends/json/json

jsonbackendservicedir = $(datadir)/dbus-1/services
jsonbackendservice_DATA = \
	backends/json/org.gnome.CodeAssist.v1.json.service

EXTRA_DIST += $(jsonbackendservice_DATA)

include backends/json/deps.mf

GITIGNOREDEPS += backends/json/Makefile.am
