/* jshint moz: true */

const GLib = imports.gi.GLib;
const Gio = imports.gi.Gio;
const Transport = imports.gnome.codeassistance.transport;
const Types = imports.gnome.codeassistance.types;
const Acorn = imports.gnome.codeassistance.js.deps.acorn.acorn;
const JsHint = imports.gnome.codeassistance.js.deps.jshint.JSHINT;

function Document() {
    this._init();
}

Document.prototype = {
    _init: function() {
        this.diagnostics = [];
    },

    'org.gnome.CodeAssist.v1.Document': {
    },

    'org.gnome.CodeAssist.v1.Diagnostics': {
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

    _translateJshintDiagnostics: function(errors, severity, doc) {
        if (!errors) {
            return;
        }

        for (let i = 0; i < errors.length; i++) {
            let error = JsHint.errors[i];

            let start = new Types.SourceLocation({
                line: error.line,
                column: error.character
            });

            var sym = error.reason.match(/('[^']+')/);
            let end;

            if (sym) {
                end = new Types.SourceLocation({
                    line: error.line,
                    column: error.character + sym.length - 2
                });
            } else {
                end = start;
            }

            let range = new Types.SourceRange({
                start: start,
                end: end
            });

            let diag = new Types.Diagnostic({
                severity: severity,
                locations: [range],
                message: error.reason + ' (' + error.code + ')'
            });

            doc.diagnostics.push(diag);
        }
    },

    _jshintrcSearchPaths: function(doc) {
        let dir = Gio.file_new_for_path(doc.path).get_parent();
        let searchPaths = [];

        while (dir) {
            searchPaths.push(dir);
            dir = dir.get_parent();
        }

        searchPaths.push(Gio.file_new_for_path(GLib.get_home_dir()));
        return searchPaths;
    },

    _mergeOptions: function(base, options) {
        for (let option in options) {
            let val = options[option];

            if (val instanceof Object && !(val instanceof Array)) {
                if (!base[option]) {
                    base[option] = {};
                }

                this._mergeOptions(base[option], val);
            } else {
                base[option] = val;
            }
        }

        return base;
    },

    _jshintExtendedOptions: function(rc, options) {
        if (!options.extends) {
            return options;
        }

        let f;

        if (GLib.path_is_absolute(options.extends)) {
            f = Gio.file_new_for_path(options.extends);
        } else {
            f = rc.get_parent().resolve_relative_path(options.extends);
        }

        let base = this._jshintJson(f);

        if (!base) {
            return options;
        }

        delete options.extends;
        return this._mergeOptions(base, options);
    },

    _jshintJson: function(rc) {
        try {
            let c = rc.load_contents(null);

            if (!c[0]) {
                return null;
            }

            return this._jshintExtendedOptions(JSON.parse(String(c[1])));
        } catch (e) {
            return null;
        }
    },

    _jshintOptions: function(rc) {
        let opts = this._jshintJson(rc);

        if (!opts) {
            return opts;
        }

        let ret = {
            globals: {},
            options: {}
        };

        for (let k in opts) {
            let val = opts[k];

            if (k === 'global' || k === 'predef') {
                if (val instanceof Array) {
                    for (let i = 0; i < val.length; i++) {
                        ret.globals[val[i]] = true;
                    }
                } else {
                    for (let n in val) {
                        ret.globals[n] = (val[n] === 'true' || val[n] === true);
                    }
                }
            } else {
                if (val === 'true' || val === 'false') {
                    ret.options[k] = (val === 'true');
                } else {
                    ret.options[k] = val;
                }
            }
        }

        return ret;
    },

    _jshint: function(doc, contents, options) {
        if (options.jshint !== undefined && !options.jshint) {
            return;
        }

        var enabled = !!options.jshint || !!contents.match(/(\/\/|\/\*)\s*jshint/g);

        // Setup jshint options
        let searchPaths = this._jshintrcSearchPaths(doc);
        let rcopts = {
            globals: {},
            options: {}
        };

        for (let i = 0; i < searchPaths.length; i++) {
            let dir = searchPaths[i];
            let rc = dir.get_child('.jshintrc');

            if (rc.query_exists(null)) {
                let opts = this._jshintOptions(rc);

                if (opts) {
                    enabled = true;
                    rcopts = opts;
                    break;
                }
            }
        }

        if (!enabled) {
            return;
        }

        if (JsHint(contents)) {
            return;
        }

        this._translateJshintDiagnostics(JsHint.errors, Types.Severity.ERROR, doc);
        this._translateJshintDiagnostics(JsHint.warnings, Types.Severity.WARNING, doc);
        this._translateJshintDiagnostics(JsHint.info, Types.Severity.INFO, doc);
    },

    'org.gnome.CodeAssist.v1.Service': {
        parse: function(doc, options) {
            let c = GLib.file_get_contents(doc.dataPath);

            doc.diagnostics = [];

            if (!c[0]) {
                return;
            }

            c = String(c[1]);

            try {
                Acorn.parse(c);
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
                return;
            }

            try {
                this._jshint(doc, c, options);
            } catch (e) {
                print(e.message, e.stack);
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
