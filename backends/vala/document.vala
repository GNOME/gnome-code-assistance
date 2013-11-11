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

public class Document : Object
{
	public string path { get; construct set; }
	public string data_path { get; set; }
	public SourceLocation cursor { get; set; }
	public string client_path { get; set; }

	public Diagnostic[] diagnostics { get; set; }

	public Document(string path)
	{
		Object(path: path);
	}
}

}

/* vi:ex:ts=4 */
