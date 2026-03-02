// SPDX-License-Identifier: MIT AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
SWOT Matrix Dashboard Example

Demonstrates:
- Tea.Layout for declarative CSS Grid/Flexbox layouts
- Tea.Sub.Animation for smooth transitions without dropped frames
- Quadrant-based layout for SWOT (Strengths, Weaknesses, Opportunities, Threats)
- Throttled animations during heavy recalculations
")

open Tea

// ============================================================================
// Types
// ============================================================================

type swotItem = {
  id: string,
  text: string,
  priority: int,
}

type quadrantData = {
  strengths: array<swotItem>,
  weaknesses: array<swotItem>,
  opportunities: array<swotItem>,
  threats: array<swotItem>,
}

type flipState =
  | Idle
  | Flipping(Layout.quadrant, float)

type model = {
  data: quadrantData,
  flipState: flipState,
  activeQuadrant: option<Layout.quadrant>,
  isAnimating: bool,
  lastFrameTime: float,
}

type msg =
  | StartFlip(Layout.quadrant)
  | AnimationFrame(float)
  | FlipComplete
  | SelectQuadrant(Layout.quadrant)
  | ClearSelection
  | AddItem(Layout.quadrant, string)

// ============================================================================
// Init
// ============================================================================

let sampleData: quadrantData = {
  strengths: [
    {id: "s1", text: "Strong CI/CD pipeline", priority: 1},
    {id: "s2", text: "Comprehensive test coverage", priority: 2},
    {id: "s3", text: "Active maintainer community", priority: 3},
  ],
  weaknesses: [
    {id: "w1", text: "Missing SBOM generation", priority: 1},
    {id: "w2", text: "Outdated dependencies", priority: 2},
  ],
  opportunities: [
    {id: "o1", text: "OpenSSF badge potential", priority: 1},
    {id: "o2", text: "Fuzzing integration possible", priority: 2},
    {id: "o3", text: "SLSA Level 3 achievable", priority: 3},
  ],
  threats: [
    {id: "t1", text: "Supply chain vulnerabilities", priority: 1},
    {id: "t2", text: "Unmaintained transitive deps", priority: 2},
  ],
}

let init = (): (model, Cmd.t<msg>) => {
  (
    {
      data: sampleData,
      flipState: Idle,
      activeQuadrant: None,
      isAnimating: false,
      lastFrameTime: 0.0,
    },
    Cmd.none,
  )
}

// ============================================================================
// Update
// ============================================================================

let update = (msg: msg, model: model): (model, Cmd.t<msg>) => {
  switch msg {
  | StartFlip(quadrant) => (
      {...model, flipState: Flipping(quadrant, 0.0), isAnimating: true},
      Cmd.none,
    )

  | AnimationFrame(timestamp) =>
    switch model.flipState {
    | Flipping(quadrant, progress) =>
      let newProgress = progress +. 0.02
      if newProgress >= 1.0 {
        ({...model, flipState: Idle, isAnimating: false, lastFrameTime: timestamp}, Cmd.none)
      } else {
        ({...model, flipState: Flipping(quadrant, newProgress), lastFrameTime: timestamp}, Cmd.none)
      }
    | Idle => ({...model, lastFrameTime: timestamp}, Cmd.none)
    }

  | FlipComplete => ({...model, flipState: Idle, isAnimating: false}, Cmd.none)

  | SelectQuadrant(quadrant) => ({...model, activeQuadrant: Some(quadrant)}, Cmd.none)

  | ClearSelection => ({...model, activeQuadrant: None}, Cmd.none)

  | AddItem(_quadrant, _text) => (model, Cmd.none)
  }
}

// ============================================================================
// View Components
// ============================================================================

let quadrantTitle = (quadrant: Layout.quadrant): string => {
  switch quadrant {
  | TopLeft => "Strengths"
  | TopRight => "Weaknesses"
  | BottomLeft => "Opportunities"
  | BottomRight => "Threats"
  }
}

let quadrantColor = (quadrant: Layout.quadrant): string => {
  switch quadrant {
  | TopLeft => "#22c55e"
  | TopRight => "#ef4444"
  | BottomLeft => "#3b82f6"
  | BottomRight => "#f59e0b"
  }
}

let itemView = (item: swotItem): React.element => {
  let itemStyle = Layout.combineStyles([
    Layout.flexRow(~gap=Layout.Px(8), ~justify=Layout.SpaceBetween, ()),
    Layout.withPadding(ReactDOM.Style.make(), Layout.Px(8)),
    Layout.withBackground(ReactDOM.Style.make(), "rgba(255,255,255,0.1)"),
    Layout.withBorderRadius(ReactDOM.Style.make(), Layout.Px(4)),
  ])

  <div key={item.id} style={itemStyle}>
    <span> {React.string(item.text)} </span>
    <span style={ReactDOM.Style.make(~opacity="0.6", ())}>
      {React.string(`P${Belt.Int.toString(item.priority)}`)}
    </span>
  </div>
}

let quadrantView = (
  quadrant: Layout.quadrant,
  items: array<swotItem>,
  isActive: bool,
  flipProgress: option<float>,
  dispatch: msg => unit,
): React.element => {
  let baseStyle = Layout.quadrantCellStyle(quadrant)
  let color = quadrantColor(quadrant)

  let transform = switch flipProgress {
  | Some(progress) =>
    let rotation = progress *. 360.0
    `perspective(1000px) rotateY(${Belt.Float.toString(rotation)}deg)`
  | None => "none"
  }

  let cellStyle = Layout.combineStyles([
    baseStyle,
    Layout.flexColumn(~gap=Layout.Px(12), ()),
    Layout.withPadding(ReactDOM.Style.make(), Layout.Px(16)),
    Layout.withBackground(ReactDOM.Style.make(), color),
    Layout.withBorderRadius(ReactDOM.Style.make(), Layout.Px(8)),
    ReactDOM.Style.make(
      ~transform,
      ~cursor="pointer",
      ~border=isActive ? "3px solid white" : "none",
      ~boxShadow=isActive ? "0 0 20px rgba(255,255,255,0.3)" : "none",
      ~transition="border 0.2s, box-shadow 0.2s",
      (),
    ),
  ])

  let headerStyle = Layout.spaceBetweenRow()

  <div
    style={cellStyle}
    onClick={_ => dispatch(SelectQuadrant(quadrant))}
    onDoubleClick={_ => dispatch(StartFlip(quadrant))}>
    <div style={headerStyle}>
      <h3 style={ReactDOM.Style.make(~margin="0", ~color="white", ())}>
        {React.string(quadrantTitle(quadrant))}
      </h3>
      <span style={ReactDOM.Style.make(~color="rgba(255,255,255,0.7)", ())}>
        {React.string(`(${Belt.Int.toString(Belt.Array.length(items))})`)}
      </span>
    </div>
    <div style={Layout.flexColumn(~gap=Layout.Px(8), ())}>
      {items->Belt.Array.map(itemView)->React.array}
    </div>
  </div>
}

// ============================================================================
// View
// ============================================================================

let view = (model: model, dispatch: msg => unit): React.element => {
  let containerStyle = Layout.combineStyles([
    Layout.dashboardContainerStyle(Layout.defaultDashboardConfig),
    ReactDOM.Style.make(~minHeight="100vh", ~backgroundColor="#1a1a2e", ()),
  ])

  let headerStyle = Layout.combineStyles([
    Layout.dashboardAreaStyle(Layout.Header),
    Layout.spaceBetweenRow(),
    Layout.withPadding(ReactDOM.Style.make(), Layout.Px(16)),
    Layout.withBackground(ReactDOM.Style.make(), "#16213e"),
  ])

  let sidebarStyle = Layout.combineStyles([
    Layout.dashboardAreaStyle(Layout.Sidebar),
    Layout.flexColumn(~gap=Layout.Px(16), ()),
    Layout.withPadding(ReactDOM.Style.make(), Layout.Px(16)),
    Layout.withBackground(ReactDOM.Style.make(), "#0f3460"),
  ])

  let mainStyle = Layout.combineStyles([
    Layout.dashboardAreaStyle(Layout.Main),
    Layout.withPadding(ReactDOM.Style.make(), Layout.Px(16)),
  ])

  let quadrantGridStyle = Layout.quadrantContainerStyle({
    ...Layout.defaultQuadrantConfig,
    gap: Some(Layout.Px(16)),
    minCellHeight: Some(Layout.Px(250)),
  })

  let getFlipProgress = (quadrant: Layout.quadrant): option<float> => {
    switch model.flipState {
    | Flipping(q, progress) if q == quadrant => Some(progress)
    | _ => None
    }
  }

  let isActive = (quadrant: Layout.quadrant): bool => {
    switch model.activeQuadrant {
    | Some(q) => q == quadrant
    | None => false
    }
  }

  <div style={containerStyle}>
    <header style={headerStyle}>
      <h1 style={ReactDOM.Style.make(~color="white", ~margin="0", ())}>
        {React.string("SWOT Dashboard")}
      </h1>
      <div style={Layout.flexRow(~gap=Layout.Px(16), ())}>
        <span style={ReactDOM.Style.make(~color="rgba(255,255,255,0.6)", ())}>
          {React.string(model.isAnimating ? "Animating..." : "Ready")}
        </span>
        {switch model.activeQuadrant {
        | Some(_) =>
          <button
            onClick={_ => dispatch(ClearSelection)}
            style={ReactDOM.Style.make(
              ~backgroundColor="#e94560",
              ~color="white",
              ~border="none",
              ~padding="8px 16px",
              ~borderRadius="4px",
              ~cursor="pointer",
              (),
            )}>
            {React.string("Clear Selection")}
          </button>
        | None => React.null
        }}
      </div>
    </header>
    <aside style={sidebarStyle}>
      <h3 style={ReactDOM.Style.make(~color="white", ~marginTop="0", ())}>
        {React.string("Controls")}
      </h3>
      <p style={ReactDOM.Style.make(~color="rgba(255,255,255,0.7)", ~fontSize="14px", ())}>
        {React.string("Click a quadrant to select. Double-click to flip.")}
      </p>
      <div style={Layout.flexColumn(~gap=Layout.Px(8), ())}>
        {[Layout.TopLeft, Layout.TopRight, Layout.BottomLeft, Layout.BottomRight]
        ->Belt.Array.map(q => {
          let btnStyle = ReactDOM.Style.make(
            ~backgroundColor=quadrantColor(q),
            ~color="white",
            ~border="none",
            ~padding="12px",
            ~borderRadius="4px",
            ~cursor="pointer",
            ~textAlign="left",
            (),
          )
          <button key={quadrantTitle(q)} style={btnStyle} onClick={_ => dispatch(StartFlip(q))}>
            {React.string(`Flip ${quadrantTitle(q)}`)}
          </button>
        })
        ->React.array}
      </div>
    </aside>
    <main style={mainStyle}>
      <div style={quadrantGridStyle}>
        {quadrantView(
          Layout.TopLeft,
          model.data.strengths,
          isActive(Layout.TopLeft),
          getFlipProgress(Layout.TopLeft),
          dispatch,
        )}
        {quadrantView(
          Layout.TopRight,
          model.data.weaknesses,
          isActive(Layout.TopRight),
          getFlipProgress(Layout.TopRight),
          dispatch,
        )}
        {quadrantView(
          Layout.BottomLeft,
          model.data.opportunities,
          isActive(Layout.BottomLeft),
          getFlipProgress(Layout.BottomLeft),
          dispatch,
        )}
        {quadrantView(
          Layout.BottomRight,
          model.data.threats,
          isActive(Layout.BottomRight),
          getFlipProgress(Layout.BottomRight),
          dispatch,
        )}
      </div>
    </main>
  </div>
}

// ============================================================================
// Subscriptions
// ============================================================================

let subscriptions = (model: model): Sub.t<msg> => {
  if model.isAnimating {
    Sub.Animation.throttledFrames(16.67, timestamp => AnimationFrame(timestamp))
  } else {
    Sub.none
  }
}

// ============================================================================
// App
// ============================================================================

module App = MakeWithDispatch({
  type model = model
  type msg = msg
  let app = {
    init: () => init(),
    update,
    view,
    subscriptions,
  }
})
