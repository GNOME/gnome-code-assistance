const GLib = imports.gi.GLib;
const Transport = imports.gnome.codeassistance.transport;
const Types = imports.gnome.codeassistance.types;
const Acorn = imports.gnome.codeassistance.js.acorn.acorn;

function Document() {
    this._init();
}

Document.prototype = {
    _init: function() {
        this.errors = [];
    },

    'org.gnome.CodeAssist.Document': {
    },

    'org.gnome.CodeAssist.Diagnostics': {
        diagnostics: function() {
            return this.errors;
        }
    }
}

function Service() {
    this._init();
}

Service.prototype = {
    _init: function() {
    
    },

    _data_path: function(path, unsaved) {
        for (var i = 0; i < unsaved.length; i++) {
            if (unsaved[i].path == path) {
                return unsaved[i].data_path;
            }
        }

        return path;
    },

    'org.gnome.CodeAssist.Service': {
        parse: function(path, cursor, unsaved, options, doc) {
            if (doc == null) {
                doc = new Document();
            }

            var p = this._data_path(path, unsaved);
            var c = GLib.file_get_contents(p);

            try {
                Acorn.parse(c);
                doc.errors = [];
            } catch (e) {
                let loc = new Types.SourceLocation({
                    line: e.loc.line,
                    column: e.loc.column + 1
                });

                let diag = new Types.Diagnostic({
                    severity: Types.Severity.ERROR,
                    locations: [loc.to_range({})],
                    message: e.message
                });

                doc.errors = [diag];
            }

            return doc;
        },

        dispose: function(doc) {
        }
    }
};

Service.language = "js";

function run() {
    var t = new Transport.Transport(Service, Document);
    t.run();
}

// vi:ts=4:et
