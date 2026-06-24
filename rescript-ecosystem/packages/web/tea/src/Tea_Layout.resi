// SPDX-License-Identifier: MPL-2.0 AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

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
let lengthToString: cssLength => string

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
let trackToString: gridTrackSize => string

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

let defaultFlexConfig: flexConfig
let defaultFlexItemConfig: flexItemConfig
let defaultGridConfig: gridConfig
let defaultGridItemConfig: gridItemConfig

// ============================================================================
// Style Builders
// ============================================================================

@ocaml.doc("Build ReactDOM.Style.t from flex container config")
let flexContainerStyle: flexConfig => ReactDOM.Style.t

@ocaml.doc("Build ReactDOM.Style.t from flex item config")
let flexItemStyle: flexItemConfig => ReactDOM.Style.t

@ocaml.doc("Build ReactDOM.Style.t from grid container config")
let gridContainerStyle: gridConfig => ReactDOM.Style.t

@ocaml.doc("Build ReactDOM.Style.t from grid item config")
let gridItemStyle: gridItemConfig => ReactDOM.Style.t

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

let defaultQuadrantConfig: quadrantConfig

@ocaml.doc("Create a 2x2 quadrant grid style (SWOT matrix)")
let quadrantContainerStyle: quadrantConfig => ReactDOM.Style.t

@ocaml.doc("Quadrant position for SWOT-style layouts")
type quadrant =
  | TopLeft
  | TopRight
  | BottomLeft
  | BottomRight

@ocaml.doc("Get grid area name for quadrant")
let quadrantToArea: quadrant => string

@ocaml.doc("Create style for a quadrant cell")
let quadrantCellStyle: quadrant => ReactDOM.Style.t

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

let defaultDashboardConfig: dashboardConfig

@ocaml.doc("Create dashboard grid container style")
let dashboardContainerStyle: dashboardConfig => ReactDOM.Style.t

@ocaml.doc("Dashboard area names")
type dashboardArea =
  | Header
  | Sidebar
  | Main
  | Footer

@ocaml.doc("Get grid area name for dashboard section")
let dashboardAreaToString: dashboardArea => string

@ocaml.doc("Create style for a dashboard area")
let dashboardAreaStyle: dashboardArea => ReactDOM.Style.t

// ============================================================================
// Responsive Helpers
// ============================================================================

@ocaml.doc("Media query breakpoints")
type breakpoint =
  | Sm
  | Md
  | Lg
  | Xl
  | Xxl

@ocaml.doc("Get pixel value for breakpoint")
let breakpointToPx: breakpoint => int

// ============================================================================
// Convenience Functions
// ============================================================================

@ocaml.doc("Create a simple flex row with gap")
let flexRow: (~gap: cssLength=?, ~justify: justifyContent=?, ~align: alignItems=?, unit) => ReactDOM.Style.t

@ocaml.doc("Create a simple flex column with gap")
let flexColumn: (~gap: cssLength=?, ~justify: justifyContent=?, ~align: alignItems=?, unit) => ReactDOM.Style.t

@ocaml.doc("Create an equal-width column grid")
let equalColumns: (~count: int, ~gap: cssLength=?, unit) => ReactDOM.Style.t

@ocaml.doc("Create a responsive auto-fit grid with minimum column width")
let autoFitGrid: (~minWidth: cssLength, ~gap: cssLength=?, unit) => ReactDOM.Style.t

@ocaml.doc("Create a centered flex container")
let centered: unit => ReactDOM.Style.t

@ocaml.doc("Create a space-between row (useful for headers)")
let spaceBetweenRow: (~align: alignItems=?, unit) => ReactDOM.Style.t

// ============================================================================
// Style Combination Utilities
// ============================================================================

@ocaml.doc("Combine multiple styles")
let combineStyles: array<ReactDOM.Style.t> => ReactDOM.Style.t

@ocaml.doc("Add width and height to a style")
let withSize: (ReactDOM.Style.t, ~width: cssLength=?, ~height: cssLength=?, unit) => ReactDOM.Style.t

@ocaml.doc("Add padding to a style")
let withPadding: (ReactDOM.Style.t, cssLength) => ReactDOM.Style.t

@ocaml.doc("Add margin to a style")
let withMargin: (ReactDOM.Style.t, cssLength) => ReactDOM.Style.t

@ocaml.doc("Add background color to a style")
let withBackground: (ReactDOM.Style.t, string) => ReactDOM.Style.t

@ocaml.doc("Add border radius to a style")
let withBorderRadius: (ReactDOM.Style.t, cssLength) => ReactDOM.Style.t
