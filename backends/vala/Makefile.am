valabackenddir = $(GCA_BACKENDS_EXEC_DIR)

noinst_LTLIBRARIES = backends/vala/libvalashared.la

valabackend_PROGRAMS = backends/vala/vala backends/vala/valahelper

backends_vala_libvalashared_la_SOURCES =	\
	backends/vala/types.vala		\
	backends/vala/rpc.vala			\
	backends/vala/hashutils.vala

backends_vala_vala_SOURCES =			\
	backends/vala/application.vala		\
	backends/vala/dbus.vala			\
	backends/vala/document.vala		\
	backends/vala/service.vala		\
	backends/vala/makefileintegration.vala	\
	backends/vala/config.vala

backends_vala_valahelper_SOURCES =		\
	backends/vala/valaoptionparser.vala	\
	backends/vala/diagnostics.vala		\
	backends/vala/helper.vala

backends_vala_common_valaflags =		\
	--target-glib=2.36			\
	--pkg gio-2.0				\
	--pkg gee-0.8				\
	--pkg $(BACKEND_VALA_LIBVALA)

if ENABLE_DEBUG
backends_vala_common_valaflags += --debug -X -O0
endif

backends_vala_libvalashared_la_VALAFLAGS =	\
	$(backends_vala_common_valaflags)	\
	--library libvalashared			\
	--vapi backends/vala/libvalashared.vapi	\
	--header backends/vala/libvalashared.h	\
	--includedir backends/vala

backends_vala_vala_VALAFLAGS =			\
	$(backends_vala_common_valaflags)	\
	--pkg libvalashared			\
	--vapidir backends/vala

backends_vala_valahelper_VALAFLAGS =		\
	$(backends_vala_common_valaflags)	\
	--pkg libvalashared			\
	--vapidir backends/vala

backends_vala_libvalashared_la_CFLAGS = $(BACKEND_VALA_CFLAGS) -w

backends_vala_vala_CFLAGS = $(BACKEND_VALA_CFLAGS) -w
backends_vala_vala_LDADD = $(BACKEND_VALA_LIBS) backends/vala/libvalashared.la

backends_vala_valahelper_CFLAGS = $(BACKEND_VALA_CFLAGS) -w
backends_vala_valahelper_LDADD = $(BACKEND_VALA_LIBS) backends/vala/libvalashared.la

valabackendservicedir = $(datadir)/dbus-1/services
valabackendservice_DATA = \
	backends/vala/org.gnome.CodeAssist.v1.vala.service

CLEANFILES +=							\
	$(backends_vala_vala_SOURCES:.vala=.c)			\
	$(backends_vala_valahelper_SOURCES:.vala=.c)		\
	$(backends_vala_libvalashared_la_SOURCES:.vala=.c)	\
	backends/vala/libvalashared.h				\
	backends/vala/libvalashared.vapi			\
	backends_vala_vala_vala.stamp				\
	backends_vala_valahelper_vala.stamp			\
	backends_vala_libvalashared_la_vala.stamp

GITIGNOREFILES +=				\
	backends/vala/$(DEPDIR)			\
	backends/vala/.libs			\
	backends/vala/.dirstamp			\
	backends/vala/*.o			\
	backends/vala/*.lo

EXTRA_DIST += $(valabackendservice_DATA)

GITIGNOREDEPS += backends/vala/Makefile.am
