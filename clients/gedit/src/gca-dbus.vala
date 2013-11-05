/*
 * This file is part of gedit-code-assistant.
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
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

namespace Gca.DBus
{

struct UnsavedDocument
{
	public string path;
	public string data_path;
}

struct SourceLocation
{
	public int64 line;
	public int64 column;

	public Gca.SourceLocation to_native()
	{
		return Gca.SourceLocation() {
			line = (int)line,
			column = (int)column
		};
	}
}

struct SourceRange
{
	public int64 file;

	public SourceLocation start;
	public SourceLocation end;

	public Gca.SourceRange to_native()
	{
		return Gca.SourceRange() {
			start = start.to_native(),
			end = end.to_native()
		};
	}
}

struct Fixit
{
	public SourceRange location;
	public string replacement;

	public Gca.Diagnostic.Fixit to_native()
	{
		return Gca.Diagnostic.Fixit() {
			range = location.to_native(),
			replacement = replacement
		};
	}
}

struct Diagnostic
{
	public uint32 severity;
	public Fixit[] fixits;
	public SourceRange[] locations;
	public string message;

	public Gca.Diagnostic to_native()
	{
		var f = new Gca.Diagnostic.Fixit[fixits.length];

		for (var i = 0; i < fixits.length; ++i)
		{
			f[i] = fixits[i].to_native();
		}

		var l = new Gca.SourceRange[locations.length];

		for (var i = 0; i < locations.length; ++i)
		{
			l[i] = locations[i].to_native();
		}

		return new Gca.Diagnostic((Gca.Diagnostic.Severity)severity, l, f, message);
	}
}

[DBus(name = "org.gnome.CodeAssist.Service")]
interface Service : Object
{
	public abstract async ObjectPath parse(string                     path,
	                                       int64                      cursor,
	                                       UnsavedDocument[]          unsaved,
	                                       HashTable<string, Variant> options) throws IOError;

	public abstract async void dispose(string path) throws IOError;

	public abstract async string[] supported_services() throws IOError;
}

[DBus(name = "org.gnome.CodeAssist.Document")]
interface Document : Object
{
	public abstract async string[] paths(int64[] ids) throws IOError;
}

[DBus(name = "org.gnome.CodeAssist.Diagnostics")]
interface Diagnostics : Object
{
	public abstract async Diagnostic[] diagnostics() throws IOError;
}

}

/* vi:ex:ts=4 */
