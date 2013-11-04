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

class View : Object
{
	private unowned Gedit.View d_view;

	private Gedit.Document d_buffer;
	private Backend d_backend;
	private Document d_document;
	private DiagnosticTags d_tags;
	private ScrollbarMarker d_scrollbarMarker;
	private HashMap<TextMark, Gdk.RGBA?> d_diagnosticsAtEnd;
	private Diagnostic[] d_cursorDiagnostics;
	private DiagnosticMessage? d_cursorDiagnosticMessage;
	private SemanticValue? d_semanticValue;
	private TextTag? d_semanticTag;
	private uint d_lastMergeId;
	private Gdk.RGBA d_refColor;

	private static unowned BindingSet s_bindingSet;

	static construct
	{
		s_bindingSet = Gtk.BindingSet.find("GcaViewBindings");
	}

	public View(Gedit.View view)
	{
		d_view = view;

		d_view.notify["buffer"].connect(on_notify_buffer);
		d_view.draw.connect_after(on_view_draw);
		d_view.key_press_event.connect(on_view_key_press);

		d_tags = new DiagnosticTags(d_view);
		d_diagnosticsAtEnd = new HashMap<TextMark, Gdk.RGBA?>();

		connect_buffer(d_view.buffer as Gedit.Document);

		ScrolledWindow? sw = d_view.parent as ScrolledWindow;

		if (sw != null)
		{
			d_scrollbarMarker = new ScrollbarMarker(sw.get_vscrollbar() as Scrollbar);
		}
	}

	private void scroll_in_view(TextIter iter)
	{
		Gdk.Rectangle vrect;
		Gdk.Rectangle irect;

		d_view.get_visible_rect(out vrect);
		d_view.get_iter_location(iter, out irect);

		if (irect.y < vrect.y || irect.y + irect.height > vrect.y + vrect.height)
		{
			d_view.scroll_to_iter(iter, 0, true, 0, 0.5);
		}
	}

	private void move_cursor_to_semantic_value(SemanticValue? val)
	{
		if (val == null)
		{
			return;
		}

		TextIter start;
		TextIter end;

		SourceRange range = highlight_range(val);

		if (!range.start.get_iter(d_buffer, out start))
		{
			return;
		}

		if (!range.end.get_iter(d_buffer, out end))
		{
			return;
		}

		d_buffer.select_range(start, end);
		scroll_in_view(start);
	}

	[Signal(action = true)]
	public virtual signal bool find_definition()
	{
		SemanticValue? v = semantic_value_at_cursor();

		if (v == null)
		{
			return false;
		}

		if ((v.reference_type & SemanticValue.ReferenceType.DEFINITION) != 0)
		{
			return true;
		}

		move_cursor_to_semantic_value(v.definition);
		return true;
	}

	[Signal(action = true)]
	public virtual signal bool find_reference(int direction)
	{
		SemanticValueSupport? sem = d_document as SemanticValueSupport;

		if (sem == null)
		{
			return false;
		}

		SemanticValue? v;
		int vidx;

		SemanticValue[] refs = references_at_cursor(out v, out vidx);

		if (v == null || refs.length <= 1)
		{
			return true;
		}

		vidx = (vidx + direction) % refs.length;

		if (vidx < 0)
		{
			vidx = refs.length + vidx;
		}

		move_cursor_to_semantic_value(refs[vidx]);
		return true;
	}

	public void deactivate()
	{
		d_view.notify["buffer"].disconnect(on_notify_buffer);
		d_view.draw.disconnect(on_view_draw);
		d_view.key_press_event.disconnect(on_view_key_press);

		disconnect_buffer();

		d_view = null;
	}

	private void disconnect_buffer()
	{
		if (d_buffer == null)
		{
			return;
		}

		d_buffer.notify["language"].disconnect(on_notify_language);
		d_buffer.changed.disconnect(on_buffer_changed);
		d_buffer.mark_set.disconnect(on_buffer_mark_set);
		d_buffer.notify["style-scheme"].disconnect(on_notify_style_scheme);

		if (d_semanticTag != null)
		{
			remove_references();
			d_buffer.tag_table.remove(d_semanticTag);
			d_semanticValue = null;
		}

		unregister_backend();
		d_buffer = null;
	}

	private void update_semantic_tag()
	{
		remove_references();

		d_semanticValue = null;

		if (d_semanticTag != null)
		{
			d_buffer.tag_table.remove(d_semanticTag);
		}

		Gtk.SourceStyle? style = null;
		if (d_buffer.style_scheme != null)
		{
			style = d_buffer.style_scheme.get_style("search-match");
		}

		Gdk.Color bg = {0, 0, 0, 0};
		Gdk.Color fg = {0, 0, 0, 0};

		if (style == null)
		{
			Gdk.Color.parse("#fff600", out bg);
			Gdk.Color.parse("#333", out fg);
		}
		else
		{
			StyleContext ctx;

			ctx = d_view.get_style_context();

			ctx.save();
			ctx.add_class(STYLE_CLASS_VIEW);

			var fgcol = ctx.get_color(StateFlags.NORMAL);
			var bgcol = ctx.get_background_color(StateFlags.NORMAL);

			bg.red = (ushort)(bgcol.red * 65535);
			bg.green = (ushort)(bgcol.green * 65535);
			bg.blue = (ushort)(bgcol.blue * 65535);

			fg.red = (ushort)(fgcol.red * 65535);
			fg.green = (ushort)(fgcol.green * 65535);
			fg.blue = (ushort)(fgcol.blue * 65535);

			ctx.restore();

			if (style.background_set)
			{
				Gdk.Color.parse(style.background, out bg);
			}

			if (style.foreground_set)
			{
				Gdk.Color.parse(style.foreground, out fg);
			}
		}

		d_refColor = {bg.red / 65535.0, bg.green / 65535.0, bg.blue / 65535.0, 1};

		d_semanticTag = d_buffer.create_tag("Gca.View.Semantic",
		                                    background_gdk: bg,
		                                    foreground_gdk: fg,
		                                    background_full_height: true);

		update_references();
	}

	private void connect_buffer(Gedit.Document buffer)
	{
		d_buffer = buffer;

		if (d_buffer == null)
		{
			return;
		}

		d_buffer.notify["language"].connect(on_notify_language);
		d_buffer.changed.connect(on_buffer_changed);
		d_buffer.mark_set.connect(on_buffer_mark_set);
		d_buffer.notify["style-scheme"].connect(on_notify_style_scheme);

		update_semantic_tag();
		update_backend();
	}

	private void on_notify_style_scheme()
	{
		update_semantic_tag();
		update_diagnostic_message();
	}

	private void on_buffer_changed()
	{
		d_scrollbarMarker.max_line = d_buffer.get_line_count();
	}

	private void update_backend()
	{
		unregister_backend();

		/* Update the backend according to the current language on the buffer */
		if (d_buffer != null && d_buffer.language != null)
		{
			var manager = BackendManager.instance;

			manager.backend.begin(d_buffer.language.id, (obj, res) => {
				var backend = manager.backend.end(res);
				register_backend(backend);
			});
		}
	}

	private void unregister_backend()
	{
		if (d_backend == null)
		{
			return;
		}

		if (d_document != null)
		{
			if (d_document is DiagnosticSupport)
			{
				d_view.query_tooltip.disconnect(on_view_query_tooltip);
				d_view.set_show_line_marks(false);

				d_buffer.cursor_moved.disconnect(on_cursor_diagnostics_moved);
			}

			if (d_document is SemanticValueSupport)
			{
				d_buffer.cursor_moved.disconnect(on_cursor_semantics_moved);
			}

			d_backend.unregister_document(d_document);
		}

		d_backend = null;
		d_document = null;
	}

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

	// CHECK: allow NULL
	private string on_diagnostic_tooltip(SourceMark mark)
	{
		TextIter iter;

		Diagnostic? diagnostic = mark.get_data("Gca.Document.MarkDiagnostic");

		if (diagnostic == null)
		{
			d_view.buffer.get_iter_at_mark(out iter, mark);
			int line = iter.get_line() + 1;

			DiagnosticSupport diag = d_document as DiagnosticSupport;

			return format_diagnostics(diag.find_at_line(line));
		}
		else
		{
			return diagnostic.to_markup(false);
		}
	}

	private bool on_view_query_tooltip(int x,
	                                   int y,
	                                   bool keyboard_mode,
	                                   Tooltip tooltip)
	{
		int bx;
		int by;

		d_view.window_to_buffer_coords(Gtk.TextWindowType.WIDGET,
		                               x,
		                               y,
		                               out bx,
		                               out by);

		TextIter iter;
	
		d_view.get_iter_at_location(out iter, bx, by);

		SourceLocation location = new SourceLocation.iter(iter);
		DiagnosticSupport diag = d_document as DiagnosticSupport;

		string? s = format_diagnostics(diag.find_at(location));

		if (s == null)
		{
			return false;
		}

		tooltip.set_markup(s);
		return true;
	}

	private void register_backend(Backend? backend)
	{
		d_backend = backend;

		if (backend == null)
		{
			return;
		}

		if (d_view.buffer != null)
		{
			d_document = d_backend.register_document(d_view.buffer as Gedit.Document);

			var diag = d_document.services.diagnostics;

			if (diag != null)
			{
				SourceMarkAttributes attr;

				diag.diagnostic_tags = d_tags;
				diag.diagnostics_updated.connect(on_diagnostic_updated);

				// Error
				attr = new SourceMarkAttributes();
				attr.set_gicon(new ThemedIcon.with_default_fallbacks("dialog-error-symbolic"));
				attr.query_tooltip_markup.connect(on_diagnostic_tooltip);
				d_view.set_mark_attributes(Document.error_mark_category,
				                           attr,
				                           0);

				// Warning
				attr = new SourceMarkAttributes();
				attr.set_gicon(new ThemedIcon.with_default_fallbacks("dialog-warning-symbolic"));
				attr.query_tooltip_markup.connect(on_diagnostic_tooltip);
				d_view.set_mark_attributes(Document.warning_mark_category,
				                           attr,
				                           0);

				// Info
				attr = new SourceMarkAttributes();
				attr.set_gicon(new ThemedIcon.with_default_fallbacks("dialog-information-symbolic"));
				attr.query_tooltip_markup.connect(on_diagnostic_tooltip);
				d_view.set_mark_attributes(Document.info_mark_category,
				                           attr,
				                           0);

				d_view.query_tooltip.connect(on_view_query_tooltip);

				d_view.set_show_line_marks(true);

				d_buffer.cursor_moved.connect(on_cursor_diagnostics_moved);
			}

			var sem = d_document.services.semantic_value;

			if (sem != null)
			{
				sem.semantic_values_updated.connect(on_semantics_updated);
				d_buffer.cursor_moved.connect(on_cursor_semantics_moved);
			}
		}
		else
		{
			d_document = null;
		}
	}

	private bool diagnostic_is_at_end(SourceLocation location)
	{
		TextIter iter;

		d_buffer.get_iter_at_line(out iter, location.line - 1);
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
		TextIter iter;

		d_buffer.get_iter_at_line(out iter, location.line - 1);

		TextMark mark = d_buffer.create_mark(null, iter, false);
		d_diagnosticsAtEnd[mark] = color;
	}

	private void on_semantics_updated(SemanticValueSupport semantics)
	{
		Timer timer = new Timer();
		double elapsed = 0;

		timer.start();

		update_references();

		elapsed = timer.elapsed();

		Log.debug("Semantics update in: %f seconds...", elapsed);
	}

	private void on_diagnostic_updated(DiagnosticSupport diagnostics)
	{
		Timer timer = new Timer();
		double elapsed = 0;

		timer.start();

		d_scrollbarMarker.clear();

		DiagnosticColors colors;

		colors = new DiagnosticColors(d_scrollbarMarker.scrollbar.get_style_context());

		DiagnosticColors mixed;

		mixed = new DiagnosticColors(d_scrollbarMarker.scrollbar.get_style_context());
		mixed.mix_in_widget(d_view);

		MapIterator<TextMark, Gdk.RGBA?> it = d_diagnosticsAtEnd.map_iterator();

		while (it.next())
		{
			d_buffer.delete_mark(it.get_key());
		}

		d_diagnosticsAtEnd.clear();

		uint mid = d_scrollbarMarker.new_merge_id();

		foreach (var obj in diagnostics.diagnostics)
		{
			Diagnostic d = (Diagnostic)obj;

			Gdk.RGBA color = colors[d.severity];
			Gdk.RGBA mix = mixed[d.severity];

			foreach (SourceRange range in d.ranges)
			{
				d_scrollbarMarker.add_with_id(mid, range, color);

				if (range.start.line == range.end.line &&
					range.start.column == range.end.column)
				{
					if (diagnostic_is_at_end(range.start))
					{
						add_diagnostic_at_end(range.start, mix);
					}
				}
			}

			d_scrollbarMarker.add_with_id(mid, d.location.range, color);

			if (diagnostic_is_at_end(d.location))
			{
				add_diagnostic_at_end(d.location, mix);
			}
		}

		update_diagnostic_message();
		elapsed = timer.elapsed();

		Log.debug("Diagnostics update in: %f seconds...", elapsed);
	}

	private void on_notify_buffer()
	{
		disconnect_buffer();
		connect_buffer(d_view.buffer as Gedit.Document);
	}

	private void on_notify_language()
	{
		update_backend();
	}

	private bool on_view_draw(Cairo.Context ctx)
	{
		if (d_diagnosticsAtEnd.size == 0)
		{
			return false;
		}

		var window = d_view.get_window(Gtk.TextWindowType.TEXT);

		if (!Gtk.cairo_should_draw_window(ctx, window))
		{
			return false;
		}

		MapIterator<TextMark, Gdk.RGBA?> it = d_diagnosticsAtEnd.map_iterator();

		Gtk.cairo_transform_to_window(ctx, d_view, window);
		Gdk.Rectangle rect;
		TextIter start;
		TextIter end;

		d_view.get_visible_rect(out rect);
		d_view.get_line_at_y(out start, rect.y, null);
		start.backward_line();

		d_view.get_line_at_y(out end, rect.y + rect.height, null);
		end.forward_line();

		int window_width = window.get_width();

		while (it.next())
		{
			TextIter iter;

			d_view.buffer.get_iter_at_mark(out iter, it.get_key());

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

			d_view.get_line_yrange(iter, out y, out height);
			d_view.get_iter_location(iter, out irect);

			d_view.buffer_to_window_coords(Gtk.TextWindowType.TEXT,
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

	private void on_buffer_mark_set(TextIter location, TextMark mark)
	{
		if (d_diagnosticsAtEnd.has_key(mark) && !location.starts_line())
		{
			location.set_line_offset(0);
			d_buffer.move_mark(mark, location);
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
		// Check if we moved in or out of a diagnostic
		var diag = d_document.services.diagnostics;

		if (diag == null)
		{
			return;
		}

		TextIter iter;

		d_buffer.get_iter_at_mark(out iter, d_buffer.get_insert());

		SourceLocation location = new SourceLocation.iter(iter);
		Diagnostic[] diagnostics = diag.find_at(location);

		if (same_diagnostics(diagnostics, d_cursorDiagnostics))
		{
			return;
		}

		if (d_cursorDiagnosticMessage != null)
		{
			d_cursorDiagnosticMessage.destroy();
		}

		d_cursorDiagnosticMessage = new DiagnosticMessage(d_view, diagnostics);

		d_cursorDiagnosticMessage.destroy.connect(() => {
			d_cursorDiagnosticMessage = null;
		});

		d_cursorDiagnosticMessage.show();
		d_cursorDiagnostics = diagnostics;
	}

	private SourceRange highlight_range(SemanticValue? val)
	{
		SourceRange range = val.range;

		if (val.kind == SemanticValue.Kind.FUNCTION &&
		    (val.reference_type & SemanticValue.ReferenceType.DEFINITION) != 0)
		{
			// We special case this because we really don't want to highlight
			// the whole function definition

			SemanticValue? par = val.find_child(SemanticValue.Kind.PARAMETER);

			if (par != null)
			{
				SourceLocation paramstart = par.range.start.copy();

				paramstart = new SourceLocation(paramstart.file,
				                                paramstart.line,
				                                paramstart.column - 1);

				range = new SourceRange(val.range.start.copy(), paramstart);
			}
		}

		return range;
	}

	private void mark_reference(SemanticValue val)
	{
		TextIter start;
		TextIter end;

		SourceRange range = highlight_range(val);

		if (d_document.source_range(range, out start, out end))
		{
			d_buffer.apply_tag(d_semanticTag, start, end);
		}

		d_scrollbarMarker.add_with_id(d_lastMergeId, range, d_refColor);
	}

	private void mark_references(SemanticValue[] refs)
	{
		if (refs.length <= 1)
		{
			return;
		}

		d_lastMergeId = d_scrollbarMarker.new_merge_id();

		foreach (SemanticValue r in refs)
		{
			mark_reference(r);
		}
	}

	private void remove_references()
	{
		TextIter start;
		TextIter end;

		if (d_lastMergeId != 0)
		{
			d_scrollbarMarker.remove(d_lastMergeId);
			d_lastMergeId = 0;
		}

		if (d_semanticTag == null)
		{
			return;
		}

		d_buffer.get_bounds(out start, out end);
		d_buffer.remove_tag(d_semanticTag, start, end);
	}

	private SemanticValue? semantic_value_at_cursor()
	{
		var sem = d_document.services.semantic_value;

		if (sem == null)
		{
			return null;
		}

		TextIter iter;
		d_buffer.get_iter_at_mark(out iter, d_buffer.get_insert());

		SourceLocation loc = new SourceLocation.iter(iter);
		SemanticValue? ret = null;

		sem.with_semantics((semantics) => {
			ret = (SemanticValue)semantics.find_inner_at(loc);
		});

		return ret;
	}

	private SemanticValue[] references_at_cursor(out SemanticValue? val, out int vidx)
	{
		vidx = -1;

		val = semantic_value_at_cursor();

		if (val == null)
		{
			return new SemanticValue[] {};
		}

		LinkedList<SemanticValue> refs = new LinkedList<SemanticValue>();

		for (int i = 0; i < val.num_references; ++i)
		{
			SemanticValue r = val.reference(i);
			File f = r.range.start.file;

			if (f != null && f.equal(d_document.location))
			{
				refs.add(r);
			}
		}

		refs.add(val);
		refs.sort((CompareFunc)compare_ranges);

		SemanticValue[] ret = refs.to_array();

		for (int i = 0; i < ret.length; ++i)
		{
			if (ret[i] == val)
			{
				vidx = i;
				break;
			}
		}

		return ret;
	}

	private static int compare_ranges(SemanticValue a, SemanticValue b)
	{
		return a.range.compare_to(b.range);
	}

	private void update_references()
	{
		var sem = d_document.services.semantic_value;

		if (sem == null)
		{
			return;
		}

		SemanticValue? v;
		int vidx;
		SemanticValue[] refs = references_at_cursor(out v, out vidx);

		if (v == d_semanticValue)
		{
			return;
		}

		if (d_semanticValue != null)
		{
			remove_references();
		}

		d_semanticValue = v;

		if (d_semanticValue != null)
		{
			mark_references(refs);
		}
	}

	private void on_cursor_diagnostics_moved()
	{
		update_diagnostic_message();
	}

	private void on_cursor_semantics_moved()
	{
		update_references();
	}

	private bool on_view_key_press(Gdk.EventKey event)
	{
		if (s_bindingSet == null)
		{
			return false;
		}

		return s_bindingSet.activate(event.keyval, event.state, this);
	}
}

}

/* vi:ex:ts=4 */
