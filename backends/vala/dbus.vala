/*
 * This file is part of gnome-code-assistance.
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
 *
 * gnome-code-assistance is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * gnome-code-assistance is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gnome-code-assistance.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gca.Backends.Vala.DBus
{

[DBus (name = "org.gnome.CodeAssist.v1.Document")]
public class Document : Object
{
	private Gca.Backends.Vala.Document? d_document;

	public Document(Gca.Backends.Vala.Document? document = null)
	{
		d_document = document;
	}
}

[DBus (name = "org.gnome.CodeAssist.v1.Diagnostics")]
public class Diagnostics : Object
{
	private Gca.Backends.Vala.Document? d_document;

	public Diagnostics(Gca.Backends.Vala.Document? document = null)
	{
		d_document = document;
	}

	public Diagnostic[] diagnostics()
	{
		if (d_document != null)
		{
			return d_document.diagnostics;
		}
		else
		{
			return new Diagnostic[0];
		}
	}
}

[DBus (name = "org.freedesktop.DBus")]
interface FreedesktopDBus : Object {
	public signal void name_owner_changed(string name, string oldowner, string newowner);
}

[DBus (name = "org.gnome.CodeAssist.v1.Service")]
public class Service : Object
{
	class Document
	{
		public uint id;
		public Gca.Backends.Vala.Document document;

		public ObjectPath path;

		public Gca.Backends.Vala.DBus.Document ddocument;
		public uint ddocument_regid;

		public Gca.Backends.Vala.DBus.Diagnostics ddiagnostics;
		public uint ddiagnostics_regid;

		public Document(Gca.Backends.Vala.Document document, uint id)
		{
			this.id = id;
			this.document = document;

			ddocument = new Gca.Backends.Vala.DBus.Document(document);
			ddiagnostics_regid = 0;

			ddiagnostics = new Gca.Backends.Vala.DBus.Diagnostics(document);
			ddiagnostics_regid = 0;
		}
	}

	class App
	{
		public uint id;
		public string name;
		public Gca.Backends.Vala.Service service;
		public Gee.HashMap<string, Document> docs;
		public uint nextid;

		public App(uint id, string name)
		{
			this.id = id;
			this.name = name;

			service = new Gca.Backends.Vala.Service();
			docs = new Gee.HashMap<string, Document>();

			nextid = 0;
		}
	}

	private MainLoop d_main;
	private DBusConnection d_conn;
	private Gee.HashMap<string, App> d_apps;
	private uint d_nextid;
	private FreedesktopDBus d_proxy;

	public Service(MainLoop mloop, DBusConnection conn)
	{
		d_main = mloop;
		d_conn = conn;
		d_apps = new Gee.HashMap<string, App>();
		d_nextid = 0;

		Bus.get_proxy.begin<FreedesktopDBus>(BusType.SESSION, "org.freedesktop.DBus", "/org/freedesktop/DBus", 0, null, (obj, res) => {
			try
			{
				d_proxy = Bus.get_proxy.end<FreedesktopDBus>(res);
				d_proxy.name_owner_changed.connect(on_name_owner_changed);
			} catch { return; }
		});
	}

	private void on_name_owner_changed(string name, string oldowner, string newowner)
	{
		if (newowner == "" && d_apps.has_key(oldowner))
		{
			dispose_app(d_apps[oldowner]);
		}
	}

	private App make_app(string name)
	{
		var app = new App(d_nextid, name);

		d_nextid++;
		d_apps[name] = app;

		return app;
	}

	private App ensure_app(string name)
	{
		if (d_apps.has_key(name))
		{
			return d_apps[name];
		}
		else
		{
			return make_app(name);
		}
	}

	private string clean_path(string path)
	{
		if (path.length == 0)
		{
			return path;
		}

		return File.new_for_path(path).get_path();
	}

	private Document make_document(App app, string path, string client_path)
	{
		var ndoc = new Gca.Backends.Vala.Document(path);
		ndoc.client_path = client_path;

		var doc = new Document(ndoc, app.nextid);

		doc.path = new ObjectPath("/org/gnome/CodeAssist/v1/vala/%u/documents/%u".printf(app.id, doc.id));

		try
		{
			doc.ddocument_regid = d_conn.register_object(doc.path, doc.ddocument);
			doc.ddiagnostics_regid = d_conn.register_object(doc.path, doc.ddiagnostics);
		}
		catch (IOError e)
		{
			stderr.printf("Failed to register document: %s\n", e.message);
		}

		app.docs[path] = doc;
		app.nextid++;

		return doc;
	}

	private Document ensure_document(App app, string path, string data_path, int64 cursor)
	{
		var cpath = clean_path(path);
		Document doc;

		if (app.docs.has_key(cpath))
		{
			doc = app.docs[cpath];
		}
		else
		{
			doc = make_document(app, cpath, path);
		}

		if (data_path != null && data_path != "")
		{
			doc.document.data_path = data_path;
		}
		else
		{
			doc.document.data_path = doc.document.path;
		}

		doc.document.cursor = cursor;
		return doc;
	}

	public ObjectPath parse(string path, int64 cursor, string data_path, HashTable<string, Variant> options, GLib.BusName sender) throws Error
	{
		var app = ensure_app(sender);
		var doc = ensure_document(app, path, data_path, cursor);

		app.service.parse(doc.document, options);

		return doc.path;
	}

	private void dispose_document(App a, Document ddoc)
	{
		a.service.dispose(ddoc.document);

		if (ddoc.ddocument_regid != 0)
		{
			d_conn.unregister_object(ddoc.ddocument_regid);
		}

		if (ddoc.ddiagnostics_regid != 0)
		{
			d_conn.unregister_object(ddoc.ddiagnostics_regid);
		}
	}

	private void dispose_app(App app)
	{
		foreach (var ddoc in app.docs.values)
		{
			dispose_document(app, ddoc);
		}

		app.docs.clear();

		d_apps.unset(app.name);

		if (d_apps.size == 0)
		{
			d_main.quit();
		}
	}

	public new void dispose(string path, GLib.BusName sender)
	{
		if (d_apps.has_key(sender))
		{
			var app = d_apps[sender];
			var cpath = clean_path(path);

			if (app.docs.has_key(cpath))
			{
				dispose_document(app, app.docs[cpath]);
				app.docs.unset(cpath);

				if (app.docs.size == 0)
				{
					dispose_app(app);
				}
			}
		}
	}
}

public class Transport
{
	private Service d_service;
	private MainLoop d_main;

	public Transport()
	{
		d_main = new MainLoop();
	}

	private void on_bus_aquired(DBusConnection conn)
	{
		d_service = new Service(d_main, conn);

		try
		{
			conn.register_object("/org/gnome/CodeAssist/v1/vala", d_service);
			conn.register_object("/org/gnome/CodeAssist/v1/vala/document", new DBus.Document());
			conn.register_object("/org/gnome/CodeAssist/v1/vala/document", new DBus.Diagnostics());
		}
		catch (Error e)
		{
			stderr.printf("Failed to register service: %s\n", e.message);
		}
	}

	private void on_name_acquired(DBusConnection conn, string name)
	{
	}

	private void on_name_lost(DBusConnection conn, string name)
	{
		d_main.quit();
	}

	public void run()
	{
		Bus.own_name(BusType.SESSION,
		             "org.gnome.CodeAssist.v1.vala",
		             BusNameOwnerFlags.NONE,
		             on_bus_aquired,
		             on_name_acquired,
		             on_name_lost);

		d_main.run();
	}
}

}

/* vi:ts=4: */
