/* valaoptionparser.vala
 *
 * Copyright (C) 2013  Jesse van den Kieboom
 * Copyright (C) 2006-2012  Jürg Billeter
 * Copyright (C) 1996-2002, 2004, 2005, 2006 Free Software Foundation, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Jürg Billeter <j@bitron.ch>
 */

using GLib;

class Vala.OptionParser {
	static string basedir;
	static string directory;
	static bool version;
	static bool api_version;
	[CCode (array_length = false, array_null_terminated = true)]
	static string[] sources;
	[CCode (array_length = false, array_null_terminated = true)]
	static string[] vapi_directories;
	[CCode (array_length = false, array_null_terminated = true)]
	static string[] gir_directories;
	[CCode (array_length = false, array_null_terminated = true)]
	static string[] metadata_directories;
	static string vapi_filename;
	static string library;
	static string gir;
	[CCode (array_length = false, array_null_terminated = true)]
	static string[] packages;
	[CCode (array_length = false, array_null_terminated = true)]
	static string[] fast_vapis;
	static string target_glib;
	[CCode (array_length = false, array_null_terminated = true)]
	static string[] gresources;

	static bool ccode_only;
	static string header_filename;
	static bool use_header;
	static string internal_header_filename;
	static string internal_vapi_filename;
	static string fast_vapi_filename;
	static string symbols_filename;
	static string includedir;
	static bool compile_only;
	static string output;
	static bool debug;
	static bool thread;
	static bool mem_profiler;
	static bool disable_assert;
	static bool enable_checking;
	static bool deprecated;
	static bool experimental;
	static bool experimental_non_null;
	static bool gobject_tracing;
	static bool disable_warnings;
	static string cc_command;
	[CCode (array_length = false, array_null_terminated = true)]
	static string[] cc_options;
	static string dump_tree;
	static bool save_temps;
	[CCode (array_length = false, array_null_terminated = true)]
	static string[] defines;
	static bool quiet_mode;
	static bool verbose_mode;
	static string profile;
	static bool nostdpkg;
	static bool enable_version_header;
	static bool disable_version_header;
	static bool fatal_warnings;
	static string dependencies;

	static string entry_point;
	static bool run_output;

	static const OptionEntry[] options = {
		{ "vapidir", 0, 0, OptionArg.FILENAME_ARRAY, ref vapi_directories, "Look for package bindings in DIRECTORY", "DIRECTORY..." },
		{ "girdir", 0, 0, OptionArg.FILENAME_ARRAY, ref gir_directories, "Look for .gir files in DIRECTORY", "DIRECTORY..." },
		{ "metadatadir", 0, 0, OptionArg.FILENAME_ARRAY, ref metadata_directories, "Look for GIR .metadata files in DIRECTORY", "DIRECTORY..." },
		{ "pkg", 0, 0, OptionArg.STRING_ARRAY, ref packages, "Include binding for PACKAGE", "PACKAGE..." },
		{ "vapi", 0, 0, OptionArg.FILENAME, ref vapi_filename, "Output VAPI file name", "FILE" },
		{ "library", 0, 0, OptionArg.STRING, ref library, "Library name", "NAME" },
		{ "gir", 0, 0, OptionArg.STRING, ref gir, "GObject-Introspection repository file name", "NAME-VERSION.gir" },
		{ "basedir", 'b', 0, OptionArg.FILENAME, ref basedir, "Base source directory", "DIRECTORY" },
		{ "directory", 'd', 0, OptionArg.FILENAME, ref directory, "Output directory", "DIRECTORY" },
		{ "version", 0, 0, OptionArg.NONE, ref version, "Display version number", null },
		{ "api-version", 0, 0, OptionArg.NONE, ref api_version, "Display API version number", null },
		{ "ccode", 'C', 0, OptionArg.NONE, ref ccode_only, "Output C code", null },
		{ "header", 'H', 0, OptionArg.FILENAME, ref header_filename, "Output C header file", "FILE" },
		{ "use-header", 0, 0, OptionArg.NONE, ref use_header, "Use C header file", null },
		{ "includedir", 0, 0, OptionArg.FILENAME, ref includedir, "Directory used to include the C header file", "DIRECTORY" },
		{ "internal-header", 'h', 0, OptionArg.FILENAME, ref internal_header_filename, "Output internal C header file", "FILE" },
		{ "internal-vapi", 0, 0, OptionArg.FILENAME, ref internal_vapi_filename, "Output vapi with internal api", "FILE" },
		{ "fast-vapi", 0, 0, OptionArg.STRING, ref fast_vapi_filename, "Output vapi without performing symbol resolution", null },
		{ "use-fast-vapi", 0, 0, OptionArg.STRING_ARRAY, ref fast_vapis, "Use --fast-vapi output during this compile", null },
		{ "deps", 0, 0, OptionArg.STRING, ref dependencies, "Write make-style dependency information to this file", null },
		{ "symbols", 0, 0, OptionArg.FILENAME, ref symbols_filename, "Output symbols file", "FILE" },
		{ "compile", 'c', 0, OptionArg.NONE, ref compile_only, "Compile but do not link", null },
		{ "output", 'o', 0, OptionArg.FILENAME, ref output, "Place output in file FILE", "FILE" },
		{ "debug", 'g', 0, OptionArg.NONE, ref debug, "Produce debug information", null },
		{ "thread", 0, 0, OptionArg.NONE, ref thread, "Enable multithreading support", null },
		{ "enable-mem-profiler", 0, 0, OptionArg.NONE, ref mem_profiler, "Enable GLib memory profiler", null },
		{ "define", 'D', 0, OptionArg.STRING_ARRAY, ref defines, "Define SYMBOL", "SYMBOL..." },
		{ "main", 0, 0, OptionArg.STRING, ref entry_point, "Use SYMBOL as entry point", "SYMBOL..." },
		{ "nostdpkg", 0, 0, OptionArg.NONE, ref nostdpkg, "Do not include standard packages", null },
		{ "disable-assert", 0, 0, OptionArg.NONE, ref disable_assert, "Disable assertions", null },
		{ "enable-checking", 0, 0, OptionArg.NONE, ref enable_checking, "Enable additional run-time checks", null },
		{ "enable-deprecated", 0, 0, OptionArg.NONE, ref deprecated, "Enable deprecated features", null },
		{ "enable-experimental", 0, 0, OptionArg.NONE, ref experimental, "Enable experimental features", null },
		{ "disable-warnings", 0, 0, OptionArg.NONE, ref disable_warnings, "Disable warnings", null },
		{ "fatal-warnings", 0, 0, OptionArg.NONE, ref fatal_warnings, "Treat warnings as fatal", null },
		{ "enable-experimental-non-null", 0, 0, OptionArg.NONE, ref experimental_non_null, "Enable experimental enhancements for non-null types", null },
		{ "enable-gobject-tracing", 0, 0, OptionArg.NONE, ref gobject_tracing, "Enable GObject creation tracing", null },
		{ "cc", 0, 0, OptionArg.STRING, ref cc_command, "Use COMMAND as C compiler command", "COMMAND" },
		{ "Xcc", 'X', 0, OptionArg.STRING_ARRAY, ref cc_options, "Pass OPTION to the C compiler", "OPTION..." },
		{ "dump-tree", 0, 0, OptionArg.FILENAME, ref dump_tree, "Write code tree to FILE", "FILE" },
		{ "save-temps", 0, 0, OptionArg.NONE, ref save_temps, "Keep temporary files", null },
		{ "profile", 0, 0, OptionArg.STRING, ref profile, "Use the given profile instead of the default", "PROFILE" },
		{ "quiet", 'q', 0, OptionArg.NONE, ref quiet_mode, "Do not print messages to the console", null },
		{ "verbose", 'v', 0, OptionArg.NONE, ref verbose_mode, "Print additional messages to the console", null },
		{ "target-glib", 0, 0, OptionArg.STRING, ref target_glib, "Target version of glib for code generation", "MAJOR.MINOR" },
		{ "gresources", 0, 0, OptionArg.STRING_ARRAY, ref gresources, "XML of gresources", "FILE..." },
		{ "enable-version-header", 0, 0, OptionArg.NONE, ref enable_version_header, "Write vala build version in generated files", null },
		{ "disable-version-header", 0, 0, OptionArg.NONE, ref disable_version_header, "Do not write vala build version in generated files", null },
		{ "", 0, 0, OptionArg.FILENAME_ARRAY, ref sources, null, "FILE..." },
		{ null }
	};

	private static bool apply (global::Vala.CodeContext context, string cwd) {
		context.assert = !disable_assert;
		context.checking = enable_checking;
		context.deprecated = deprecated;
		context.experimental = experimental;
		context.experimental_non_null = experimental_non_null;
		context.gobject_tracing = gobject_tracing;
		context.report.enable_warnings = !disable_warnings;
		context.report.set_verbose_errors (!quiet_mode);
		context.verbose_mode = verbose_mode;
		context.version_header = !disable_version_header;

		context.ccode_only = ccode_only;
		context.compile_only = compile_only;
		context.header_filename = header_filename;
		if (header_filename == null && use_header) {
			Report.error (null, "--use-header may only be used in combination with --header");
		}
		context.use_header = use_header;
		context.internal_header_filename = internal_header_filename;
		context.symbols_filename = symbols_filename;
		context.includedir = includedir;
		context.output = output;
		if (basedir == null) {
			context.basedir = CodeContext.realpath (cwd);
		} else {
			context.basedir = CodeContext.realpath (basedir);
		}
		if (directory != null) {
			context.directory = CodeContext.realpath (directory);
		} else {
			context.directory = context.basedir;
		}
		context.vapi_directories = vapi_directories;
		context.gir_directories = gir_directories;
		context.metadata_directories = metadata_directories;
		context.debug = debug;
		context.thread = thread;
		context.mem_profiler = mem_profiler;
		context.save_temps = save_temps;
		if (profile == "gobject-2.0" || profile == "gobject" || profile == null) {
			// default profile
			context.profile = Profile.GOBJECT;
			context.add_define ("GOBJECT");
		} else {
			Report.error (null, "Unknown profile %s".printf (profile));
		}
		nostdpkg |= fast_vapi_filename != null;
		context.nostdpkg = nostdpkg;

		context.entry_point_name = entry_point;

		context.run_output = run_output;

		if (defines != null) {
			foreach (string define in defines) {
				context.add_define (define);
			}
		}

		for (int i = 2; i <= 24; i += 2) {
			context.add_define ("VALA_0_%d".printf (i));
		}

		int glib_major = 2;
		int glib_minor = 18;
		if (target_glib != null && target_glib.scanf ("%d.%d", out glib_major, out glib_minor) != 2) {
			Report.error (null, "Invalid format for --target-glib");
		}

		context.target_glib_major = glib_major;
		context.target_glib_minor = glib_minor;
		if (context.target_glib_major != 2) {
			Report.error (null, "This version of valac only supports GLib 2");
		}

		for (int i = 16; i <= glib_minor; i += 2) {
			context.add_define ("GLIB_2_%d".printf (i));
		}

		if (!nostdpkg) {
			/* default packages */
			context.add_external_package ("glib-2.0");
			context.add_external_package ("gobject-2.0");
		}

		if (packages != null) {
			foreach (string package in packages) {
				context.add_external_package (package);
			}
			packages = null;
		}

		if (fast_vapis != null) {
			foreach (string vapi in fast_vapis) {
				var rpath = CodeContext.realpath (vapi);
				var source_file = new SourceFile (context, SourceFileType.FAST, rpath);
				context.add_source_file (source_file);
			}
			context.use_fast_vapi = true;
		}

		return (context.report.get_errors () > 0 || (fatal_warnings && context.report.get_warnings () > 0));
	}

	public static bool parse(string[] args) {
		try {
			var opt_context = new OptionContext ("- Vala Compiler");
			opt_context.set_help_enabled (false);
			opt_context.add_main_entries (options, null);
			opt_context.set_ignore_unknown_options (true);
			opt_context.parse (ref args);
		} catch { return false; }

		return true;
	}

	public static bool parse_and_apply(string cwd, global::Vala.CodeContext context, string[] args) {
		if (!parse(args))
		{
			return false;
		}

		return apply(context, cwd);
	}
}
