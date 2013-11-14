cssbackenddir = $(GCA_RBBACKENDS_DIR)/css
cssbackend_DATA = 				\
	backends/css/app.rb

cssbackendexecdir = $(GCA_BACKENDS_EXEC_DIR)
cssbackendexec_SCRIPTS = \
	backends/css/css

cssbackendservicedir = $(datadir)/dbus-1/services
cssbackendservice_DATA = \
	backends/css/org.gnome.CodeAssist.v1.css.service

EXTRA_DIST +=				\
	$(cssbackend_DATA)		\
	$(cssbackendservice_DATA)	\
	backends/css/gems

if RUBY_SASS
else
include backends/css/deps.mf
endif

GITIGNOREDEPS += backends/css/Makefile.am
