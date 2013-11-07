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

using Gtk;

namespace Gca
{

struct SourceLocation
{
//	public File? file;
	public int line;
	public int column;

	public static SourceLocation from_iter(TextIter iter)
	{
		return SourceLocation() {
			line = iter.get_line() + 1,
			column = iter.get_line_offset() + 1
		};
	}

	public static SourceLocation from_dbus(DBus.SourceLocation location)
	{
		return Gca.SourceLocation() {
			line = (int)location.line,
			column = (int)location.column
		};
	}

	public SourceRange to_range()
	{
		return SourceRange() {
			start = this,
			end = this
		};
	}

	private int compare_int(int a, int b)
	{
		return a < b ? -1 : (a == b ? 0 : 1);
	}

	public int compare_to(SourceLocation other)
	{
		if (line == other.line)
		{
			return compare_int(column, other.column);
		}
		else
		{
			return compare_int(line, other.line);
		}
	}

	public bool get_iter(TextBuffer buffer, out TextIter iter)
	{
		buffer.get_iter_at_line(out iter, line - 1);

		if (iter.get_line() != line - 1)
		{
			if (iter.is_end())
			{
				return true;
			}

			return false;
		}

		if (column <= 1)
		{
			return true;
		}

		bool ret = iter.forward_chars(column - 1);

		if (!ret && iter.is_end())
		{
			ret = true;
		}

		return ret;
	}

	public bool buffer_coordinates(TextView view, out Gdk.Rectangle rect)
	{
		TextIter iter;

		rect = Gdk.Rectangle();

		if (!get_iter(view.buffer, out iter))
		{
			return false;
		}

		view.get_iter_location(iter, out rect);

		// We are more interested in the full yrange actually
		view.get_line_yrange(iter, out rect.y, out rect.height);
		return true;
	}

	public string to_string()
	{
		return "(%d.%d)".printf(line, column);
	}
}

}

/* vi:ex:ts=4 */
