// SPDX-License-Identifier: AGPL-3.0-or-later
// Build orchestration for ReScript + Deno/Bun

type buildMode =
  | Development
  | Production

type buildConfig = {
  mode: buildMode,
  entry: string,
  outDir: string,
  minify: bool,
  sourceMaps: bool,
  target: Detect.runtime,
}

type buildResult = {
  success: bool,
  duration: float,
  outputFiles: array<string>,
  errors: array<string>,
  warnings: array<string>,
}

let defaultConfig: buildConfig = {
  mode: Development,
  entry: "src/Main.res",
  outDir: "dist",
  minify: false,
  sourceMaps: true,
  target: Detect.detect(),
}

let productionConfig: buildConfig = {
  ...defaultConfig,
  mode: Production,
  minify: true,
  sourceMaps: false,
}

// ReScript compilation
module ReScript = {
  let build = async (~watch: bool=false): bool => {
    let args = watch ? ["build", "-w"] : ["build"]
    await Dev.runCommand("npx", ["rescript"]->Js.Array2.concat(args))
  }

  let clean = async (): bool => {
    await Dev.runCommand("npx", ["rescript", "clean"])
  }

  let format = async (): bool => {
    await Dev.runCommand("npx", ["rescript", "format", "-all"])
  }
}

// Deno-specific bundling
module DenoBundler = {
  @scope("Deno") @val
  external emit: string => promise<{"files": Js.Dict.t<string>}> = "emit"

  let bundle = async (entry: string, outFile: string): bool => {
    // Use deno compile or esbuild via Deno
    let args = ["bundle", "--output=" ++ outFile, entry]
    await Dev.runCommand("deno", args)
  }
}

// Bun-specific bundling
module BunBundler = {
  type buildOutput = {
    success: bool,
    outputs: array<{."path": string}>,
    logs: array<string>,
  }

  @scope("Bun") @val
  external build: {
    "entrypoints": array<string>,
    "outdir": string,
    "minify": bool,
    "sourcemap": string,
    "target": string,
  } => promise<buildOutput> = "build"

  let bundle = async (config: buildConfig): buildResult => {
    let startTime = Js.Date.now()
    try {
      let result = await build({
        "entrypoints": [config.entry],
        "outdir": config.outDir,
        "minify": config.minify,
        "sourcemap": config.sourceMaps ? "external" : "none",
        "target": "bun",
      })
      {
        success: result.success,
        duration: Js.Date.now() -. startTime,
        outputFiles: result.outputs->Js.Array2.map(o => o["path"]),
        errors: [],
        warnings: [],
      }
    } catch {
    | Js.Exn.Error(e) => {
        success: false,
        duration: Js.Date.now() -. startTime,
        outputFiles: [],
        errors: [Js.Exn.message(e)->Belt.Option.getWithDefault("Build failed")],
        warnings: [],
      }
    }
  }
}

// Unified build command
let build = async (config: buildConfig): buildResult => {
  let startTime = Js.Date.now()
  Js.Console.log("🔨 Building...")

  // Step 1: Compile ReScript
  let rescriptOk = await ReScript.build()
  if !rescriptOk {
    return {
      success: false,
      duration: Js.Date.now() -. startTime,
      outputFiles: [],
      errors: ["ReScript compilation failed"],
      warnings: [],
    }
  }

  // Step 2: Bundle for target runtime
  let result = switch config.target {
  | Detect.Deno => {
      let entryJs = config.entry->Js.String2.replace(".res", ".res.js")
      let outFile = config.outDir ++ "/bundle.js"
      let ok = await DenoBundler.bundle(entryJs, outFile)
      {
        success: ok,
        duration: Js.Date.now() -. startTime,
        outputFiles: ok ? [outFile] : [],
        errors: ok ? [] : ["Deno bundling failed"],
        warnings: [],
      }
    }
  | Detect.Bun => await BunBundler.bundle(config)
  | _ => {
      // Fallback: just use compiled ReScript output
      success: true,
      duration: Js.Date.now() -. startTime,
      outputFiles: [config.entry->Js.String2.replace(".res", ".res.js")],
      errors: [],
      warnings: ["No bundler available for this runtime"],
    }
  }

  if result.success {
    Js.Console.log(`✅ Build complete in ${result.duration->Js.Float.toFixedWithPrecision(~digits=0)}ms`)
    result.outputFiles->Js.Array2.forEach(f => Js.Console.log(`   📄 ${f}`))
  } else {
    Js.Console.error("❌ Build failed")
    result.errors->Js.Array2.forEach(e => Js.Console.error(`   ${e}`))
  }

  result
}

// Watch mode
let watch = async (config: buildConfig): unit => {
  Js.Console.log("👀 Watching for changes...")
  let _ = await ReScript.build(~watch=true)
}

// Clean build artifacts
let clean = async (): unit => {
  Js.Console.log("🧹 Cleaning...")
  let _ = await ReScript.clean()
  Js.Console.log("✅ Clean complete")
}

// Format all ReScript files
let format = async (): unit => {
  Js.Console.log("✨ Formatting...")
  let ok = await ReScript.format()
  if ok {
    Js.Console.log("✅ Format complete")
  } else {
    Js.Console.error("❌ Format failed")
  }
}
