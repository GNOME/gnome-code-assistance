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

struct SourceRange
{
	public SourceLocation start;
	public SourceLocation end;

	public static SourceRange from_iter(Gtk.TextIter iter)
	{
		var loc = SourceLocation.from_iter(iter);

		return SourceRange() {
			start = loc,
			end = loc
		};
	}

	public static SourceRange from_dbus(DBus.SourceRange range)
	{
		return Gca.SourceRange() {
			start = SourceLocation.from_dbus(range.start),
			end = SourceLocation.from_dbus(range.end)
		};
	}

	public int compare_to(SourceRange other)
	{
		int st = start.compare_to(other.start);

		if (st == 0)
		{
			st = other.end.compare_to(end);
		}

		return st;
	}

	public bool get_iters(Gtk.TextBuffer   buffer,
	                      out Gtk.TextIter start,
	                      out Gtk.TextIter end)
	{
		bool rets;
		bool rete;

		rets = this.start.get_iter(buffer, out start);
		rete = this.end.get_iter(buffer, out end);

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
		return (start.line < line || (start.line == line && start.column <= column)) &&
		       (end.line > line || (end.line == line && end.column >= column));
	}

	public bool contains_line(int line)
	{
		return start.line <= line && end.line >= line;
	}

	public string to_string()
	{
		if (start.line == end.line && end.column - start.column <= 1)
		{
			return start.to_string();
		}

		return "%s-%s".printf(start.to_string(), end.to_string());
	}
}

}

/* vi:ex:ts=4 */
