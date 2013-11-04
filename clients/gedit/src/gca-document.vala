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
	private DocumentServices d_services;

	private bool d_untitled;
	private bool d_modified;
	private string? d_text;
	private File? d_location;
	private bool d_tainted;
	private bool d_dispose_ran;

	public signal void location_changed(File? previous_location);
	public signal void changed();

	public Gedit.Document document
	{
		get { return d_document; }
	}

	public DocumentServices services
	{
		get { return d_services; }
	}

	public static string error_mark_category
	{
		get { return "Gca.Document.ErrorCategory"; }
	}

	public static string warning_mark_category
	{
		get { return "Gca.Document.WarningCategory"; }
	}

	public static string info_mark_category
	{
		get { return "Gca.Document.InfoCategory"; }
	}

	public Document(Gedit.Document document, DocumentServices services)
	{
		d_document = document;
		d_services = services;

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

		if (d_services.diagnostics != null)
		{
			d_services.diagnostics.diagnostics_updated.connect(on_diagnostic_updated);
		}
	}

	private void remove_marks()
	{
		TextIter start;
		TextIter end;

		d_document.get_bounds(out start, out end);
		d_document.remove_source_marks(start, end, info_mark_category);

		d_document.get_bounds(out start, out end);
		d_document.remove_source_marks(start, end, warning_mark_category);

		d_document.get_bounds(out start, out end);
		d_document.remove_source_marks(start, end, error_mark_category);
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

			if (d_services.diagnostics != null)
			{
				d_services.diagnostics.diagnostics_updated.disconnect(on_diagnostic_updated);
				remove_marks();
			}
		}

		base.dispose();
	}

	private bool source_location(SourceLocation location, out TextIter iter)
	{
		return location.get_iter(d_document, out iter);
	}

	public bool source_range(SourceRange range, out TextIter start, out TextIter end)
	{
		return range.get_iters(d_document, out start, out end);
	}

	public static string? mark_category_for_severity(Diagnostic.Severity severity)
	{
		switch (severity)
		{
			case Diagnostic.Severity.WARNING:
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

	private void mark_diagnostic_range(Diagnostic diagnostic,
	                                   TextIter   start,
	                                   TextIter   end)
	{
		DiagnosticSupport sup = d_services.diagnostics;

		TextTag? tag = sup.diagnostic_tags[diagnostic.severity];
		string? category = mark_category_for_severity(diagnostic.severity);

		d_document.apply_tag(tag, start, end);

		TextIter m = start;

		if (!m.starts_line())
		{
			m.set_line_offset(0);
		}

		while (category != null && m.compare(end) <= 0)
		{
			bool alreadyhas = false;

			foreach (var mark in d_document.get_source_marks_at_iter(m, category))
			{
				if (mark.get_data<Diagnostic>("Gca.Document.MarkDiagnostic") == diagnostic)
				{
					alreadyhas = true;
					break;
				}
			}

			if (!alreadyhas)
			{
				var mark = d_document.create_source_mark(null, category, m);

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
		TextIter start;
		TextIter end;

		DiagnosticSupport sup = d_services.diagnostics;

		for (uint i = 0; i < diagnostic.ranges.length; ++i)
		{
			if (!source_range(diagnostic.ranges[i], out start, out end))
			{
				continue;
			}

			mark_diagnostic_range(diagnostic, start, end);
		}

		if (source_location(diagnostic.location, out start))
		{
			end = start;

			if (!start.ends_line())
			{
				end.forward_char();
			}

			mark_diagnostic_range(diagnostic, start, end);

			d_document.apply_tag(sup.diagnostic_tags.location_tag, start, end);
		}

		for (uint i = 0; i < diagnostic.fixits.length; ++i)
		{
			SourceRange r = diagnostic.fixits[i].range;

			if (source_range(r, out start, out end))
			{
				d_document.apply_tag(sup.diagnostic_tags.fixit_tag, start, end);
			}
		}
	}

	private void on_diagnostic_updated(DiagnosticSupport diagnostic)
	{
		TextIter start;
		TextIter end;

		d_document.get_bounds(out start, out end);

		var tags = diagnostic.diagnostic_tags;

		d_document.remove_tag(tags.error_tag, start, end);
		d_document.remove_tag(tags.warning_tag, start, end);
		d_document.remove_tag(tags.info_tag, start, end);
		d_document.remove_tag(tags.location_tag, start, end);
		d_document.remove_tag(tags.fixit_tag, start, end);

		remove_marks();

		foreach (var diag in diagnostic.diagnostics)
		{
			mark_diagnostic((Diagnostic)diag);
		}
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

	public virtual bool tainted
	{
		get
		{
			return d_tainted;
		}
		set
		{
			d_tainted = false;
		}
	}

	protected void emit_changed()
	{
		d_tainted = true;

		changed();
	}

	private void update_text()
	{
		TextIter start;
		TextIter end;

		d_document.get_bounds(out start, out end);
		d_text = d_document.get_text(start, end, true);

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
