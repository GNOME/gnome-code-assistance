let SourceLocation = function(line, column) {
    this._init(line, column);
};

SourceLocation.prototype = {
    _init: function(vals) {
        this.line = vals.line || 0;
        this.column = vals.column || 0;
    },

    to_range: function(vals) {
        return new SourceRange({
            file: vals.file || 0,
            start: new SourceLocation(this),
            end: new SourceLocation(this)
        });
    },

    to_tuple: function() {
        return [this.line, this.column];
    },

    toString: function() {
        return '[object SourceLocation{line:' + this.line + ', column:' + this.column + '}]';
    }
};

let SourceRange = function(vals) {
    this._init(vals);
};

SourceRange.prototype = {
    _init: function(vals) {
        this.file = vals.file || 0;
        this.start = vals.start || new SourceLocation({line: 0, column: 0});
        this.end = vals.end || new SourceLocation(this);
    },

    to_range: function() {
        return new SourceRange({
            file: this.file,
            start: new SourceLocation(this.start),
            end: new SourceLocation(this.end)
        });
    },

    to_tuple: function() {
        return [this.file, this.start.to_tuple(), this.end.to_tuple()];
    },

    toString: function() {
        return '[object SourceRange{file:' + this.file + ', start:' + this.start + ', end:' + this.end + '}]';
    }
};

let Fixit = function(vals) {
    this._init(vals);
};

Fixit.prototype = {
    _init: function(vals) {
        this.location = vals.location || new SourceRange({});
        this.replacement = vals.replacement || '';
    },

    to_tuple: function() {
        return [this.location.to_tuple(), this.replacement];
    },

    toString: function() {
        return '[object Fixit{location:' + this.location + ', replacement:' + this.replacement +'}]';
    }
};

let Severity = {
    NONE: 0,
    INFO: 1,
    WARNING: 2,
    DEPRECATED: 3,
    ERROR: 4,
    FATAL: 5
};

let Diagnostic = function(vals) {
    this._init(vals);
};

Diagnostic.prototype = {
    _init: function(vals) {
        this.severity = vals.severity || Severity.NONE;
        this.fixits = vals.fixits || [];
        this.locations = vals.locations || [];
        this.message = vals.message || '';
    },

    to_tuple: function() {
        let m = function(ar) {
            let ret = [];

            for (let i = 0; i < ar.length; i++) {
                ret.push(ar[i].to_tuple());
            }

            return ret;
        }

        return [this.severity, m(this.fixits), m(this.locations), this.message];
    },

    toString: function() {
        return '[object Diagnostic{severity:' + this.severity + ', fixits:' + this.fixits + ', locations:' + this.locations + ', message:' + this.message + '}]';
    }
};

// vi:ts=4:et