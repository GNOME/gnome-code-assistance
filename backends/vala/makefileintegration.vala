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

namespace Gca.Backends.Vala
{

public errordomain MakefileIntegrationError
{
	MISSING_MAKEFILE,
	MISSING_TARGET,
	MISSING_MAKE_OUTPUT
}

class MakefileIntegration : Object
{
	private class Cache
	{
		private File d_source;
		private File? d_makefile;
		private string[] d_args;

		public Cache(File source, File? makefile, string[] args)
		{
			d_source = source;
			d_makefile = makefile;
			d_args = args;
		}

		public File makefile
		{
			get { return d_makefile; }
		}

		public File source
		{
			get { return d_source; }
		}

		public string[] args
		{
			get { return d_args; }
			set { d_args = value; }
		}
	}

	private class Makefile
	{
		private File d_file;
		private Gee.ArrayList<File> d_sources;
		private FileMonitor ?d_monitor;
		private uint d_timeoutid;

		public signal void changed();

		public Makefile(File file)
		{
			d_file = file;
			d_timeoutid = 0;
			d_monitor = null;

			try
			{
				d_monitor = file.monitor(FileMonitorFlags.NONE);
			}
			catch (Error error)
			{
				return;
			}

			d_sources = new Gee.ArrayList<File>();

			d_monitor.changed.connect(on_makefile_changed);
		}

		public bool valid
		{
			get
			{
				return d_monitor != null;
			}
		}

		public void add(File source)
		{
			d_sources.add(source);
		}

		public bool remove(File source)
		{
			d_sources.remove(source);

			return (d_sources.size == 0);
		}

		public Gee.ArrayList<File> sources
		{
			get { return d_sources; }
		}

		public File file
		{
			get { return d_file; }
		}

		private void on_makefile_changed(File file, File ?other, FileMonitorEvent event_type)
		{
			if (event_type == FileMonitorEvent.CHANGED ||
			    event_type == FileMonitorEvent.CREATED)
			{
				if (d_timeoutid != 0)
				{
					Source.remove(d_timeoutid);
				}

				d_timeoutid = Timeout.add(100, on_makefile_timeout);
			}
		}

		private bool on_makefile_timeout()
		{
			d_timeoutid = 0;

			changed();

			return false;
		}
		
	}

	private Gee.HashMap<File, Cache> d_argsCache;
	private Gee.HashMap<File, Makefile> d_makefileCache;

	public signal void arguments_changed(File file);

	construct
	{
		d_argsCache = new Gee.HashMap<File, Cache>();
		d_makefileCache = new Gee.HashMap<File, Makefile>();
	}

	private File ?makefile_for(File file,
	                           Cancellable ?cancellable = null) throws IOError,
	                                                                   Error
	{
		File ?ret = null;

		File? par = file.get_parent();

		while (par != null && ret == null)
		{
			File makefile = par.get_child("Makefile");

			if (makefile.query_exists(cancellable))
			{
				ret = makefile;
			}

			par = par.get_parent();
		}

		if (ret != null)
		{
			log("GcaVala", LogLevelFlags.LEVEL_DEBUG,
			    "Resolved makefile for `%s': `%s'",
			    file.get_path(),
			    ret.get_path());
		}

		return ret;
	}

	private string[] targets_from_make(File makefile,
	                                   File source) throws SpawnError,
	                                                       RegexError,
	                                                       MakefileIntegrationError
	{
		File wd = makefile.get_parent();
		string basen = wd.get_relative_path(source);

		string[] args = new string[] {
			"make",
			"-p",
			"-n",
			null
		};

		string outstr;

		/* Spawn make to find out which target has the source as a
		   dependency */
		Process.spawn_sync(wd.get_path(),
		                   args,
		                   null,
		                   SpawnFlags.SEARCH_PATH |
		                   SpawnFlags.STDERR_TO_DEV_NULL,
		                   null,
		                   out outstr);

		/* Scan the output to find the target */
		string reg = "^([^:\n]*?(\\.stamp:|:)).*%s".printf(Regex.escape_string(basen));

		Regex regex = new Regex(reg, RegexCompileFlags.MULTILINE);
		MatchInfo info;

		var ret = new string[1];

		if (regex.match(outstr, 0, out info))
		{
			while (true)
			{
				var target = info.fetch(1);
				target = target.substring(0, target.length - 1);

				if (target.has_suffix(".stamp"))
				{
					ret[0] = target;
				}
				else
				{
					ret += target;
				}

				if (!info.next())
				{
					break;
				}
			}
		}

		if (ret[0] == null)
		{
			ret = ret[1:ret.length];
		}

		if (ret.length != 0)
		{
			return ret;
		}

		throw new MakefileIntegrationError.MISSING_TARGET(
			"Could not find make target for %s".printf(basen));
	}

	private string[] ?flags_from_targets(File     makefile,
	                                     File     source,
	                                     string[] targets) throws SpawnError,
	                                                              MakefileIntegrationError,
	                                                              ShellError
	{
		/* Fake make to build the target and extract the flags */
		var wd = makefile.get_parent();
		string relsource = wd.get_relative_path(source);

		string fakecc = "__GCA_VALA_COMPILE_ARGS__";

		string?[] args = new string?[] {
			"make",
			"-s",
			"-i",
			"-n",
			"-W",
			relsource,
			"V=1",
			"VALAC=" + fakecc
		};

		foreach (var target in targets)
		{
			args += target;
		}

		args += null;

		log("GcaVala", LogLevelFlags.LEVEL_DEBUG,
		    "Running: %s",
		    string.joinv(" ", args));

		string outstr;

		Process.spawn_sync(makefile.get_parent().get_path(),
		                   args,
		                   null,
		                   SpawnFlags.SEARCH_PATH |
		                   SpawnFlags.STDERR_TO_DEV_NULL,
		                   null,
		                   out outstr);

		/* Extract args */
		int idx = outstr.last_index_of(fakecc);

		if (idx < 0)
		{
			throw new MakefileIntegrationError.MISSING_MAKE_OUTPUT("Make output did not contain flags");
		}

		string[] retargs;
		string[] parts = outstr.substring(idx).split("\n");

		Shell.parse_argv(parts[0], out retargs);

		log("GcaVala", LogLevelFlags.LEVEL_DEBUG,
		    "Parsed command: %s => '%s'\n",
		    parts[0],
		    string.joinv("', '", retargs));

		return retargs;
	}

	private async void makefile_changed_async(Makefile makefile)
	{
		ThreadFunc<void *> func = () => {
			foreach (File file in makefile.sources)
			{
				find_for_makefile(makefile.file, file);
			}

			return null;
		};

		try
		{
			new Thread<void *>.try("find makefile", func);
			yield;
		}
		catch
		{
		}
	}

	private void on_makefile_changed(Makefile makefile)
	{
		makefile_changed_async.begin(makefile);
	}

	private void find_for_makefile(File makefile, File file)
	{
		string[] targets;
		string[] args = {};

		try
		{
			targets = targets_from_make(makefile, file);

			log("GcaVala", LogLevelFlags.LEVEL_DEBUG,
			    "Makefile make targets for `%s': `%s'",
			    file.get_path(),
			    string.joinv(", ", targets));

			args = flags_from_targets(makefile, file, targets);

			log("GcaVala", LogLevelFlags.LEVEL_DEBUG,
			    "Compile flags for `%s': `%s`",
			    file.get_path(),
			    string.joinv("`, `", args));
		}
		catch (Error e)
		{
			stderr.printf("Makefile error: %s\n", e.message);
		}

		lock(d_makefileCache)
		{
			lock(d_argsCache)
			{
				if (d_argsCache.has_key(file))
				{
					d_argsCache[file].args = args;
				}
				else
				{
					Cache c = new Cache(file, makefile, args);
					d_argsCache[file] = c;
				}

				if (!d_makefileCache.has_key(makefile))
				{
					Makefile m = new Makefile(makefile);
					m.add(file);

					m.changed.connect(on_makefile_changed);
					d_makefileCache[makefile] = m;
				}
			}
		}

		changed_in_idle(file);
	}

	private void changed_in_idle(File file)
	{
		Idle.add(() => {
			arguments_changed(file);
			return false;
		});
	}

	private async void find_async(File file)
	{
		ThreadFunc<void *> func = () => {
			File ?makefile = null;

			try
			{
				makefile = makefile_for(file);
			}
			catch (Error e)
			{
				makefile = null;
			}

			if (makefile == null)
			{
				Cache c = new Cache(file, null, new string[] {});
				d_argsCache[file] = c;

				changed_in_idle(file);
				return null;
			}

			find_for_makefile(makefile, file);

			lock(d_makefileCache)
			{
				if (d_makefileCache.has_key(file))
				{
					d_makefileCache[makefile].add(file);
				}
			}

			return null;
		};

		try
		{
			new Thread<void *>.try("findasync", func);
			yield;
		}
		catch
		{
		}
	}

	public new string[]? get(File file)
	{
		string[] ?ret = null;

		lock(d_argsCache)
		{
			if (d_argsCache.has_key(file))
			{
				ret = d_argsCache[file].args;
			}
			else
			{
				monitor(file);
			}
		}

		return ret;
	}

	public async string[] args_for_file(File file) throws MakefileIntegrationError {
		lock(d_argsCache)
		{
			if (d_argsCache.has_key(file))
			{
				return d_argsCache[file].;

				lock(d_makefileCache)
				{
					return 
				}
			}
		}
	}

	public void monitor(File file)
	{
		bool hascache;

		lock(d_argsCache)
		{
			hascache = d_argsCache.has_key(file);
		}

		if (hascache)
		{
			arguments_changed(file);
		}
		else
		{
			find_async.begin(file, (source, res) => find_async.end(res));
		}
	}

	public void remove_monitor(File file)
	{
		lock(d_argsCache)
		{
			if (d_argsCache.has_key(file))
			{
				Cache c = d_argsCache[file];

				lock (d_makefileCache)
				{
					if (d_makefileCache.has_key(c.makefile))
					{
						Makefile m = d_makefileCache[c.makefile];

						if (m.remove(file))
						{
							d_makefileCache.unset(c.makefile);
						}
					}
				}

				d_argsCache.unset(file);
			}
		}
	}
}

public static int main(string[] a){
	var ml = new MainLoop();

	MakefileIntegration it = new MakefileIntegration();

	it.monitor(File.new_for_commandline_arg("dbus.vala"));

	ml.run();

	return 0;
}

}

/* vi:ex:ts=4 */
