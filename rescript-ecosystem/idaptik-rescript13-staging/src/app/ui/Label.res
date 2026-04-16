// SPDX-License-Identifier: PMPL-1.0-or-later
// Label component for ReScript

open Pixi

type labelStyle = {
  fontFamily?: string,
  align?: string,
  fill?: int,
  fontSize?: int,
  fontWeight?: string,
}

let defaultStyle: labelStyle = {
  fontFamily: "Arial Rounded MT Bold",
  align: "center",
}

// Create a Label (centered Text)
let make = (~text: string, ~style: labelStyle=defaultStyle, ()): Text.t => {
  let label = Text.make({
    "text": text,
    "style": {
      "fontFamily": style.fontFamily->Option.getOr(
        defaultStyle.fontFamily->Option.getOr("Arial Rounded MT Bold"),
      ),
      "align": style.align->Option.getOr(defaultStyle.align->Option.getOr("center")),
      "fill": style.fill->Option.getOr(0xffffff),
      "fontSize": style.fontSize->Option.getOr(24),
      "fontWeight": style.fontWeight->Option.getOr("normal"),
    },
  })

  // Center the anchor
  ObservablePoint.set(Text.anchor(label), 0.5, ~y=0.5)

  label
}
