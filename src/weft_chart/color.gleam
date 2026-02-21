//// Color palette utilities for chart series.
////
//// Provides the standard recharts color palette and helpers for
//// cycling through colors when assigning series colors automatically.

import gleam/list
import weft

/// The standard recharts COLOR_PANEL palette of 26 colors.
/// Used as the default color source when series don't specify
/// explicit colors.
pub fn recharts_palette() -> List(weft.Color) {
  list.map(recharts_palette_strings, fn(s) { weft.css_color(value: s) })
}

/// Raw hex strings for the recharts COLOR_PANEL palette.
const recharts_palette_strings = [
  "#0088FE", "#00C49F", "#FFBB28", "#FF8042", "#8884D8", "#82CA9D", "#FFC658",
  "#8DD1E1", "#A4DE6C", "#D0ED57", "#FAD000", "#F66D44", "#FEAE65", "#E6F69D",
  "#AADEA7", "#64C2A6", "#2D87BB", "#553772", "#823C56", "#D35B5B", "#F39C6B",
  "#FFC93C", "#9ACD32", "#20B2AA", "#778899", "#FF6B6B",
]

/// Get a color from a palette by index, wrapping around when the
/// index exceeds the palette length.
///
/// Returns the color at `index % len(palette)`.  If the palette
/// is empty, returns black as a fallback.
pub fn cycle_color(
  palette palette: List(weft.Color),
  index index: Int,
) -> weft.Color {
  let len = list.length(palette)
  case len == 0 {
    True -> weft.rgb(red: 0, green: 0, blue: 0)
    False -> {
      let safe_index = case index < 0 {
        True -> len - { { { 0 - index } - 1 } % len + 1 }
        False -> index % len
      }
      get_at(palette, safe_index, 0)
    }
  }
}

fn get_at(items: List(weft.Color), target: Int, current: Int) -> weft.Color {
  case items {
    [] -> weft.rgb(red: 0, green: 0, blue: 0)
    [first, ..rest] ->
      case current == target {
        True -> first
        False -> get_at(rest, target, current + 1)
      }
  }
}
