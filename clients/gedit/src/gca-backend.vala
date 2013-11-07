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

class Backend : Object
{
	private Gee.ArrayList<View> d_views;
	private string d_name;
	private DBus.Service d_service;
	private RemoteServices d_supported_services;

	public static async Backend create(string language) throws IOError, DBusError
	{
		var name = "org.gnome.CodeAssist." + language;
		var path = "/org/gnome/CodeAssist/" + language;

		var service = yield Bus.get_proxy<DBus.Service>(BusType.SESSION, name, path);
		var services = yield service.supported_services();

		return new Backend(name, service, services);
	}

	private Backend(string name, DBus.Service service, string[] services)
	{
		d_name = name;
		d_service = service;

		d_views = new Gee.ArrayList<View>();
		d_supported_services = 0;

		foreach (var s in services)
		{
			d_supported_services = RemoteServices.parse(s);
		}
	}

	public bool supports(RemoteServices services)
	{
		return (d_supported_services & services) != 0;
	}

	public void register(View view)
	{
		d_views.add(view);

		view.changed.connect(on_view_changed);
	}

	public void unregister(View view)
	{
		view.changed.disconnect(on_view_changed);
		d_views.remove(view);
	}

	private async DBus.UnsavedDocument? unsaved_document(View v)
	{
		var doc = v.document;

		if (doc.is_modified)
		{
			try
			{
				var dp = yield doc.unsaved_data_path();

				return DBus.UnsavedDocument() {
					path = doc.path,
					data_path = dp
				};
			}
			catch (Error e)
			{
				Log.debug("Failed to get unsaved document: %s", e.message);
			}
		}

		return null;
	}

	private async DBus.UnsavedDocument[] unsaved_documents(View primary)
	{
		if ((d_supported_services & RemoteServices.MULTI_DOC) == 0)
		{
			var unsaved = yield unsaved_document(primary);

			if (unsaved == null)
			{
				return new DBus.UnsavedDocument[0];
			}

			return new DBus.UnsavedDocument[] {unsaved};
		}

		var unsaved = new DBus.UnsavedDocument[d_views.size];
		unsaved.length = 0;

		foreach (var v in d_views)
		{
			var u = yield unsaved_document(v);

			if (u != null)
			{
				unsaved += u;
			}
		}

		return unsaved;
	}

	private void parse(View view)
	{
		unsaved_documents.begin(view, (obj, res) => {
			var unsaved = unsaved_documents.end(res);

			var path = view.document.path;
			var cursor = view.document.cursor;

			var options = new HashTable<string, Variant>(str_hash, str_equal);

			d_service.parse.begin(path, cursor, unsaved, options, (obj, res) => {
				ObjectPath ret;

				try
				{
					ret = d_service.parse.end(res);
				}
				catch (Error e)
				{
					Log.debug("Failed to parse: %s", e.message);
					return;
				}

				view.update(new RemoteDocument(d_name, ret));
			});
		});
	}

	private void on_view_changed(View view)
	{
		parse(view);
	}
}

}

/* vi:ex:ts=4 */
