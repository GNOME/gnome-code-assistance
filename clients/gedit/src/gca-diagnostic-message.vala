using Gtk;
using Gee;

namespace Gca
{

class DiagnosticMessage : EventBox
{
	private Diagnostic[] d_diagnostics;
	private Box? d_vbox;
	private DiagnosticColors d_colors;
	private unowned SourceView? d_view;
	private Diagnostic.Severity d_rulingSeverity;
	private bool d_inserted;
	private int d_width;
	private int d_height;
	private bool d_updating;

	public DiagnosticMessage(SourceView view, Diagnostic[] diagnostics)
	{
		d_diagnostics = diagnostics;
		d_view = view;

		visible_window = false;
		app_paintable = true;

		d_colors = new DiagnosticColors(get_style_context());
		d_view.style_updated.connect(on_view_style_updated);

		d_view.buffer.notify["style-scheme"].connect(on_style_scheme_changed);

		d_view.key_press_event.connect(on_view_key_press);

		d_inserted = false;

		update();
	}

	private bool on_view_key_press(Gdk.EventKey event)
	{
		if (event.keyval == Gdk.keyval_from_name("Escape"))
		{
			destroy();
			return true;
		}

		return false;
	}

	private void on_style_scheme_changed()
	{
		style_changed();
	}

	private void style_changed()
	{
		d_colors = new DiagnosticColors(get_style_context());

		if (d_view != null)
		{
			d_colors.mix_in_widget(d_view);
		}

		update();
	}

	private void on_view_style_updated()
	{
		style_changed();
	}

	protected override void destroy()
	{
		if (d_view != null)
		{
			d_view.style_updated.disconnect(on_view_style_updated);
			d_view.buffer.notify["style-scheme"].disconnect(on_style_scheme_changed);

			d_view.key_press_event.disconnect(on_view_key_press);
		}

		base.destroy();
	}

	protected override void style_updated()
	{
		base.style_updated();

		style_changed();
	}

	private void update()
	{
		if (d_updating)
		{
			return;
		}

		if (d_vbox != null)
		{
			d_vbox.destroy();
			d_vbox = null;
		}

		if (d_view == null)
		{
			return;
		}

		d_updating = true;

		d_vbox = new Box(Orientation.VERTICAL, 1);
		d_vbox.show();

		var ctx = d_view.get_style_context();
		ctx.save();

		ctx.add_class(STYLE_CLASS_VIEW);
		//var color = ctx.get_color(StateFlags.NORMAL);

		ctx.restore();

		bool ismixed = mixed_severity;

		foreach (Diagnostic d in d_diagnostics)
		{
			Label label = new Label(null);

			if (ismixed)
			{
				label.set_markup("<b>%s</b>: %s".printf(d.severity.to_string(),
				                                        Markup.escape_text(d.message)));
			}
			else
			{
				label.set_text(d.message);
			}

			label.set_margin_left(6);
			label.set_margin_right(6);

			label.show();

			//label.override_color(StateFlags.NORMAL, color);

			label.halign = Align.START;
			label.valign = Align.CENTER;
			label.wrap = true;

			d_vbox.pack_start(label, false, true, 0);
		}

		add(d_vbox);
		show();

		d_rulingSeverity = diagnostics_ruling_severity;

		reposition();

		d_updating = false;
	}

	private bool mixed_severity
	{
		get
		{
			bool first = true;
			Diagnostic.Severity s = Diagnostic.Severity.NONE;

			foreach (Diagnostic d in d_diagnostics)
			{
				if (first)
				{
					first = false;
					s = d.severity;
				}

				if (s != d.severity)
				{
					return true;
				}
			}

			return false;
		}
	}

	public Diagnostic[] diagnostics
	{
		get
		{
			return d_diagnostics;
		}
		set
		{
			d_diagnostics = value;

			stderr.printf("set diagnostics\n");

			update();
		}
	}

	private Diagnostic.Severity diagnostics_ruling_severity
	{
		get
		{
			Diagnostic.Severity severity = Diagnostic.Severity.NONE;
			bool first = true;

			foreach (Diagnostic d in d_diagnostics)
			{
				if (first || d.severity > severity)
				{
					severity = d.severity;
				}

				first = false;
			}

			return severity;
		}
	}

	private void expand_range(ExpandRange topx,
	                          ExpandRange bottomx,
	                          ExpandRange y,
	                          SourceLocation location)
	{
		Gdk.Rectangle rect;

		location.buffer_coordinates(d_view, out rect);

		if (rect.y < y.min)
		{
			bottomx.reset();
		}

		if (rect.y + rect.height > y.max)
		{
			topx.reset();
		}

		y.add(rect.y);
		y.add(rect.y + rect.height);

		if (rect.y == y.min)
		{
			topx.add(rect.x);
			topx.add(rect.x + rect.width);
		}

		if (rect.y + rect.height == y.max)
		{
			bottomx.add(rect.x);
			bottomx.add(rect.x + rect.width);
		}
	}

	public void reposition()
	{
		ExpandRange topx = new ExpandRange();
		ExpandRange bottomx = new ExpandRange();
		ExpandRange y = new ExpandRange();

		foreach (Diagnostic d in d_diagnostics)
		{
			foreach (SourceRange r in d.ranges)
			{
				expand_range(topx, bottomx, y, r.start);
				expand_range(topx, bottomx, y, r.end);
			}
		}

		// Position the message depending on where we can find the largest
		// space with the message aligned on the range.

		// 1) Find whether it's better to show at the top or at the bottom
		// 2) Align right or left with the boundary of the diagnostic
		int ymin;
		int ymax;

		d_view.buffer_to_window_coords(TextWindowType.TEXT, 0, y.min, null, out ymin);
		d_view.buffer_to_window_coords(TextWindowType.TEXT, 0, y.max, null, out ymax);

		var window = d_view.get_window(TextWindowType.TEXT);
		int aligny;
		int alignyat;
		ExpandRange xrange;

		if (ymin > window.get_height() - ymax)
		{
			// Show above
			aligny = 1;
			alignyat = ymin - 3;
			xrange = topx;
		}
		else
		{
			// Show below
			aligny = 0;
			alignyat = ymax + 3;
			xrange = bottomx;
		}

		// Check whether to align on right or left boundary
		int xmin;
		int xmax;

		d_view.buffer_to_window_coords(TextWindowType.TEXT, xrange.min, 0, out xmin, null);
		d_view.buffer_to_window_coords(TextWindowType.TEXT, xrange.max, 0, out xmax, null);

		int xc;
		int width;

		if (window.get_width() - xmin > xmax)
		{
			// Align on xmin to the right
			xc = xmin;
			width = window.get_width() - xmin;
		}
		else
		{
			// Align on 0 to xmax
			xc = 0;
			width = xmax;
		}

		if (!d_inserted)
		{
			d_view.add_child_in_window(this, TextWindowType.TEXT, 0, 0);
		}

		int minwidth;
		base.get_preferred_width(null, out minwidth);

		if (minwidth < width)
		{
			width = minwidth;
		}

		int natural_height;
		base.get_preferred_height_for_width(width, out d_height, out natural_height);
		d_width = width;

		int yc = alignyat - d_height * aligny;

		d_view.move_child(this, xc, yc);
		d_inserted = true;

		queue_resize();
	}

	protected override SizeRequestMode get_request_mode()
	{
		return SizeRequestMode.HEIGHT_FOR_WIDTH;
	}

	protected override void get_preferred_height(out int minimum_height,
	                                             out int natural_height)
	{
		int minwidth;

		get_preferred_width(out minwidth, null);
		get_preferred_height_for_width(minwidth, out minimum_height, out natural_height);
	}

	protected override void get_preferred_width(out int minimum_width,
	                                            out int natural_width)
	{
		minimum_width = d_width;
		natural_width = d_width;
	}

	protected override void get_preferred_height_for_width(int width,
	                                                       out int minimum_height,
	                                                       out int natural_height)
	{
		if (width == d_width)
		{
			minimum_height = d_height;
			natural_height = d_height;
		}
		else
		{
			base.get_preferred_height_for_width(width,
			                                    out minimum_height,
			                                    out natural_height);
		}
	}

	private void add_class_for_severity(StyleContext ctx)
	{
		switch (d_rulingSeverity)
		{
			case Diagnostic.Severity.ERROR:
			case Diagnostic.Severity.FATAL:
				ctx.add_class(STYLE_CLASS_ERROR);
			break;
			case Diagnostic.Severity.WARNING:
				ctx.add_class(STYLE_CLASS_WARNING);
			break;
			case Diagnostic.Severity.INFO:
				ctx.add_class(STYLE_CLASS_INFO);
			break;
			default:
			break;
		}
	}

	protected override bool draw(Cairo.Context context)
	{
		Allocation alloc;

		get_allocation(out alloc);

		var ctx = get_style_context();

		ctx.save();
		add_class_for_severity(ctx);

		ctx.render_background(context, 0, 0, alloc.width, alloc.height);
		ctx.render_frame(context, 0, 0, alloc.width, alloc.height);

		ctx.save();

		base.draw(context);

		return false;
	}
}

}

/* vi:ex:ts=4 */
