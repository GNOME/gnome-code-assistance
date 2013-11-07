gobackenddir = $(GCA_BACKENDS_EXEC_DIR)
gobackend_PROGRAMS = backends/go/go

backends_go_go_SOURCES =			\
	$(wildcard $(top_srcdir)/backends/go/*.go)

go_verbose = $(go_verbose_@AM_V@)
go_verbose_ = $(go_verbose_@AM_DEFAULT_V@)
go_verbose_0 = @echo [GO] $@;

backends/go/go: $(backends_go_go_SOURCES)
	$(go_verbose) (cd $(top_srcdir)/backends/go && GOPATH=$(abs_srcdir)/backends/go/deps go build)

gobackendservicedir = $(datadir)/dbus-1/services
gobackendservice_DATA = \
	backends/go/org.gnome.CodeAssist.go.service

EXTRA_DIST += backends/go/deps

GITIGNOREDEPS += backends/go/Makefile.am
