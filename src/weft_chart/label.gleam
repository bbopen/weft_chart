//// Label and LabelList components.
////
//// Labels attach text annotations to chart elements (axes, bars,
//// dots, sectors).  LabelList renders one label per data point.
//// Matches the recharts Label and LabelList components including
//// polar arc-following text, rotation, and word wrapping.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import weft_chart/internal/math
import weft_chart/internal/polar
import weft_chart/internal/svg

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Position of a label relative to its parent element.
/// Matches recharts position prop values.
pub type LabelPosition {
  /// Above the element, centered.
  Top
  /// Below the element, centered.
  Bottom
  /// Left of the element, vertically centered.
  Left
  /// Right of the element, vertically centered.
  Right
  /// Center of the element.
  Center
  /// Inside top edge.
  InsideTop
  /// Inside bottom edge.
  InsideBottom
  /// Inside left edge.
  InsideLeft
  /// Inside right edge.
  InsideRight
  /// Inside top-left corner.
  InsideTopLeft
  /// Inside top-right corner.
  InsideTopRight
  /// Inside bottom-left corner.
  InsideBottomLeft
  /// Inside bottom-right corner.
  InsideBottomRight
  /// Places the label at the center of the element.
  Inside
  /// Outside a polar element.
  Outside
  /// Start of arc (for pie/radial labels).
  InsideStart
  /// End of arc (for pie/radial labels).
  InsideEnd
  /// Outside end of element.
  End
  /// Center horizontally, top vertically.
  CenterTop
  /// Center horizontally, bottom vertically.
  CenterBottom
  /// Center both axes.
  Middle
  /// Places label at absolute coordinates.
  AtCoordinate(x: Float, y: Float)
}

/// A cartesian viewbox for label positioning.
pub type CartesianViewBox {
  CartesianViewBox(x: Float, y: Float, width: Float, height: Float)
}

/// A polar viewbox for label positioning.
pub type PolarViewBox {
  PolarViewBox(
    cx: Float,
    cy: Float,
    inner_radius: Float,
    outer_radius: Float,
    start_angle: Float,
    end_angle: Float,
    /// When true, text follows the arc clockwise; when false, counterclockwise.
    clock_wise: Bool,
  )
}

/// Configuration for a label.
pub type LabelConfig {
  LabelConfig(
    position: LabelPosition,
    offset: Float,
    fill: String,
    font_size: Int,
    font_weight: String,
    formatter: fn(String) -> String,
    angle: Option(Float),
    max_width: Option(Float),
    max_lines: Option(Int),
  )
}

/// Configuration for a label list.
pub type LabelListConfig {
  LabelListConfig(
    data_key: String,
    position: LabelPosition,
    offset: Float,
    fill: String,
    font_size: Int,
    /// Font weight for label list text elements.
    font_weight: String,
    formatter: fn(String) -> String,
    angle: Option(Float),
    max_width: Option(Float),
    max_lines: Option(Int),
  )
}

/// An entry in a label list with position and value.
pub type LabelListEntry {
  /// Cartesian label entry (bars, lines, areas).
  CartesianLabelEntry(value: String, view_box: CartesianViewBox)
  /// Polar label entry (pie sectors, radial bars).
  PolarLabelEntry(value: String, view_box: PolarViewBox)
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a default label configuration.
pub fn label_config(position position: LabelPosition) -> LabelConfig {
  LabelConfig(
    position: position,
    offset: 5.0,
    fill: "var(--weft-chart-label, currentColor)",
    font_size: 12,
    font_weight: "normal",
    formatter: fn(v) { v },
    angle: None,
    max_width: None,
    max_lines: None,
  )
}

/// Create a default label list configuration.
pub fn label_list_config(data_key data_key: String) -> LabelListConfig {
  LabelListConfig(
    data_key: data_key,
    position: Top,
    offset: 5.0,
    fill: "var(--weft-chart-label, currentColor)",
    font_size: 12,
    font_weight: "normal",
    formatter: fn(v) { v },
    angle: None,
    max_width: None,
    max_lines: None,
  )
}

// ---------------------------------------------------------------------------
// Label builders
// ---------------------------------------------------------------------------

/// Set the label offset from its position.
pub fn label_offset(
  config config: LabelConfig,
  offset offset: Float,
) -> LabelConfig {
  LabelConfig(..config, offset: offset)
}

/// Set the label fill color.
pub fn label_fill(config config: LabelConfig, fill fill: String) -> LabelConfig {
  LabelConfig(..config, fill: fill)
}

/// Set the label font size.
pub fn label_font_size(
  config config: LabelConfig,
  size size: Int,
) -> LabelConfig {
  LabelConfig(..config, font_size: size)
}

/// Set the label font weight.
pub fn label_font_weight(
  config config: LabelConfig,
  weight weight: String,
) -> LabelConfig {
  LabelConfig(..config, font_weight: weight)
}

/// Set the label text formatter.
pub fn label_formatter(
  config config: LabelConfig,
  formatter formatter: fn(String) -> String,
) -> LabelConfig {
  LabelConfig(..config, formatter: formatter)
}

/// Set the label rotation angle in degrees.
/// Applied via SVG transform="rotate(angle, cx, cy)".
/// Matches recharts Label `angle` prop.
pub fn label_angle(
  config config: LabelConfig,
  angle angle: Float,
) -> LabelConfig {
  LabelConfig(..config, angle: Some(angle))
}

/// Set the maximum width for word wrapping.
/// When set, text is split into multiple tspan elements.
/// Matches recharts Text `width` prop behavior.
pub fn label_max_width(
  config config: LabelConfig,
  width width: Float,
) -> LabelConfig {
  LabelConfig(..config, max_width: Some(width))
}

/// Set the maximum number of lines.
/// When set, text is truncated with "..." after max_lines.
/// Matches recharts Text `maxLines` prop.
pub fn label_max_lines(
  config config: LabelConfig,
  lines lines: Int,
) -> LabelConfig {
  LabelConfig(..config, max_lines: Some(lines))
}

/// Create a label configuration with position set to Inside (centered).
pub fn label_inside() -> LabelConfig {
  label_config(position: Inside)
}

/// Create a label configuration positioned at absolute coordinates.
pub fn label_at_coordinate(x x_val: Float, y y_val: Float) -> LabelConfig {
  label_config(position: AtCoordinate(x: x_val, y: y_val))
}

// ---------------------------------------------------------------------------
// LabelList builders
// ---------------------------------------------------------------------------

/// Set the label list position.
pub fn label_list_position(
  config config: LabelListConfig,
  position position: LabelPosition,
) -> LabelListConfig {
  LabelListConfig(..config, position: position)
}

/// Set the label list offset.
pub fn label_list_offset(
  config config: LabelListConfig,
  offset offset: Float,
) -> LabelListConfig {
  LabelListConfig(..config, offset: offset)
}

/// Set the label list fill color.
pub fn label_list_fill(
  config config: LabelListConfig,
  fill fill: String,
) -> LabelListConfig {
  LabelListConfig(..config, fill: fill)
}

/// Set the label list font size.
pub fn label_list_font_size(
  config config: LabelListConfig,
  size size: Int,
) -> LabelListConfig {
  LabelListConfig(..config, font_size: size)
}

/// Set the label list formatter.
pub fn label_list_formatter(
  config config: LabelListConfig,
  formatter formatter: fn(String) -> String,
) -> LabelListConfig {
  LabelListConfig(..config, formatter: formatter)
}

/// Set the label list rotation angle in degrees.
pub fn label_list_angle(
  config config: LabelListConfig,
  angle angle: Float,
) -> LabelListConfig {
  LabelListConfig(..config, angle: Some(angle))
}

/// Set the label list maximum width for word wrapping.
pub fn label_list_max_width(
  config config: LabelListConfig,
  width width: Float,
) -> LabelListConfig {
  LabelListConfig(..config, max_width: Some(width))
}

/// Set the label list maximum number of lines.
pub fn label_list_max_lines(
  config config: LabelListConfig,
  lines lines: Int,
) -> LabelListConfig {
  LabelListConfig(..config, max_lines: Some(lines))
}

/// Set the label list font weight.
pub fn label_list_font_weight(
  config config: LabelListConfig,
  weight weight: String,
) -> LabelListConfig {
  LabelListConfig(..config, font_weight: weight)
}

// ---------------------------------------------------------------------------
// Rendering — single label
// ---------------------------------------------------------------------------

/// Render a label at a cartesian position.
/// Matches recharts getCartesianPosition logic.
pub fn render_cartesian_label(
  config config: LabelConfig,
  view_box view_box: CartesianViewBox,
  content content: String,
) -> Element(msg) {
  let formatted = config.formatter(content)
  let #(lx, ly, anchor, baseline) =
    cartesian_position(config.position, view_box, config.offset)

  // Build rotation transform if angle is set
  let transform_attr = case config.angle {
    None -> []
    Some(a) -> [
      svg.attr(
        "transform",
        "rotate("
          <> math.fmt(a)
          <> ", "
          <> math.fmt(lx)
          <> ", "
          <> math.fmt(ly)
          <> ")",
      ),
    ]
  }

  let base_attrs = [
    svg.attr("text-anchor", anchor),
    svg.attr("dominant-baseline", baseline),
    svg.attr("fill", config.fill),
    svg.attr("font-size", int.to_string(config.font_size)),
    svg.attr("font-weight", config.font_weight),
    ..transform_attr
  ]

  // Handle word wrapping
  case config.max_width {
    None ->
      svg.text(
        x: math.fmt(lx),
        y: math.fmt(ly),
        content: formatted,
        attrs: base_attrs,
      )
    Some(width) -> {
      let lines = wrap_text(formatted, width, config.font_size)
      let truncated = truncate_lines(lines, config.max_lines)
      render_wrapped_text(
        x: lx,
        y: ly,
        lines: truncated,
        font_size: config.font_size,
        attrs: base_attrs,
      )
    }
  }
}

/// Render a label at a polar position.
/// Matches recharts getAttrsOfPolarLabel logic.
/// For InsideStart, InsideEnd, and End positions, generates arc-following
/// text using SVG textPath elements.
pub fn render_polar_label(
  config config: LabelConfig,
  view_box view_box: PolarViewBox,
  content content: String,
) -> Element(msg) {
  let formatted = config.formatter(content)
  let mid = polar.mid_angle(view_box.start_angle, view_box.end_angle)

  // Check for arc-following positions
  case config.position {
    InsideStart | InsideEnd | End ->
      render_radial_label(
        config: config,
        view_box: view_box,
        content: formatted,
      )
    _ -> {
      let #(lx, ly, anchor, baseline) =
        polar_position(config.position, view_box, config.offset, mid)

      let transform_attr = case config.angle {
        None -> []
        Some(a) -> [
          svg.attr(
            "transform",
            "rotate("
              <> math.fmt(a)
              <> ", "
              <> math.fmt(lx)
              <> ", "
              <> math.fmt(ly)
              <> ")",
          ),
        ]
      }

      let base_attrs = [
        svg.attr("text-anchor", anchor),
        svg.attr("dominant-baseline", baseline),
        svg.attr("fill", config.fill),
        svg.attr("font-size", int.to_string(config.font_size)),
        svg.attr("font-weight", config.font_weight),
        ..transform_attr
      ]

      case config.max_width {
        None ->
          svg.text(
            x: math.fmt(lx),
            y: math.fmt(ly),
            content: formatted,
            attrs: base_attrs,
          )
        Some(width) -> {
          let lines = wrap_text(formatted, width, config.font_size)
          let truncated = truncate_lines(lines, config.max_lines)
          render_wrapped_text(
            x: lx,
            y: ly,
            lines: truncated,
            font_size: config.font_size,
            attrs: base_attrs,
          )
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Rendering — radial arc-following text
// ---------------------------------------------------------------------------

/// Render a label that follows an arc path using SVG textPath.
/// Used for InsideStart, InsideEnd, and End positions on polar elements.
/// Matches recharts renderRadialLabel.
fn render_radial_label(
  config config: LabelConfig,
  view_box view_box: PolarViewBox,
  content content: String,
) -> Element(msg) {
  let radius = { view_box.inner_radius +. view_box.outer_radius } /. 2.0
  let delta =
    math.abs(view_box.end_angle -. view_box.start_angle)
    |> math.clamp(0.0, 359.999)
  let sign = math.sign(view_box.end_angle -. view_box.start_angle)

  let #(label_angle, direction) = case config.position {
    InsideStart -> #(view_box.start_angle +. sign *. config.offset, sign >. 0.0)
    InsideEnd -> #(view_box.end_angle -. sign *. config.offset, sign <=. 0.0)
    End -> #(view_box.end_angle +. sign *. config.offset, sign >. 0.0)
    // Fallback — should not reach here due to caller pattern match
    _ -> #(view_box.start_angle, True)
  }

  // Apply clock_wise: when counter-clockwise, flip the initial direction
  let cw_direction = case view_box.clock_wise {
    True -> direction
    False -> !direction
  }

  // Invert direction if delta is positive (CW vs CCW)
  let effective_direction = case delta <=. 0.0 {
    True -> cw_direction
    False -> !cw_direction
  }

  let #(sx, sy) =
    polar.to_cartesian(
      cx: view_box.cx,
      cy: view_box.cy,
      radius: radius,
      angle_degrees: label_angle,
    )
  let arc_end_angle = case effective_direction {
    True -> label_angle +. 359.0
    False -> label_angle -. 359.0
  }
  let #(ex, ey) =
    polar.to_cartesian(
      cx: view_box.cx,
      cy: view_box.cy,
      radius: radius,
      angle_degrees: arc_end_angle,
    )

  let sweep_flag = case effective_direction {
    True -> "0"
    False -> "1"
  }

  let path_d =
    "M"
    <> math.fmt(sx)
    <> ","
    <> math.fmt(sy)
    <> "A"
    <> math.fmt(radius)
    <> ","
    <> math.fmt(radius)
    <> ",0,1,"
    <> sweep_flag
    <> ","
    <> math.fmt(ex)
    <> ","
    <> math.fmt(ey)

  // Generate a stable path ID from angle values to avoid collisions
  let path_id =
    "weft-radial-label-"
    <> int.to_string(float.truncate(view_box.start_angle *. 1000.0))
    <> "-"
    <> int.to_string(float.truncate(view_box.end_angle *. 1000.0))

  svg.el(
    tag: "text",
    attrs: [
      svg.attr("dominant-baseline", "central"),
      svg.attr("fill", config.fill),
      svg.attr("font-size", int.to_string(config.font_size)),
      svg.attr("font-weight", config.font_weight),
      svg.attr("class", "recharts-radial-bar-label"),
    ],
    children: [
      svg.el(tag: "defs", attrs: [], children: [
        svg.el(
          tag: "path",
          attrs: [svg.attr("id", path_id), svg.attr("d", path_d)],
          children: [],
        ),
      ]),
      svg.el(
        tag: "textPath",
        attrs: [svg.attr("href", "#" <> path_id)],
        children: [element.text(content)],
      ),
    ],
  )
}

// ---------------------------------------------------------------------------
// Rendering — label list
// ---------------------------------------------------------------------------

/// Render a list of labels for multiple data entries.
pub fn render_label_list(
  config config: LabelListConfig,
  entries entries: List(LabelListEntry),
) -> Element(msg) {
  let label_cfg =
    LabelConfig(
      position: config.position,
      offset: config.offset,
      fill: config.fill,
      font_size: config.font_size,
      font_weight: config.font_weight,
      formatter: config.formatter,
      angle: config.angle,
      max_width: config.max_width,
      max_lines: config.max_lines,
    )

  let label_els =
    list.map(entries, fn(entry) {
      case entry {
        CartesianLabelEntry(value:, view_box:) ->
          render_cartesian_label(
            config: label_cfg,
            view_box: view_box,
            content: value,
          )
        PolarLabelEntry(value:, view_box:) ->
          render_polar_label(
            config: label_cfg,
            view_box: view_box,
            content: value,
          )
      }
    })

  svg.g(attrs: [svg.attr("class", "recharts-label-list")], children: label_els)
}

// ---------------------------------------------------------------------------
// Position computation — cartesian
// ---------------------------------------------------------------------------

/// Compute label position, text-anchor, and dominant-baseline for
/// cartesian positions.  Matches recharts getCartesianPosition.
/// Sign-aware: when width or height is negative (e.g. bars below zero),
/// offsets flip direction and anchors swap start/end.
fn cartesian_position(
  position: LabelPosition,
  vb: CartesianViewBox,
  offset: Float,
) -> #(Float, Float, String, String) {
  let cx = vb.x +. vb.width /. 2.0
  let cy = vb.y +. vb.height /. 2.0
  let v_sign = case vb.height >=. 0.0 {
    True -> 1.0
    False -> -1.0
  }
  let h_sign = case vb.width >=. 0.0 {
    True -> 1.0
    False -> -1.0
  }

  let #(lx, ly, anchor, baseline) = case position {
    AtCoordinate(x:, y:) -> #(x, y, "middle", "central")
    Top -> #(cx, vb.y -. offset *. v_sign, "middle", "auto")
    Bottom -> #(cx, vb.y +. vb.height +. offset *. v_sign, "middle", "hanging")
    Left -> #(vb.x -. offset *. h_sign, cy, "end", "central")
    Right -> #(vb.x +. vb.width +. offset *. h_sign, cy, "start", "central")
    Center -> #(cx, cy, "middle", "central")
    InsideTop -> #(cx, vb.y +. offset *. v_sign, "middle", "hanging")
    InsideBottom -> #(
      cx,
      vb.y +. vb.height -. offset *. v_sign,
      "middle",
      "auto",
    )
    InsideLeft -> #(vb.x +. offset *. h_sign, cy, "start", "central")
    InsideRight -> #(vb.x +. vb.width -. offset *. h_sign, cy, "end", "central")
    InsideTopLeft -> #(
      vb.x +. offset *. h_sign,
      vb.y +. offset *. v_sign,
      "start",
      "hanging",
    )
    InsideTopRight -> #(
      vb.x +. vb.width -. offset *. h_sign,
      vb.y +. offset *. v_sign,
      "end",
      "hanging",
    )
    InsideBottomLeft -> #(
      vb.x +. offset *. h_sign,
      vb.y +. vb.height -. offset *. v_sign,
      "start",
      "auto",
    )
    InsideBottomRight -> #(
      vb.x +. vb.width -. offset *. h_sign,
      vb.y +. vb.height -. offset *. v_sign,
      "end",
      "auto",
    )
    Inside -> #(cx, cy, "middle", "central")
    Outside -> #(cx, vb.y -. offset *. v_sign, "middle", "auto")
    InsideStart -> #(cx, cy, "middle", "central")
    InsideEnd -> #(cx, cy, "middle", "central")
    End -> #(vb.x +. vb.width +. offset *. h_sign, cy, "start", "central")
    CenterTop -> #(cx, vb.y +. offset *. v_sign, "middle", "hanging")
    CenterBottom -> #(
      cx,
      vb.y +. vb.height -. offset *. v_sign,
      "middle",
      "auto",
    )
    Middle -> #(cx, cy, "middle", "central")
  }

  // Flip anchors for negative dimensions
  let final_anchor = case h_sign <. 0.0 {
    True -> flip_anchor(anchor)
    False -> anchor
  }
  let final_baseline = case v_sign <. 0.0 {
    True -> flip_baseline(baseline)
    False -> baseline
  }
  #(lx, ly, final_anchor, final_baseline)
}

/// Swap "start" and "end" text-anchor values for negative-width bars.
fn flip_anchor(anchor: String) -> String {
  case anchor {
    "start" -> "end"
    "end" -> "start"
    other -> other
  }
}

/// Swap "hanging" and "auto" baseline values for negative-height bars.
fn flip_baseline(baseline: String) -> String {
  case baseline {
    "hanging" -> "auto"
    "auto" -> "hanging"
    other -> other
  }
}

// ---------------------------------------------------------------------------
// Position computation — polar
// ---------------------------------------------------------------------------

/// Compute label position for polar elements.
/// Matches recharts getAttrsOfPolarLabel.
fn polar_position(
  position: LabelPosition,
  vb: PolarViewBox,
  offset: Float,
  mid_angle: Float,
) -> #(Float, Float, String, String) {
  case position {
    AtCoordinate(x:, y:) -> #(x, y, "middle", "central")
    Outside -> {
      let #(px, py) =
        polar.to_cartesian(
          cx: vb.cx,
          cy: vb.cy,
          radius: vb.outer_radius +. offset,
          angle_degrees: mid_angle,
        )
      let anchor = case px >=. vb.cx {
        True -> "start"
        False -> "end"
      }
      #(px, py, anchor, "central")
    }
    Center -> #(vb.cx, vb.cy, "middle", "central")
    CenterTop -> #(vb.cx, vb.cy, "middle", "hanging")
    CenterBottom -> #(vb.cx, vb.cy, "middle", "auto")
    Middle -> #(vb.cx, vb.cy, "middle", "central")
    // Default: inside the sector at the midpoint radius
    _ -> {
      let mid_radius = { vb.inner_radius +. vb.outer_radius } /. 2.0
      let #(px, py) =
        polar.to_cartesian(
          cx: vb.cx,
          cy: vb.cy,
          radius: mid_radius,
          angle_degrees: mid_angle,
        )
      #(px, py, "middle", "central")
    }
  }
}

// ---------------------------------------------------------------------------
// Word wrapping helpers
// ---------------------------------------------------------------------------

/// Wrap text into lines based on approximate character width.
/// Uses a simple character-count heuristic since we cannot measure
/// actual text width in pure Gleam (no DOM access).
fn wrap_text(text: String, max_width: Float, font_size: Int) -> List(String) {
  let char_width = int.to_float(font_size) *. 0.6
  let chars_per_line = case char_width >. 0.0 {
    True -> float.round(max_width /. char_width)
    False -> 20
  }
  let chars_per_line_safe = case chars_per_line < 1 {
    True -> 1
    False -> chars_per_line
  }

  let words = string.split(text, " ")
  wrap_words(words, chars_per_line_safe)
}

/// Wrap words into lines, each not exceeding max characters.
fn wrap_words(words: List(String), max_chars: Int) -> List(String) {
  let #(lines, current) =
    list.fold(words, #([], ""), fn(acc, word) {
      let #(done, current_line) = acc
      case string.length(current_line) {
        0 -> #(done, word)
        len ->
          case len + 1 + string.length(word) <= max_chars {
            True -> #(done, current_line <> " " <> word)
            False -> #(list.append(done, [current_line]), word)
          }
      }
    })
  case string.length(current) {
    0 -> lines
    _ -> list.append(lines, [current])
  }
}

/// Truncate lines to max_lines, adding "..." to the last line.
fn truncate_lines(lines: List(String), max_lines: Option(Int)) -> List(String) {
  case max_lines {
    None -> lines
    Some(max) ->
      case list.length(lines) <= max {
        True -> lines
        False -> {
          let taken = list.take(lines, max)
          // Add ellipsis to last line
          case list.reverse(taken) {
            [last, ..rest] -> list.reverse([last <> "...", ..rest])
            [] -> taken
          }
        }
      }
  }
}

/// Render wrapped text as multiple tspan elements within a text element.
fn render_wrapped_text(
  x x: Float,
  y y: Float,
  lines lines: List(String),
  font_size font_size: Int,
  attrs attrs: List(attribute.Attribute(msg)),
) -> Element(msg) {
  let line_height = int.to_float(font_size) *. 1.2
  let tspan_els =
    list.index_map(lines, fn(line_text, index) {
      let dy_val = case index {
        0 -> "0"
        _ -> math.fmt(line_height)
      }
      svg.el(
        tag: "tspan",
        attrs: [
          svg.attr("x", math.fmt(x)),
          svg.attr("dy", dy_val),
        ],
        children: [element.text(line_text)],
      )
    })

  svg.el(
    tag: "text",
    attrs: [svg.attr("x", math.fmt(x)), svg.attr("y", math.fmt(y)), ..attrs],
    children: tspan_els,
  )
}
