# Code Assistance
This page describes the gnome-code-assistance project.

git: https://git.gnome.org/browse/gnome-code-assistance
bugs: https://bugzilla.gnome.org/browse.cgi?product=gnome-code-assistance

## Description
gnome-code-assistance is a project which aims to provide common code assistance
services for code editors (simple editors as well as IDEs). It is an effort to
provide a centralized code-assistance as a service for the GNOME platform
instead of having every editor implement their own solution.

## Design
gnome-code-assistance is designed as a set of DBus services which editors can
query to integrate code assistance. There are several advantages of this design.
As DBus services, the code assistance code runs out-of-process which ensures
robustness (in terms of crashing clients). Having each language backend being
implemented as a separate process further allows backends to be implemented in
a language of choice (often the language for which the service is being
provided). Many languages nowadays provide code analysis tools as part of the
language's standard library which simplifies writing code assistance support.

The set of DBus interfaces defined in this document represent the contract
between the client and backend services. This allows clients to implement code
assistance in a largely language agnostic manner and using DBus
introspection, clients can find out what kind of services a certain language
backend supports.

## Existing clients
The only existing client currently is being developed as a plugin for gedit
at https://git.gnome.org/browse/gedit-code-assistance.git. This serves as a
reference implementation for other clients.

## DBus objects and interfaces
The following section describes the various DBus interfaces and objects which
define the code assistance protocol.

### Interfaces
    // All services must implement this interface on the root object.
    type org.gnome.CodeAssist.Service interface {
        // Parse and analyse a single document.
        //
        // path:     the file path to be parsed.
        // cursor:   the current location (in bytes) of the cursor. The cursor
        //           position can be used for the purpose of obtaining
        //           information for services like auto-completion.
        // dataPath: the path where the actual file data can be obtained. The
        //           dataPath should be used to provide the contents of a file
        //           that has modifications not yet written to disk (i.e. a file
        //           being edited).
        // options:  a map of backend specific options.
        //
        // returns:  a dbus object path where information on the parsed document
        //           can be obtained. The object located at this path can
        //           be introspected to find out which services are available.
        //
        Parse(path string, cursor int64, dataPath string, options map[string]variant) object

        // Dispose the document representing the given file path. Note that this
        // is a file path, not a dbus object path. Clients can call dispose
        // to allow backends to cleanup resources (e.g. a cache) associated
        // with the document. Editors should normally call this as soon as
        // code assistance for a document is no longer required (e.g. closing
        // the document).
        Dispose(path string)
    }

    // This interface is implemented by backends that support parsing and
    // analysing multiple documents at the same time to complete a translation
    // unit. This is mostly useful for statically typed languages, where multiple
    // documents are parsed to complete type information (think headers in C).
    type org.gnome.CodeAssist.Project interface {
        // Parse a number of documents to complete the translation unit of the
        // given path.
        //
        // path:      the file path to be parsed.
        // cursor:    the cursor location (see org.gnome.CodeAssist.Service.Parse).
        // documents: a list of open documents (path string, dataPath string).
        //            This list serves two purposes. 1) it provides dataPath
        //            for all being-edited documents and 2) it provides a list
        //            of all documents in which the editor is currently
        //            interested in (i.e. all open documents for the given
        //            language). Note that this list is *not* a list of files
        //            in a project. It is up to the backend to parse all files
        //            relevant to complete the file at path.
        // options:   a map of backend specific options.
        //
        // returns:   a list of RemoteDocument (path string, remotePath object).
        //            The returned list of remote documents is the subset of
        //            provided documents for which new information is available
        //            after parsing.
        //
        ParseAll(path string, cursor int64, documents []OpenDocument, options map[string]variant) []RemoteDocument
    }

    // All services must the Document interface on each document
    type org.gnome.CodeAssist.Document interface {
    }

    // The Diagnostics interface can be implemented on a document to provide
    // diagnostics after parsing.
    type org.gnome.CodeAssist.Diagnostics {
        // Obtain diagnostic information for the document. The return value
        // is a list of Diagnostic structs. Each diagnostic contains at least
        // a Severity level (e.g. Warning or Error), one or more SourceRange
        // locations on where the Diagnostic is located and a message. A
        // diagnostic can optionally also contain a list of Fixits which provide
        // hints on how to fix a particular problem. A Fixit consists of a
        // SourceRange location and a suggested replacement of that range.
        Diagnostics() []Diagnostic
    }

### Objects
A service for a language `X` is available on the dbus name `org.gnome.CodeAssist.X`.
It further makes available two objects. The first is located at `/org/gnome/CodeAssist/X`
and implements at least the `org.gnome.CodeAssist.Service` interface. It
can optionally also implement the `org.gnome.CodeAssist.Project` interface if
the language supports parsing multiple documents at once.

The second object that is made available is located at `/org/gnome/CodeAssist/X/document`
and represents an empty dummy document which can be introspected to find out
which services are implemented. All documents implement `org.gnome.CodeAssist.Document`,
but other services are optional.

### Types
    // (ua((x(xx)(xx))s)a(x(xx)(xx))s)
    type Diagnostic struct {
        Severity  Severity
        Fixits    []Fixit
        Locations []SourceRange
        Message   string
    }

    // u
    type Severity uint32 // None = 0, Info, Warning, Deprecated, Error, Fatal)

    // ((x(xx)(xx))s)
    type Fixit struct {
        Location SourceRange
        Message  string
    }

    // (x(xx)(xx))
    type SourceRange struct {
        File  int64
        Start SourceLocation
        End   SourceLocation
    }

    // (xx)
    type SourceLocation struct {
        Line   int64 // Starts at 1
        Column int64 // Starts at 1
    }

    // (so)
    type RemoteDocument struct {
        Path       string
        RemotePath object
    }

    // (ss)
    type OpenDocument struct {
        Path     string
        DataPath string
    }
