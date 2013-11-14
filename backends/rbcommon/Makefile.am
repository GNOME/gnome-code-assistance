rbgnomecodeassistancebackenddir = $(GCA_RBBACKENDS_ROOT)/gnome/codeassistance

rbgnomecodeassistancebackend_DATA =					\
	backends/rbcommon/gnome/codeassistance/transport.rb		\
	backends/rbcommon/gnome/codeassistance/types.rb

rbgnomecodeassistancebackendtransportdir = $(GCA_RBBACKENDS_ROOT)/gnome/codeassistance/transport
rbgnomecodeassistancebackendtransport_DATA =				\
	backends/rbcommon/gnome/codeassistance/transport/dbus.rb

EXTRA_DIST +=								\
	$(rbgnomecodeassistancebackend_DATA)				\
	$(rbgnomecodeassistancebackendtransport_DATA)

GITIGNOREDEPS += backends/rbcommon/Makefile.am
