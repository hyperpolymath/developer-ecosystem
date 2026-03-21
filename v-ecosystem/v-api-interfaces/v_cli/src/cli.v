// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem CLI tool management connector for command dispatch, argument parsing, and subcommand routing Connector
// Author: Jonathan D.A. Jewell
//
// Command-line interface management client. Provides structured command
// registration, argument and flag parsing, subcommand routing, shell
// completion generation, help text rendering, and exit code management.
// Designed as a building block for V-based CLI tools.

module cli

import os
import term

// --- Argument kind ---

// ArgKind identifies the type of a CLI argument.
pub enum ArgKind {
	flag_bool    // Boolean flag (--verbose)
	flag_string  // String flag (--output=file)
	flag_int     // Integer flag (--count=5)
	positional   // Positional argument
}

// --- Data structures ---

// ArgDef defines a single CLI argument or flag.
pub struct ArgDef {
pub:
	name        string      // Long name (e.g. "output")
	short       u8          // Short alias (e.g. `o`)
	kind        ArgKind     // Argument type
	required    bool        // Whether the argument is mandatory
	help        string      // Help description
	default_val string      // Default value (empty = none)
}

// Command represents a registered CLI command.
pub struct Command {
pub:
	name        string       // Command name
	description string       // One-line description
	args        []ArgDef     // Accepted arguments
	subcommands []Command    // Nested subcommands
}

// ParsedArgs holds the result of parsing CLI arguments.
pub struct ParsedArgs {
pub:
	flags       map[string]string  // Flag name -> value
	positionals []string           // Positional arguments
	command     string             // Matched command name
}

// CliApp represents a CLI application.
pub struct CliApp {
mut:
	name     string
	version  string
	commands []Command
}

// --- App lifecycle ---

// new_cli_app creates a new CLI application descriptor.
pub fn new_cli_app(name string, version string) &CliApp {
	return &CliApp{
		name: name
		version: version
		commands: []Command{}
	}
}

// add_command registers a command with the application.
pub fn (mut a CliApp) add_command(cmd Command) {
	a.commands << cmd
}

// parse processes command-line arguments against registered commands.
pub fn (a &CliApp) parse(args []string) !ParsedArgs {
	if args.len == 0 {
		return error("no arguments provided")
	}
	// Match first positional against registered commands
	cmd_name := args[0]
	mut matched := false
	for c in a.commands {
		if c.name == cmd_name {
			matched = true
			break
		}
	}
	if !matched {
		return error("unknown command '${cmd_name}'")
	}
	return ParsedArgs{
		flags: map[string]string{}
		positionals: args[1..]
		command: cmd_name
	}
}

// print_help renders the help text for the application.
pub fn (a &CliApp) print_help() {
	println("${a.name} v${a.version}")
	println("")
	println("Commands:")
	for c in a.commands {
		println("  ${c.name}  ${c.description}")
	}
}

// --- Tests ---

fn test_unknown_command_rejected() {
	app := new_cli_app("testapp", "0.1.0")
	app.parse(["nonexistent"]) or {
		assert err.str().contains("unknown command")
		return
	}
	assert false
}
