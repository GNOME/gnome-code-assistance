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

using global::Vala;

namespace Gca.Backends.Vala
{

public class Diagnostics : Report
{
	private Diagnostic[] d_diagnostics;
	public string path { get; set; }

	public Diagnostics(string path)
	{
		this.path = path;

		d_diagnostics = new Diagnostic[20];
		d_diagnostics.length = 0;
	}

	private void diags_report(SourceReference? source, string message, Severity severity)
	{
		if (source == null || source.file == null || source.file.filename == null)
		{
			return;
		}

		if (source.file.filename != path)
		{
			return;
		}

		var start = SourceLocation() {
			line = source.begin.line,
			column = source.begin.column
		};

		var end = SourceLocation() {
			line = source.end.line,
			column = source.end.column
		};

		if (start.compare_to(end) > 0)
		{
			var tmp = end;

			end = start;
			start = tmp;
		}

		var range = SourceRange() {
			file = 0,
			start = start,
			end = end
		};

		d_diagnostics += Diagnostic() {
			severity = severity,
			fixits = new Fixit[] {},
			locations = new SourceRange[] {range},
			message = message
		};
	}

	public Diagnostic[] diagnostics
	{
		get { return d_diagnostics; }
	}

	public override void err(SourceReference? source, string message)
	{
		diags_report(source, message, Severity.ERROR);
	}

	public override void warn(SourceReference? source, string message)
	{
		if (!enable_warnings)
		{
			return;
		}

		diags_report(source, message, Severity.WARNING);
	}

	public override void depr(SourceReference? source, string message)
	{
		if (!enable_warnings)
		{
			return;
		}

		diags_report(source, message, Severity.DEPRECATED);
	}

	public override void note(SourceReference? source, string message)
	{
		if (!enable_warnings)
		{
			return;
		}

		diags_report(source, message, Severity.INFO);
	}
}

public class Service : Object
{
	public Document parse(string path, int64 cursor, string data_path, HashTable<string, Variant> options, Document? document)
	{
		var doc = document;

		if (doc == null)
		{
			doc = new Document(path);
		}

		CodeContext context = new CodeContext();

		var diags = new Diagnostics(data_path);
		context.report = diags;

		CodeContext.push(context);

		var sf = new SourceFile(context, SourceFileType.SOURCE, data_path, null, true);
		context.add_source_file(sf);

		Parser ast = new Parser();
		ast.parse(context);

		CodeContext.pop();

		doc.diagnostics = diags.diagnostics;

		return doc;
	}

	public new void dispose(Document document)
	{
	}
}

}

/* vi:ex:ts=4 */
