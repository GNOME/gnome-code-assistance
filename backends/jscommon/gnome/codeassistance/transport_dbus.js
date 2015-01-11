const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Lang = imports.lang;
const Types = imports.gnome.codeassistance.types;
const system = imports.system;

var ServiceIface = '<node>                                                      \
  <interface name="org.gnome.CodeAssist.v1.Service">                            \
    <method name="Parse">                                                       \
      <arg direction="in"  type="s" name="path" />                              \
      <arg direction="in"  type="s" name="dataPath" />                          \
      <arg direction="in"  type="(xx)" name="cursor" />                         \
      <arg direction="in"  type="a{sv}" name="options" />                       \
      <arg direction="out" type="o" name="documentPath"/>                       \
    </method>                                                                   \
    <method name="Dispose">                                                     \
      <arg direction="in"  type="s" name="path" />                              \
    </method>                                                                   \
  </interface>                                                                  \
</node>';

var ProjectIface = '<node>                                                      \
  <interface name="org.gnome.CodeAssist.v1.Project">                            \
    <method name="ParseAll">                                                    \
      <arg direction="in"  type="s" name="path" />                              \
      <arg direction="in"  type="a(ss)" name="documents" />                     \
      <arg direction="in"  type="(xx)" name="cursor" />                         \
      <arg direction="in"  type="a{sv}" name="options" />                       \
      <arg direction="out" type="a(so)" name="documents" />                     \
    </method>                                                                   \
  </interface>                                                                  \
</node>';

var DocumentIface = '<node>                                                     \
  <interface name="org.gnome.CodeAssist.v1.Document">                           \
  </interface>                                                                  \
</node>';

var DiagnosticsIface = '<node>                                                  \
  <interface name="org.gnome.CodeAssist.v1.Diagnostics">                        \
    <method name="Diagnostics">                                                 \
      <arg direction="out" type="a(ua((x(xx)(xx))s)a(x(xx)(xx))s)" name="diagnostics"/> \
    </method>                                                                   \
  </interface>                                                                  \
</node>';

var FreedesktopDBusIface = '<node>                                              \
  <interface name="org.freedesktop.DBus">                                       \
    <signal name="NameOwnerChanged">                                            \
      <arg direction="out" type="s"/>                                           \
      <arg direction="out" type="s"/>                                           \
      <arg direction="out" type="s"/>                                           \
    </signal>                                                                   \
  </interface>                                                                  \
</node>';

let OpenDocument = function(vals) {
    this._init(vals);
};

OpenDocument.prototype = {
    _init: function(vals) {
        this.path = vals.path || '';
        this.dataPath = vals.dataPath || '';
    },

    toString: function() {
        return '[object OpenDocument{path:' + this.path + ', dataPath:' + this.dataPath + '}]';
    }
};

OpenDocument.fromTuple = function(tp) {
    return new OpenDocument({
        path: tp[0],
        dataPath: tp[1]
    });
};

let RemoteDocument = function(vals) {
    this._init(vals);
};

RemoteDocument.prototype = {
    _init: function(vals) {
        this.path = vals.path || '';
        this.remotePath = vals.remotePath || '';
    },

    toTuple: function() {
        return [this.path, this.remotePath];
    },

    toString: function() {
        return '[object RemoteDocument{path:' + this.path + ', remotePath:' + this.remotePath + '}]';
    }
};

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
        let diagnostics = this.doc['org.gnome.CodeAssist.v1.Diagnostics'].diagnostics.call(this.doc);

        return diagnostics.map(function (d) {
            return d.toTuple();
        });
    }
};

var Service = function(server) {
    this._init(server);
};

Service.prototype = {
    _init: function(server) {
        this.server = server;
        this.dbus = Gio.DBusExportedObject.wrapJSObject(ServiceIface, this);
    },

    ParseAsync: function(args, invocation) {
        this.server.dbusAsync(args, invocation, function(sender, path, dataPath, cursor, options) {
            let app = this.ensureApp(sender);
            let doc = this.ensureDocument(app, path, dataPath, Types.SourceLocation.fromTuple(cursor));

            app.service['org.gnome.CodeAssist.v1.Service'].parse.call(app.service,
                                                                      doc,
                                                                      options);

            return this.documentPath(app, doc);
        });
    },

    DisposeAsync: function(args, invocation) {
        var retval;

        this.server.dbusAsync(args, invocation, function(sender, path) {
            if (sender in this.apps) {
                let app = this.apps[sender];
                let cpath = this.cleanPath(path);

                if (cpath in app.docs) {
                    this.disposeDocument(app, app.docs[cpath]);
                    delete app.docs[cpath];

                    if (Object.keys(app.docs).length == 0) {
                        retval = this.disposeApp(app);
                    }
                }
            }
        }, function() {
            if (retval)
            {
                this.conn.flush_sync(null);
                this.main.quit();
            }
        });
    }
};

var Project = function(server) {
    this._init(server);
};

Project.prototype = {
    _init: function(server) {
        this.server = server;
        this.dbus = Gio.DBusExportedObject.wrapJSObject(ProjectIface, this);
    },

    ParseAllAsync: function(args, invocation) {
        this.server.dbusAsync(args, invocation, function(sender, path, cursor, documents, options) {
            let app = this.ensureApp(sender);
            let doc = this.ensureDocument(app, path, '', Types.SourceLocation.fromTuple(cursor));

            let opendocs = documents.map(function (d) {
                return OpenDocument.fromTuple(d);
            });

            let docs = opendocs.map(function(d) {
                return this.ensureDocument(app, d.path, d.dataPath);
            });

            parsed = app.service['org.gnome.CodeAssist.v1.Project'].call(app.service, doc, docs, options);

            return parsed.map(function(d) {
                return (new RemoteDocument({
                    path: d.clientPath,
                    remotePath: this.documentPath(app, d)
                })).toTuple();
            });
        });
    }
};

var ServerServices = {
    'org.gnome.CodeAssist.v1.Service': Service,
    'org.gnome.CodeAssist.v1.Project': Project,
};

var DocumentServices = {
    'org.gnome.CodeAssist.v1.Document': Document,
    'org.gnome.CodeAssist.v1.Diagnostics': Diagnostics
};

const FreedesktopDBusProxy = Gio.DBusProxy.makeProxyWrapper(FreedesktopDBusIface);

function Server(main, conn, service, document) {
    this._init(main, conn, service, document);
}

Server.prototype = {
    _init: function(main, conn, service, document) {
        this.main = main;
        this.conn = conn;
        this.service = service;
        this.document = document;

        this.apps = {};
        this.nextid = 0;
        this.services = {};

        let path = '/org/gnome/CodeAssist/v1/' + service.language;

        // Setup relevant server services
        for (let s in ServerServices) {
            if (s in service.prototype) {
                let serv = new ServerServices[s](this);
                serv.dbus.export(conn, path);

                this.services[s] = serv;
            }
        }

        let docservices = [];

        for (let s in DocumentServices) {
            if (s in document.prototype) {
                docservices.push(DocumentServices[s]);
            }
        }

        this.makeDocumentProxies = function(doc, path) {
            let remotes = [];

            for (let i = 0; i < docservices.length; i++) {
                let remote = new docservices[i](doc);

                remote.dbus.export(conn, path);
                remotes.push(remote);
            }

            return remotes;
        };

        this.dummy = this.makeDocumentProxies(null, path + '/document');

        var proxy = new FreedesktopDBusProxy(Gio.DBus.session,
                                             'org.freedesktop.DBus',
                                             '/org/freedesktop/DBus');

        proxy.connectSignal('NameOwnerChanged', Lang.bind(this, this.onNameOwnerChanged));
    },

    onNameOwnerChanged: function(emitter, senderName, parameters) {
        let oldname = parameters[1];
        let newname = parameters[2];

        if (newname == '' && oldname in this.apps) {
            this.disposeApp(this.apps[oldname]);
        }
    },

    makeApp: function(appid) {
        let app = {
            id: this.nextid,
            name: appid,
            service: new this.service(),
            docs: {},
            nextid: 0
        };

        this.apps[appid] = app;
        this.nextid += 1;

        return app;
    },

    ensureApp: function(appid) {
        if (!(appid in this.apps)) {
            return this.makeApp(appid);
        } else {
            return this.apps[appid];
        }
    },

    documentPath: function(app, doc) {
        return '/org/gnome/CodeAssist/v1/' + this.service.language + '/' + app.id + '/documents/' + doc.id;
    },

    makeDocument: function(app, path, clientPath) {
        let doc = new this.document();

        doc.id = app.nextid;
        doc.path = path;
        doc.clientPath = clientPath;

        app.nextid += 1;
        app.docs[path] = doc;

        doc._proxies = this.makeDocumentProxies(doc, this.documentPath(app, doc));
        return doc;
    },

    cleanPath: function(path) {
        if (path.length == 0) {
            return path;
        }

        return Gio.file_new_for_path(path).get_path();
    },

    ensureDocument: function(app, path, dataPath, cursor) {
        let cpath = this.cleanPath(path);

        let doc;

        if (cpath in app.docs) {
            doc = app.docs[cpath];
        } else {
            doc = this.makeDocument(app, cpath, path);
        }

        doc.dataPath = dataPath;

        if (!doc.dataPath) {
            doc.dataPath = path;
        }

        doc.cursor = cursor;
        return doc;
    },

    disposeDocument: function(app, doc) {
        app.service['org.gnome.CodeAssist.v1.Service'].dispose.call(app.service, doc);

        for (let i = 0; i < doc._proxies.length; i++) {
            doc._proxies[i].dbus.unexport(this.conn);

            doc._proxies[i].doc = null;
            doc._proxies[i].dbus = null;
        }

        doc._proxies = [];
    },

    disposeApp: function(app) {
        for (let path in app.docs) {
            this.disposeDocument(app, app.docs[path]);
        }

        app.docs = {};
        delete this.apps[app.name];

        return (Object.keys(this.apps).length == 0);
    },

    makeOutSignature: function(args) {
        var ret = '(';

        for (var i = 0; i < args.length; i++) {
            ret += args[i].signature;
        }

        return ret + ')';
    },

    // Mostly copied from gjs
    dbusAsync: function(args, invocation, f, finishedcb) {
        var retval;

        try {
            let rargs = args.map(function (a) { return a; });

            rargs.unshift(invocation.get_sender());
            retval = f.apply(this, rargs);
        } catch (e) {
            if (e instanceof GLib.Error) {
                invocation.return_gerror(e);
            } else {
                let name = e.name;

                if (name.indexOf('.') == -1) {
                    name = 'org.gnome.CodeAssist.v1.js.Error.' + name;
                }

                let errLoc = e.fileName + ':' + e.lineNumber + '.' + e.columnNumber;
                invocation.return_dbus_error(name, errLoc + ': ' + e.message);
            }

            if (finishedcb)
            {
                finishedcb.call(this);
            }

            return;
        }

        if (retval == undefined) {
            retval = new GLib.Variant('()', []);
        }

        if (!(retval instanceof GLib.Variant)) {
            let methodInfo = invocation.get_method_info();
            let outArgs = methodInfo.out_args;

            let outSignature = this.makeOutSignature(outArgs);

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

                invocation.return_dbus_error('org.gnome.CodeAssist.v1.js.ValueError',
                                             'Failed to encode return value in `' + errMsg + '\': ' + e.message);

                if (finishedcb)
                {
                    finishedcb.call(this);
                }

                return;
            }
        }

        invocation.return_value(retval);

        if (finishedcb)
        {
            finishedcb.call(this);
        }
    }
};

function Transport(service, document) {
    this._init(service, document);
}

Transport.prototype = {
    _init: function(service, document) {
        this.service = service;
        this.document = document;
        this.main = new GLib.MainLoop(null, true);
    },

    onBusAcquired: function(conn, name) {
        this.server = new Server(this.main, conn, this.service, this.document);
    },

    onNameAcquired: function(conn, name) {
    },

    onNameLost: function(conn, name) {
        system.exit(1);
    },

    run: function() {
        Gio.bus_own_name(Gio.BusType.SESSION,
                         'org.gnome.CodeAssist.v1.' + this.service.language,
                         Gio.BusNameOwnerFlags.NONE,
                         Lang.bind(this, this.onBusAcquired),
                         Lang.bind(this, this.onNameAcquired),
                         Lang.bind(this, this.onNameLost));

        this.main.run();
    }
};

let exports = {
    Transport: Transport
};

// vi:ts=4:et
