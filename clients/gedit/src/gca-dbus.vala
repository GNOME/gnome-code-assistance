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

public struct UnsavedDocument
{
	public string path;
	public string data_path;
}

public struct SourceLocation
{
	public int64 line;
	public int64 column;
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

public struct Diagnostic
{
	public uint32 severity;
	public Fixit[] fixits;
	public SourceRange[] locations;
	public string message;
}

[DBus(name = "org.gnome.CodeAssist.Service")]
interface Service : Object
{
	public abstract async ObjectPath parse(string                     path,
	                                       int64                      cursor,
	                                       UnsavedDocument[]          unsaved,
	                                       HashTable<string, Variant> options) throws DBusError;

	public abstract async void dispose(string path) throws DBusError;

	public abstract async string[] supported_services() throws DBusError;
}

[DBus(name = "org.gnome.CodeAssist.Document")]
interface Document : Object
{
}

[DBus(name = "org.gnome.CodeAssist.Diagnostics")]
interface Diagnostics : Object
{
	public abstract async Diagnostic[] diagnostics() throws DBusError;
}

}

/* vi:ex:ts=4 */
