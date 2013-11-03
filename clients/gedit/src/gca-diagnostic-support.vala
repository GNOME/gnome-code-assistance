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

public delegate void WithDiagnosticsCallback(SourceIndex diagnostics);

public interface DiagnosticSupport : Document
{
	public signal void diagnostics_updated();

	public abstract SourceIndex begin_diagnostics();
	public abstract void end_diagnostics();

	public Diagnostic[] find_at(SourceLocation location)
	{
		Diagnostic[] ret = new Diagnostic[0];

		var diagnostics = begin_diagnostics();

		foreach (var d in diagnostics.find_at(location))
		{
			ret += (Diagnostic)d;
		}

		end_diagnostics();

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

		var diagnostics = begin_diagnostics();

		foreach (var d in diagnostics.find_at_line(line))
		{
			ret += (Diagnostic)d;
		}

		end_diagnostics();

		Posix.qsort(ret, ret.length, sizeof(Diagnostic), (Posix.compar_fn_t)sort_on_severity);

		return ret;
	}

	public void with_diagnostics(WithDiagnosticsCallback callback)
	{
		var d = begin_diagnostics();
		callback(d);
		end_diagnostics();
	}

	public abstract void set_diagnostic_tags(Gca.DiagnosticTags tags);
	public abstract Gca.DiagnosticTags get_diagnostic_tags();
}

}

/* vi:ex:ts=4 */
