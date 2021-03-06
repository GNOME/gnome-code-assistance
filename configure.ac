AC_PREREQ(2.63.2)

m4_define(gnome_code_assistance_major_version, 3)
m4_define(gnome_code_assistance_minor_version, 16)
m4_define(gnome_code_assistance_micro_version, 1)
m4_define(gnome_code_assistance_version, gnome_code_assistance_major_version.gnome_code_assistance_minor_version.gnome_code_assistance_micro_version)

AC_INIT([gnome-code-assistance],[gnome_code_assistance_version],[http://bugzilla.gnome.org/enter_bug.cgi?product=gnome-code-assistance],[gnome-code-assistance],[http://live.gnome.org/CodeAssistance/])

AC_CONFIG_HEADERS(config.h)
AC_CONFIG_MACRO_DIR([m4])

AM_PROG_LIBTOOL
AM_PATH_PYTHON(3, [python_found=3], [python_found=no])

if test "x$python_found" = "xno"; then
	AM_PATH_PYTHON(2, [python_found=2])
fi

AM_INIT_AUTOMAKE([1.11 tar-ustar dist-xz no-dist-gzip -Wno-portability subdir-objects])
AM_MAINTAINER_MODE([enable])
AM_SILENT_RULES([yes])

AC_PROG_INSTALL
AC_PROG_MAKE_SET

GLIB_GSETTINGS

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

AC_DEFUN([color_enable_var],
[if test "x$1" != "xyes"; then
	$2="\033@<:@31m$1\033@<:@0m"
else
	$2="\033@<:@32m$1\033@<:@0m"
fi])

AC_ARG_ENABLE([debug],
              AS_HELP_STRING([--enable-debug],[enable debug build]),
              [enable_debug=$enableval],
              [enable_debug=no])

color_enable_var("$enable_debug", [enable_debug_msg])

AM_CONDITIONAL(ENABLE_DEBUG, test "x$enable_debug" = "xyes")

dnl ================================================================
dnl python support
dnl ================================================================
if test "x$python_found" != "xno"; then
	AC_MSG_CHECKING([python dbus])
	$PYTHON -c 'import dbus' 2>/dev/null
	if test $? -ne 0 ; then
		AC_MSG_RESULT([no])
		python_found=no
	else
		AC_MSG_RESULT([yes])
	fi
fi

if test "x$python_found" != "xno"; then
	AC_MSG_CHECKING([python gobject])
	$PYTHON -c 'import gi; gi.check_version("3.8")' 2>/dev/null
	if test $? -ne 0 ; then
		AC_MSG_RESULT([no (require at least 3.8)])
		python_found=no
	else
		AC_MSG_RESULT([yes])
	fi
fi

AM_CONDITIONAL(PYTHON_ENABLE, test "x$PYTHON" != "x")



dnl ================================================================
dnl c backend configuration
dnl ================================================================
AC_ARG_ENABLE([c],
              AS_HELP_STRING([--enable-c],[enable c backend]),
              [enable_c=$enableval],
              [enable_c=auto])

if test "x$enable_c" = "xauto"; then
	AC_PATH_PROGS([LLVM_CONFIG], [ \
		llvm-config-6.0 llvm-config60 \
		llvm-config-5.0 llvm-config50 \
		llvm-config-4.0 llvm-config40 \
		llvm-config-3.9 llvm-config39 \
		llvm-config-3.8 llvm-config38 \
		llvm-config-3.7 llvm-config37 \
		llvm-config-3.6 llvm-config36 \
		llvm-config-3.5 llvm-config35 \
		llvm-config \
		llvm-config-7 llvm-config-devel])

	AC_MSG_CHECKING([c backend])

	if test "x$python_found" = "xno" || test "x$LLVM_CONFIG" = "x"; then
		AC_MSG_RESULT([no])
		enable_c=no
	else
		AC_MSG_RESULT([yes])
		enable_c=yes
	fi
elif test "x$enable_c" != "xno"; then
	AC_PATH_PROGS([LLVM_CONFIG], [ \
		llvm-config-6.0 llvm-config60 \
		llvm-config-5.0 llvm-config50 \
		llvm-config-4.0 llvm-config40 \
		llvm-config-3.9 llvm-config39 \
		llvm-config-3.8 llvm-config38 \
		llvm-config-3.7 llvm-config37 \
		llvm-config-3.6 llvm-config36 \
		llvm-config-3.5 llvm-config35 \
		llvm-config \
		llvm-config-7 llvm-config-devel])

	AC_MSG_CHECKING([c backend])

	if test "x$LLVM_CONFIG" = "x"; then
		AC_MSG_ERROR([llvm-config not found])
	elif test "x$python_found" = "xno"; then
		AC_MSG_ERROR([python not found])
	else
		AC_MSG_RESULT([yes])
		enable_c=yes
	fi
fi

if test "x$enable_c" = "xyes"; then
llvm_libdir=`$LLVM_CONFIG --libdir`
AC_SUBST(llvm_libdir)
fi

color_enable_var("$enable_c", [enable_c_msg])

AM_CONDITIONAL(BACKENDS_C_ENABLE, test "x$enable_c" = "xyes")


dnl ================================================================
dnl python backend configuration
dnl ================================================================
AC_ARG_ENABLE([python],
              AS_HELP_STRING([--enable-python],[enable python backend]),
              [enable_python=$enableval],
              [enable_python=auto])

AC_MSG_CHECKING([python backend])

if test "x$enable_python" = "xauto"; then
	if test "x$python_found" = "xno"; then
		AC_MSG_RESULT([no])
		enable_python=no
	else
		AC_MSG_RESULT([yes])
		enable_python=yes
	fi
elif test "x$enable_python" != "xno"; then
	if test "x$python_found" = "xno"; then
		AC_MSG_ERROR([python not found])
	else
		AC_MSG_RESULT([yes])
		enable_python=yes
	fi
else
	AC_MSG_RESULT([no])
fi

color_enable_var("$enable_python", [enable_python_msg])

AM_CONDITIONAL(BACKENDS_PYTHON_ENABLE, test "x$enable_python" = "xyes")


dnl ================================================================
dnl ruby support
dnl ================================================================
AC_PATH_PROGS([RUBY],[ruby2.0 ruby1.9.3 ruby1.9.2 ruby1.9.1 ruby])

RUBY_MSG="requires ruby 2.0"

if test "x$RUBY" != "x"; then
	AC_MSG_CHECKING([ruby dbus])
	$RUBY -rdbus -e '' 2>/dev/null
	if test $? -ne 0 ; then
		AC_MSG_RESULT([no])
		RUBY=
		RUBY_MSG="requires ruby dbus"
	else
		AC_MSG_RESULT([yes])
	fi
fi

AM_CONDITIONAL(RUBY_ENABLE, test "x$RUBY" != "x")



dnl ================================================================
dnl ruby backend configuration
dnl ================================================================
AC_ARG_ENABLE([ruby],
              AS_HELP_STRING([--enable-ruby],[enable ruby backend]),
              [enable_ruby=$enableval],
              [enable_ruby=auto])

AC_MSG_CHECKING([ruby backend])

ruby_ripper=no

if test "x$RUBY" != "x"; then
	$RUBY -rripper -e '' 2>/dev/null
	if test $? -eq 0 ; then
		ruby_ripper=yes
	fi
fi

RUBY_BASE=`basename "$RUBY"`
AC_SUBST(RUBY_BASE)

if test "x$enable_ruby" = "xauto"; then
	if test "x$RUBY" = "x" || test "x$ruby_ripper" = "x"; then
		AC_MSG_RESULT([no ($RUBY_MSG)])
		enable_ruby=no
	else
		AC_MSG_RESULT([yes])
		enable_ruby=yes
	fi
elif test "x$enable_ruby" != "xno"; then
	if test "x$RUBY" = "x" || test "x$ruby_ripper" = "x"; then
		AC_MSG_ERROR([no ($RUBY_MSG)])
	else
		AC_MSG_RESULT([yes])
		enable_ruby=yes
	fi
else
	AC_MSG_RESULT([no])
fi

color_enable_var("$enable_ruby", [enable_ruby_msg])

AM_CONDITIONAL(BACKENDS_RUBY_ENABLE, test "x$enable_ruby" = "xyes")



dnl ================================================================
dnl css backend configuration
dnl ================================================================
AC_ARG_ENABLE([css],
              AS_HELP_STRING([--enable-css],[enable css backend]),
              [enable_css=$enableval],
              [enable_css=auto])

AC_MSG_CHECKING([css backend])

if test "x$enable_css" = "xauto"; then
	if test "x$RUBY" = "x"; then
		AC_MSG_RESULT([no ($RUBY_MSG)])
		enable_css=no
	else
		AC_MSG_RESULT([yes])
		enable_css=yes
	fi
elif test "x$enable_css" != "xno"; then
	if test "x$RUBY" = "x"; then
		AC_MSG_ERROR([no ($RUBY_MSG)])
	else
		AC_MSG_RESULT([yes])
		enable_css=yes
	fi
else
	AC_MSG_RESULT([no])
fi

ruby_sass=

if test "x$enable_css" = "xyes"; then
	AC_MSG_CHECKING([system provided sass])

	MAJOR=`$RUBY -rsass -e 'puts Sass.version[[:major]]' 2>/dev/null`

	if test $? -eq 0; then
		MINOR=`$RUBY -rsass -e 'puts Sass.version[[:minor]]' 2>/dev/null`

		if test "$MAJOR" -lt 3 || (test "$MAJOR" = "3" && test "$MINOR" -lt 3); then
			AC_MSG_RESULT([no (required sass version >= 3.3 not found), using vendored sass gem])
		else
			ruby_sass=yes
			AC_MSG_RESULT([yes, found sass $MAJOR.$MINOR])
		fi
	else
		AC_MSG_RESULT([no, using vendored sass gem])
	fi
fi

color_enable_var("$enable_css", [enable_css_msg])

AM_CONDITIONAL(BACKENDS_CSS_ENABLE, test "x$enable_css" = "xyes")
AM_CONDITIONAL(RUBY_SASS, test "x$ruby_sass" = "xyes")



dnl ================================================================
dnl json backend configuration
dnl ================================================================
AC_ARG_ENABLE([json],
              AS_HELP_STRING([--enable-json],[enable json backend]),
              [enable_json=$enableval],
              [enable_json=auto])

AC_MSG_CHECKING([json backend])

if test "x$enable_json" = "xauto"; then
	if test "x$PYTHON" = "x"; then
		AC_MSG_RESULT([no (requires python)])
		enable_json=no
	else
		AC_MSG_RESULT([yes])
		enable_json=yes
	fi
elif test "x$enable_json" != "xno"; then
	if test "x$PYTHON" = "x"; then
		AC_MSG_ERROR([no (requires python)])
	else
		AC_MSG_RESULT([yes])
		enable_json=yes
	fi
else
	AC_MSG_RESULT([no])
fi

python_simplejson=

if test "x$enable_json" = "xyes"; then
	$PYTHON -c 'import simplejson' 2>/dev/null
	if test $? -eq 0 ; then
		python_simplejson=yes
	fi
fi

color_enable_var("$enable_json", [enable_json_msg])

AM_CONDITIONAL(BACKENDS_JSON_ENABLE, test "x$enable_json" = "xyes")
AM_CONDITIONAL(PYTHON_SIMPLEJSON, test "x$python_simplejson" = "xyes")

dnl ================================================================
dnl js support
dnl ================================================================
AC_PATH_PROG([GJS],[gjs])
AM_CONDITIONAL(GJS_ENABLE, test "x$GJS" != "x")


dnl ================================================================
dnl js backend configuration
dnl ================================================================
AC_ARG_ENABLE([js],
              AS_HELP_STRING([--enable-js],[enable js backend]),
              [enable_js=$enableval],
              [enable_js=auto])

if test "x$enable_js" = "xauto"; then
	if test "x$GJS" != "x"; then
		enable_js=yes
	else
		enable_js=no
	fi
fi

if test "x$enable_js" = "xyes" && test "x$GJS" = "x"; then
	AC_MSG_CHECKING([js backend])
	AC_MSG_ERROR([could not find gjs])
fi

AM_CONDITIONAL(BACKENDS_JS_ENABLE, test "x$enable_js" = "xyes")
color_enable_var("$enable_js", [enable_js_msg])

dnl ================================================================
dnl xml backend configuration
dnl ================================================================
AC_ARG_ENABLE([xml],
              AS_HELP_STRING([--enable-xml],[enable xml backend]),
              [enable_xml=$enableval],
              [enable_xml=auto])

AC_MSG_CHECKING([xml backend])

if test "x$enable_xml" = "xauto"; then
	if test "x$python_found" = "xno"; then
		AC_MSG_RESULT([no])
		enable_xml=no
	else
		AC_MSG_RESULT([yes])
		enable_xml=yes
	fi
elif test "x$enable_xml" != "xno"; then
	if test "x$python_found" = "xno"; then
		AC_MSG_ERROR([python not found])
	else
		AC_MSG_RESULT([yes])
		enable_xml=yes
	fi
else
	AC_MSG_RESULT([no])
fi

color_enable_var("$enable_xml", [enable_xml_msg])

AM_CONDITIONAL(BACKENDS_XML_ENABLE, test "x$enable_xml" = "xyes")


dnl ================================================================
dnl yaml backend configuration
dnl ================================================================
AC_ARG_ENABLE([yaml],
              AS_HELP_STRING([--enable-yaml],[enable yaml backend]),
              [enable_yaml=$enableval],
              [enable_yaml=auto])

AC_MSG_CHECKING([yaml backend])

if test "x$enable_yaml" = "xauto"; then
	if test "x$python_found" = "xno"; then
		AC_MSG_RESULT([no])
		enable_yaml=no
	else
		AC_MSG_RESULT([yes])
		enable_yaml=yes
	fi
elif test "x$enable_yaml" != "xno"; then
	if test "x$python_found" = "xno"; then
		AC_MSG_ERROR([python not found])
	else
		AC_MSG_RESULT([yes])
		enable_yaml=yes
	fi
else
	AC_MSG_RESULT([no])
fi

color_enable_var("$enable_yaml", [enable_yaml_msg])

AM_CONDITIONAL(BACKENDS_YAML_ENABLE, test "x$enable_yaml" = "xyes")

dnl ================================================================
dnl vala backend configuration
dnl ================================================================
AC_ARG_ENABLE([vala],
              AS_HELP_STRING([--enable-vala],[enable vala backend]),
              [enable_vala=$enableval],
              [enable_vala=auto])

BACKEND_VALA_LIBVALA_VERSIONS="libvala-0.42 libvala-0.40 libvala-0.38 libvala-0.36 libvala-0.34 libvala-0.32 libvala-0.30 libvala-0.28 libvala-0.26 libvala-0.24 libvala-0.22 libvala-0.20"
BACKEND_VALA_MODULES="gobject-2.0 >= 2.36 glib-2.0 >= 2.36 gio-2.0 >= 2.36 gee-0.8 gio-unix-2.0 >= 2.36"

BACKEND_VALA_LIBVALA=

for i in $BACKEND_VALA_LIBVALA_VERSIONS; do
	if test "x$BACKEND_VALA_LIBVALA" = "x"; then
		BACKEND_VALA_LIBVALA="$i"
	fi

	PKG_CHECK_EXISTS([$i], [libvala_found=yes], [libvala_found=no])

	if test "x$libvala_found" = "xyes"; then
		BACKEND_VALA_LIBVALA="$i"
		BACKEND_VALA_MODULES="$BACKEND_VALA_MODULES $BACKEND_VALA_LIBVALA"
		break
	fi
done

AC_SUBST(BACKEND_VALA_LIBVALA)

if test "x$enable_vala" != "xno"; then
	AM_PROG_VALAC
fi

if test "x$enable_vala" = "xauto"; then
	AC_MSG_CHECKING([vala backend])

	if test "x$VALAC" = "x"; then
		AC_MSG_RESULT([no])
		enable_vala=no
	else
		PKG_CHECK_EXISTS([$BACKEND_VALA_MODULES],
		                 [enable_vala=yes],
		                 [enable_vala=no])

		AC_MSG_RESULT([$enable_vala])
	fi
fi

if test "x$enable_vala" != "xno"; then

	if test "x$VALAC" = "x"; then
		AC_MSG_ERROR([Cannot find the "valac" compiler])
	else
		PKG_CHECK_MODULES([BACKEND_VALA], $BACKEND_VALA_MODULES)

		AC_SUBST(BACKEND_VALA_CFLAGS)
		AC_SUBST(BACKEND_VALA_LIBS)

		enable_vala=yes
	fi
fi

# Check for deprecated threading support
AS_IF([test x$enable_vala = xyes],[
	cflags_save="${CFLAGS}"
	libs_save="${LIBS}"
	CFLAGS="${CFLAGS} ${BACKEND_VALA_CFLAGS}"
	LIBS="${LIBS} ${BACKEND_VALA_LIBS}"

	AC_MSG_CHECKING([if vala CodeContext supports thread property])

	AC_TRY_LINK([#include <vala.h>],[
		vala_code_context_set_thread (NULL, TRUE);
	], [have_vala_code_context_set_thread=yes], [have_vala_code_context_set_thread=no])

	CFLAGS="${cflags_save}"
	LIBS="${libs_save}"
])
AC_MSG_RESULT([$have_vala_code_context_set_thread])

color_enable_var("$enable_vala", [enable_vala_msg])

AM_CONDITIONAL(BACKENDS_VALA_ENABLE, test "x$enable_vala" = "xyes")
AM_CONDITIONAL(BACKENDS_VALA_ENABLE_VALA_CODE_CONTEXT_SET_THREAD, test x$have_vala_code_context_set_thread = xyes)

AC_SUBST(BACKEND_VALA_LIBVALA)


dnl ================================================================
dnl go backend configuration
dnl ================================================================
AC_ARG_ENABLE([go],
              AS_HELP_STRING([--enable-go],[enable go backend]),
              [enable_go=$enableval],
              [enable_go=auto])

if test "x$enable_go" = "xauto"; then
	AC_PATH_PROG([GO], [go])

	if test "x$GO" = "x"; then
		enable_go=no
	else
		enable_go=yes
	fi
elif test "x$enable_go" != "xno"; then
	AC_PATH_PROG([GO], [go])

	if test "x$GO" = "x"; then
		AC_MSG_ERROR([could not find go compiler])
	fi

	enable_go=yes
fi

color_enable_var("$enable_go", [enable_go_msg])

AM_CONDITIONAL(BACKENDS_GO_ENABLE, test "x$enable_go" = "xyes")


dnl ================================================================
dnl shell backend configuration
dnl ================================================================
AC_ARG_ENABLE([sh],
              AS_HELP_STRING([--enable-sh],[enable shell backend]),
              [enable_sh=$enableval],
              [enable_sh=yes])

if test "x$enable_sh" != "xno"; then
	# we assume /bin/sh is always there or we would not be
	# running this scrip
	enable_sh=yes
fi

color_enable_var("$enable_sh", [enable_sh_msg])

AM_CONDITIONAL(BACKENDS_SH_ENABLE, test "x$enable_sh" = "xyes")


backendexecdir_unex="$libexecdir/gnome-code-assistance"
adl_RECURSIVE_EVAL("$backendexecdir_unex", [backendexecdir])
AC_SUBST(backendexecdir)

adl_RECURSIVE_EVAL("$datadir", [datadirex])
AC_SUBST(datadirex)

GCA_BACKENDS_EXEC_DIR="$backendexecdir_unex"
AC_SUBST(GCA_BACKENDS_EXEC_DIR)

GCA_BACKENDS_DIR="$GCA_BACKENDS_EXEC_DIR/backends"
AC_SUBST(GCA_BACKENDS_DIR)

adl_RECURSIVE_EVAL("$GCA_BACKENDS_DIR", [GCA_BACKENDS_DIR_EX])
AC_SUBST(GCA_BACKENDS_DIR_EX)


dnl python backends
GCA_PYBACKENDS_ROOT="$GCA_BACKENDS_DIR/py"
AC_SUBST(GCA_PYBACKENDS_ROOT)

adl_RECURSIVE_EVAL("$GCA_PYBACKENDS_ROOT", [GCA_PYBACKENDS_ROOT_EX])
AC_SUBST(GCA_PYBACKENDS_ROOT_EX)

GCA_PYBACKENDS_DIR="$GCA_PYBACKENDS_ROOT/gnome/codeassistance"
AC_SUBST(GCA_PYBACKENDS_DIR)

adl_RECURSIVE_EVAL("$GCA_PYBACKENDS_DIR", [GCA_PYBACKENDS_DIR_EX])
AC_SUBST(GCA_PYBACKENDS_DIR_EX)


dnl ruby backends
GCA_RBBACKENDS_ROOT="$GCA_BACKENDS_DIR/rb"
AC_SUBST(GCA_RBBACKENDS_ROOT)

adl_RECURSIVE_EVAL("$GCA_RBBACKENDS_ROOT", [GCA_RBBACKENDS_ROOT_EX])
AC_SUBST(GCA_RBBACKENDS_ROOT_EX)

GCA_RBBACKENDS_DIR="$GCA_RBBACKENDS_ROOT/gnome/codeassistance"
AC_SUBST(GCA_RBBACKENDS_DIR)

adl_RECURSIVE_EVAL("$GCA_RBBACKENDS_DIR", [GCA_RBBACKENDS_DIR_EX])
AC_SUBST(GCA_RBBACKENDS_DIR_EX)


dnl js backends
GCA_JSBACKENDS_ROOT="$GCA_BACKENDS_DIR/js"
AC_SUBST(GCA_JSBACKENDS_ROOT)

adl_RECURSIVE_EVAL("$GCA_JSBACKENDS_ROOT", [GCA_JSBACKENDS_ROOT_EX])
AC_SUBST(GCA_JSBACKENDS_ROOT_EX)

GCA_JSBACKENDS_DIR="$GCA_JSBACKENDS_ROOT/gnome/codeassistance"
AC_SUBST(GCA_JSBACKENDS_DIR)

adl_RECURSIVE_EVAL("$GCA_JSBACKENDS_DIR", [GCA_JSBACKENDS_DIR_EX])
AC_SUBST(GCA_JSBACKENDS_DIR_EX)

if test "x$python_found" != "xno"; then
	PYTHON_VERSION_MAJOR=$python_found
else
	PYTHON_VERSION_MAJOR=
fi

AC_SUBST(PYTHON_VERSION_MAJOR)

AC_DEFINE_UNQUOTED([BACKENDEXECDIR], ["$backendexecdir"], [The backend exec dir])

AC_CONFIG_FILES([
Makefile
backends/c/org.gnome.CodeAssist.v1.c.service
backends/c/config.py
backends/c/c
backends/python/org.gnome.CodeAssist.v1.python.service
backends/python/python
backends/ruby/org.gnome.CodeAssist.v1.ruby.service
backends/ruby/ruby
backends/xml/org.gnome.CodeAssist.v1.xml.service
backends/xml/xml
backends/vala/org.gnome.CodeAssist.v1.vala.service
backends/go/org.gnome.CodeAssist.v1.go.service
backends/js/org.gnome.CodeAssist.v1.js.service
backends/js/js
backends/sh/org.gnome.CodeAssist.v1.sh.service
backends/sh/sh
backends/css/org.gnome.CodeAssist.v1.css.service
backends/css/css
backends/json/org.gnome.CodeAssist.v1.json.service
backends/json/json
backends/yaml/org.gnome.CodeAssist.v1.yaml.service
backends/yaml/yaml
data/org.gnome.codeassistance.gschema.xml
tests/dbus.conf
])

AC_OUTPUT

echo -e "

Configuration:

	prefix:                 ${prefix}
	source code location:   ${srcdir}
	compiler:               ${CC}
	debug:                  $enable_debug_msg

	backends:
		c:              $enable_c_msg
		python:         $enable_python_msg
		xml:            $enable_xml_msg
		vala:           $enable_vala_msg
		go:             $enable_go_msg
		ruby:           $enable_ruby_msg
		javascript:     $enable_js_msg
		shell:          $enable_sh_msg
		css:            $enable_css_msg
		json:           $enable_json_msg
		yaml:           $enable_yaml_msg
"

