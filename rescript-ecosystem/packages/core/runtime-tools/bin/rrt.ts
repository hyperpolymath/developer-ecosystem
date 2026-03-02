#!/usr/bin/env -S deno run --allow-read --allow-write --allow-run --allow-net --allow-env
// SPDX-License-Identifier: AGPL-3.0-or-later
// rrt - ReScript Runtime Tools CLI
// Works on both Deno and Bun

const VERSION = "0.1.0";

// Detect runtime
const isDeno = typeof (globalThis as any).Deno !== "undefined";
const isBun = typeof (globalThis as any).Bun !== "undefined";
const runtime = isDeno ? "deno" : isBun ? "bun" : "unknown";

// Colors for terminal output
const colors = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m",
};

const c = (color: keyof typeof colors, text: string) =>
  `${colors[color]}${text}${colors.reset}`;

// Help text
const HELP = `
${c("bold", "rrt")} - ReScript Runtime Tools v${VERSION}
${c("dim", `Running on ${runtime}`)}

${c("yellow", "USAGE:")}
  rrt <command> [options]

${c("yellow", "COMMANDS:")}
  ${c("green", "dev")}      Start dev server with watch mode
  ${c("green", "build")}    Build for production
  ${c("green", "test")}     Run tests
  ${c("green", "bench")}    Run benchmarks
  ${c("green", "fmt")}      Format ReScript files
  ${c("green", "clean")}    Clean build artifacts
  ${c("green", "info")}     Show runtime info

${c("yellow", "OPTIONS:")}
  -p, --port <port>    Dev server port (default: 8000)
  -h, --host <host>    Dev server host (default: 127.0.0.1)
  --prod               Production build
  --watch              Watch mode
  --help               Show this help
  --version            Show version

${c("yellow", "EXAMPLES:")}
  rrt dev                  # Start dev server
  rrt dev -p 3000          # Dev server on port 3000
  rrt build --prod         # Production build
  rrt test                 # Run all tests
  rrt test --watch         # Watch mode testing
`;

// Parse command line args
function parseArgs(args: string[]): {
  command: string;
  options: Record<string, string | boolean>;
} {
  const command = args[0] || "help";
  const options: Record<string, string | boolean> = {};

  for (let i = 1; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--help" || arg === "-h") {
      options.help = true;
    } else if (arg === "--version" || arg === "-v") {
      options.version = true;
    } else if (arg === "--prod") {
      options.prod = true;
    } else if (arg === "--watch" || arg === "-w") {
      options.watch = true;
    } else if ((arg === "-p" || arg === "--port") && args[i + 1]) {
      options.port = args[++i];
    } else if ((arg === "-h" || arg === "--host") && args[i + 1]) {
      options.host = args[++i];
    }
  }

  return { command, options };
}

// Run shell command
async function run(cmd: string, args: string[]): Promise<boolean> {
  if (isDeno) {
    const command = new (globalThis as any).Deno.Command(cmd, { args });
    const { success } = await command.output();
    return success;
  } else if (isBun) {
    const proc = (globalThis as any).Bun.spawn([cmd, ...args]);
    const code = await proc.exited;
    return code === 0;
  }
  return false;
}

// Run rescript via Deno's npm: specifier (no npm install needed)
async function runRescript(args: string[]): Promise<boolean> {
  if (isDeno) {
    return run("deno", ["run", "-A", "npm:rescript", ...args]);
  } else if (isBun) {
    // Bun can run npm packages directly
    return run("bunx", ["rescript", ...args]);
  }
  return false;
}

// Commands
async function cmdDev(options: Record<string, string | boolean>) {
  const port = options.port || "8000";
  const host = options.host || "127.0.0.1";

  console.log(c("cyan", `\n🚀 Starting dev server on ${runtime}...`));
  console.log(c("dim", `   http://${host}:${port}\n`));

  // Start ReScript watcher in background (no npm needed)
  console.log(c("yellow", "📦 Starting ReScript compiler..."));

  if (isDeno) {
    // Deno: use npm: specifier directly - no node_modules
    const rescriptCmd = new (globalThis as any).Deno.Command("deno", {
      args: ["run", "-A", "npm:rescript", "build", "-w"],
      stdout: "inherit",
      stderr: "inherit",
    });
    rescriptCmd.spawn();
  } else if (isBun) {
    // Bun: use bunx for npm packages
    (globalThis as any).Bun.spawn(["bunx", "rescript", "build", "-w"], {
      stdout: "inherit",
      stderr: "inherit",
    });
  }

  // Give ReScript a moment to start
  await new Promise((r) => setTimeout(r, 1000));

  // Run the entry file with watch
  console.log(c("green", "\n👀 Watching for changes...\n"));

  if (isDeno) {
    await run("deno", [
      "run",
      "--watch",
      "--allow-all",
      "src/Main.res.js",
    ]);
  } else if (isBun) {
    await run("bun", ["--watch", "src/Main.res.js"]);
  }
}

async function cmdBuild(options: Record<string, string | boolean>) {
  const isProd = options.prod === true;
  console.log(
    c("cyan", `\n🔨 Building for ${isProd ? "production" : "development"}...`)
  );

  // Clean first in prod
  if (isProd) {
    await runRescript(["clean"]);
  }

  // Build ReScript (no npm install needed)
  const success = await runRescript(["build"]);
  if (!success) {
    console.error(c("red", "❌ ReScript build failed"));
    if (isDeno) (globalThis as any).Deno.exit(1);
    if (isBun) process.exit(1);
  }

  console.log(c("green", "✅ Build complete\n"));
}

async function cmdTest(options: Record<string, string | boolean>) {
  console.log(c("cyan", `\n🧪 Running tests on ${runtime}...\n`));

  const watchFlag = options.watch ? ["--watch"] : [];

  if (isDeno) {
    await run("deno", [
      "test",
      "--allow-all",
      ...watchFlag,
      "tests/",
    ]);
  } else if (isBun) {
    await run("bun", ["test", ...watchFlag]);
  }
}

async function cmdBench(_options: Record<string, string | boolean>) {
  console.log(c("cyan", `\n⚡ Running benchmarks on ${runtime}...\n`));

  if (isDeno) {
    await run("deno", ["bench", "--allow-all", "bench/"]);
  } else if (isBun) {
    // Bun doesn't have built-in bench, use a script
    await run("bun", ["run", "bench/index.ts"]);
  }
}

async function cmdFmt(_options: Record<string, string | boolean>) {
  console.log(c("cyan", "\n✨ Formatting...\n"));
  await runRescript(["format", "-all"]);
  console.log(c("green", "✅ Format complete\n"));
}

async function cmdClean(_options: Record<string, string | boolean>) {
  console.log(c("cyan", "\n🧹 Cleaning...\n"));
  await runRescript(["clean"]);
  console.log(c("green", "✅ Clean complete\n"));
}

function cmdInfo() {
  const info = {
    runtime,
    version: isDeno
      ? (globalThis as any).Deno.version.deno
      : isBun
        ? (globalThis as any).Bun.version
        : "unknown",
    platform: isDeno
      ? (globalThis as any).Deno.build.os
      : process?.platform || "unknown",
    arch: isDeno
      ? (globalThis as any).Deno.build.arch
      : process?.arch || "unknown",
  };

  console.log(c("cyan", "\n📋 Runtime Info\n"));
  console.log(`  Runtime:  ${c("green", info.runtime)} v${info.version}`);
  console.log(`  Platform: ${info.platform}`);
  console.log(`  Arch:     ${info.arch}`);
  console.log(`  rrt:      v${VERSION}\n`);
}

// Main
async function main() {
  const args = isDeno
    ? (globalThis as any).Deno.args
    : isBun
      ? process.argv.slice(2)
      : [];

  const { command, options } = parseArgs(args);

  if (options.version) {
    console.log(`rrt v${VERSION} (${runtime})`);
    return;
  }

  if (options.help || command === "help") {
    console.log(HELP);
    return;
  }

  switch (command) {
    case "dev":
      await cmdDev(options);
      break;
    case "build":
      await cmdBuild(options);
      break;
    case "test":
      await cmdTest(options);
      break;
    case "bench":
      await cmdBench(options);
      break;
    case "fmt":
    case "format":
      await cmdFmt(options);
      break;
    case "clean":
      await cmdClean(options);
      break;
    case "info":
      cmdInfo();
      break;
    default:
      console.error(c("red", `Unknown command: ${command}`));
      console.log(c("dim", "Run 'rrt --help' for usage"));
      if (isDeno) (globalThis as any).Deno.exit(1);
      if (isBun) process.exit(1);
  }
}

main();
