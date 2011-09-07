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

namespace Gcp
{
	class DiagnosticColors
	{
		private Gdk.RGBA d_errorColor;
		private Gdk.RGBA d_warningColor;
		private Gdk.RGBA d_infoColor;

		public DiagnosticColors(StyleContext context)
		{
			d_errorColor = update_color(context,
			             "error_bg_color",
			             {1, 0, 0, 1},
			             0.5);

			d_warningColor = update_color(context,
			             "warning_bg_color",
			             {1, 0.5, 0, 1},
			             0.5);

			d_infoColor = update_color(context,
			             "info_bg_color",
			             {0, 0, 1, 1},
			             0.5);
		}

		public Gdk.RGBA? get(Diagnostic.Severity severity)
		{
			switch (severity)
			{
				case Diagnostic.Severity.INFO:
					return d_infoColor;
				case Diagnostic.Severity.WARNING:
					return d_warningColor;
				case Diagnostic.Severity.ERROR:
				case Diagnostic.Severity.FATAL:
					return d_errorColor;
				default:
					return null;
			}
		}

		public Gdk.RGBA error_color
		{
			get { return d_errorColor; }
		}

		public Gdk.RGBA warning_color
		{
			get { return d_warningColor; }
		}

		public Gdk.RGBA info_color
		{
			get { return d_infoColor; }
		}

		private Gdk.RGBA update_color(StyleContext context,
		                              string color_name,
		                              Gdk.RGBA defcol,
		                              double alpha)
		{
			Gdk.RGBA col;

			if (!context.lookup_color(color_name, out col))
			{
				col = defcol;
			}

			double h;
			double s;
			double v;

			Gtk.rgb_to_hsv(col.red, col.green, col.blue, out h, out s, out v);

			if (s < 0.5)
			{
				col.red *= 0.5;
				col.blue *= 0.5;
				col.green *= 0.5;
			}

			col.alpha *= alpha;

			return col;
		}
	}
}

/* vi:ex:ts=4 */
