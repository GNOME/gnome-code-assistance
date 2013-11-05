AC_PREREQ(2.63.2)

m4_define(gnome_code_assistance_major_version, 0)
m4_define(gnome_code_assistance_minor_version, 2)
m4_define(gnome_code_assistance_micro_version, 0)
m4_define(gnome_code_assistance_version, gnome_code_assistance_major_version.gnome_code_assistance_minor_version.gnome_code_assistance_micro_version)

AC_INIT([gnome-code-assistance],[gnome_code_assistance_version],[http://bugzilla.gnome.org/enter_bug.cgi?product=gedit],[gnome-code-assistance],[http://projects.gnome.org/gedit/])

AC_CONFIG_HEADERS(config.h)
AC_CONFIG_MACRO_DIR([m4])

AM_PROG_LIBTOOL

AM_PATH_PYTHON

AM_INIT_AUTOMAKE([1.11 tar-ustar dist-xz no-dist-gzip -Wno-portability subdir-objects])
AM_MAINTAINER_MODE([enable])
AM_SILENT_RULES([yes])

AC_PROG_INSTALL
AC_PROG_MAKE_SET

dnl adl_RECURSIVE_EVAL(VALUE, RESULT)
dnl =================================
dnl Interpolate the VALUE in loop until it doesn't change,
dnl and set the result to $RESULT.
dnl WARNING: It's easy to get an infinite loop with some unsane input.
AC_DEFUN([adl_RECURSIVE_EVAL],
[_lcl_receval="$1"
$2=`(test "x$prefix" = xNONE && prefix="$ac_default_prefix"
     test "x$exec_prefix" = xNONE && exec_prefix="${prefix}"
     _lcl_receval_old=''
     while test "[$]_lcl_receval_old" != "[$]_lcl_receval"; do
       _lcl_receval_old="[$]_lcl_receval"
       eval _lcl_receval="\"[$]_lcl_receval\""
     done
     echo "[$]_lcl_receval")`])

#AC_PATH_PROG([LLVM_CONFIG], [llvm-config], [])

#if test "x$LLVM_CONFIG" = "x"; then
#	clang_enabled=no
#	AC_MSG_WARN([could not find llvm-config])
#else
#	dnl find out the libdir of llvm
#	LLVM_LIBS=$($LLVM_CONFIG --ldflags)
#	LLVM_CFLAGS=$($LLVM_CONFIG --cflags)

#	dnl ================================================================
#	dnl Find clang headers and lib
#	dnl ================================================================
#	OLDCFLAGS="$CFLAGS"
#	OLDLDFLAGS="$LDFLAGS"

#	CFLAGS="$OLDCFLAGS $LLVM_CFLAGS"
#	LDFLAGS="$OLDLDFLAGS $LLVM_LIBS"

#	AC_CHECK_LIB([clang],
#	             [clang_createIndex],
#	             [LLVM_LIBS="$LLVM_LIBS -lclang"
#	              clang_enabled="yes"],
#	             [AC_MSG_WARN([could not find clang library])
#	              clang_enabled="no"])

#	if test "x$clang_enabled" = "xyes"; then
#		AC_CHECK_HEADER([clang-c/Index.h],
#		                [],
#		                [AC_MSG_WARN([could not find clang header Index.h])
#		                 clang_enabled="no"])
#	fi

#	if test "x$clang_enabled" = "xyes"; then
#		LLVM_LIBS="$LLVM_LIBS -lclang"
#	fi

#	AC_SUBST(LLVM_CFLAGS)
#	AC_SUBST(LLVM_LIBS)

#	CFLAGS="$OLDCFLAGS"
#	LDFLAGS="$OLDLDFLAGS"

#	LLVM_VERSION=$($LLVM_CONFIG --version)
#	AC_DEFINE_UNQUOTED([LLVM_VERSION], "$LLVM_VERSION", [LLVM version])

#	AC_SUBST(LLVM_VERSION)
#fi

#AM_CONDITIONAL(CLANG_ENABLED, test "x$clang_enabled" = "xyes")

AC_ARG_ENABLE([debug],
              AS_HELP_STRING([--enable-debug],[enable debug build]),
              [enable_debug=$enableval],
              [enable_debug=no])

AM_CONDITIONAL(ENABLE_DEBUG, test "x$enable_debug" = "xyes")

AC_ARG_ENABLE([local],
              AS_HELP_STRING([--enable-local],[enable local install (in user directory)]),
              [enable_local=$enableval],
              [enable_local=no])

dnl ================================================================
dnl gedit client configuration
dnl ================================================================
AC_ARG_ENABLE([gedit],
              AS_HELP_STRING([--enable-gedit],[enable gedit client]),
              [enable_gedit=$enableval],
              [enable_gedit=auto])

GEDIT_MODULES="gedit >= 3.8 gee-0.8"

if test "x$enable_gedit" != "xno"; then
	AM_PROG_VALAC
	PKG_PROG_PKG_CONFIG
fi

if test "x$enable_gedit" = "xauto"; then
	PKG_CHECK_EXISTS([$GEDIT_MODULES],
	                 [enable_gedit=yes],
	                 [enable_gedit=no])

	if test "x$VALAC" = "x"; then
		enable_gedit=no
	fi
fi

if test "x$enable_gedit" = "xyes"; then
	PKG_CHECK_MODULES([GEDIT], $GEDIT_MODULES)

	if test "x$VALAC" = "x"; then
		AC_MSG_ERROR([Cannot find the "valac" compiler])
	fi

	gedit_prefix=`$PKG_CONFIG --variable=prefix gedit`

	GEDIT_GIR_DIR="$gedit_prefix/share/gedit/gir-1.0"
	AC_SUBST(GEDIT_GIR_DIR)

	GEDIT_API_VERSION=3.0
	AC_SUBST(GEDIT_API_VERSION)

	if test "x$enable_local" = "xyes"; then
		geditlibdir="$HOME/.local/share"
		geditdatadir="$HOME/.local/share"
	else
		geditlibdir="${libdir}"
		geditdatadir="${datadir}"
	fi

	GEDIT_PLUGIN_DIR="$geditlibdir/gedit/plugins"
	GEDIT_DATA_DIR="$geditdatadir/gedit/plugins"

	AC_SUBST(GEDIT_PLUGIN_DIR)
	AC_SUBST(GEDIT_DATA_DIR)

	AC_SUBST(GEDIT_CFLAGS)
	AC_SUBST(GEDIT_LIBS)
fi

AM_CONDITIONAL(GEDIT_ENABLE, test "x$enable_gedit" = "xyes")



dnl ================================================================
dnl python support
dnl ================================================================
AM_CONDITIONAL(PYTHON_ENABLE, test "x$PYTHON" != "x")



dnl ================================================================
dnl python backend configuration
dnl ================================================================
AC_ARG_ENABLE([python],
              AS_HELP_STRING([--enable-python],[enable python backend]),
              [enable_python=$enableval],
              [enable_python=auto])

AC_MSG_CHECKING([python backend])

if test "x$enable_python" = "xauto"; then
	if test "x$PYTHON" = "x"; then
		AC_MSG_RESULT([no])
		enable_python=no
	else
		AC_MSG_RESULT([yes])
		enable_python=yes
	fi
elif test "x$enable_python" != "xno"; then
	if test "x$PYTHON" = "x"; then
		AC_MSG_ERROR([python not found])
	else
		AC_MSG_RESULT([yes])
		enable_python=yes
	fi
else
	AC_MSG_RESULT([no])
fi

AM_CONDITIONAL(BACKENDS_PYTHON_ENABLE, test "x$enable_python" = "xyes")



dnl ================================================================
dnl xml backend configuration
dnl ================================================================
AC_ARG_ENABLE([xml],
              AS_HELP_STRING([--enable-xml],[enable xml backend]),
              [enable_xml=$enableval],
              [enable_xml=auto])

AC_MSG_CHECKING([xml backend])

if test "x$enable_xml" = "xauto"; then
	if test "x$PYTHON" = "x"; then
		AC_MSG_RESULT([no])
		enable_xml=no
	else
		AC_MSG_RESULT([yes])
		enable_xml=yes
	fi
elif test "x$enable_xml" != "xno"; then
	if test "x$PYTHON" = "x"; then
		AC_MSG_ERROR([python not found])
	else
		AC_MSG_RESULT([yes])
		enable_xml=yes
	fi
else
	AC_MSG_RESULT([no])
fi

AM_CONDITIONAL(BACKENDS_XML_ENABLE, test "x$enable_xml" = "xyes")



backendexecdir_unex="$libexecdir/gnome-code-assistance"
adl_RECURSIVE_EVAL("$backendexecdir_unex", [backendexecdir])
AC_SUBST(backendexecdir)

GCA_BACKENDS_EXEC_DIR="$libexecdir/gnome-code-assistance"
AC_SUBST(GCA_BACKENDS_EXEC_DIR)

GCA_BACKENDS_DIR="$libexecdir/gnome-code-assistance/backends"
AC_SUBST(GCA_BACKENDS_DIR)

adl_RECURSIVE_EVAL("$GCA_BACKENDS_DIR", [GCA_BACKENDS_DIR_EX])
AC_SUBST(GCA_BACKENDS_DIR_EX)

GCA_PYBACKENDS_DIR="$libexecdir/gnome-code-assistance/backends/gnome/codeassistance"
AC_SUBST(GCA_PYBACKENDS_DIR)

adl_RECURSIVE_EVAL("$GCA_PYBACKENDS_DIR", [GCA_PYBACKENDS_DIR_EX])
AC_SUBST(GCA_PYBACKENDS_DIR_EX)

AC_CONFIG_FILES([
Makefile
clients/gedit/data/codeassistance.plugin
backends/python/org.gnome.CodeAssist.python.service
backends/python/python
backends/xml/org.gnome.CodeAssist.xml.service
backends/xml/xml
])

AC_OUTPUT

echo "

Configuration:

	prefix:                 ${prefix}
	source code location:   ${srcdir}
	compiler:               ${CC}
	debug:                  $enable_debug

	backends:
		python:         $enable_python
		xml:            $enable_xml

	clients:
		gedit:          $enable_gedit
"

