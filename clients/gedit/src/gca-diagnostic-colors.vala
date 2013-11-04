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

	private Gdk.RGBA mix_colors(Gdk.RGBA source, Gdk.RGBA dest)
	{
		Gdk.RGBA mixed = {0, 0, 0, 0};

		mixed.alpha = source.alpha + dest.alpha * (1 - source.alpha);

		mixed.red = (source.red * source.alpha +
		             dest.red * dest.alpha * (1 - source.alpha)) / mixed.alpha;

		mixed.green = (source.green * source.alpha +
		             dest.green * dest.alpha * (1 - source.alpha)) / mixed.alpha;

		mixed.blue = (source.blue * source.alpha +
		             dest.blue * dest.alpha * (1 - source.alpha)) / mixed.alpha;

		return mixed;
	}

	public void mix_in_widget(Widget widget)
	{
		StyleContext ctx = widget.get_style_context();

		ctx.save();
		ctx.add_class(STYLE_CLASS_VIEW);

		var dest = ctx.get_background_color(widget.get_state_flags());
		mix_in_color(widget, dest);

		ctx.restore();
	}

	public void mix_in_color(Widget widget, Gdk.RGBA dest)
	{
		StyleContext ctx = widget.get_style_context();

		ctx.save();

		ctx.add_class(STYLE_CLASS_VIEW);

		d_errorColor = mix_colors(update_color(ctx,
		                                       "error_bg_color",
		                                       {1, 0, 0, 1},
		                                       0.5), dest);

		d_warningColor = mix_colors(update_color(ctx,
		                                         "warning_bg_color",
		                                         {1, 0.5, 0, 1},
		                                         0.5), dest);

		d_infoColor = mix_colors(update_color(ctx,
		                                      "info_bg_color",
		                                      {0, 0, 1, 1},
		                                      0.5), dest);

		ctx.restore();
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

		double s = 0;

		var max = double.max(col.red, double.max(col.green, col.blue));
		var min = double.min(col.red, double.min(col.green, col.blue));

		var dm = max - min;

		if (dm != 0)
		{
			s = dm / max;
		}

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
