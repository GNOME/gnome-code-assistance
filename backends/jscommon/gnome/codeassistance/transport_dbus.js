const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const System = imports.system;
const Lang = imports.lang;

var ServiceIface = <interface name="org.gnome.CodeAssist.Service">
  <method name="Parse">
    <arg direction="in"  type="s" name="path" />
    <arg direction="in"  type="x" name="cursor" />
    <arg direction="in"  type="a(ss)" name="unsaved" />
    <arg direction="in"  type="a{sv}" name="options" />
    <arg direction="out" type="o" />
  </method>
  <method name="Dispose">
    <arg direction="in"  type="s" name="path" />
  </method>
  <method name="SupportedServices">
    <arg direction="out" type="as" />
  </method>
</interface>

var DocumentIface = <interface name="org.gnome.CodeAssist.Document">
</interface>

var DiagnosticsIface = <interface name="org.gnome.CodeAssist.Diagnostics">
  <method name="Diagnostics">
    <arg direction="out" type="a(ua((x(xx)(xx))s)a(x(xx)(xx))s)"/>
  </method>
</interface>

var Document = function(doc) {
    this._init(doc);
};

Document.prototype = {
    _init: function(doc) {
        this.doc = doc;
        this.dbus = Gio.DBusExportedObject.wrapJSObject(DocumentIface, this);
    }
};

var Diagnostics = function(doc) {
    this._init(doc);
};

Diagnostics.prototype = {
    _init: function(doc) {
        this.doc = doc;
        this.dbus = Gio.DBusExportedObject.wrapJSObject(DiagnosticsIface, this);
    },

    Diagnostics: function() {
        let retval = this.doc['org.gnome.CodeAssist.Diagnostics'].diagnostics.call(this.doc);
        let ret = [];

        for (let i = 0; i < retval.length; i++) {
            ret.push(retval[i].to_tuple());
        }

        return ret;
    }
};

var Services = {
    'org.gnome.CodeAssist.Document': Document,
    'org.gnome.CodeAssist.Diagnostics': Diagnostics
};

function Server(conn, service, document) {
    this._init(conn, service, document);
}

Server.prototype = {
    _init: function(conn, service, document) {
        this.conn = conn;
        this.service = service;
        this.document = document;

        this.apps = {};
        this.nextid = 0;

        this._impl = Gio.DBusExportedObject.wrapJSObject(ServiceIface, this);
        this._impl.export(Gio.DBus.session, '/org/gnome/CodeAssist/' + service.language);

        this.services = [];

        var proto = this.document.prototype;

        for (var s in Services) {
            if (s in proto) {
                this.services.push(s);
            }
        }
    },

    app: function(appid) {
        if (!(appid in this.apps)) {
            var app = {
                id: this.nextid,
                name: appid,
                service: new this.service(),
                docs: {},
                ids: {},
                nextid: 0
            };

            this.apps[appid] = app;
            this.nextid += 1;
        }

        return this.apps[appid];
    },

    _SupportedServices: function(sender) {
        this.app(sender);
    },

    _makeOutSignature: function(args) {
        var ret = '(';

        for (var i = 0; i < args.length; i++) {
            ret += args[i].signature;
        }

        return ret + ')';
    },

    // Mostly copied from gjs
    _callSync: function(f, invocation) {
        var retval;

        try {
            retval = f.call(this, invocation.get_sender());
        } catch (e) {
            if (e instanceof GLib.Error) {
                invocation.return_gerror(e);
            } else {
                let name = e.name;

                if (name.indexOf('.') == -1) {
                    name = 'org.gnome.CodeAssist.JSError.' + name;
                }

                let errLoc = e.fileName + ':' + e.lineNumber + '.' + e.columnNumber;
                invocation.return_dbus_error(name, errLoc + ': ' + e.message);
            }

            return;
        }

        if (retval == undefined) {
            retval = new GLib.Variant('()', []);
        }

        if (!(retval instanceof GLib.Variant)) {
            let methodInfo = invocation.get_method_info();
            let outArgs = methodInfo.out_args;

            let outSignature = this._makeOutSignature(outArgs);

            if (outArgs.length == 1) {
                retval = [retval];
            }

            try {
                retval = new GLib.Variant(outSignature, retval);
            } catch (e) {
                let ifaceName = invocation.get_interface_name();
                let methodName = methodInfo.name;
                let objectPath = invocation.get_object_path();

                let errLoc = e.fileName + ':' + e.lineNumber + '.' + e.columnNumber;
                let errMsg = 'in ' + errLoc + ': ' + objectPath + '(' + ifaceName + '.' + methodName + ') -> ' + outSignature;

                invocation.return_dbus_error('org.gnome.CodeAssist.js.ValueError',
                                             'Failed to encode return value in `' + errMsg + '\': ' + e.message);
                return;
            }
        }

        invocation.return_value(retval);
    },

    documentPath: function(app, doc) {
        return '/org/gnome/CodeAssist/' + this.service.language + '/' + app.id + '/documents/' + doc.id;
    },

    exportDocument: function(app, doc) {
        doc._dbus_registered = {};

        var path = this.documentPath(app, doc);

        for (var i = 0; i < this.services.length; i++) {
            var name = this.services[i];
            var service = Services[name];

            var obj = new service(doc);

            doc._dbus_registered[name] = obj;
            obj.dbus.export(this.conn, path);
        }
    },

    parse: function(app, path, cursor, unsaved, options) {
        var doc = null;

        if (path in app.ids) {
            doc = app.docs[app.ids[path]];
        }

        var uns = [];

        for (var i = 0; i < unsaved.length; i++) {
            uns.push({
                path: unsaved[i][0],
                data_path: unsaved[i][1]
            });
        }

        doc = app.service['org.gnome.CodeAssist.Service'].parse.call(app.service,
                                                                     path,
                                                                     cursor,
                                                                     uns,
                                                                     options,
                                                                     doc);

        if (!(path in app.ids)) {
            doc.id = app.nextid;
            app.nextid += 1

            app.ids[path] = doc.id;
            app.docs[doc.id] = doc

            this.exportDocument(app, doc);
        }

        return this.documentPath(app, doc);
    },

    dispose_app: function(app) {
        for (var id in app.docs) {
            this.dispose_document(app.docs[id]);
        }

        app.ids = {};
        app.docs = {};

        delete this.apps[app.name];

        if (Object.keys(this.apps).length == 0) {
            System.exit(0);
        }
    },

    dispose_document: function(app, doc) {
        app.service['org.gnome.CodeAssist.Service'].dispose.call(app.service, doc);

        for (var name in doc._dbus_registered) {
            doc._dbus_registered[name].unexport(this.conn);
        }
    },

    dispose_real: function(app, path) {
        if (path in app.ids) {
            var id = app.ids[path];
            var doc = app.docs[id];

            this.dispose_document(app, doc);

            delete app.docs[id];
            delete app.ids[path];
        }

        if (Object.keys(a.ids).length == 0)
        {
            this.dispose_app(app);
        }
    },

    SupportedServicesAsync: function([], invocation) {
        this._callSync(function (sender) {
            this.app(sender);
            return this.services;
        }, invocation);
    },

    ParseAsync: function([path, cursor, unsaved, options], invocation) {
        this._callSync(function (sender) {
            return this.parse(this.app(sender), path, cursor, unsaved, options);
        }, invocation);
    },

    DisposeAsync: function([path], invocation) {
        this._callSync(function (sender) {
            this.dispose_real(this.app(sender), path);
        }, invocation);
    }
}

function Transport(service, document) {
    this._init(service, document);
}

Transport.prototype = {
    _init: function(service, document) {
        this.service = service;
        this.document = document;
        this.main = new GLib.MainLoop(null, true);
    },

    on_bus_acquired: function(conn, name) {
        this.server = new Server(conn, this.service, this.document);
    },

    on_name_acquired: function(conn, name) {
    
    },

    on_name_lost: function(conn, name) {
    
    },

    run: function() {
        Gio.DBus.session.own_name('org.gnome.CodeAssist.' + this.service.language,
                                  Gio.BusNameOwnerFlags.NONE,
                                  Lang.bind(this, this.on_bus_acquired),
                                  Lang.bind(this, this.on_name_acquired),
                                  Lang.bind(this, this.on_name_lost));

        this.main.run();
    }
};

var exports = {
    Document: Document,
    Diagnostics: Diagnostics,
    Transport: Transport
};

// vi:ts=4:et
