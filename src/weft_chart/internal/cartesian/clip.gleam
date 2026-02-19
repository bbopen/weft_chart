//// Cartesian clip-path helpers.
////
//// Builds chart-scoped clip identifiers and reusable clip definitions
//// for cartesian chart rendering.

import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import lustre/element.{type Element}
import weft_chart/internal/math
import weft_chart/internal/svg

/// Build a chart-scoped clip-path id.
///
/// Uses the explicit chart id when provided; otherwise computes a
/// deterministic fallback from chart kind, dimensions, and data signatures.
pub fn clip_path_id(
  explicit_id explicit_id: String,
  chart_kind chart_kind: String,
  width width: Int,
  height height: Int,
  categories categories: List(String),
  values values: List(dict.Dict(String, Float)),
) -> String {
  case explicit_id {
    "" -> {
      let category_signature =
        list.fold(categories, 0, fn(acc, category) {
          acc + string.length(category)
        })
      let values_signature =
        list.fold(values, 0, fn(acc, row) {
          acc
          + dict.fold(row, 0, fn(inner, key, value) {
            inner + string.length(key) + string.length(float.to_string(value))
          })
        })
      "weft-chart-clip-"
      <> chart_kind
      <> "-"
      <> int.to_string(width)
      <> "-"
      <> int.to_string(height)
      <> "-"
      <> int.to_string(list.length(categories))
      <> "-"
      <> int.to_string(category_signature)
      <> "-"
      <> int.to_string(values_signature)
    }
    id -> "weft-chart-clip-" <> id
  }
}

/// Build a clip-path `<defs>` block for the given plot rectangle.
pub fn clip_defs(
  clip_id clip_id: String,
  plot_x plot_x: Float,
  plot_y plot_y: Float,
  plot_width plot_width: Float,
  plot_height plot_height: Float,
) -> Element(msg) {
  svg.defs([
    svg.clip_path(id: clip_id, children: [
      svg.rect(
        x: math.fmt(plot_x),
        y: math.fmt(plot_y),
        width: math.fmt(plot_width),
        height: math.fmt(plot_height),
        attrs: [],
      ),
    ]),
  ])
}

/// Wrap an element in a clip-path group.
pub fn clip_series(el el: Element(msg), clip_id clip_id: String) -> Element(msg) {
  svg.g(attrs: [svg.attr("clip-path", "url(#" <> clip_id <> ")")], children: [
    el,
  ])
}
