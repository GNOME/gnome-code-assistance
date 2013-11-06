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

[DBus (name = "org.gnome.CodeAssist.Document")]
public class Document : Object
{
	private Gca.Backends.Vala.Document d_document;

	public Document(Gca.Backends.Vala.Document document)
	{
		d_document = document;
	}
}

[DBus (name = "org.gnome.CodeAssist.Diagnostics")]
public class Diagnostics : Object
{
	private Gca.Backends.Vala.Document d_document;

	public Diagnostics(Gca.Backends.Vala.Document document)
	{
		d_document = document;
	}

	public Diagnostic[] diagnostics()
	{
		return d_document.diagnostics;
	}
}

[DBus (name = "org.freedesktop.DBus")]
interface FreedesktopDBus : Object {
	public signal void name_owner_changed(string name, string oldowner, string newowner);
}

[DBus (name = "org.gnome.CodeAssist.Service")]
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
		public Gee.HashMap<string, uint> ids;
		public Gee.HashMap<uint, Document> docs;
		public uint nextid;

		public App(uint id, string name)
		{
			this.id = id;
			this.name = name;

			service = new Gca.Backends.Vala.Service();
			ids = new Gee.HashMap<string, uint>();
			docs = new Gee.HashMap<uint, Document>();

			nextid = 0;
		}
	}

	private MainLoop d_main;
	private DBusConnection d_conn;
	private Gee.HashMap<string, App> d_services;
	private uint d_nextid;
	private FreedesktopDBus d_proxy;

	public Service(MainLoop mloop, DBusConnection conn)
	{
		d_main = mloop;
		d_conn = conn;
		d_services = new Gee.HashMap<string, App>();
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
		if (newowner == "" && d_services.has_key(oldowner))
		{
			dispose_app(d_services[oldowner]);
		}
	}

	private App app(string name)
	{
		if (!d_services.has_key(name))
		{
			var app = new App(d_nextid, name);

			d_nextid++;
			d_services[name] = app;
		}

		return d_services[name];
	}

	public ObjectPath parse(string path, int64 cursor, UnsavedDocument[] unsaved, HashTable<string, Variant> options, GLib.BusName sender)
	{
		var a = app(sender);
		Gca.Backends.Vala.Document? doc = null;
		Document? ddoc = null;

		if (a.ids.has_key(path))
		{
			ddoc = a.docs[a.ids[path]];
			doc = ddoc.document;
		}

		doc = a.service.parse(path, cursor, unsaved, options, doc);

		if (!a.ids.has_key(path))
		{
			ddoc = new Document(doc, a.nextid);
			ddoc.path = new ObjectPath("/org/gnome/CodeAssist/vala/%u/documents/%u".printf(a.id, ddoc.id));

			try
			{
				ddoc.ddocument_regid = d_conn.register_object(ddoc.path, ddoc.ddocument);
				ddoc.ddiagnostics_regid = d_conn.register_object(ddoc.path, ddoc.ddiagnostics);
			}
			catch (IOError e)
			{
				stderr.printf("Failed to register document: %s\n", e.message);
			}

			a.ids[path] = a.nextid;
			a.docs[a.nextid] = ddoc;

			a.nextid++;
		}

		return ddoc.path;
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

		app.ids.clear();
		app.docs.clear();

		d_services.unset(app.name);

		if (d_services.size == 0)
		{
			d_main.quit();
		}
	}

	private void dispose_real(App app, string path)
	{
		if (app.ids.has_key(path))
		{
			var id = app.ids[path];
			var ddoc = app.docs[id];

			dispose_document(app, ddoc);

			app.docs.unset(id);
			app.ids.unset(path);
		}

		if (app.ids.size == 0)
		{
			dispose_app(app);
		}
	}

	public new void dispose(string path, GLib.BusName sender)
	{
		dispose_real(app(sender), path);
	}

	public string[] supported_services(GLib.BusName sender)
	{
		app(sender);

		return new string[] {
			"org.gnome.CodeAssist.Document",
			"org.gnome.CodeAssist.Diagnostics",
		};
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
			conn.register_object("/org/gnome/CodeAssist/vala", d_service);
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
		             "org.gnome.CodeAssist.vala",
		             BusNameOwnerFlags.NONE,
		             on_bus_aquired,
		             on_name_acquired,
		             on_name_lost);

		d_main.run();
	}
}

}

/* vi:ts=4: */
