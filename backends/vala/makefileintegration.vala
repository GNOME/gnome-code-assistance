/*
 * This file is part of gedit-code-assistant.
 *
 * Copyright (C) 2011 - Jesse van den Kieboom
 *
 * gedit-code-assistant is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * gedit-code-assistant is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gedit-code-assistant.  If not, see <http://www.gnu.org/licenses/>.
 */

class MakefileIntegration
{
	class Makefile
	{
		class Source
		{
			public TimeVal mtime;
			public string[] flags;
		}

		private File d_file;
		private Gee.HashMap<File, Source> d_sources;
		private TimeVal d_mtime;
		private FileMonitor? d_monitor;

		public Makefile(File file)
		{
			d_file = file;
			d_sources = new Gee.HashMap<File, Source>(HashUtils.File.hash, HashUtils.File.equal);

			update_mtime();

			try
			{
				d_monitor = file.monitor(FileMonitorFlags.NONE);
			}
			catch (Error error)
			{
				return;
			}

			d_monitor.changed.connect(on_changed);
		}

		public File file
		{
			get { return d_file; }
		}

		private TimeVal file_mtime(File f)
		{
			try
			{
				var info = f.query_info(FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
				return info.get_modification_time();
			}
			catch {}

			return TimeVal() {
				tv_sec = 0,
				tv_usec = 0
			};
		}

		private void update_mtime()
		{
			d_mtime = file_mtime(d_file);
		}

		private void on_changed()
		{
			update_mtime();
		}

		private Source make_source(string[] flags)
		{
			var ret = new Source();

			ret.flags = flags;
			ret.mtime = d_mtime;

			return ret;
		}

		public void dispose()
		{
			if (d_monitor != null)
			{
				d_monitor.cancel();
				d_monitor = null;
			}
		}

		public void add(File source, string[] flags)
		{
			d_sources[file] = make_source(flags);
		}

		public bool remove(File source)
		{
			if (d_sources.unset(source) && d_sources.size == 0)
			{
				dispose();
				return true;
			}

			return false;
		}

		private bool newer(TimeVal t1, TimeVal t2)
		{
			if (t1.tv_sec == t2.tv_sec)
			{
				return t1.tv_usec > t2.tv_usec;
			}
			else
			{
				return t1.tv_sec > t2.tv_sec;
			}
		}

		public bool up_to_date_for(File source)
		{
			var s = d_sources[source];

			if (s != null)
			{
				return !newer(d_mtime, s.mtime);
			}
			else
			{
				return false;
			}
		}

		public string[]? flags_for_file(File source)
		{
			var s = d_sources[source];

			if (s != null)
			{
				return s.flags;
			}
			else
			{
				return null;
			}
		}
	}

	private Gee.HashMap<File, Makefile> d_cache;
	private Gee.HashMap<File, Makefile> d_file_to_makefile;

	public MakefileIntegration()
	{
		d_cache = new Gee.HashMap<File, Makefile>(HashUtils.File.hash, HashUtils.File.equal);
		d_file_to_makefile = new Gee.HashMap<File, Makefile>(HashUtils.File.hash, HashUtils.File.equal);
	}

	public bool changed_for_file(File f)
	{
		var makefile = makefile_for(f);

		if (makefile == null)
		{
			return false;
		}

		var m = d_cache[makefile];

		if (m != null)
		{
			return m.up_to_date_for(f);
		}

		return true;
	}

	public void dispose(File f)
	{
		var m = d_file_to_makefile[f];

		if (m != null)
		{
			if (m.remove(f))
			{
				d_cache.unset(m.file);
			}

			d_file_to_makefile.unset(f);
		}
	}

	public string[]? flags_for_file(File f, out string? wd)
	{
		var makefile = makefile_for(f);

		wd = null;

		if (makefile == null)
		{
			return null;
		}

		wd = makefile.get_parent().get_path();

		var m = d_cache[makefile];

		if (m != null)
		{
			if (m.up_to_date_for(f))
			{
				return m.flags_for_file(f);
			}
		}

		var targets = targets_from_make(makefile, f);
		var flags = flags_from_targets(makefile, f, targets);

		return update_cache(makefile, f, flags);
	}

	private string[]? update_cache(File makefile, File f, string[] flags)
	{
		var m = d_cache[makefile];

		if (m == null)
		{
			m = new Makefile(makefile);
			d_cache[makefile] = m;
		}

		m.add(f, flags);
		d_file_to_makefile[f] = m;

		return flags;
	}

	private File? find_subdir_with_path(File parent, string relpath)
	{
		// All dirs in parent, recursively
		var dirs = new File[]{parent};

		while (dirs.length != 0)
		{
			var d = dirs[0];
			dirs = dirs[1:dirs.length];

			FileEnumerator iter;

			try
			{
				var attrs = FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE;
				iter = d.enumerate_children(attrs, FileQueryInfoFlags.NONE);
			} catch {
				continue;
			}

			FileInfo? info;

			try
			{
				while ((info = iter.next_file()) != null)
				{
					if (info.get_file_type() == FileType.DIRECTORY)
					{
						File dir = iter.get_child(info);
						File child = dir.get_child(relpath);

						if (child.query_exists())
						{
							var mf = makefile_for(child, false);

							if (mf != null)
							{
								return mf;
							}
						}

						dirs += dir;
					}
				}
			} catch { continue; }
		}

		return null;
	}

	private File? subdir_makefile_for(File parent, File f)
	{
		var relpath = Path.get_dirname(parent.get_relative_path(f));
		return find_subdir_with_path(parent, relpath);
	}

	private File ?makefile_for(File f, bool tryac = true)
	{
		var fromcache = d_file_to_makefile[f];

		if (fromcache != null)
		{
			return fromcache.file;
		}

		var parent = f.get_parent();
		var tocheck = new string[] {"configure.ac", "configure.in", "configure"};

		while (parent != null)
		{
			var makefile = parent.get_child("Makefile");

			if (makefile.query_exists())
			{
				return makefile;
			}

			foreach (var c in tocheck)
			{
				var cc = parent.get_child(c);

				if (cc.query_exists())
				{
					var ret = subdir_makefile_for(parent, f);

					if (ret != null)
					{
						return ret;
					}

					break;
				}
			}

			parent = parent.get_parent();
		}

		return null;
	}

	private string[] targets_from_make(File makefile, File source)
	{
		File wd = makefile.get_parent();
		var relpath = wd.get_relative_path(source);

		var lookfor = new string[] {
			wd.get_relative_path(source)
		};

		var bname = source.get_basename();

		if (bname != relpath)
		{
			lookfor += bname;
		}

		string[] args = new string[] {
			"make",
			"-p",
			"-n",
			"-s",
			null
		};

		string outstr;

		/* Spawn make to find out which target has the source as a
		   dependency */
		try
		{
			Process.spawn_sync(wd.get_path(),
			                   args,
			                   null,
			                   SpawnFlags.SEARCH_PATH |
			                   SpawnFlags.STDERR_TO_DEV_NULL,
			                   null,
			                   out outstr);
		}
		catch (SpawnError e)
		{
			return new string[0];
		}

		var targets = new string[0];
		var found = new Gee.HashSet<string>();

		while (lookfor.length > 0)
		{
			for (var i = 0; i < lookfor.length; i++)
			{
				lookfor[i] = Regex.escape_string(lookfor[i]);
			}

			var relookfor = string.joinv("|", lookfor);
			lookfor = new string[0];

			Regex reg;

			try
			{
				reg = new Regex("^([^:\n ]+):.*\\b(%s)\\b".printf(relookfor), RegexCompileFlags.MULTILINE);
			} catch (Error e) { stderr.printf("regex: %s\n", e.message); continue; }

			MatchInfo info;

			reg.match(outstr, 0, out info);

			while (info.matches())
			{
				var target = info.fetch(1);

				try
				{
					info.next();
				} catch {};

				if (target[0] == '#' || target[0] == '.' || target.has_suffix("-am"))
				{
					continue;
				}

				if (found.contains(target))
				{
					continue;
				}

				targets += target;
				found.add(target);
				lookfor += target;
			}
		}

		var sorted = new Gee.ArrayList<string>.wrap(targets);

		sorted.sort((a, b) => {
			var sa = a.has_suffix(".stamp");
			var sb = b.has_suffix(".stamp");

			if (sa == sb)
			{
				return 0;
			}

			return sa ? -1 : 1;
		});

		return sorted.to_array();
	}

	private string[] flags_from_targets(File makefile, File source, string[] targets)
	{
		if (targets.length == 0)
		{
			return new string[0];
		}

		var fakevalac = "__GCA_VALA_COMPILE_ARGS__";

		var wd = makefile.get_parent();
		var relsource = wd.get_relative_path(source);

		var args = new string?[] {
			"make",
			"-s",
			"-i",
			"-n",
			"-W",
			relsource,
			"V=1",
			"VALAC=" + fakevalac
		};

		foreach (var target in targets)
		{
			args += target;
		}

		args += null;

		string outstr;

		try
		{
			Process.spawn_sync(wd.get_path(),
			                   args,
			                   null,
			                   SpawnFlags.SEARCH_PATH |
			                   SpawnFlags.STDERR_TO_DEV_NULL,
			                   null,
			                   out outstr);
		}
		catch (SpawnError e)
		{
			return new string[0];
		}

		/* Extract args */
		int pos = outstr.index_of(fakevalac);

		if (pos < 0)
		{
			return new string[0];
		}

		int epos = outstr.index_of("\n", pos);

		if (epos < 0)
		{
			epos = outstr.length;
		}

		string[] retargs;
		var sargs = outstr[pos:epos];

		try
		{
			Shell.parse_argv(sargs, out retargs);
		}
		catch (ShellError e)
		{
			return new string[0];
		}

		log("GcaVala", LogLevelFlags.LEVEL_DEBUG,
		    "Parsed command: %s => '%s'\n",
		    sargs,
		    string.joinv("', '", retargs));

		return retargs;
	}
}

#if MAIN
public static int main(string[] a){
	MakefileIntegration it = new MakefileIntegration();
	string wd;
	stdout.printf("Flags: %s\n", string.joinv(", ", it.flags_for_file(File.new_for_commandline_arg(a[1]), out wd)));
	return 0;
}
#endif

/* vi:ex:ts=4 */
