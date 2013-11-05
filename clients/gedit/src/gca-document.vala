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

public class Document : Object
{
	private Gedit.Document d_document;

	private bool d_untitled;
	private bool d_modified;
	private string? d_text;
	private File? d_location;
	private bool d_dispose_ran;

	private File? d_unsaved_file;

	public signal void location_changed(File? previous_location);
	public signal void changed();

	public Gedit.Document document
	{
		get { return d_document; }
	}

	public Document(Gedit.Document document)
	{
		d_document = document;

		d_untitled = d_document.is_untitled();
		d_modified = false;
		d_text = null;

		update_modified();

		d_document.modified_changed.connect(on_document_modified_changed);
		d_document.end_user_action.connect(on_document_end_user_action);
		d_document.notify["location"].connect(on_location_changed);
		d_document.saved.connect(on_document_saved);

		d_location = null;

		update_location();
	}

	public override void dispose()
	{
		if (!d_dispose_ran)
		{
			d_dispose_ran = true;

			d_document.modified_changed.disconnect(on_document_modified_changed);
			d_document.notify["location"].disconnect(on_location_changed);

			d_document.end_user_action.disconnect(on_document_end_user_action);
			d_document.saved.disconnect(on_document_saved);

			clear_unsaved_file();
		}

		base.dispose();
	}

	private void set_location(File? location)
	{
		if (location == d_location)
		{
			return;
		}

		File? prev = d_location;
		d_location = location;

		if ((prev == null) != (d_location == null))
		{
			location_changed(prev);
		}
		else if (prev != null && !prev.equal(d_location))
		{
			location_changed(prev);
		}
	}

	private void update_location()
	{
		if (document.is_untitled())
		{
			set_location(null);
			return;
		}

		if (!document.is_local())
		{
			set_location(null);
			return;
		}

		set_location(document.location);
	}

	private void update_modified()
	{
		if (d_modified == d_document.get_modified())
		{
			return;
		}

		d_text = null;
		d_modified = !d_modified;

		if (d_modified)
		{
			update_text();
		}
		else
		{
			emit_changed();
		}
	}

	protected void emit_changed()
	{
		changed();
	}

	private void clear_unsaved_file()
	{
		if (d_unsaved_file != null)
		{
			try
			{
				d_unsaved_file.delete();
			} catch {}

			d_unsaved_file = null;
		}
	}

	private void update_text()
	{
		TextIter start;
		TextIter end;

		d_document.get_bounds(out start, out end);
		d_text = d_document.get_text(start, end, true);

		clear_unsaved_file();

		emit_changed();
	}

	public File? location
	{
		get { return d_location; }
	}

	public unowned string text
	{
		get { return d_text; }
	}

	public bool is_modified
	{
		get { return d_modified; }
	}

	public int64 cursor
	{
		get
		{
			var mark = d_document.get_insert();
			Gtk.TextIter iter;

			d_document.get_iter_at_mark(out iter, mark);

			return iter.get_offset();
		}
	}

	public string path
	{
		owned get
		{
			if (d_location == null)
			{
				return d_document.shortname;
			}
			else
			{
				return d_location.get_path();
			}
		}
	}

	public async string? unsaved_data_path() throws IOError, Error
	{
		if (!d_modified)
		{
			return null;
		}

		if (d_unsaved_file != null)
		{
			return d_unsaved_file.get_path();
		}

		var orig = path;
		var idx = orig.last_index_of(".");
		string filename;

		if (idx != -1)
		{
			filename = "gca-unsaved-XXXXXX.%s".printf(orig[idx+1:orig.length]);
		}
		else
		{
			filename = "gca-unsaved-XXXXXX";
		}

		FileIOStream stream;
		File f;

		f = File.new_tmp(filename, out stream);
		var ostream = stream.output_stream;

		try
		{
			yield ostream.write_async(d_text.data);
		}
		catch (IOError e)
		{
			try
			{
				f.delete();
			} catch {}

			try
			{
				ostream.close();
			} catch {}

			throw e;
		}

		ostream.close();
		d_unsaved_file = f;

		return d_unsaved_file.get_path();
	}

	private void on_document_end_user_action()
	{
		if (d_modified)
		{
			update_text();
		}
	}

	private void on_document_modified_changed()
	{
		update_modified();
	}

	private void on_location_changed()
	{
		update_location();
	}

	private void on_document_saved()
	{
		emit_changed();
	}
}

}

/* vi:ex:ts=4 */
