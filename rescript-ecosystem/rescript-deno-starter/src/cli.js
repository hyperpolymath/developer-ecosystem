#!/usr/bin/env -S deno run --allow-run --allow-read --allow-write --allow-env --allow-net
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
//
// rescript-deno — Start ReScript projects with Deno, not npm.
//
// Wraps the ReScript compiler to work natively with Deno's module system.
// No npm, no node_modules (unless --node-modules-dir is needed for ReScript).
//
// Usage:
//   deno run --allow-run --allow-read --allow-write --allow-env --allow-net jsr:@hyperpolymath/rescript-deno init my-app
//   deno run --allow-run --allow-read --allow-write --allow-env --allow-net jsr:@hyperpolymath/rescript-deno build
//   deno run --allow-run --allow-read --allow-write --allow-env --allow-net jsr:@hyperpolymath/rescript-deno dev
//   deno run --allow-run --allow-read --allow-write --allow-env --allow-net jsr:@hyperpolymath/rescript-deno clean

const VERSION = "1.0.0";

// --- Templates ---

const DENO_JSON_TEMPLATE = `{
  "imports": {
    "@rescript/core": "npm:@rescript/core@1.6.1",
    "@rescript/runtime": "npm:@rescript/runtime@12.2.0",
    "rescript": "npm:rescript@12.2.0"
  },
  "tasks": {
    "res:build": "deno run --node-modules-dir=auto --allow-read --allow-write --allow-env --allow-run npm:rescript@12.2.0",
    "res:dev": "deno run --node-modules-dir=auto --allow-read --allow-write --allow-env --allow-run npm:rescript@12.2.0 -w",
    "res:clean": "deno run --node-modules-dir=auto --allow-read --allow-write --allow-env --allow-run npm:rescript@12.2.0 clean",
    "dev": "deno task res:dev",
    "build": "deno task res:build"
  }
}
`;

const RESCRIPT_JSON_TEMPLATE = `{
  "name": "{{NAME}}",
  "sources": [{"dir": "src", "subdirs": true}],
  "package-specs": [{"module": "esmodule", "in-source": true}],
  "suffix": ".res.mjs",
  "compiler-flags": ["-open RescriptCore"],
  "dependencies": ["@rescript/core"]
}
`;

const MAIN_RES_TEMPLATE = `// SPDX-License-Identifier: PMPL-1.0-or-later
// {{NAME}} — entry point

let greeting = "Hello from ReScript on Deno!"

Console.log(greeting)
Console.log("No npm required.")
`;

const GITIGNORE_TEMPLATE = `node_modules/
.deno/
*.res.mjs
lib/
`;

// --- Commands ---

async function init(name) {
  if (!name) {
    console.error("Usage: rescript-deno init <project-name>");
    Deno.exit(1);
  }

  console.log(`Creating ReScript + Deno project: ${name}`);

  await Deno.mkdir(`${name}/src`, { recursive: true });

  await Deno.writeTextFile(`${name}/deno.json`, DENO_JSON_TEMPLATE);
  await Deno.writeTextFile(
    `${name}/rescript.json`,
    RESCRIPT_JSON_TEMPLATE.replaceAll("{{NAME}}", name)
  );
  await Deno.writeTextFile(
    `${name}/src/Main.res`,
    MAIN_RES_TEMPLATE.replaceAll("{{NAME}}", name)
  );
  await Deno.writeTextFile(`${name}/.gitignore`, GITIGNORE_TEMPLATE);

  console.log(`
Done! Next steps:

  cd ${name}
  deno task build    # compile ReScript
  deno run src/Main.res.mjs  # run it

No npm install needed. Deno handles everything.
`);
}

async function build() {
  console.log("[rescript-deno] Building...");
  const cmd = new Deno.Command("deno", {
    args: [
      "run",
      "--node-modules-dir=auto",
      "--allow-read",
      "--allow-write",
      "--allow-env",
      "--allow-run",
      "npm:rescript@12.2.0",
    ],
    stdout: "inherit",
    stderr: "inherit",
  });
  const { code } = await cmd.output();
  Deno.exit(code);
}

async function dev() {
  console.log("[rescript-deno] Starting watch mode...");
  const cmd = new Deno.Command("deno", {
    args: [
      "run",
      "--node-modules-dir=auto",
      "--allow-read",
      "--allow-write",
      "--allow-env",
      "--allow-run",
      "npm:rescript@12.2.0",
      "-w",
    ],
    stdout: "inherit",
    stderr: "inherit",
  });
  const { code } = await cmd.output();
  Deno.exit(code);
}

async function clean() {
  console.log("[rescript-deno] Cleaning build artifacts...");
  const cmd = new Deno.Command("deno", {
    args: [
      "run",
      "--node-modules-dir=auto",
      "--allow-read",
      "--allow-write",
      "--allow-env",
      "--allow-run",
      "npm:rescript@12.2.0",
      "clean",
    ],
    stdout: "inherit",
    stderr: "inherit",
  });
  const { code } = await cmd.output();
  Deno.exit(code);
}

// --- Main ---

const command = Deno.args[0];

switch (command) {
  case "init":
    await init(Deno.args[1]);
    break;
  case "build":
    await build();
    break;
  case "dev":
    await dev();
    break;
  case "clean":
    await clean();
    break;
  case "--version":
  case "-v":
    console.log(`rescript-deno ${VERSION}`);
    break;
  case "--help":
  case "-h":
  case undefined:
    console.log(`
rescript-deno ${VERSION} — ReScript on Deno, no npm required

Commands:
  init <name>   Create a new ReScript + Deno project
  build         Compile ReScript sources
  dev           Watch mode (recompile on change)
  clean         Remove build artifacts
  --version     Show version
  --help        Show this help

Example:
  rescript-deno init my-app
  cd my-app
  deno task build
  deno run src/Main.res.mjs
`);
    break;
  default:
    console.error(`Unknown command: ${command}. Use --help for usage.`);
    Deno.exit(1);
}
