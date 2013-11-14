ACLOCAL_AMFLAGS = -I m4

MAINTAINERCLEANFILES = 			\
	INSTALL				\
	aclocal.m4			\
	config.guess			\
	config.h.in			\
	config.sub			\
	depcomp				\
	gnome-code-assistance.doap	\
	gtk-doc.make			\
	install-sh			\
	ltmain.sh			\
	missing				\
	mkinstalldirs			\
	omf.make			\
	py-compile			\
	m4/libtool.m4			\
	m4/ltoptions.m4			\
	m4/ltsugar.m4			\
	m4/ltversion.m4			\
	m4/lt~obsolete.m4		\
	`find "$(srcdir)" -type f -name Makefile.in -print`

CLEANFILES =
EXTRA_DIST =
GITIGNOREFILES =
GITIGNOREDEPS =
BUILT_SOURCES =
DISTCLEANFILES =
MAINTAINERCLEANFILES =
gsettings_SCHEMAS =

include data/Makefile.am
include backends/Makefile.am

@GSETTINGS_RULES@

CLEANFILES += $(gsettings_SCHEMAS)
DISTCLEANFILES += $(gsettings_SCHEMAS)

MAINTAINERCLEANFILES += $(gsettings_SCHEMAS:.xml=.valid)

dist-hook-changelog:
	@if test -d "$(srcdir)/.git"; \
	then \
		echo Creating ChangeLog && \
		(GIT_DIR=$(top_srcdir)/.git \
		  ./missing --run git log --stat -M -C --name-status  --date=short --no-color) | \
		  fmt --split-only > ChangeLog.tmp \
		&& mv -f ChangeLog.tmp $(top_distdir)/ChangeLog \
		|| ( rm -f ChangeLog.tmp ; \
		  echo Failed to generate ChangeLog >&2 ); \
	else \
		echo A git clone is required to generate a ChangeLog >&2; \
	fi

dist-hook-built-sources:
	cd $(distdir); rm -f $(BUILT_SOURCES)

dist-hook: dist-hook-changelog dist-hook-built-sources

-include $(top_srcdir)/git.mk
