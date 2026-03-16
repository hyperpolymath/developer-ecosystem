// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// D3 Scale bindings for color/size mapping

// Generic scale type
type t<'domain, 'range>

// Linear scale (numbers -> numbers)
type linear = t<float, float>

@module("d3") external scaleLinear: unit => linear = "scaleLinear"
@send external linearDomain: (linear, (float, float)) => linear = "domain"
@send external linearRange: (linear, (float, float)) => linear = "range"
@send external linearClamp: (linear, bool) => linear = "clamp"
@send external linearNice: (linear, ~count: int=?) => linear = "nice"
@send external linearInvert: (linear, float) => float = "invert"
@send external linearCall: (linear, float) => float = "%identity"

// Ordinal scale (discrete domain -> discrete range)
type ordinal<'domain, 'range> = t<'domain, 'range>

@module("d3") external scaleOrdinal: unit => ordinal<'domain, 'range> = "scaleOrdinal"
@send external ordinalDomain: (ordinal<'domain, 'range>, array<'domain>) => ordinal<'domain, 'range> = "domain"
@send external ordinalRange: (ordinal<'domain, 'range>, array<'range>) => ordinal<'domain, 'range> = "range"
@send external ordinalUnknown: (ordinal<'domain, 'range>, 'range) => ordinal<'domain, 'range> = "unknown"
@send external ordinalCall: (ordinal<'domain, 'range>, 'domain) => 'range = "%identity"

// Color scale (numbers -> colors)
type colorScale = t<float, string>

@module("d3") external scaleSequential: ('interpolator) => colorScale = "scaleSequential"
@send external colorDomain: (colorScale, (float, float)) => colorScale = "domain"
@send external colorCall: (colorScale, float) => string = "%identity"

// Built-in color interpolators
@module("d3") external interpolateViridis: float => string = "interpolateViridis"
@module("d3") external interpolatePlasma: float => string = "interpolatePlasma"
@module("d3") external interpolateInferno: float => string = "interpolateInferno"
@module("d3") external interpolateMagma: float => string = "interpolateMagma"
@module("d3") external interpolateWarm: float => string = "interpolateWarm"
@module("d3") external interpolateCool: float => string = "interpolateCool"
@module("d3") external interpolateRainbow: float => string = "interpolateRainbow"
@module("d3") external interpolateTurbo: float => string = "interpolateTurbo"
@module("d3") external interpolateBlues: float => string = "interpolateBlues"
@module("d3") external interpolateGreens: float => string = "interpolateGreens"
@module("d3") external interpolateOranges: float => string = "interpolateOranges"
@module("d3") external interpolateReds: float => string = "interpolateReds"

// Categorical color schemes
@module("d3") external schemeCategory10: array<string> = "schemeCategory10"
@module("d3") external schemeAccent: array<string> = "schemeAccent"
@module("d3") external schemeDark2: array<string> = "schemeDark2"
@module("d3") external schemePaired: array<string> = "schemePaired"
@module("d3") external schemePastel1: array<string> = "schemePastel1"
@module("d3") external schemePastel2: array<string> = "schemePastel2"
@module("d3") external schemeSet1: array<string> = "schemeSet1"
@module("d3") external schemeSet2: array<string> = "schemeSet2"
@module("d3") external schemeSet3: array<string> = "schemeSet3"
@module("d3") external schemeTableau10: array<string> = "schemeTableau10"

// Sqrt scale (useful for circle sizes)
type sqrt = t<float, float>

@module("d3") external scaleSqrt: unit => sqrt = "scaleSqrt"
@send external sqrtDomain: (sqrt, (float, float)) => sqrt = "domain"
@send external sqrtRange: (sqrt, (float, float)) => sqrt = "range"
@send external sqrtCall: (sqrt, float) => float = "%identity"

// Point scale (discrete -> continuous positions)
type point<'domain> = t<'domain, float>

@module("d3") external scalePoint: unit => point<'domain> = "scalePoint"
@send external pointDomain: (point<'domain>, array<'domain>) => point<'domain> = "domain"
@send external pointRange: (point<'domain>, (float, float)) => point<'domain> = "range"
@send external pointPadding: (point<'domain>, float) => point<'domain> = "padding"
@send external pointRound: (point<'domain>, bool) => point<'domain> = "round"
@send external pointBandwidth: point<'domain> => float = "bandwidth"
@send external pointStep: point<'domain> => float = "step"
@send external pointCall: (point<'domain>, 'domain) => float = "%identity"

// Band scale (discrete -> continuous bands)
type band<'domain> = t<'domain, float>

@module("d3") external scaleBand: unit => band<'domain> = "scaleBand"
@send external bandDomain: (band<'domain>, array<'domain>) => band<'domain> = "domain"
@send external bandRange: (band<'domain>, (float, float)) => band<'domain> = "range"
@send external bandPaddingInner: (band<'domain>, float) => band<'domain> = "paddingInner"
@send external bandPaddingOuter: (band<'domain>, float) => band<'domain> = "paddingOuter"
@send external bandPadding: (band<'domain>, float) => band<'domain> = "padding"
@send external bandRound: (band<'domain>, bool) => band<'domain> = "round"
@send external bandBandwidth: band<'domain> => float = "bandwidth"
@send external bandStep: band<'domain> => float = "step"
@send external bandCall: (band<'domain>, 'domain) => float = "%identity"
