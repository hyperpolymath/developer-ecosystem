// SPDX-License-Identifier: PMPL-1.0-or-later
// Main Creation Engine for ReScript

open Pixi

// Manifest type
type bundleItem = {name: string}
type manifest = {bundles: array<bundleItem>}

// Import manifest
@module("../manifest.json") external manifest: manifest = "default"

// Resize options
type resizeOptions = {
  minWidth: float,
  minHeight: float,
  letterbox: bool,
}

// Engine state
type t = {
  app: Application.t,
  audio: Audio.audioManager,
  navigation: Navigation.t,
  mutable resizeOptions: resizeOptions,
  mutable visibilityHandler: option<Pixi.event => unit>,
}

// Create a new engine
let make = (): t => {
  app: Application.make(),
  audio: Audio.makeAudioManager(),
  navigation: Navigation.make(),
  resizeOptions: {
    minWidth: 768.0,
    minHeight: 1024.0,
    letterbox: true,
  },
  visibilityHandler: None,
}

// Visibility change handler
let createVisibilityHandler = (engine: t): (Pixi.event => unit) => {
  (_: Pixi.event) => {
    if Pixi.hidden(Pixi.document) {
      PixiSound.pauseAll()
      Navigation.blur(engine.navigation)
    } else {
      PixiSound.resumeAll()
      Navigation.focus(engine.navigation)
    }
  }
}

// Helper to set canvas CSS size
let setCanvasSize: (Pixi.htmlCanvasElement, int, int) => unit = %raw(`
  function(canvas, width, height) {
    canvas.style.width = width + "px";
    canvas.style.height = height + "px";
    window.scrollTo(0, 0);
  }
`)

// Resize handler
let handleResize = (engine: t): unit => {
  let width = Pixi.innerWidth(Pixi.window)
  let height = Pixi.innerHeight(Pixi.window)

  let _result = Resize.resize(
    ~w=Int.toFloat(width),
    ~h=Int.toFloat(height),
    ~minWidth=engine.resizeOptions.minWidth,
    ~minHeight=engine.resizeOptions.minHeight,
    ~letterbox=engine.resizeOptions.letterbox,
  )

  let renderer = Application.renderer(engine.app)

  // Resize renderer - autoDensity handles CSS sizing
  Renderer.resize(renderer, Int.toFloat(width), Int.toFloat(height))

  // Notify navigation of resize with actual window dimensions
  Navigation.resize(engine.navigation, Int.toFloat(width), Int.toFloat(height))
}

// Initialize the engine
let init = async (
  engine: t,
  ~background: string,
  ~resizeOptions: resizeOptions,
): unit => {
  engine.resizeOptions = resizeOptions

  let resolution = GetResolution.getResolution()

  await Application.init(
    engine.app,
    {
      "background": background,
      "resizeTo": Pixi.window,
      "resolution": resolution,
      "autoDensity": true,
    },
  )

  // Enable interactions on stage
  let stage = Application.stage(engine.app)
  Container.setEventMode(stage, "static")
  Container.setInteractiveChildren(stage, true)

  // Append canvas to container
  let container = Pixi.getElementById(Pixi.document, "pixi-container")
  switch container->Nullable.toOption {
  | Some(el) =>
    Pixi.appendChild(el, Application.canvas(engine.app))
  | None => ()
  }

  // Initialize navigation
  Navigation.init(engine.navigation, engine.app)

  // Setup visibility handler
  let handler = createVisibilityHandler(engine)
  engine.visibilityHandler = Some(handler)
  Pixi.addEventListener(Pixi.document, "visibilitychange", handler)

  // Setup resize handler using proper binding
  let setupResizeListener: (unit => unit) => unit = %raw(`
    function(handler) {
      window.addEventListener("resize", handler);
    }
  `)
  setupResizeListener(() => handleResize(engine))
  handleResize(engine)

  // Init assets
  await Assets.init({"manifest": manifest, "basePath": "assets"})
  await Assets.loadBundleString("preload")

  // Background load all bundles
  let allBundles = Array.map(manifest.bundles, item => item.name)
  Assets.backgroundLoadBundle(allBundles)
}

// Destroy the engine
let destroy = (engine: t): unit => {
  switch engine.visibilityHandler {
  | Some(handler) =>
    Pixi.removeEventListener(Pixi.document, "visibilitychange", handler)
  | None => ()
  }
  Application.destroy(engine.app, ~removeView=true)
}
