/*
 * This file is part of gnome-code-assistance.
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
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

class Helper
{
	static void add_to_context(CodeContext context, string path, string? data_path)
	{
		if (data_path == null || data_path == path)
		{
			context.add_source_filename(path, false, false);
			return;
		}

		SourceFile? sf = null;

		if (path.has_suffix(".vala") || path.has_suffix(".gs"))
		{
			sf = new SourceFile(context, SourceFileType.SOURCE, path, null, false);
			var nsref = new UsingDirective(new UnresolvedSymbol(null, "GLib", null));

			sf.add_using_directive(nsref);
			context.root.add_using_directive(nsref);
		}
		else if (path.has_suffix(".vapi") || path.has_suffix(".gir"))
		{
			sf = new SourceFile(context, SourceFileType.PACKAGE, path, null, false);
		}

		if (sf != null)
		{
			try
			{
				string c;
				FileUtils.get_contents(data_path, out c);

				sf.content = c;
			} catch {}

			context.add_source_file(sf);
		}
	}

	private static bool has_errors(ParserOptions opts)
	{
		var c = opts.context;
		return c.report.get_errors() > 0 || (opts.fatal_warnings && c.report.get_warnings() > 0);
	}

	private static void parse(ParserOptions opts)
	{
		CodeContext.push(opts.context);

		var parser = new Parser();
		parser.parse(opts.context);

		var genie_parser = new Genie.Parser();
		genie_parser.parse(opts.context);

		if (!has_errors(opts))
		{
			opts.context.check();
		}

		CodeContext.pop();
	}

	private static void extract_diagnostics(ParserOptions opts, Rpc.Document[] docs)
	{
		var d = opts.context.report as Diagnostics;

		for (int i = 0; i < docs.length; i++)
		{
			docs[i].diagnostics = d.diagnostics_for_path(docs[i].path);
		}
	}

	private static ParserOptions create_context(Rpc.Parse parse, out Rpc.Document[] rpcdocs)
	{
		var opts = OptionParser.parse_and_apply(".", parse.args);
		var sources = OptionParser.real_sources(".");

		var c = opts.context;
		CodeContext.push(c);

		var docs = new Gee.HashMap<File, OpenDocument?>(HashUtils.File.hash, HashUtils.File.equal);
		var retdocs = new Rpc.Document[0];

		foreach (var doc in parse.documents)
		{
			var f = File.new_for_path(doc.path);
			docs[f] = doc;
		}

		foreach (var source in sources)
		{
			var f = File.new_for_path(source);
			var doc = docs[f];

			if (doc != null)
			{
				add_to_context(c, doc.path, doc.data_path);

				retdocs += Rpc.Document() {
					path = doc.path
				};
			}
			else
			{
				add_to_context(c, source, null);
			}
		}

		CodeContext.pop();

		rpcdocs = retdocs;
		return opts;
	}

	private static Rpc.Reply run(Rpc.Parse cmd)
	{
		Rpc.Document[] docs;

		var opts = create_context(cmd, out docs);

		parse(opts);

		extract_diagnostics(opts, docs);

		return Rpc.Reply() {
			documents = docs
		};
	}

	private static uint8[] read_all()
	{
		uint8[] buffer = new uint8[4096];
		uint8[] ret = new uint8[4096];
		ret.length = 0;

		while (!stdin.eof())
		{
			var n = stdin.read(buffer);

			for (var i = 0; i < n; i++)
			{
				ret += buffer[i];
			}
		}

		return ret;
	}

	public static void main(string[] args)
	{
		Rpc.Parse p = Rpc.Parse();
		Variant dummy = p;

		var inp = read_all();
		var parse = Variant.new_from_data<void>(dummy.get_type(), inp, true);
		p = (Rpc.Parse)parse;

		var reply = run(p);
		Variant ret = reply;

		uint8[] data = new uint8[(int)ret.get_size()];
		ret.store((void *)data);

		stdout.write(data);
	}
}

/* vi:ex:ts=4 */
