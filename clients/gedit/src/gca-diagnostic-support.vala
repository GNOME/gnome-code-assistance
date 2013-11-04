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

using Gee;

namespace Gca
{

public class DiagnosticSupport : Object
{
	private Gca.DiagnosticTags d_diagnostic_tags;
	private Gca.SourceIndex d_diagnostics;

	public signal void diagnostics_updated();

	construct
	{
		d_diagnostics = new SourceIndex();
	}

	public Diagnostic[] find_at(SourceLocation location)
	{
		Diagnostic[] ret = new Diagnostic[0];

		foreach (var d in d_diagnostics.find_at(location))
		{
			ret += (Diagnostic)d;
		}

		Posix.qsort(ret, ret.length, sizeof(Diagnostic), (Posix.compar_fn_t)sort_on_severity);

		return ret;
	}

	private int sort_on_severity(void *a, void *b)
	{
		Diagnostic? da = (Diagnostic ?)a;
		Diagnostic? db = (Diagnostic ?)b;

		if (da.severity == db.severity)
		{
			return 0;
		}

		// Higer priorities last
		return da.severity < db.severity ? -1 : 1;
	}

	public Diagnostic[] find_at_line(int line)
	{
		Diagnostic[] ret = new Diagnostic[0];

		foreach (var d in d_diagnostics.find_at_line(line))
		{
			ret += (Diagnostic)d;
		}

		Posix.qsort(ret, ret.length, sizeof(Diagnostic), (Posix.compar_fn_t)sort_on_severity);

		return ret;
	}

	public SourceIndex diagnostics
	{
		get { return d_diagnostics; }
		set
		{
			d_diagnostics = value;
		}
	}

	public Gca.DiagnosticTags diagnostic_tags
	{
		get { return d_diagnostic_tags; }
		set { d_diagnostic_tags = value; }
	}
}

}

/* vi:ex:ts=4 */
