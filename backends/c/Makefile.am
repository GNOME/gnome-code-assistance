cbackenddir = $(GCA_PYBACKENDS_DIR)/c
cbackend_PYTHON = 				\
	backends/c/__init__.py			\
	backends/c/service.py			\
	backends/c/clangimporter.py		\
	backends/c/makefileintegration.py	\
	backends/c/config.py

cclangbackenddir = $(GCA_PYBACKENDS_DIR)/c/clang
cclangbackend_PYTHON = 				\
	backends/c/clang/__init__.py		\
	backends/c/clang/cindex.py		\
	backends/c/clang/enumerations.py

cbackendexecdir = $(GCA_BACKENDS_EXEC_DIR)
cbackendexec_SCRIPTS = \
	backends/c/c

cbackendservicedir = $(datadir)/dbus-1/services
cbackendservice_DATA = \
	backends/c/org.gnome.CodeAssist.v1.c.service

GITIGNOREDEPS += backends/c/Makefile.am
