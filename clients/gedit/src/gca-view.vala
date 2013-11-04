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

/**
 * Wrapper around Gedit.View.
 *
 * View is a wrapper around Gedit.View. It keeps track of changes to the document
 * of the gedit view and of the language of the document and registers itself
 * with the appropriate assistance backend.
 */
class View : Object
{
	private unowned Gedit.View d_view;
	private Document d_document;
	private Backend d_backend;
	private ScrollbarMarker? d_scrollbar_marker;
	private uint d_timeout;

	private RemoteService[] d_services;

	public signal void changed();

	public View(Gedit.View view)
	{
		d_view = view;

		d_view.notify["buffer"].connect(on_notify_buffer);

		connect_document(d_view.buffer as Gedit.Document);

		ScrolledWindow? sw = d_view.parent as ScrolledWindow;

		if (sw != null)
		{
			d_scrollbar_marker = new ScrollbarMarker(sw.get_vscrollbar() as Scrollbar);
		}

		d_services = new RemoteService[] {
			new DiagnosticService()
		};
	}

	public unowned Gedit.View view
	{
		get { return d_view; }
	}

	public Document document
	{
		get { return d_document; }
	}

	public ScrollbarMarker? scrollbar_marker
	{
		get { return d_scrollbar_marker; }
	}

	public void deactivate()
	{
		d_view.notify["buffer"].disconnect(on_notify_buffer);

		disconnect_document();

		d_view = null;
	}

	public void update(RemoteDocument doc)
	{
		foreach (var service in d_services)
		{
			if (d_backend.supports(service.services()))
			{
				service.update(this, doc);
			}
		}
	}

	private void disconnect_document()
	{
		if (d_document == null)
		{
			return;
		}

		var buf = d_document.document;

		buf.notify["language"].disconnect(on_notify_language);
		d_document.changed.disconnect(on_document_changed);

		unregister_backend();

		d_document = null;
	}

	private void connect_document(Gedit.Document? document)
	{
		disconnect_document();

		if (document == null)
		{
			return;
		}

		d_document = new Document(document);

		var buf = d_document.document;

		buf.notify["language"].connect(on_notify_language);

		d_document.changed.connect(on_document_changed);
		update_backend();
	}

	private void on_document_changed()
	{
		d_scrollbar_marker.max_line = d_document.document.get_line_count();

		if (d_timeout != 0)
		{
			Source.remove(d_timeout);
		}

		d_timeout = Timeout.add(200, () => {
			d_timeout = 0;
			changed();
			return false;
		});
	}

	private void update_backend()
	{
		unregister_backend();

		/* Update the backend according to the current language on the buffer */
		if (d_document != null && d_document.document.language != null)
		{
			var manager = BackendManager.instance;

			manager.backend.begin(d_document.document.language.id, (obj, res) => {
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

		foreach (var service in d_services)
		{
			service.destroy();
		}

		d_backend.unregister(this);
		d_backend = null;
	}

	private void register_backend(Backend? backend)
	{
		d_backend = backend;

		if (backend == null)
		{
			return;
		}

		backend.register(this);
		on_document_changed();
	}

	private void on_notify_buffer()
	{
		disconnect_document();
		connect_document(d_view.buffer as Gedit.Document);
	}

	private void on_notify_language()
	{
		update_backend();
	}
}

}

/* vi:ex:ts=4 */
