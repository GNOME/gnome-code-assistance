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

class DiagnosticService : RemoteService, Object
{
	private Diagnostics d_diagnostics;
	private DBus.Diagnostics d_proxy;
	private ObjectPath? d_path;

	public RemoteServices services()
	{
		return RemoteServices.DIAGNOSTICS;
	}

	public void update(View view, RemoteDocument document)
	{
		if (d_diagnostics == null)
		{
			d_diagnostics = new Diagnostics(view);
		}

		if (d_path != document.path)
		{
			d_proxy = null;
			d_path = null;
		}

		if (d_proxy == null)
		{
			document.get_proxy.begin<DBus.Diagnostics>((obj, res) => {
				try
				{
					d_proxy = document.get_proxy<DBus.Diagnostics>.end(res);
					update_proxy();
				}
				catch (IOError e)
				{
					Log.debug("Failed to get diagnostics proxy: %s", e.message);
				}
			});
		}
		else
		{
			update_proxy();
		}
	}

	private void update_proxy()
	{
		d_proxy.diagnostics.begin((obj, res) => {
			try
			{
				var ret = d_proxy.diagnostics.end(res);
				d_diagnostics.update(transform(ret));
			}
			catch (Error e)
			{
				Log.debug("Failed to call diagnostics: %s", e.message);
			}
		});
	}

	private Diagnostic[] transform(DBus.Diagnostic[] diagnostics)
	{
		var ret = new Diagnostic[diagnostics.length];

		for (var i = 0; i < ret.length; ++i)
		{
			ret[i] = new Diagnostic.from_dbus(diagnostics[i]);
		}

		return ret;
	}

	public void destroy()
	{
		if (d_diagnostics != null)
		{
			d_diagnostics.destroy();
			d_diagnostics = null;
		}
	}
}

class Diagnostics : Object
{
	private View? d_view;
	private SourceIndex<Diagnostic> d_index;
	private DiagnosticTags d_tags;

	private Gee.HashMap<Gtk.TextMark, Gdk.RGBA?> d_diagnostics_at_end;
	private Diagnostic[] d_cursor_diagnostics;
	private DiagnosticMessage? d_cursor_diagnostic_message;
	private uint d_last_marker_id;

	public static string error_mark_category
	{
		get { return "Gca.Document.ErrorCategory"; }
	}

	public static string error_icon_name
	{
		get { return "dialog-error-symbolic"; }
	}

	public static string warning_mark_category
	{
		get { return "Gca.Document.WarningCategory"; }
	}

	public static string warning_icon_name
	{
		get { return "dialog-warning-symbolic"; }
	}

	public static string info_mark_category
	{
		get { return "Gca.Document.InfoCategory"; }
	}

	public static string info_icon_name
	{
		get { return "dialog-information-symbolic"; }
	}

	public Diagnostics(View view)
	{
		d_view = view;

		d_index = new SourceIndex<Diagnostic>();
		d_tags = new DiagnosticTags(d_view.view);
		d_diagnostics_at_end = new Gee.HashMap<Gtk.TextMark, Gdk.RGBA?>();

		register_marks();

		var v = d_view.view;

		v.set_show_line_marks(true);
		v.query_tooltip.connect(on_view_query_tooltip);
		v.draw.connect(on_view_draw);

		var doc = d_view.document.document;
		doc.mark_set.connect(on_buffer_mark_set);
		doc.cursor_moved.connect(on_cursor_moved);
	}

	public void update(Diagnostic[] diagnostics)
	{
		d_index.clear();

		foreach (var d in diagnostics)
		{
			d_index.add(d);
		}

		update_scrollbar();
		update_marks();
	}

	private void update_scrollbar()
	{
		var sm = d_view.scrollbar_marker;

		if (sm == null)
		{
			return;
		}

		sm.remove(d_last_marker_id);

		var colors = new DiagnosticColors(sm.scrollbar.get_style_context());
		var mixed = new DiagnosticColors(sm.scrollbar.get_style_context());

		mixed.mix_in_widget(d_view.view);

		var it = d_diagnostics_at_end.map_iterator();

		var buf = d_view.view.buffer;

		while (it.next())
		{
			buf.delete_mark(it.get_key());
		}

		d_diagnostics_at_end.clear();

		d_last_marker_id = sm.new_merge_id();

		foreach (var d in d_index)
		{
			Gdk.RGBA color = colors[d.severity];
			Gdk.RGBA mix = mixed[d.severity];

			foreach (SourceRange range in d.ranges)
			{
				sm.add_with_id(d_last_marker_id, range, color);

				if (range.start.line == range.end.line &&
					range.start.column == range.end.column)
				{
					if (diagnostic_is_at_end(range.start))
					{
						add_diagnostic_at_end(range.start, mix);
					}
				}
			}
		}

		update_diagnostic_message();
	}

	private void update_marks()
	{
		Gtk.TextIter start;
		Gtk.TextIter end;

		var buf = d_view.view.buffer;

		buf.get_bounds(out start, out end);

		buf.remove_tag(d_tags.error_tag, start, end);
		buf.remove_tag(d_tags.warning_tag, start, end);
		buf.remove_tag(d_tags.info_tag, start, end);
		buf.remove_tag(d_tags.fixit_tag, start, end);

		remove_marks();

		foreach (var d in d_index)
		{
			mark_diagnostic(d);
		}
	}

	private Diagnostic.Severity[] mark_severities()
	{
		return new Diagnostic.Severity[]{
			Diagnostic.Severity.ERROR,
			Diagnostic.Severity.WARNING,
			Diagnostic.Severity.INFO
		};
	}

	private void register_marks()
	{
		foreach (var sev in mark_severities())
		{
			var attr = new Gtk.SourceMarkAttributes();

			attr.set_gicon(new ThemedIcon.with_default_fallbacks(icon_name_for_severity(sev)));
			attr.query_tooltip_markup.connect(on_diagnostic_tooltip);

			d_view.view.set_mark_attributes(mark_category_for_severity(sev), attr, 0);
		}
	}

	private void unregister_marks()
	{
		foreach (var sev in mark_severities())
		{
			var attr = new Gtk.SourceMarkAttributes();
			d_view.view.set_mark_attributes(mark_category_for_severity(sev), attr, 0);
		}
	}

	public void destroy()
	{
		if (d_view == null)
		{
			return;
		}

		remove_marks();
		unregister_marks();

		var view = d_view.view;
		view.set_show_line_marks(false);
		view.query_tooltip.disconnect(on_view_query_tooltip);
		view.draw.disconnect(on_view_draw);

		var doc = d_view.document.document;
		doc.mark_set.disconnect(on_buffer_mark_set);
		doc.cursor_moved.disconnect(on_cursor_moved);

		d_view = null;
	}

	private void remove_marks()
	{
		if (d_view == null)
		{
			return;
		}

		Gtk.TextIter start;
		Gtk.TextIter end;

		var buf = d_view.document.document;

		buf.get_bounds(out start, out end);
		buf.remove_source_marks(start, end, info_mark_category);

		buf.get_bounds(out start, out end);
		buf.remove_source_marks(start, end, warning_mark_category);

		buf.get_bounds(out start, out end);
		buf.remove_source_marks(start, end, error_mark_category);
	}

	public static string? mark_category_for_severity(Diagnostic.Severity severity)
	{
		switch (severity)
		{
			case Diagnostic.Severity.WARNING:
			case Diagnostic.Severity.DEPRECATED:
				return warning_mark_category;
			case Diagnostic.Severity.ERROR:
			case Diagnostic.Severity.FATAL:
				return error_mark_category;
			case Diagnostic.Severity.INFO:
				return info_mark_category;
			default:
				return null;
		}
	}

	public static string? icon_name_for_severity(Diagnostic.Severity severity)
	{
		switch (severity)
		{
			case Diagnostic.Severity.WARNING:
			case Diagnostic.Severity.DEPRECATED:
				return warning_icon_name;
			case Diagnostic.Severity.ERROR:
			case Diagnostic.Severity.FATAL:
				return error_icon_name;
			case Diagnostic.Severity.INFO:
				return info_icon_name;
			default:
				return null;
		}
	}

	private Diagnostic[] sorted_on_severity(Diagnostic[] diagnostics)
	{
		var lst = new Gee.ArrayList<Diagnostic>.wrap(diagnostics);

		lst.sort((a, b) => {
			if (a.severity == b.severity)
			{
				return 0;
			}

			// Higer priorities last
			return a.severity < b.severity ? -1 : 1;
		});

		return lst.to_array();
	}

	private Diagnostic[] find_at(SourceRange range)
	{
		return sorted_on_severity(d_index.find_at(range));
	}

	private Diagnostic[] find_at_line(int line)
	{
		return sorted_on_severity(d_index.find_at_line(line));
	}

	private void mark_diagnostic_range(Diagnostic   diagnostic,
	                                   Gtk.TextIter start,
	                                   Gtk.TextIter end)
	{
		Gtk.TextTag? tag = d_tags[diagnostic.severity];
		string? category = mark_category_for_severity(diagnostic.severity);

		var doc = d_view.document.document;

		doc.apply_tag(tag, start, end);

		Gtk.TextIter m = start;

		if (!m.starts_line())
		{
			m.set_line_offset(0);
		}

		while (category != null && m.compare(end) <= 0)
		{
			bool alreadyhas = false;

			foreach (var mark in doc.get_source_marks_at_iter(m, category))
			{
				if (mark.get_data<Diagnostic>("Gca.Document.MarkDiagnostic") == diagnostic)
				{
					alreadyhas = true;
					break;
				}
			}

			if (!alreadyhas)
			{
				var mark = doc.create_source_mark(null, category, m);

				mark.set_data("Gca.Document.MarkDiagnostic", diagnostic);
			}

			if (!m.forward_line())
			{
				break;
			}
		}
	}

	private void mark_diagnostic(Diagnostic diagnostic)
	{
		Gtk.TextIter start;
		Gtk.TextIter end;

		var doc = d_view.document.document;

		for (uint i = 0; i < diagnostic.ranges.length; ++i)
		{
			if (!diagnostic.ranges[i].get_iters(doc, out start, out end))
			{
				continue;
			}

			mark_diagnostic_range(diagnostic, start, end);
		}

		for (uint i = 0; i < diagnostic.fixits.length; ++i)
		{
			SourceRange r = diagnostic.fixits[i].range;

			if (r.get_iters(doc, out start, out end))
			{
				doc.apply_tag(d_tags.fixit_tag, start, end);
			}
		}
	}

	private bool diagnostic_is_at_end(SourceLocation location)
	{
		Gtk.TextIter iter;

		d_view.view.buffer.get_iter_at_line(out iter, location.line - 1);
		iter.forward_chars(location.column - 1);

		if (iter.get_line() != location.line - 1)
		{
			return false;
		}

		return iter.ends_line();
	}

	private void add_diagnostic_at_end(SourceLocation location,
	                                   Gdk.RGBA       color)
	{
		Gtk.TextIter iter;

		d_view.view.buffer.get_iter_at_line(out iter, location.line - 1);

		var mark = d_view.view.buffer.create_mark(null, iter, false);
		d_diagnostics_at_end[mark] = color;
	}

	private bool on_view_draw(Cairo.Context ctx)
	{
		if (d_diagnostics_at_end.size == 0)
		{
			return false;
		}

		var view = d_view.view;

		var window = view.get_window(Gtk.TextWindowType.TEXT);

		if (!Gtk.cairo_should_draw_window(ctx, window))
		{
			return false;
		}

		var it = d_diagnostics_at_end.map_iterator();

		Gtk.cairo_transform_to_window(ctx, view, window);
		Gdk.Rectangle rect;
		Gtk.TextIter start;
		Gtk.TextIter end;

		view.get_visible_rect(out rect);
		view.get_line_at_y(out start, rect.y, null);
		start.backward_line();

		view.get_line_at_y(out end, rect.y + rect.height, null);
		end.forward_line();

		int window_width = window.get_width();

		var buf = view.buffer;

		while (it.next())
		{
			Gtk.TextIter iter;

			buf.get_iter_at_mark(out iter, it.get_key());

			if (!iter.in_range(start, end) && !iter.equal(end))
			{
				continue;
			}

			if (!iter.ends_line())
			{
				if (iter.forward_visible_line())
				{
					iter.backward_char();
				}
			}

			int y;
			int height;

			int wy;
			int wx;

			Gdk.Rectangle irect;

			view.get_line_yrange(iter, out y, out height);
			view.get_iter_location(iter, out irect);

			view.buffer_to_window_coords(Gtk.TextWindowType.TEXT,
			                             irect.x + irect.width,
			                             y,
			                             out wx,
			                             out wy);

			ctx.rectangle(wx,
			              wy,
			              window_width - wx,
			              height);

			Gdk.cairo_set_source_rgba(ctx, it.get_value());
			ctx.fill();
		}

		return false;
	}

	private void on_buffer_mark_set(Gtk.TextIter location, Gtk.TextMark mark)
	{
		if (d_diagnostics_at_end.has_key(mark) && !location.starts_line())
		{
			location.set_line_offset(0);
			d_view.view.buffer.move_mark(mark, location);
		}
	}

	private bool same_diagnostics(Diagnostic[]? first, Diagnostic[]? second)
	{
		if (first == second)
		{
			return true;
		}

		if (first == null || second == null)
		{
			return false;
		}

		if (first.length != second.length)
		{
			return false;
		}

		for (int i = 0; i < first.length; ++i)
		{
			if (first[i] != second[i])
			{
				return false;
			}
		}

		return true;
	}

	private void update_diagnostic_message()
	{
		Gtk.TextIter iter;

		var buf = d_view.view.buffer;

		buf.get_iter_at_mark(out iter, buf.get_insert());

		var range = SourceRange.from_iter(iter);
		var diagnostics = find_at(range);

		if (same_diagnostics(diagnostics, d_cursor_diagnostics))
		{
			return;
		}

		if (d_cursor_diagnostic_message != null)
		{
			d_cursor_diagnostic_message.destroy();
		}

		d_cursor_diagnostic_message = new DiagnosticMessage(d_view.view, diagnostics);

		d_cursor_diagnostic_message.destroy.connect(() => {
			d_cursor_diagnostic_message = null;
		});

		d_cursor_diagnostic_message.show();
		d_cursor_diagnostics = diagnostics;
	}

	private void on_cursor_moved()
	{
		update_diagnostic_message();
	}

	// Tooltips
	private string? format_diagnostics(Diagnostic[] diagnostics)
	{
		if (diagnostics.length == 0)
		{
			return null;
		}

		string[] markup = new string[diagnostics.length];

		for (int i = 0; i < diagnostics.length; ++i)
		{
			markup[i] = diagnostics[i].to_markup(false);
		}

		return string.joinv("\n", markup);
	}

	private string on_diagnostic_tooltip(Gtk.SourceMark mark)
	{
		Gtk.TextIter iter;

		Diagnostic? diagnostic = mark.get_data("Gca.Document.MarkDiagnostic");

		if (diagnostic == null)
		{
			d_view.document.document.get_iter_at_mark(out iter, mark);
			int line = iter.get_line() + 1;

			return format_diagnostics(find_at_line(line));
		}
		else
		{
			return diagnostic.to_markup(false);
		}
	}

	private bool on_view_query_tooltip(int         x,
	                                   int         y,
	                                   bool        keyboard_mode,
	                                   Gtk.Tooltip tooltip)
	{
		int bx;
		int by;

		d_view.view.window_to_buffer_coords(Gtk.TextWindowType.WIDGET,
		                                    x,
		                                    y,
		                                    out bx,
		                                    out by);

		Gtk.TextIter iter;
	
		d_view.view.get_iter_at_location(out iter, bx, by);

		var range = SourceRange.from_iter(iter);

		string? s = format_diagnostics(find_at(range));

		if (s == null)
		{
			return false;
		}

		tooltip.set_markup(s);
		return true;
	}
}

}

/* vi:ex:ts=4 */
