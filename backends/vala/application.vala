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

public class Application
{
	public static int main(string[] args)
	{
		Options.init();

		var ctx = new OptionContext("- gnome code assistance daemon");

		ctx.set_help_enabled(true);
		ctx.add_main_entries(Options.options, null);

		try
		{

			ctx.parse(ref args);
		}
		catch (OptionError e)
		{
			stderr.printf("Failed to parse options: %s\n", e.message);
			return 1;
		}

		if (Options.transport == "dbus")
		{
			(new DBus.Transport()).run();
		}

		return 0;
	}
}

}

/* vi:ts=4: */
