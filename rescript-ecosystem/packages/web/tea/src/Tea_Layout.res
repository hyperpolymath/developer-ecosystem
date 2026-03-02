// SPDX-License-Identifier: MIT AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

open ReactDOM

module Style = {
  include ReactDOM.Style
  @obj external make: (
    ~display: string=?,
    ~flexDirection: string=?,
    ~flexWrap: string=?,
    ~justifyContent: string=?,
    ~alignItems: string=?,
    ~alignContent: string=?,
    ~flexGrow: string=?,
    ~flexShrink: string=?,
    ~flexBasis: string=?,
    ~alignSelf: string=?,
    ~gridTemplateColumns: string=?,
    ~gridTemplateRows: string=?,
    ~gridTemplateAreas: string=?,
    ~gridArea: string=?,
    ~gridGap: string=?,
    ~gridRowGap: string=?,
    ~gridColumnGap: string=?,
    ~gridAutoFlow: string=?,
    ~gridAutoRows: string=?,
    ~gridAutoColumns: string=?,
    ~gridRowStart: string=?,
    ~gridRowEnd: string=?,
    ~gridColumnStart: string=?,
    ~gridColumnEnd: string=?,
    ~gap: string=?,
    ~rowGap: string=?,
    ~columnGap: string=?,
    ~justifyItems: string=?,
    ~justifySelf: string=?,
    ~width: string=?,
    ~height: string=?,
    ~minHeight: string=?,
    ~padding: string=?,
    ~margin: string=?,
    ~background: string=?,
    ~backgroundColor: string=?,
    ~borderRadius: string=?,
    ~order: string=?,
    ~aspectRatio: string=?,
    unit,
  ) => t = ""
}

@@ocaml.doc("
Type-safe CSS Grid and Flexbox layout engine for TEA applications.
Provides declarative layout primitives that eliminate brittle manual class manipulation.
Ideal for complex dashboards and SWOT-style matrix layouts.
")

// ============================================================================
// CSS Unit Types
// ============================================================================

@ocaml.doc("CSS length unit for dimensions")
type cssLength =
  | Px(int)
  | Rem(float)
  | Em(float)
  | Percent(float)
  | Vh(float)
  | Vw(float)
  | Fr(float)
  | MinContent
  | MaxContent
  | Auto

@ocaml.doc("Convert CSS length to string")
let lengthToString = (length: cssLength): string => {
  switch length {
  | Px(n) => `${Belt.Int.toString(n)}px`
  | Rem(n) => `${Belt.Float.toString(n)}rem`
  | Em(n) => `${Belt.Float.toString(n)}em`
  | Percent(n) => `${Belt.Float.toString(n)}%`
  | Vh(n) => `${Belt.Float.toString(n)}vh`
  | Vw(n) => `${Belt.Float.toString(n)}vw`
  | Fr(n) => `${Belt.Float.toString(n)}fr`
  | MinContent => "min-content"
  | MaxContent => "max-content"
  | Auto => "auto"
  }
}

// ============================================================================
// Flexbox Types
// ============================================================================

@ocaml.doc("Flex direction")
type flexDirection =
  | Row
  | RowReverse
  | Column
  | ColumnReverse

@ocaml.doc("Flex wrap behavior")
type flexWrap =
  | NoWrap
  | Wrap
  | WrapReverse

@ocaml.doc("Justify content alignment")
type justifyContent =
  | FlexStart
  | FlexEnd
  | Center
  | SpaceBetween
  | SpaceAround
  | SpaceEvenly

@ocaml.doc("Align items alignment")
type alignItems =
  | AlignStretch
  | AlignFlexStart
  | AlignFlexEnd
  | AlignCenter
  | AlignBaseline

@ocaml.doc("Align content for multi-line flex containers")
type alignContent =
  | ContentStretch
  | ContentFlexStart
  | ContentFlexEnd
  | ContentCenter
  | ContentSpaceBetween
  | ContentSpaceAround

@ocaml.doc("Flex container configuration")
type flexConfig = {
  direction: option<flexDirection>,
  wrap: option<flexWrap>,
  justifyContent: option<justifyContent>,
  alignItems: option<alignItems>,
  alignContent: option<alignContent>,
  gap: option<cssLength>,
  rowGap: option<cssLength>,
  columnGap: option<cssLength>,
}

@ocaml.doc("Flex item configuration")
type flexItemConfig = {
  grow: option<float>,
  shrink: option<float>,
  basis: option<cssLength>,
  alignSelf: option<alignItems>,
  order: option<int>,
}

// ============================================================================
// CSS Grid Types
// ============================================================================

@ocaml.doc("Grid track size - single track definition")
type gridTrackSize =
  | Fixed(cssLength)
  | MinMax(cssLength, cssLength)
  | FitContent(cssLength)
  | Repeat(int, cssLength)
  | RepeatAutoFill(cssLength)
  | RepeatAutoFit(cssLength)

@ocaml.doc("Convert grid track to string")
let trackToString = (track: gridTrackSize): string => {
  switch track {
  | Fixed(len) => lengthToString(len)
  | MinMax(min, max) => `minmax(${lengthToString(min)}, ${lengthToString(max)})`
  | FitContent(len) => `fit-content(${lengthToString(len)})`
  | Repeat(count, len) => `repeat(${Belt.Int.toString(count)}, ${lengthToString(len)})`
  | RepeatAutoFill(len) => `repeat(auto-fill, ${lengthToString(len)})`
  | RepeatAutoFit(len) => `repeat(auto-fit, ${lengthToString(len)})`
  }
}

@ocaml.doc("Grid line position for placement")
type gridLine =
  | LineNumber(int)
  | LineSpan(int)
  | LineName(string)
  | LineAuto

@ocaml.doc("Grid area placement")
type gridPlacement = {
  rowStart: option<gridLine>,
  rowEnd: option<gridLine>,
  columnStart: option<gridLine>,
  columnEnd: option<gridLine>,
}

@ocaml.doc("Grid container configuration")
type gridConfig = {
  templateColumns: option<array<gridTrackSize>>,
  templateRows: option<array<gridTrackSize>>,
  templateAreas: option<array<string>>,
  gap: option<cssLength>,
  rowGap: option<cssLength>,
  columnGap: option<cssLength>,
  justifyItems: option<justifyContent>,
  alignItems: option<alignItems>,
  justifyContent: option<justifyContent>,
  alignContent: option<alignContent>,
  autoFlow: option<string>,
  autoRows: option<cssLength>,
  autoColumns: option<cssLength>,
}

@ocaml.doc("Grid item configuration")
type gridItemConfig = {
  placement: option<gridPlacement>,
  area: option<string>,
  justifySelf: option<justifyContent>,
  alignSelf: option<alignItems>,
}

// ============================================================================
// Default Configurations
// ============================================================================

let defaultFlexConfig: flexConfig = {
  direction: None,
  wrap: None,
  justifyContent: None,
  alignItems: None,
  alignContent: None,
  gap: None,
  rowGap: None,
  columnGap: None,
}

let defaultFlexItemConfig: flexItemConfig = {
  grow: None,
  shrink: None,
  basis: None,
  alignSelf: None,
  order: None,
}

let defaultGridConfig: gridConfig = {
  templateColumns: None,
  templateRows: None,
  templateAreas: None,
  gap: None,
  rowGap: None,
  columnGap: None,
  justifyItems: None,
  alignItems: None,
  justifyContent: None,
  alignContent: None,
  autoFlow: None,
  autoRows: None,
  autoColumns: None,
}

let defaultGridItemConfig: gridItemConfig = {
  placement: None,
  area: None,
  justifySelf: None,
  alignSelf: None,
}

// ============================================================================
// Style Conversion Helpers
// ============================================================================

let flexDirectionToString = (dir: flexDirection): string => {
  switch dir {
  | Row => "row"
  | RowReverse => "row-reverse"
  | Column => "column"
  | ColumnReverse => "column-reverse"
  }
}

let flexWrapToString = (wrap: flexWrap): string => {
  switch wrap {
  | NoWrap => "nowrap"
  | Wrap => "wrap"
  | WrapReverse => "wrap-reverse"
  }
}

let justifyContentToString = (jc: justifyContent): string => {
  switch jc {
  | FlexStart => "flex-start"
  | FlexEnd => "flex-end"
  | Center => "center"
  | SpaceBetween => "space-between"
  | SpaceAround => "space-around"
  | SpaceEvenly => "space-evenly"
  }
}

let alignItemsToString = (ai: alignItems): string => {
  switch ai {
  | AlignStretch => "stretch"
  | AlignFlexStart => "flex-start"
  | AlignFlexEnd => "flex-end"
  | AlignCenter => "center"
  | AlignBaseline => "baseline"
  }
}

let alignContentToString = (ac: alignContent): string => {
  switch ac {
  | ContentStretch => "stretch"
  | ContentFlexStart => "flex-start"
  | ContentFlexEnd => "flex-end"
  | ContentCenter => "center"
  | ContentSpaceBetween => "space-between"
  | ContentSpaceAround => "space-around"
  }
}

let gridLineToString = (line: gridLine): string => {
  switch line {
  | LineNumber(n) => Belt.Int.toString(n)
  | LineSpan(n) => `span ${Belt.Int.toString(n)}`
  | LineName(name) => name
  | LineAuto => "auto"
  }
}

// ============================================================================
// Style Builders
// ============================================================================

@ocaml.doc("Build Style.t from flex container config")
let flexContainerStyle = (config: flexConfig): Style.t => {
  let style = Style.make(~display="flex", ())

  let style = switch config.direction {
  | Some(dir) => Style.combine(style, Style.make(~flexDirection=flexDirectionToString(dir), ()))
  | None => style
  }

  let style = switch config.wrap {
  | Some(wrap) => Style.combine(style, Style.make(~flexWrap=flexWrapToString(wrap), ()))
  | None => style
  }

  let style = switch config.justifyContent {
  | Some(jc) => Style.combine(style, Style.make(~justifyContent=justifyContentToString(jc), ()))
  | None => style
  }

  let style = switch config.alignItems {
  | Some(ai) => Style.combine(style, Style.make(~alignItems=alignItemsToString(ai), ()))
  | None => style
  }

  let style = switch config.alignContent {
  | Some(ac) => Style.combine(style, Style.make(~alignContent=alignContentToString(ac), ()))
  | None => style
  }

  let style = switch config.gap {
  | Some(gap) => Style.combine(style, Style.make(~gap=lengthToString(gap), ()))
  | None => style
  }

  let style = switch config.rowGap {
  | Some(gap) => Style.combine(style, Style.make(~rowGap=lengthToString(gap), ()))
  | None => style
  }

  let style = switch config.columnGap {
  | Some(gap) => Style.combine(style, Style.make(~columnGap=lengthToString(gap), ()))
  | None => style
  }

  style
}

@ocaml.doc("Build Style.t from flex item config")
let flexItemStyle = (config: flexItemConfig): Style.t => {
  let style = Style.make()

  let style = switch config.grow {
  | Some(grow) => Style.combine(style, Style.make(~flexGrow=Belt.Float.toString(grow), ()))
  | None => style
  }

  let style = switch config.shrink {
  | Some(shrink) => Style.combine(style, Style.make(~flexShrink=Belt.Float.toString(shrink), ()))
  | None => style
  }

  let style = switch config.basis {
  | Some(basis) => Style.combine(style, Style.make(~flexBasis=lengthToString(basis), ()))
  | None => style
  }

  let style = switch config.alignSelf {
  | Some(align) => Style.combine(style, Style.make(~alignSelf=alignItemsToString(align), ()))
  | None => style
  }

  let style = switch config.order {
  | Some(order) => Style.combine(style, Style.make(~order=Belt.Int.toString(order), ()))
  | None => style
  }

  style
}

@ocaml.doc("Build Style.t from grid container config")
let gridContainerStyle = (config: gridConfig): Style.t => {
  let style = Style.make(~display="grid", ())

  let style = switch config.templateColumns {
  | Some(cols) =>
    let colStr = cols->Belt.Array.map(trackToString)->Belt.Array.joinWith(" ", x => x)
    Style.combine(style, Style.make(~gridTemplateColumns=colStr, ()))
  | None => style
  }

  let style = switch config.templateRows {
  | Some(rows) =>
    let rowStr = rows->Belt.Array.map(trackToString)->Belt.Array.joinWith(" ", x => x)
    Style.combine(style, Style.make(~gridTemplateRows=rowStr, ()))
  | None => style
  }

  let style = switch config.templateAreas {
  | Some(areas) =>
    let areasStr = areas->Belt.Array.map(row => `"${row}"`)->Belt.Array.joinWith(" ", x => x)
    Style.combine(style, Style.make(~gridTemplateAreas=areasStr, ()))
  | None => style
  }

  let style = switch config.gap {
  | Some(gap) => Style.combine(style, Style.make(~gap=lengthToString(gap), ()))
  | None => style
  }

  let style = switch config.rowGap {
  | Some(gap) => Style.combine(style, Style.make(~rowGap=lengthToString(gap), ()))
  | None => style
  }

  let style = switch config.columnGap {
  | Some(gap) => Style.combine(style, Style.make(~columnGap=lengthToString(gap), ()))
  | None => style
  }

  let style = switch config.justifyItems {
  | Some(ji) => Style.combine(style, Style.make(~justifyItems=justifyContentToString(ji), ()))
  | None => style
  }

  let style = switch config.alignItems {
  | Some(ai) => Style.combine(style, Style.make(~alignItems=alignItemsToString(ai), ()))
  | None => style
  }

  let style = switch config.justifyContent {
  | Some(jc) => Style.combine(style, Style.make(~justifyContent=justifyContentToString(jc), ()))
  | None => style
  }

  let style = switch config.alignContent {
  | Some(ac) => Style.combine(style, Style.make(~alignContent=alignContentToString(ac), ()))
  | None => style
  }

  let style = switch config.autoFlow {
  | Some(flow) => Style.combine(style, Style.make(~gridAutoFlow=flow, ()))
  | None => style
  }

  let style = switch config.autoRows {
  | Some(rows) => Style.combine(style, Style.make(~gridAutoRows=lengthToString(rows), ()))
  | None => style
  }

  let style = switch config.autoColumns {
  | Some(cols) => Style.combine(style, Style.make(~gridAutoColumns=lengthToString(cols), ()))
  | None => style
  }

  style
}

@ocaml.doc("Build Style.t from grid item config")
let gridItemStyle = (config: gridItemConfig): Style.t => {
  let style = Style.make()

  let style = switch config.placement {
  | Some({rowStart, rowEnd, columnStart, columnEnd}) =>
    let style = switch rowStart {
    | Some(line) => Style.combine(style, Style.make(~gridRowStart=gridLineToString(line), ()))
    | None => style
    }
    let style = switch rowEnd {
    | Some(line) => Style.combine(style, Style.make(~gridRowEnd=gridLineToString(line), ()))
    | None => style
    }
    let style = switch columnStart {
    | Some(line) => Style.combine(style, Style.make(~gridColumnStart=gridLineToString(line), ()))
    | None => style
    }
    let style = switch columnEnd {
    | Some(line) => Style.combine(style, Style.make(~gridColumnEnd=gridLineToString(line), ()))
    | None => style
    }
    style
  | None => style
  }

  let style = switch config.area {
  | Some(area) => Style.combine(style, Style.make(~gridArea=area, ()))
  | None => style
  }

  let style = switch config.justifySelf {
  | Some(js) => Style.combine(style, Style.make(~justifySelf=justifyContentToString(js), ()))
  | None => style
  }

  let style = switch config.alignSelf {
  | Some(as_) => Style.combine(style, Style.make(~alignSelf=alignItemsToString(as_), ()))
  | None => style
  }

  style
}

// ============================================================================
// High-Level Layout Primitives
// ============================================================================

@ocaml.doc("
SWOT-style 2x2 quadrant layout configuration.
Creates a grid with named areas: 'tl' (top-left), 'tr' (top-right),
'bl' (bottom-left), 'br' (bottom-right).
")
type quadrantConfig = {
  gap: option<cssLength>,
  minCellHeight: option<cssLength>,
  aspectRatio: option<string>,
}

let defaultQuadrantConfig: quadrantConfig = {
  gap: Some(Px(16)),
  minCellHeight: Some(Px(200)),
  aspectRatio: None,
}

@ocaml.doc("Create a 2x2 quadrant grid style (SWOT matrix)")
let quadrantContainerStyle = (config: quadrantConfig): Style.t => {
  let baseStyle = Style.make(
    ~display="grid",
    ~gridTemplateColumns="1fr 1fr",
    ~gridTemplateRows="1fr 1fr",
    ~gridTemplateAreas=`"tl tr" "bl br"`,
    (),
  )

  let style = switch config.gap {
  | Some(gap) => Style.combine(baseStyle, Style.make(~gap=lengthToString(gap), ()))
  | None => baseStyle
  }

  let style = switch config.minCellHeight {
  | Some(height) => Style.combine(style, Style.make(~minHeight=`calc(${lengthToString(height)} * 2)`, ()))
  | None => style
  }

  let style = switch config.aspectRatio {
  | Some(ratio) => Style.combine(style, Style.make(~aspectRatio=ratio, ()))
  | None => style
  }

  style
}

@ocaml.doc("Quadrant position for SWOT-style layouts")
type quadrant =
  | TopLeft
  | TopRight
  | BottomLeft
  | BottomRight

@ocaml.doc("Get grid area name for quadrant")
let quadrantToArea = (q: quadrant): string => {
  switch q {
  | TopLeft => "tl"
  | TopRight => "tr"
  | BottomLeft => "bl"
  | BottomRight => "br"
  }
}

@ocaml.doc("Create style for a quadrant cell")
let quadrantCellStyle = (position: quadrant): Style.t => {
  Style.make(~gridArea=quadrantToArea(position), ())
}

// ============================================================================
// Dashboard Layout Primitives
// ============================================================================

@ocaml.doc("Dashboard layout with header, sidebar, main, and footer")
type dashboardConfig = {
  headerHeight: cssLength,
  sidebarWidth: cssLength,
  footerHeight: option<cssLength>,
  gap: option<cssLength>,
}

let defaultDashboardConfig: dashboardConfig = {
  headerHeight: Px(64),
  sidebarWidth: Px(250),
  footerHeight: None,
  gap: Some(Px(0)),
}

@ocaml.doc("Create dashboard grid container style")
let dashboardContainerStyle = (config: dashboardConfig): Style.t => {
  let hasFooter = Belt.Option.isSome(config.footerHeight)
  let rowTemplate = switch config.footerHeight {
  | Some(fh) => `${lengthToString(config.headerHeight)} 1fr ${lengthToString(fh)}`
  | None => `${lengthToString(config.headerHeight)} 1fr`
  }
  let areasTemplate = if hasFooter {
    `"header header" "sidebar main" "footer footer"`
  } else {
    `"header header" "sidebar main"`
  }

  let baseStyle = Style.make(
    ~display="grid",
    ~gridTemplateColumns=`${lengthToString(config.sidebarWidth)} 1fr`,
    ~gridTemplateRows=rowTemplate,
    ~gridTemplateAreas=areasTemplate,
    ~minHeight="100vh",
    (),
  )

  switch config.gap {
  | Some(gap) => Style.combine(baseStyle, Style.make(~gap=lengthToString(gap), ()))
  | None => baseStyle
  }
}

@ocaml.doc("Dashboard area names")
type dashboardArea =
  | Header
  | Sidebar
  | Main
  | Footer

@ocaml.doc("Get grid area name for dashboard section")
let dashboardAreaToString = (area: dashboardArea): string => {
  switch area {
  | Header => "header"
  | Sidebar => "sidebar"
  | Main => "main"
  | Footer => "footer"
  }
}

@ocaml.doc("Create style for a dashboard area")
let dashboardAreaStyle = (area: dashboardArea): Style.t => {
  Style.make(~gridArea=dashboardAreaToString(area), ())
}

// ============================================================================
// Responsive Helpers
// ============================================================================

@ocaml.doc("Media query breakpoints")
type breakpoint =
  | Sm  // 640px
  | Md  // 768px
  | Lg  // 1024px
  | Xl  // 1280px
  | Xxl // 1536px

@ocaml.doc("Get pixel value for breakpoint")
let breakpointToPx = (bp: breakpoint): int => {
  switch bp {
  | Sm => 640
  | Md => 768
  | Lg => 1024
  | Xl => 1280
  | Xxl => 1536
  }
}

// ============================================================================
// Convenience Functions
// ============================================================================

@ocaml.doc("Create a simple flex row with gap")
let flexRow = (~gap: cssLength=Px(8), ~justify: justifyContent=FlexStart, ~align: alignItems=AlignCenter, ()): Style.t => {
  flexContainerStyle({
    ...defaultFlexConfig,
    direction: Some(Row),
    gap: Some(gap),
    justifyContent: Some(justify),
    alignItems: Some(align),
  })
}

@ocaml.doc("Create a simple flex column with gap")
let flexColumn = (~gap: cssLength=Px(8), ~justify: justifyContent=FlexStart, ~align: alignItems=AlignStretch, ()): Style.t => {
  flexContainerStyle({
    ...defaultFlexConfig,
    direction: Some(Column),
    gap: Some(gap),
    justifyContent: Some(justify),
    alignItems: Some(align),
  })
}

@ocaml.doc("Create an equal-width column grid")
let equalColumns = (~count: int, ~gap: cssLength=Px(16), ()): Style.t => {
  gridContainerStyle({
    ...defaultGridConfig,
    templateColumns: Some(Belt.Array.make(count, Fixed(Fr(1.0)))),
    gap: Some(gap),
  })
}

@ocaml.doc("Create a responsive auto-fit grid with minimum column width")
let autoFitGrid = (~minWidth: cssLength, ~gap: cssLength=Px(16), ()): Style.t => {
  gridContainerStyle({
    ...defaultGridConfig,
    templateColumns: Some([RepeatAutoFit(minWidth)]),
    gap: Some(gap),
  })
}

@ocaml.doc("Create a centered flex container")
let centered = (): Style.t => {
  flexContainerStyle({
    ...defaultFlexConfig,
    justifyContent: Some(Center),
    alignItems: Some(AlignCenter),
  })
}

@ocaml.doc("Create a space-between row (useful for headers)")
let spaceBetweenRow = (~align: alignItems=AlignCenter, ()): Style.t => {
  flexContainerStyle({
    ...defaultFlexConfig,
    direction: Some(Row),
    justifyContent: Some(SpaceBetween),
    alignItems: Some(align),
  })
}

// ============================================================================
// Style Combination Utilities
// ============================================================================

@ocaml.doc("Combine multiple styles")
let combineStyles = (styles: array<Style.t>): Style.t => {
  styles->Belt.Array.reduce(Style.make(), (acc, s) => Style.combine(acc, s))
}

@ocaml.doc("Add width and height to a style")
let withSize = (style: Style.t, ~width: option<cssLength>=?, ~height: option<cssLength>=?, ()): Style.t => {
  let style = switch width {
  | Some(w) => Style.combine(style, Style.make(~width=lengthToString(w), ()))
  | None => style
  }
  switch height {
  | Some(h) => Style.combine(style, Style.make(~height=lengthToString(h), ()))
  | None => style
  }
}

@ocaml.doc("Add padding to a style")
let withPadding = (style: Style.t, padding: cssLength): Style.t => {
  Style.combine(style, Style.make(~padding=lengthToString(padding), ()))
}

@ocaml.doc("Add margin to a style")
let withMargin = (style: Style.t, margin: cssLength): Style.t => {
  Style.combine(style, Style.make(~margin=lengthToString(margin), ()))
}

@ocaml.doc("Add background color to a style")
let withBackground = (style: Style.t, color: string): Style.t => {
  Style.combine(style, Style.make(~backgroundColor=color, ()))
}

@ocaml.doc("Add border radius to a style")
let withBorderRadius = (style: Style.t, radius: cssLength): Style.t => {
  Style.combine(style, Style.make(~borderRadius=lengthToString(radius), ()))
}
