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

class DiagnosticTags : Object
{
	private unowned TextView d_view;
	private unowned TextBuffer? d_buffer;

	private TextTag? d_infoTag;
	private TextTag? d_warningTag;
	private TextTag? d_errorTag;
	private TextTag? d_fixitTag;

	public DiagnosticTags(TextView view)
	{
		d_view = view;

		d_view.style_updated.connect(on_style_updated);
		d_view.notify["buffer"].connect(on_buffer_changed);

		d_buffer = view.buffer;

		update_tags();
	}

	~DiagnosticTags()
	{
		remove_tags();

		d_view.style_updated.disconnect(on_style_updated);
	}

	private TextTag ensure_tag(ref TextTag? tag, string name)
	{
		if (tag == null)
		{
			tag = d_buffer.create_tag(name);
		}

		return tag;
	}

	private void update_tag(ref TextTag? tag,
	                        string name,
	                        Gdk.RGBA col)
	{
		ensure_tag(ref tag, name);

		tag.background_rgba = col;
		tag.background_full_height = true;
	}

	private void update_tags()
	{
		DiagnosticColors colors;

		colors = new DiagnosticColors(d_view.get_style_context());
		colors.mix_in_widget(d_view);

		update_tag(ref d_infoTag,
		           "Gca.Info",
		           colors.info_color);

		update_tag(ref d_warningTag,
		           "Gca.Warning",
		           colors.warning_color);

		update_tag(ref d_errorTag,
		           "Gca.Error",
		           colors.error_color);

		ensure_tag(ref d_fixitTag, "Gca.Fixit");
		d_fixitTag.strikethrough = true;
	}

	public TextTag? error_tag
	{
		get { return d_errorTag; }
	}

	public TextTag? warning_tag
	{
		get { return d_warningTag; }
	}

	public TextTag? info_tag
	{
		get { return d_infoTag; }
	}

	public TextTag? fixit_tag
	{
		get { return d_fixitTag; }
	}

	public new TextTag? get(Diagnostic.Severity severity)
	{
		switch (severity)
		{
			case Diagnostic.Severity.INFO:
				return d_infoTag;
			case Diagnostic.Severity.WARNING:
				return d_warningTag;
			case Diagnostic.Severity.ERROR:
			case Diagnostic.Severity.FATAL:
				return d_errorTag;
			default:
				return null;
		}
	}

	private void remove_tag(ref TextTag? tag)
	{
		if (d_buffer != null && tag != null)
		{
			d_buffer.tag_table.remove(tag);
			tag = null;
		}
	}

	private void remove_tags()
	{
		remove_tag(ref d_errorTag);
		remove_tag(ref d_warningTag);
		remove_tag(ref d_infoTag);
		remove_tag(ref d_fixitTag);
	}

	private void on_buffer_changed()
	{
		remove_tags();

		d_buffer = d_view.buffer;

		d_errorTag = null;
		d_warningTag = null;
		d_infoTag = null;

		update_tags();
	}

	private void on_style_updated()
	{
		update_tags();
	}
}

}

/* vi:ex:ts=4 */
