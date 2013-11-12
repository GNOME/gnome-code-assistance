package main

import (
	"fmt"
	"github.com/jessevdk/go-flags"
	"os"
)

type TransportConstructor func() (Transport, error)

const defaultTransport = "dbus"

var transports = map[string]TransportConstructor{}

func RegisterTransport(name string, constructor TransportConstructor) {
	transports[name] = constructor
}

type CmdOptions struct {
	Transport string `short:"t" long:"transport" description:"Set transport (dbus or http)"`
	Address   string `short:"a" long:"address" description:"Transport address (for http)" default:":7676"`
}

var cmdoptions CmdOptions

func main() {
	cmdoptions.Transport = defaultTransport

	if _, err := flags.Parse(&cmdoptions); err != nil {
		os.Exit(1)
	}

	tc := transports[cmdoptions.Transport]

	if tc == nil {
		fmt.Fprintf(os.Stderr, "Unknown transport: %s\n", cmdoptions.Transport)
		os.Exit(1)
	}

	t, err := tc()

	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	t.Run()
}
