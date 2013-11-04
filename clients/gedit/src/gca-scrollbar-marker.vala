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
using Gee;

namespace Gca
{

class ScrollbarMarker
{
	class Marker
	{
		private Gdk.RGBA d_color;
		private SourceRange d_range;

		public Marker(SourceRange range, Gdk.RGBA color)
		{
			d_color = color;
			d_range = range;
		}

		public SourceRange range
		{
			get
			{
				return d_range;
			}
		}

		public Gdk.RGBA color
		{
			get
			{
				return d_color;
			}
		}
	}

	private unowned Scrollbar? d_scrollbar;
	private HashMap<uint, LinkedList<Marker>> d_markers;
	private int d_spacing;
	private int d_maxline;
	private int d_border;
	private int d_width;
	private uint d_mergeId;

	public ScrollbarMarker(Scrollbar scrollbar)
	{
		d_scrollbar = scrollbar;
		d_scrollbar.draw.connect_after(on_scrollbar_draw);

		d_markers = new HashMap<uint, LinkedList<Marker>>();
		d_maxline = 0;

		d_scrollbar.style_updated.connect(on_style_updated);
		update_spacing();
	}

	public int max_line
	{
		get { return d_maxline; }

		set
		{
			d_maxline = value;
			d_scrollbar.queue_draw();
		}
	}

	public Scrollbar? scrollbar
	{
		get { return d_scrollbar; }
	}

	private void update_spacing()
	{
		StyleContext ctx = d_scrollbar.get_style_context();

		int stepper_size = GcaUtilsC.get_style_property_int(ctx,
		                                                 "stepper-size");

		int stepper_spacing = GcaUtilsC.get_style_property_int(ctx,
		                                                    "stepper-spacing");

		d_border = GcaUtilsC.get_style_property_int(ctx, "trough-border");
		d_width = GcaUtilsC.get_style_property_int(ctx, "slider-width");

		d_spacing = stepper_size + stepper_spacing + 2;
	}

	private void on_style_updated()
	{
		update_spacing();
	}

	public uint new_merge_id()
	{
		return ++d_mergeId;
	}

	public void add_with_id(uint id, SourceRange range, Gdk.RGBA color)
	{
		Marker marker = new Marker(range, color);
		LinkedList<Marker> lst;

		if (d_markers.has_key(id))
		{
			lst = d_markers[id];
		}
		else
		{
			lst = new LinkedList<Marker>();
			d_markers[id] = lst;
		}

		lst.add(marker);

		d_scrollbar.queue_draw();
	}

	public void remove(uint id)
	{
		if (!d_markers.has_key(id))
		{
			return;
		}

		d_markers.unset(id);
		d_scrollbar.queue_draw();
	}

	~ScrollbarMarker()
	{
		if (d_scrollbar == null)
		{
			return;
		}

		d_scrollbar.draw.disconnect(on_scrollbar_draw);
	}

	private void draw_marker(Cairo.Context ctx,
	                         Gdk.Rectangle rect,
	                         Marker        marker)
	{
		// rect scales from line 1 to d_maxline
		SourceRange range = marker.range;
		uint height = range.end.line - range.start.line + 1;

		double scale = (double)rect.height / (double)d_maxline;

		double y = Math.round(rect.y + (range.start.line - 1) * scale - 0.5) + 0.5;
		double dy = Math.fmax(1, Math.round(height * scale));

		Gdk.cairo_set_source_rgba(ctx, marker.color);
		ctx.set_line_width(1);

		if (dy > 1.5)
		{
			ctx.rectangle(rect.x + 0.5, y, rect.width - 1, dy);
			ctx.fill();
		}
		else
		{
			ctx.move_to(rect.x + 0.5, y);
			ctx.line_to(rect.x + 0.5 + rect.width - 1, y);
			ctx.stroke();
		}
	}

	private bool on_scrollbar_draw(Cairo.Context ctx)
	{
		// TODO: check
		var range = GcaUtilsC.get_range_rect(d_scrollbar);

		// Remove stepper button sizes
		range.x += d_border;
		range.width = d_width;
		range.y += d_spacing;
		range.height -= 2 * d_spacing;

		foreach (uint key in d_markers.keys)
		{
			LinkedList<Marker> lst = d_markers[key];

			foreach (Marker marker in lst)
			{
				draw_marker(ctx, range, marker);
			}
		}

		return false;
	}
}

}

/* vi:ex:ts=4 */
