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

namespace Gca
{

public class SourceRange : Object, SourceRangeSupport
{
	private SourceLocation d_start;
	private SourceLocation d_end;

	public SourceRange(SourceLocation start, SourceLocation end)
	{
		d_start = start;
		d_end = end;
	}

	public SourceRange? range
	{
		owned get { return this; }
	}

	public SourceRange[] ranges
	{
		owned get { return new SourceRange[] {this}; }
	}

	public SourceLocation start
	{
		get { return d_start; }
	}

	public SourceLocation end
	{
		get { return d_end; }
	}

	public int compare_to(SourceRange other)
	{
		int st = d_start.compare_to(other.d_start);

		if (st != 0)
		{
			return st;
		}

		return other.d_end.compare_to(d_end);
	}

	public bool get_iters(Gtk.TextBuffer buffer,
	                      out Gtk.TextIter start,
	                      out Gtk.TextIter end)
	{
		bool rets;
		bool rete;

		rets = d_start.get_iter(buffer, out start);
		rete = d_end.get_iter(buffer, out end);

		return rets && rete;
	}

	public bool contains_range(SourceRange range)
	{
		return contains_location(range.start) && contains_location(range.end);
	}

	public bool contains_location(SourceLocation location)
	{
		return contains(location.line, location.column);
	}

	public bool contains(int line, int column)
	{
		return (d_start.line < line || (d_start.line == line && d_start.column <= column)) &&
		       (d_end.line > line || (d_end.line == line && d_end.column >= column));
	}

	public bool contains_line(int line)
	{
		return d_start.line <= line && d_end.line >= line;
	}

	public string to_string()
	{
		if (d_start.line == d_end.line && d_end.column - d_start.column <= 1)
		{
			return d_start.to_string();
		}

		return "%s-%s".printf(d_start.to_string(), d_end.to_string());
	}
}

}

/* vi:ex:ts=4 */
