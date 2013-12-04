/*
 * This file is part of gnome-code-assistance.
 *
 * Copyright (C) 2013 - Melissa Wen <melissa.srw@gmail.com>
 * Copyright (C) 2013 - Jesse van den Kieboom <jessevdk@gnome.org>
 *
 * gnome-code-assistance is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * gnome-code-assistance is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gnome-code-assistance.  If not, see <http://www.gnu.org/licenses/>.
 */

using Vala;

public class Service
{
	private MakefileIntegration d_makefile;

	public Service()
	{
		d_makefile = new MakefileIntegration();
	}

	private char[] read_all(IOChannel f)
	{
		char[] buffer = new char[4096];
		char[] ret = new char[4096];
		ret.length = 0;

		while (true)
		{
			size_t n;
			IOStatus st;

			try
			{
				st = f.read_chars(buffer, out n);
			}
			catch
			{
				st = IOStatus.ERROR;
				n = 0;
			}

			for (var i = 0; i < n; i++)
			{
				ret += buffer[i];
			}

			if (st == IOStatus.EOF || st == IOStatus.ERROR)
			{
				break;
			}
		}

		return ret;
	}

	private async Rpc.Reply spawn_helper(Document[] documents, string wd, string[] flags)
	{
		SourceFunc cb = spawn_helper.callback;
		var argv = new string[] {Path.build_filename(Config.BackendExecDir, "valahelper")};

		Pid pid;
		int inp, outp;

		try
		{
			Process.spawn_async_with_pipes(wd, argv, null, 0, null, out pid, out inp, out outp, null);
		}
		catch (SpawnError e)
		{
			log("GcaVala", LogLevelFlags.LEVEL_DEBUG, "Failed to spawn helper: %s", e.message);
			return Rpc.Reply();
		}

		var outstr = new IOChannel.unix_new(outp);
		var instr = new IOChannel.unix_new(inp);

		char[] retb = new char[0];

		Thread<void*>? reader = null;
		Thread<void*>? writer = null;

		try
		{
			reader = new Thread<void *>.try("reader", () => {
				retb = read_all(outstr);
				return null;
			});
		}
		catch (Error e)
		{
			log("GcaVala", LogLevelFlags.LEVEL_DEBUG, "Failed to create reader thread: %s", e.message);

			try
			{
				outstr.shutdown(false);
			} catch {}
		}

		try
		{
			writer = new Thread<void*>.try("writer", () => {
				var odocs = new OpenDocument[documents.length];

				for (int i = 0; i < documents.length; i++)
				{
					odocs[i].path = documents[i].path;
					odocs[i].data_path = documents[i].data_path;
				}

				var cmd = Rpc.Parse() {
					args = flags,
					documents = odocs
				};

				Variant vv = cmd;
				char[] data = new char[(int)vv.get_size()];

				vv.store((void *)data);

				try
				{
					size_t n;
					instr.write_chars(data, out n);
				} catch {}

				try
				{
					instr.shutdown(true);
				} catch {}

				return null;
			});
		}
		catch (Error e)
		{
			log("GcaVala", LogLevelFlags.LEVEL_DEBUG, "Failed to create writer thread: %s", e.message);

			try
			{
				instr.shutdown(false);
			} catch {}
		}

		ChildWatch.add(pid, (p, st) => {
			Process.close_pid(p);
			cb();
		});

		yield;

		if (writer != null)
		{
			writer.join();
		}

		if (reader != null)
		{
			reader.join();
		}

		try
		{
			outstr.shutdown(false);
			instr.shutdown(false);
		} catch {}

		Rpc.Reply r = Rpc.Reply();
		Variant dummy = r;

		var reply = Variant.new_from_data<void>(dummy.get_type(), (uchar[])retb, true);
		return (Rpc.Reply)reply;
	}

	private async Document[] parse_impl(Document doc, Document[] documents, HashTable<string, Variant> options)
	{
		var f = File.new_for_path(doc.path);

		string wd;
		var flags = d_makefile.flags_for_file(f, out wd);

		var reply = yield spawn_helper(documents, wd, flags);

		var odocs = new Gee.HashMap<string, Document>();

		foreach (var d in documents)
		{
			odocs[d.path] = doc;
		}

		var retdocs = new Document[reply.documents.length];
		retdocs.length = 0;

		foreach (var d in reply.documents)
		{
			var odoc = odocs[d.path];

			if (odoc != null)
			{
				odoc.diagnostics = d.diagnostics;
				retdocs += odoc;
			}
		}

		return retdocs;
	}

	public async void parse(Document doc, HashTable<string, Variant> options)
	{
		yield parse_impl(doc, new Document[] {doc}, options);
	}

	public async Document[] parse_all(Document doc, Document[] documents, HashTable<string, Variant> options)
	{
		return yield parse_impl(doc, documents, options);
	}

	public new void dispose(Document document)
	{
		var f = File.new_for_path(document.path);

		d_makefile.dispose(f);
	}
}

/* vi:ex:ts=4 */
