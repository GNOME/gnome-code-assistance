jsbackenddir = $(GCA_JSBACKENDS_DIR)/js
jsbackend_DATA = 				\
	backends/js/main.js			\
	backends/js/deps/acorn.js

jsbackendexecdir = $(GCA_BACKENDS_EXEC_DIR)
jsbackendexec_SCRIPTS = \
	backends/js/js

jsbackendservicedir = $(datadir)/dbus-1/services
jsbackendservice_DATA = \
	backends/js/org.gnome.CodeAssist.v1.js.service

EXTRA_DIST +=				\
	$(jsbackend_DATA)		\
	$(jsbackendservice_DATA)

GITIGNOREDEPS += backends/js/Makefile.am
