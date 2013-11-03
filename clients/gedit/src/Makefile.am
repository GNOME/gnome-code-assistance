geditcodeassistanceplugin_LTLIBRARIES = clients/gedit/src/libcodeassistance.la

clients_gedit_vala_sources =					\
	clients/gedit/src/gca.vala				\
	clients/gedit/src/gca-plugin.vala			\
	clients/gedit/src/gca-app-activatable.vala		\
	clients/gedit/src/gca-view-activatable.vala		\
	clients/gedit/src/gca-source-location.vala		\
	clients/gedit/src/gca-source-range.vala			\
	clients/gedit/src/gca-expand-range.vala			\
	clients/gedit/src/gca-source-range-support.vala		\
	clients/gedit/src/gca-source-index.vala			\
	clients/gedit/src/gca-view.vala				\
	clients/gedit/src/gca-document.vala			\
	clients/gedit/src/gca-scrollbar-marker.vala		\
	clients/gedit/src/gca-backend.vala			\
	clients/gedit/src/gca-backend-implementation.vala	\
	clients/gedit/src/gca-backend-manager.vala		\
	clients/gedit/src/gca-unsaved-file.vala			\
	clients/gedit/src/gca-semantic-value.vala		\
	clients/gedit/src/gca-semantic-value-support.vala	\
	clients/gedit/src/gca-symbol-browser.vala		\
	clients/gedit/src/gca-symbol-browser-support.vala	\
	clients/gedit/src/gca-diagnostic.vala			\
	clients/gedit/src/gca-diagnostic-colors.vala		\
	clients/gedit/src/gca-diagnostic-tags.vala		\
	clients/gedit/src/gca-diagnostic-support.vala		\
	clients/gedit/src/gca-diagnostic-message.vala		\
	clients/gedit/src/gca-log.vala

clients_gedit_libcodeassistance_NOINSTHFILES =			\
	clients/gedit/src/gca-utils-c.h

BUILT_SOURCES +=						\
	clients/gedit/src/libcodeassistance.vapi		\
	$(srcdir)/clients_gedit_src_libcodeassistance_la_vala.stamp

EXTRA_DIST += $(clients_gedit_libcodeassistance_NOINSTHFILES)

clients_gedit_src_libcodeassistance_la_SOURCES =		\
	$(clients_gedit_vala_sources)				\
	clients/gedit/src/gca-utils-c.c

clients_gedit_src_libcodeassistance_la_VALAFLAGS =		\
	--vapidir $(top_srcdir)/clients/gedit/vapi		\
	--vapi clients/gedit/src/libcodeassistance.vapi		\
	--library libcodeassistance				\
	--pkg gee-1.0						\
	--pkg gca-utils						\
	--pkg gedit						\
	--pkg libpeas-1.0					\
	--pkg posix						\
	--target-glib=2.32					\
	--thread

clients_gedit_src_libcodeassistance_la_CFLAGS = $(GEDIT_CFLAGS) -I$(top_srcdir) -w
clients_gedit_src_libcodeassistance_la_LDFLAGS = -module -shared -avoid-version $(GEDIT_LIBS)

CLEANFILES += 							\
	$(clients_gedit_vala_sources:.vala=.c)			\
	clients_gedit_src_libcodeassistance_la_vala.stamp

GITIGNOREFILES +=						\
	clients/gedit/src/libcodeassistance.vapi		\
	clients/gedit/src/$(DEPDIR)				\
	clients/gedit/src/*.lo					\
	clients/gedit/src/*.o					\
	clients/gedit/src/.libs					\
	clients/gedit/src/.dirstamp
