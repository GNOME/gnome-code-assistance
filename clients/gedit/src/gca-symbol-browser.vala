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

public class SymbolBrowser : Gtk.TreeStore
{
	private bool d_tainted;

	public SymbolBrowser()
	{
		d_tainted = false;
	}

	public bool tainted
	{
		get
		{
			return d_tainted;
		}
		set
		{
			d_tainted = value;
		}
	}

	public void begin_update()
	{
	}

	public void end_update()
	{
		d_tainted = false;
	}
}

}

/* vi:ex:ts=4 */
