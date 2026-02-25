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
  plot_x plot_x: Float,
  plot_y plot_y: Float,
  plot_width plot_width: Float,
  plot_height plot_height: Float,
  categories categories: List(String),
  values values: List(dict.Dict(String, Float)),
) -> String {
  case explicit_id {
    "" ->
      "weft-chart-clip-"
      <> chart_kind
      <> "-"
      <> to_lower_hex_8(hash_clip_fallback(
        chart_kind: chart_kind,
        width: width,
        height: height,
        plot_x: plot_x,
        plot_y: plot_y,
        plot_width: plot_width,
        plot_height: plot_height,
        categories: categories,
        values: values,
      ))
    id -> "weft-chart-clip-" <> id
  }
}

fn hash_clip_fallback(
  chart_kind chart_kind: String,
  width width: Int,
  height height: Int,
  plot_x plot_x: Float,
  plot_y plot_y: Float,
  plot_width plot_width: Float,
  plot_height plot_height: Float,
  categories categories: List(String),
  values values: List(dict.Dict(String, Float)),
) -> Int {
  // Canonical hash input:
  // - fixed field order
  // - length-prefixed text fields via encode_part
  // - row keys sorted lexicographically
  // - float values encoded as fixed-point 9dp integers
  // This keeps hash construction deterministic across renders.
  [
    encode_part(chart_kind),
    "w=" <> int.to_string(width),
    "h=" <> int.to_string(height),
    "px=" <> math.fmt(plot_x),
    "py=" <> math.fmt(plot_y),
    "pw=" <> math.fmt(plot_width),
    "ph=" <> math.fmt(plot_height),
    "categories=" <> serialize_categories(categories),
    "values=" <> serialize_values(values),
  ]
  |> string.join(with: "|")
  |> fnv1a_32
}

fn encode_part(value: String) -> String {
  int.to_string(string.length(value)) <> ":" <> value
}

fn serialize_categories(categories: List(String)) -> String {
  categories
  |> list.map(encode_part)
  |> string.join(with: ",")
}

fn serialize_values(values: List(dict.Dict(String, Float))) -> String {
  values
  |> list.map(serialize_row)
  |> string.join(with: ";")
}

fn serialize_row(row: dict.Dict(String, Float)) -> String {
  row
  |> dict.to_list
  |> list.sort(by: fn(left, right) {
    case left, right {
      #(left_key, _), #(right_key, _) -> string.compare(left_key, right_key)
    }
  })
  |> list.map(fn(item) {
    let #(key, value) = item
    encode_part(key) <> "=" <> encode_part(encode_float_for_hash(value))
  })
  |> string.join(with: "|")
}

fn encode_float_for_hash(value: Float) -> String {
  // Preserve high-fidelity value distinctions via fixed-point 9dp integers.
  let scaled = float.round(value *. 1_000_000_000.0)
  "fp9:" <> int.to_string(scaled)
}

fn fnv1a_32(value: String) -> Int {
  // NOTE: `fnv1a_32` folds over `string.to_utf_codepoints` and
  // `string.utf_codepoint_to_int`, so this is codepoint-based rather than
  // canonical byte-wise UTF-8 FNV-1a for multibyte characters.
  let offset_basis = 2_166_136_261
  let prime = 16_777_619

  value
  |> string.to_utf_codepoints
  |> list.fold(offset_basis, fn(hash, codepoint) {
    let codepoint = string.utf_codepoint_to_int(codepoint)
    let next = int.bitwise_exclusive_or(hash, codepoint)
    mul_mod_u32(a: next, b: prime)
  })
}

fn mul_mod_u32(a a: Int, b b: Int) -> Int {
  mul_mod_u32_loop(a: mask_u32(a), b: mask_u32(b), acc: 0)
}

fn mul_mod_u32_loop(a a: Int, b b: Int, acc acc: Int) -> Int {
  case b {
    0 -> acc
    _ -> {
      let next_acc = case int.bitwise_and(b, 1) {
        1 -> mask_u32(acc + a)
        _ -> acc
      }
      let next_a = mask_u32(a * 2)
      let next_b = int.bitwise_shift_right(b, 1)
      mul_mod_u32_loop(a: next_a, b: next_b, acc: next_acc)
    }
  }
}

fn mask_u32(value: Int) -> Int {
  int.bitwise_and(value, 4_294_967_295)
}

fn to_lower_hex_8(value: Int) -> String {
  let mask = 15

  let c0 = hex_digit(int.bitwise_and(int.bitwise_shift_right(value, 28), mask))
  let c1 = hex_digit(int.bitwise_and(int.bitwise_shift_right(value, 24), mask))
  let c2 = hex_digit(int.bitwise_and(int.bitwise_shift_right(value, 20), mask))
  let c3 = hex_digit(int.bitwise_and(int.bitwise_shift_right(value, 16), mask))
  let c4 = hex_digit(int.bitwise_and(int.bitwise_shift_right(value, 12), mask))
  let c5 = hex_digit(int.bitwise_and(int.bitwise_shift_right(value, 8), mask))
  let c6 = hex_digit(int.bitwise_and(int.bitwise_shift_right(value, 4), mask))
  let c7 = hex_digit(int.bitwise_and(value, mask))

  c0 <> c1 <> c2 <> c3 <> c4 <> c5 <> c6 <> c7
}

fn hex_digit(nibble: Int) -> String {
  let assert True = nibble >= 0 && nibble <= 15
    as "hex_digit: nibble out of range [0, 15]"

  case nibble {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    10 -> "a"
    11 -> "b"
    12 -> "c"
    13 -> "d"
    14 -> "e"
    15 -> "f"
    _ -> "f"
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
