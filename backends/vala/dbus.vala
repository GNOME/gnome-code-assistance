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

namespace DBus
{

[DBus (name = "org.gnome.CodeAssist.v1.Document")]
public class DocumentIface : Object
{
	private Document? d_document;

	public DocumentIface(Document? document = null)
	{
		d_document = document;
	}
}

[DBus (name = "org.gnome.CodeAssist.v1.Diagnostics")]
public class DiagnosticsIface : Object
{
	private Document? d_document;

	public DiagnosticsIface(Document? document = null)
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
public interface FreedesktopDBus : Object {
	public signal void name_owner_changed(string name, string oldowner, string newowner);
}

[DBus (name = "org.gnome.CodeAssist.v1.Service")]
public class ServiceIface : Object
{
	private Server d_server;

	public ServiceIface(Server server)
	{
		d_server = server;
	}

	public async ObjectPath parse(string path, string data_path, SourceLocation cursor, HashTable<string, Variant> options, GLib.BusName sender) throws Error
	{
		return yield d_server.parse(path, data_path, cursor, options, sender);
	}

	public new void dispose(string path, GLib.BusName sender)
	{
		d_server.dispose(path, sender);
	}
}

[DBus (name = "org.gnome.CodeAssist.v1.Project")]
public class ProjectIface : Object
{
	private Server d_server;

	public ProjectIface(Server server)
	{
		d_server = server;
	}

	public async RemoteDocument[] parse_all(string path, OpenDocument[] documents, SourceLocation cursor, HashTable<string, Variant> options, GLib.BusName sender) throws Error
	{
		return yield d_server.parse_all(path, documents, cursor, options, sender);
	}
}

public class Server
{
	class ExportedDocument
	{
		public Document document;

		public DocumentIface ddocument;
		public uint ddocument_regid;

		public DiagnosticsIface ddiagnostics;
		public uint ddiagnostics_regid;

		public ExportedDocument(Document document)
		{
			this.document = document;

			ddocument = new DocumentIface(document);
			ddiagnostics_regid = 0;

			ddiagnostics = new DiagnosticsIface(document);
			ddiagnostics_regid = 0;
		}
	}

	class App
	{
		public uint id;
		public string name;
		public Service service;
		public Gee.HashMap<string, ExportedDocument> docs;
		public uint nextid;

		public App(uint id, string name)
		{
			this.id = id;
			this.name = name;

			service = new Service();
			docs = new Gee.HashMap<string, ExportedDocument>();

			nextid = 0;
		}
	}

	private MainLoop d_main;
	private DBusConnection d_conn;
	private Gee.HashMap<string, App> d_apps;
	private uint d_nextid;
	private FreedesktopDBus d_proxy;

	public Server(MainLoop mloop, DBusConnection conn)
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
			lock(d_apps)
			{
				dispose_app(d_apps[oldowner]);
			}
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

	private ExportedDocument make_document(App app, string path, string client_path)
	{
		var ndoc = new Document(app.nextid, path);
		ndoc.client_path = client_path;

		var doc = new ExportedDocument(ndoc);
		var rpath = remote_document_path(app, ndoc);

		try
		{
			doc.ddocument_regid = d_conn.register_object(rpath, doc.ddocument);
			doc.ddiagnostics_regid = d_conn.register_object(rpath, doc.ddiagnostics);
		}
		catch (IOError e)
		{
			stderr.printf("Failed to register document: %s\n", e.message);
		}

		app.docs[path] = doc;
		app.nextid++;

		return doc;
	}

	private ExportedDocument ensure_document(App app, string path, string data_path, SourceLocation? cursor = null)
	{
		var cpath = clean_path(path);
		ExportedDocument doc;

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

		if (cursor == null)
		{
			doc.document.cursor = SourceLocation() {
				line = 0,
				column = 0
			};
		}
		else
		{
			doc.document.cursor = cursor;
		}

		return doc;
	}

	private void dispose_document(App a, ExportedDocument ddoc)
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

	private ObjectPath remote_document_path(App app, Document doc)
	{
		return (ObjectPath)("/org/gnome/CodeAssist/v1/vala/%u/documents/%u".printf(app.id, doc.id));
	}

	public async ObjectPath parse(string path, string data_path, SourceLocation cursor, HashTable<string, Variant> options, GLib.BusName sender) throws Error
	{
		App app;
		ExportedDocument doc;

		lock(d_apps)
		{
			app = ensure_app(sender);
			doc = ensure_document(app, path, data_path, cursor);
		}

		yield app.service.parse(doc.document, options);

		return remote_document_path(app, doc.document);
	}

	public new void dispose(string path, GLib.BusName sender)
	{
		lock(d_apps)
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

	public async RemoteDocument[] parse_all(string path, OpenDocument[] documents, SourceLocation cursor, HashTable<string, Variant> options, GLib.BusName sender) throws Error
	{
		App app;
		ExportedDocument doc;
		Document[] opendocs;

		lock(d_apps)
		{
			app = ensure_app(sender);
			doc = ensure_document(app, path, "", cursor);

			opendocs = new Document[documents.length];

			for (var i = 0; i < documents.length; i++)
			{
				var rdoc = ensure_document(app, documents[i].path, documents[i].data_path);
				opendocs[i] = rdoc.document;
			}
		}

		var retdocs = yield app.service.parse_all(doc.document, opendocs, options);

		var ret = new RemoteDocument[retdocs.length];

		for (var i = 0; i < retdocs.length; i++)
		{
			ret[i] = RemoteDocument() {
				path = retdocs[i].client_path,
				remote_path = remote_document_path(app, retdocs[i])
			};
		}

		return ret;
	}
}

class Transport
{
	private Server d_server;
	private MainLoop d_main;

	public Transport()
	{
		d_main = new MainLoop();
	}

	private void on_bus_aquired(DBusConnection conn)
	{
		d_server = new Server(d_main, conn);

		try
		{
			conn.register_object("/org/gnome/CodeAssist/v1/vala", new ServiceIface(d_server));
			conn.register_object("/org/gnome/CodeAssist/v1/vala", new ProjectIface(d_server));

			conn.register_object("/org/gnome/CodeAssist/v1/vala/document", new DocumentIface());
			conn.register_object("/org/gnome/CodeAssist/v1/vala/document", new DiagnosticsIface());
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
