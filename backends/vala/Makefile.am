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
	--pkg $(BACKEND_VALA_LIBVALA)

backends_vala_vala_CFLAGS = $(BACKEND_VALA_CFLAGS) -w
backends_vala_vala_LDADD = $(BACKEND_VALA_LIBS)

if ENABLE_DEBUG
backends_vala_vala_VALAFLAGS += --debug
endif

valabackendservicedir = $(datadir)/dbus-1/services
valabackendservice_DATA = \
	backends/vala/org.gnome.CodeAssist.v1.vala.service

CLEANFILES +=					\
	$(backends_vala_vala_SOURCES:.vala=.c)	\
	backends_vala_vala_vala.stamp

GITIGNOREFILES +=				\
	backends/vala/$(DEPDIR)			\
	backends/vala/.dirstamp			\
	backends/vala/*.o

EXTRA_DIST += $(valabackendservide_DATA)

GITIGNOREDEPS += backends/vala/Makefile.am
