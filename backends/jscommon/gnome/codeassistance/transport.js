const System = imports.system;

// Stupid option parser
function _parseArgs() {
    var i = 0;
    var transport = 'dbus';
    var address = ':0';

    while (i < ARGV.length) {
        var arg = ARGV[i];
        i += 1;

        switch (arg) {
        case '-t':
        case '--transport':
            if (i < ARGV.length) {
                transport = ARGV[i];
                i += 1;
            } else {
                print("Expected argument for -t,--transport");
                System.exit(1)
            }
            break;
        case '-a':
        case '--address':
            if (i < ARGV.length) {
                address = ARGV[i];
                i += 1;
            } else {
                print("Expected argument for -a,--address");
                System.exit(1)
            }
            break;
        }

        break;
    }

    return {
        transport: transport,
        address: address
    }
};

function _run() {
    var opts = _parseArgs();

    switch (opts.transport) {
    case 'dbus':
        return imports.gnome.codeassistance.transport_dbus.exports;
        break;
    default:
        print('Invalid transport: ' + opts.transport);
        System.exit(1);
    }

    return {};
}

let _mod = _run();

for (let k in _mod) {
    this[k] = _mod[k];
}

// vi:ts=4:et
