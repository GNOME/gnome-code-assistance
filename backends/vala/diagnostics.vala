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

class Diagnostics : Report
{
	private Gee.HashMap<string, Gee.ArrayList<Diagnostic?>> d_diagnostics;

	public Diagnostics()
	{
		base();

		d_diagnostics = new Gee.HashMap<string, Gee.ArrayList<Diagnostic?>>();
	}

	public Diagnostic[] diagnostics_for_path(string path)
	{
		Gee.ArrayList<Diagnostic?>? diagnostics = d_diagnostics[path];

		if (diagnostics == null)
		{
			return new Diagnostic[0];
		}

		var ret = new Diagnostic[diagnostics.size];
		ret.length = 0;

		foreach (var d in diagnostics)
		{
			ret += d;
		}

		return ret;
	}

	private void diags_report(SourceReference? source, string message, Severity severity)
	{
		if (source == null || source.file == null || source.file.filename == null)
		{
			return;
		}

		Gee.ArrayList<Diagnostic?>? diagnostics = d_diagnostics[source.file.filename];

		if (diagnostics == null)
		{
			diagnostics = new Gee.ArrayList<Diagnostic?>();
			d_diagnostics[source.file.filename] = diagnostics;
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

		diagnostics.add(Diagnostic() {
			severity = severity,
			fixits = new Fixit[] {},
			locations = new SourceRange[] {range},
			message = message
		});
	}

	public override void err(SourceReference? source, string message)
	{
		log("GcaVala", LogLevelFlags.LEVEL_DEBUG, "[err]: %s", message);

		diags_report(source, message, Severity.ERROR);
	}

	public override void warn(SourceReference? source, string message)
	{
		log("GcaVala", LogLevelFlags.LEVEL_DEBUG, "[warn]: %s", message);

		if (!enable_warnings)
		{
			return;
		}

		diags_report(source, message, Severity.WARNING);
	}

	public override void depr(SourceReference? source, string message)
	{
		log("GcaVala", LogLevelFlags.LEVEL_DEBUG, "[depr]: %s", message);

		if (!enable_warnings)
		{
			return;
		}

		diags_report(source, message, Severity.DEPRECATED);
	}

	public override void note(SourceReference? source, string message)
	{
		log("GcaVala", LogLevelFlags.LEVEL_DEBUG, "[note]: %s", message);

		if (!enable_warnings)
		{
			return;
		}

		diags_report(source, message, Severity.INFO);
	}
}

/* vi:ts=4: */
