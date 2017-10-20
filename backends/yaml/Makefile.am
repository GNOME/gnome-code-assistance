yamlbackenddir = $(GCA_PYBACKENDS_DIR)/yaml
yamlbackend_PYTHON = 				\
	backends/yaml/__init__.py

yamlbackendexecdir = $(GCA_BACKENDS_EXEC_DIR)
yamlbackendexec_SCRIPTS = \
	backends/yaml/yaml

yamlbackendservicedir = $(datadir)/dbus-1/services
yamlbackendservice_DATA = \
	backends/yaml/org.gnome.CodeAssist.v1.yaml.service

EXTRA_DIST += $(pythonbackendservice_DATA)

GITIGNOREDEPS += backends/yaml/Makefile.am
