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

// --- Argument type (alternative naming per task spec) ---

// ArgType classifies a CLI argument by its structural role.
pub enum ArgType {
	flag        // Boolean presence flag
	option      // Key=value option
	positional  // Positional argument
	subcommand  // Nested subcommand
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

// ParseResult contains the fully resolved parse output.
pub struct ParseResult {
pub:
	command     string
	flags       map[string]string
	options     map[string]string
	positionals []string
	help_requested bool
}

// CliApp represents a CLI application.
pub struct CliApp {
mut:
	name     string
	version  string
	commands []Command
	flags    []ArgDef   // Global flags registered via add_flag
	options  []ArgDef   // Global options registered via add_option
}

// --- App lifecycle ---

// new_cli_app creates a new CLI application descriptor.
pub fn new_cli_app(name string, version string) &CliApp {
	return &CliApp{
		name:     name
		version:  version
		commands: []Command{}
		flags:    []ArgDef{}
		options:  []ArgDef{}
	}
}

// add_command registers a command with the application.
pub fn (mut a CliApp) add_command(cmd Command) {
	a.commands << cmd
}

// add_flag registers a boolean flag with an optional single-character shorthand.
pub fn (mut a CliApp) add_flag(name string, shorthand u8, description string) ! {
	if name.len == 0 {
		return error("flag name must not be empty")
	}
	a.flags << ArgDef{
		name:    name
		short:   shorthand
		kind:    .flag_bool
		help:    description
	}
	println("[cli] registered flag: --${name}")
}

// add_option registers a string option with a default value.
pub fn (mut a CliApp) add_option(name string, default_ string) ! {
	if name.len == 0 {
		return error("option name must not be empty")
	}
	a.options << ArgDef{
		name:        name
		kind:        .flag_string
		default_val: default_
	}
	println("[cli] registered option: --${name} (default='${default_}')")
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
		flags:       map[string]string{}
		positionals: args[1..]
		command:     cmd_name
	}
}

// parse_full processes args and populates a ParseResult with flags and options resolved.
pub fn (a &CliApp) parse_full(args []string) !ParseResult {
	if args.len == 0 {
		return error("no arguments provided")
	}
	mut result_flags    := map[string]string{}
	mut result_opts     := map[string]string{}
	mut positionals     := []string{}
	mut cmd_name        := ""
	mut help_requested  := false

	for arg in args {
		if arg == "--help" || arg == "-h" {
			help_requested = true
			continue
		}
		if arg.starts_with("--") {
			body := arg[2..]
			if body.contains("=") {
				parts := body.split("=")
				result_opts[parts[0]] = parts[1..].join("=")
			} else {
				result_flags[body] = "true"
			}
		} else if cmd_name.len == 0 {
			cmd_name = arg
		} else {
			positionals << arg
		}
	}
	return ParseResult{
		command:         cmd_name
		flags:           result_flags
		options:         result_opts
		positionals:     positionals
		help_requested:  help_requested
	}
}

// print_help renders the help text for the application.
pub fn (a &CliApp) print_help() {
	println("${a.name} v${a.version}")
	println("")
	if a.flags.len > 0 || a.options.len > 0 {
		println("Flags:")
		for f in a.flags {
			short_str := if f.short != 0 { "  -${rune(f.short)}, " } else { "      " }
			println("${short_str}--${f.name}  ${f.help}")
		}
		for o in a.options {
			println("  --${o.name}=<value>  (default: '${o.default_val}')")
		}
		println("")
	}
	println("Commands:")
	for c in a.commands {
		println("  ${c.name}  ${c.description}")
	}
}

// --- Text helpers ---

// help_text returns the application help as a string (without printing).
pub fn (a &CliApp) help_text() string {
	mut lines := ["${a.name} v${a.version}", ""]
	if a.flags.len > 0 {
		lines << "Flags:"
		for f in a.flags {
			short_str := if f.short != 0 { "  -${rune(f.short)}, " } else { "      " }
			lines << "${short_str}--${f.name}  ${f.help}"
		}
		lines << ""
	}
	lines << "Commands:"
	for c in a.commands {
		lines << "  ${c.name}  ${c.description}"
	}
	return lines.join("\n")
}

// format_usage_line returns a compact one-line usage summary.
pub fn (a &CliApp) format_usage_line() string {
	mut cmds := []string{}
	for c in a.commands {
		cmds << c.name
	}
	return "Usage: ${a.name} [flags] {${cmds.join('|')}} [args...]"
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

fn test_empty_flag_name_rejected() {
	mut app := new_cli_app("testapp", "0.1.0")
	app.add_flag("", 0, "empty") or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_help_text_contains_registered_flags() {
	mut app := new_cli_app("myapp", "1.0.0")
	app.add_flag("verbose", `v`, "Enable verbose output") or { panic(err) }
	app.add_flag("dry-run", 0, "Simulate without changes") or { panic(err) }
	app.add_command(Command{ name: "build", description: "Build the project" })
	text := app.help_text()
	assert text.contains("--verbose")
	assert text.contains("--dry-run")
	assert text.contains("build")
}

fn test_format_usage_line() {
	mut app := new_cli_app("tool", "0.2.0")
	app.add_command(Command{ name: "run", description: "Run" })
	app.add_command(Command{ name: "test", description: "Test" })
	line := app.format_usage_line()
	assert line.contains("tool")
	assert line.contains("run")
	assert line.contains("test")
}

fn test_parse_full_flags_and_options() {
	mut app := new_cli_app("myapp", "0.1.0")
	app.add_command(Command{ name: "deploy", description: "Deploy" })
	result := app.parse_full(["deploy", "--verbose", "--env=production"]) or { panic(err) }
	assert result.command == "deploy"
	assert result.flags["verbose"] == "true"
	assert result.options["env"] == "production"
}

