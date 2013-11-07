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

namespace Gca
{

[Flags]
enum RemoteServices
{
	DIAGNOSTICS,
	SEMANTIC_VALUES,
	SYMBOLS,
	MULTI_DOC;

	public static RemoteServices parse(string s)
	{
		switch (s)
		{
		case "org.gnome.CodeAssist.Diagnostics":
			return RemoteServices.DIAGNOSTICS;
		case "org.gnome.CodeAssist.SEMANTIC_VALUES":
			return RemoteServices.SEMANTIC_VALUES;
		case "org.gnome.CodeAssist.Symbols":
			return RemoteServices.SYMBOLS;
		case "org.gnome.CodeAssist.MultiDoc":
			return RemoteServices.MULTI_DOC;
		}

		return 0;
	}
}


class RemoteDocument
{
	private string d_service;
	private ObjectPath d_path;

	public RemoteDocument(string service, ObjectPath path)
	{
		d_service = service;
		d_path = path;
	}

	public async T get_proxy<T>() throws IOError
	{
		return yield Bus.get_proxy<T>(BusType.SESSION, d_service, d_path);
	}

	public ObjectPath path
	{
		get { return d_path; }
	}
}

interface RemoteService : Object
{
	public abstract RemoteServices services();
	public abstract void update(View view, RemoteDocument document);
	public abstract void destroy();
}

}

/* vi:ex:ts=4 */
