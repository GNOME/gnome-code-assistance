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

namespace Gca.Backends.Vala
{

public struct UnsavedDocument
{
	public string path;
	public string data_path;
}

public struct SourceLocation
{
	public int64 line;
	public int64 column;

	public int compare_to(SourceLocation other)
	{
		if (other.line == line)
		{
			if (column == other.column)
			{
				return 0;
			}

			return column < other.column ? -1 : 1;
		}
		else
		{
			return line < other.line ? -1 : 1;
		}
	}
}

public struct SourceRange
{
	public int64 file;

	public SourceLocation start;
	public SourceLocation end;
}

public struct Fixit
{
	public SourceRange location;
	public string replacement;
}

public enum Severity
{
	NONE,
	INFO,
	WARNING,
	DEPRECATED,
	ERROR,
	FATAL
}

public struct Diagnostic
{
	public uint32 severity;
	public Fixit[] fixits;
	public SourceRange[] locations;
	public string message;
}

}

/* vi:ex:ts=4 */
