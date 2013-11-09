valabackenddir = $(GCA_BACKENDS_EXEC_DIR)
valabackend_PROGRAMS = backends/vala/vala

backends_vala_vala_SOURCES =			\
	backends/vala/application.vala		\
	backends/vala/options.vala		\
	backends/vala/types.vala		\
	backends/vala/dbus.vala			\
	backends/vala/document.vala		\
	backends/vala/service.vala

backends_vala_vala_VALAFLAGS =			\
	--target-glib=2.36			\
	--pkg gio-2.0				\
	--pkg gee-0.8				\
	--pkg libvala-0.22

backends_vala_vala_CFLAGS = $(BACKEND_VALA_CFLAGS) -w
backends_vala_vala_LDADD = $(BACKEND_VALA_LIBS)

if ENABLE_DEBUG
backends_vala_vala_VALAFLAGS += --debug
endif

valabackendservicedir = $(datadir)/dbus-1/services
valabackendservice_DATA = \
	backends/vala/org.gnome.CodeAssist.vala.service

CLEANFILES +=					\
	$(backends_vala_vala_SOURCES:.vala=.c)	\
	backends_vala_vala_vala.stamp

GITIGNOREFILES +=				\
	backends/vala/$(DEPDIR)			\
	backends/vala/.dirstamp			\
	backends/vala/*.o

GITIGNOREDEPS += backends/vala/Makefile.am
