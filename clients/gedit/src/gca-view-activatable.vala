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

class ViewActivatable : GLib.Object, Gedit.ViewActivatable
{
	public Gedit.View view { construct; owned get; }

	private Gca.View d_view;

	public void activate()
	{
		d_view = new Gca.View(view);
	}

	public void deactivate()
	{
		d_view.deactivate();
		d_view = null;
	}
}

}

/* vi:ex:ts=4 */
