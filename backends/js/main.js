const GLib = imports.gi.GLib;
const Transport = imports.gnome.codeassistance.transport;
const Types = imports.gnome.codeassistance.types;
const Acorn = imports.gnome.codeassistance.js.acorn.acorn;

function Document() {
    this._init();
}

Document.prototype = {
    _init: function() {
        this.diagnostics = [];
    },

    'org.gnome.CodeAssist.Document': {
    },

    'org.gnome.CodeAssist.Diagnostics': {
        diagnostics: function() {
            return this.diagnostics;
        }
    }
};

function Service() {
    this._init();
}

Service.prototype = {
    _init: function() {
    
    },

    'org.gnome.CodeAssist.Service': {
        parse: function(doc, options) {
            var c = GLib.file_get_contents(doc.dataPath);

            doc.diagnostics = [];

            try {
                Acorn.parse(c[1]);
            } catch (e) {
                let loc = new Types.SourceLocation({
                    line: e.loc.line,
                    column: e.loc.column + 1
                });

                let diag = new Types.Diagnostic({
                    severity: Types.Severity.ERROR,
                    locations: [loc.toRange({})],
                    message: e.message
                });

                doc.diagnostics = [diag];
            }
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
