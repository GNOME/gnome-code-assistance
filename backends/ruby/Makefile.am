rubybackenddir = $(GCA_RBBACKENDS_DIR)/ruby
rubybackend_DATA = 				\
	backends/ruby/app.rb			\
	backends/ruby/parser.rb

rubybackendexecdir = $(GCA_BACKENDS_EXEC_DIR)
rubybackendexec_SCRIPTS = \
	backends/ruby/ruby

rubybackendservicedir = $(datadir)/dbus-1/services
rubybackendservice_DATA = \
	backends/ruby/org.gnome.CodeAssist.v1.ruby.service

EXTRA_DIST +=					\
	$(rubybackend_DATA)			\
	$(rubybackendservice_DATA)

GITIGNOREDEPS += backends/ruby/Makefile.am
