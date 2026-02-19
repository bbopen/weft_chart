//// Reference elements for annotating charts.
////
//// ReferenceLine draws a horizontal or vertical line at a specific data
//// value.  ReferenceArea draws a shaded rectangle between two values.
//// ReferenceDot draws a circle at a specific (x, y) coordinate.
//// All three support the `ifOverflow` prop matching recharts behavior:
//// discard, hidden, extendDomain, or visible.
//// Custom shape rendering is supported via the `shape` prop (recharts
//// parity) for all three reference element types.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import weft_chart/internal/math
import weft_chart/internal/svg
import weft_chart/scale.{type Scale}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A reference line orientation.
pub type ReferenceLineDirection {
  /// Horizontal line at a specific y value.
  Horizontal
  /// Vertical line at a specific x category or value.
  Vertical
}

/// Overflow behavior for reference elements.
/// Matches recharts `ifOverflow` prop.
pub type IfOverflow {
  /// Do not render if outside the chart domain (default).
  Discard
  /// Render but clip to the plot area using SVG clipPath.
  Hidden
  /// Extend the chart domain to include the reference element.
  ExtendDomain
  /// Render without any clipping, even outside the plot area.
  Visible
}

/// Controls placement within a category axis band.
/// Matches recharts ReferenceLine `position` prop.
pub type RefLinePosition {
  /// Line at the start of the band.
  RefLineStart
  /// Line at the middle of the band (default).
  RefLineMiddle
  /// Line at the end of the band.
  RefLineEnd
}

/// Props passed to a custom ReferenceLine shape renderer.
/// Matches recharts ReferenceLine `shape` callback props.
pub type ReferenceLineProps {
  ReferenceLineProps(x1: Float, y1: Float, x2: Float, y2: Float, stroke: String)
}

/// Props passed to a custom ReferenceArea shape renderer.
/// Matches recharts ReferenceArea `shape` callback props.
pub type ReferenceAreaProps {
  ReferenceAreaProps(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    fill: String,
  )
}

/// Props passed to a custom ReferenceDot shape renderer.
/// Matches recharts ReferenceDot `shape` callback props.
pub type ReferenceDotProps {
  ReferenceDotProps(
    cx: Float,
    cy: Float,
    r: Float,
    fill: String,
    stroke: String,
  )
}

/// Configuration for a reference line.
pub type ReferenceLineConfig(msg) {
  ReferenceLineConfig(
    direction: ReferenceLineDirection,
    value: Float,
    category: String,
    stroke: String,
    stroke_width: Float,
    stroke_dasharray: String,
    label: String,
    label_position: LabelPosition,
    is_front: Bool,
    if_overflow: IfOverflow,
    segment: List(#(Float, Float)),
    fill: String,
    fill_opacity: Float,
    position: RefLinePosition,
    x_axis_id: String,
    y_axis_id: String,
    custom_shape: Option(fn(ReferenceLineProps) -> Element(msg)),
  )
}

/// Configuration for a reference area (shaded region).
pub type ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(
    direction: ReferenceLineDirection,
    value1: Float,
    value2: Float,
    category1: String,
    category2: String,
    fill: String,
    fill_opacity: Float,
    stroke: String,
    stroke_width: Float,
    label: String,
    is_front: Bool,
    if_overflow: IfOverflow,
    x_axis_id: String,
    y_axis_id: String,
    custom_shape: Option(fn(ReferenceAreaProps) -> Element(msg)),
  )
}

/// Configuration for a reference dot (circle at a data point).
pub type ReferenceDotConfig(msg) {
  ReferenceDotConfig(
    x: Float,
    y: Float,
    r: Float,
    fill: String,
    stroke: String,
    stroke_width: Float,
    label: String,
    is_front: Bool,
    if_overflow: IfOverflow,
    fill_opacity: Float,
    x_axis_id: String,
    y_axis_id: String,
    custom_shape: Option(fn(ReferenceDotProps) -> Element(msg)),
  )
}

/// Where to position a reference line label.
pub type LabelPosition {
  /// Label at the start of the line.
  LabelStart
  /// Label in the middle of the line.
  LabelMiddle
  /// Label at the end of the line.
  LabelEnd
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a horizontal reference line at a y-axis value.
/// Matches recharts ReferenceLine with y prop.
/// Defaults: stroke=#ccc, strokeWidth=1, isFront=false, ifOverflow=discard.
pub fn horizontal_line(value value: Float) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(
    direction: Horizontal,
    value: value,
    category: "",
    stroke: "#ccc",
    stroke_width: 1.0,
    stroke_dasharray: "",
    label: "",
    label_position: LabelMiddle,
    is_front: False,
    if_overflow: Discard,
    segment: [],
    fill: "none",
    fill_opacity: 1.0,
    position: RefLineMiddle,
    x_axis_id: "0",
    y_axis_id: "0",
    custom_shape: None,
  )
}

/// Create a vertical reference line at an x-axis category.
/// Matches recharts ReferenceLine with x prop.
pub fn vertical_line(category category: String) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(
    direction: Vertical,
    value: 0.0,
    category: category,
    stroke: "#ccc",
    stroke_width: 1.0,
    stroke_dasharray: "",
    label: "",
    label_position: LabelMiddle,
    is_front: False,
    if_overflow: Discard,
    segment: [],
    fill: "none",
    fill_opacity: 1.0,
    position: RefLineMiddle,
    x_axis_id: "0",
    y_axis_id: "0",
    custom_shape: None,
  )
}

/// Create a horizontal reference area between two y values.
/// Matches recharts ReferenceArea with y1/y2 props.
pub fn horizontal_area(
  value1 value1: Float,
  value2 value2: Float,
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(
    direction: Horizontal,
    value1: value1,
    value2: value2,
    category1: "",
    category2: "",
    fill: "#ccc",
    fill_opacity: 0.5,
    stroke: "none",
    stroke_width: 1.0,
    label: "",
    is_front: False,
    if_overflow: Discard,
    x_axis_id: "0",
    y_axis_id: "0",
    custom_shape: None,
  )
}

/// Create a vertical reference area between two x categories.
/// Matches recharts ReferenceArea with x1/x2 props.
pub fn vertical_area(
  category1 category1: String,
  category2 category2: String,
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(
    direction: Vertical,
    value1: 0.0,
    value2: 0.0,
    category1: category1,
    category2: category2,
    fill: "#ccc",
    fill_opacity: 0.5,
    stroke: "none",
    stroke_width: 1.0,
    label: "",
    is_front: False,
    if_overflow: Discard,
    x_axis_id: "0",
    y_axis_id: "0",
    custom_shape: None,
  )
}

/// Create a reference dot at a specific data coordinate.
/// Matches recharts ReferenceDot component.
/// Defaults: r=10, fill=#fff, stroke=#ccc, ifOverflow=discard.
pub fn reference_dot(x x: Float, y y: Float) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(
    x: x,
    y: y,
    r: 10.0,
    fill: "#fff",
    stroke: "#ccc",
    stroke_width: 1.0,
    label: "",
    is_front: False,
    if_overflow: Discard,
    fill_opacity: 1.0,
    x_axis_id: "0",
    y_axis_id: "0",
    custom_shape: None,
  )
}

// ---------------------------------------------------------------------------
// ReferenceLine builders
// ---------------------------------------------------------------------------

/// Set the stroke color.
pub fn line_stroke(
  config config: ReferenceLineConfig(msg),
  stroke_value stroke_value: String,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, stroke: stroke_value)
}

/// Set the stroke width.
pub fn line_stroke_width(
  config config: ReferenceLineConfig(msg),
  width width: Float,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, stroke_width: width)
}

/// Set the stroke dash pattern.
pub fn line_stroke_dasharray(
  config config: ReferenceLineConfig(msg),
  pattern pattern: String,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, stroke_dasharray: pattern)
}

/// Set the label text.
pub fn line_label(
  config config: ReferenceLineConfig(msg),
  label_text label_text: String,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, label: label_text)
}

/// Set the label position along the line.
pub fn line_label_position(
  config config: ReferenceLineConfig(msg),
  position position: LabelPosition,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, label_position: position)
}

/// Render in front of chart series.
/// Matches recharts ReferenceLine isFront prop.
pub fn line_is_front(
  config config: ReferenceLineConfig(msg),
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, is_front: True)
}

/// Set the overflow behavior.
/// Matches recharts ReferenceLine `ifOverflow` prop.
pub fn line_if_overflow(
  config config: ReferenceLineConfig(msg),
  overflow overflow: IfOverflow,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, if_overflow: overflow)
}

/// Set a segment of data-space points for the reference line.
/// When the segment has 2 or more points, the line is drawn between the
/// first two points (mapped through x/y scales) instead of spanning the
/// full plot width/height.  Matches recharts ReferenceLine `segment` prop.
pub fn line_segment(
  config config: ReferenceLineConfig(msg),
  points points: List(#(Float, Float)),
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, segment: points)
}

/// Set the fill opacity for the reference line.
/// Matches recharts ReferenceLine `fillOpacity` prop (default: 1.0).
pub fn line_fill_opacity(
  config config: ReferenceLineConfig(msg),
  opacity opacity: Float,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, fill_opacity: opacity)
}

/// Set the x-axis ID this reference line binds to.
/// Matches recharts ReferenceLine `xAxisId` prop (default: "0").
pub fn line_x_axis_id(
  config config: ReferenceLineConfig(msg),
  id id: String,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, x_axis_id: id)
}

/// Set the y-axis ID this reference line binds to.
/// Matches recharts ReferenceLine `yAxisId` prop (default: "0").
pub fn line_y_axis_id(
  config config: ReferenceLineConfig(msg),
  id id: String,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, y_axis_id: id)
}

/// Set a custom shape renderer for the reference line.
/// When provided, the renderer function is called instead of the default
/// line rendering.  Matches recharts ReferenceLine `shape` prop.
pub fn line_custom_shape(
  config config: ReferenceLineConfig(msg),
  renderer renderer: fn(ReferenceLineProps) -> Element(msg),
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, custom_shape: Some(renderer))
}

/// Set the position within a category axis band.
/// Matches recharts ReferenceLine `position` prop (default: RefLineMiddle).
pub fn line_position(
  config config: ReferenceLineConfig(msg),
  position position: RefLinePosition,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, position: position)
}

/// Set the fill color for the reference line.
/// Matches recharts ReferenceLine `fill` prop (default: "none").
pub fn line_fill(
  config config: ReferenceLineConfig(msg),
  fill_value fill_value: String,
) -> ReferenceLineConfig(msg) {
  ReferenceLineConfig(..config, fill: fill_value)
}

// ---------------------------------------------------------------------------
// ReferenceArea builders
// ---------------------------------------------------------------------------

/// Set the fill color.
pub fn area_fill(
  config config: ReferenceAreaConfig(msg),
  fill_value fill_value: String,
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(..config, fill: fill_value)
}

/// Set the fill opacity.
pub fn area_fill_opacity(
  config config: ReferenceAreaConfig(msg),
  opacity opacity: Float,
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(..config, fill_opacity: opacity)
}

/// Set the stroke color.
pub fn area_stroke(
  config config: ReferenceAreaConfig(msg),
  stroke_value stroke_value: String,
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(..config, stroke: stroke_value)
}

/// Set the label text.
pub fn area_label(
  config config: ReferenceAreaConfig(msg),
  label_text label_text: String,
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(..config, label: label_text)
}

/// Render in front of chart series.
pub fn area_is_front(
  config config: ReferenceAreaConfig(msg),
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(..config, is_front: True)
}

/// Set the overflow behavior.
/// Matches recharts ReferenceArea `ifOverflow` prop.
pub fn area_if_overflow(
  config config: ReferenceAreaConfig(msg),
  overflow overflow: IfOverflow,
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(..config, if_overflow: overflow)
}

/// Set the x-axis ID this reference area binds to.
/// Matches recharts ReferenceArea `xAxisId` prop (default: "0").
pub fn area_x_axis_id(
  config config: ReferenceAreaConfig(msg),
  id id: String,
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(..config, x_axis_id: id)
}

/// Set the y-axis ID this reference area binds to.
/// Matches recharts ReferenceArea `yAxisId` prop (default: "0").
pub fn area_y_axis_id(
  config config: ReferenceAreaConfig(msg),
  id id: String,
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(..config, y_axis_id: id)
}

/// Set a custom shape renderer for the reference area.
/// When provided, the renderer function is called instead of the default
/// rectangle rendering.  Matches recharts ReferenceArea `shape` prop.
pub fn area_custom_shape(
  config config: ReferenceAreaConfig(msg),
  renderer renderer: fn(ReferenceAreaProps) -> Element(msg),
) -> ReferenceAreaConfig(msg) {
  ReferenceAreaConfig(..config, custom_shape: Some(renderer))
}

// ---------------------------------------------------------------------------
// ReferenceDot builders
// ---------------------------------------------------------------------------

/// Set the dot radius.
/// Matches recharts ReferenceDot `r` prop (default: 10).
pub fn dot_radius(
  config config: ReferenceDotConfig(msg),
  radius radius: Float,
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, r: radius)
}

/// Set the fill color.
pub fn dot_fill(
  config config: ReferenceDotConfig(msg),
  fill_value fill_value: String,
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, fill: fill_value)
}

/// Set the stroke color.
pub fn dot_stroke(
  config config: ReferenceDotConfig(msg),
  stroke_value stroke_value: String,
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, stroke: stroke_value)
}

/// Set the stroke width.
pub fn dot_stroke_width(
  config config: ReferenceDotConfig(msg),
  width width: Float,
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, stroke_width: width)
}

/// Set the label text.
pub fn dot_label(
  config config: ReferenceDotConfig(msg),
  label_text label_text: String,
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, label: label_text)
}

/// Render in front of chart series.
pub fn dot_is_front(
  config config: ReferenceDotConfig(msg),
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, is_front: True)
}

/// Set the fill opacity for the reference dot.
/// Matches recharts ReferenceDot `fillOpacity` prop (default: 1.0).
pub fn dot_fill_opacity(
  config config: ReferenceDotConfig(msg),
  opacity opacity: Float,
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, fill_opacity: opacity)
}

/// Set the overflow behavior.
/// Matches recharts ReferenceDot `ifOverflow` prop (default: discard).
pub fn dot_if_overflow(
  config config: ReferenceDotConfig(msg),
  overflow overflow: IfOverflow,
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, if_overflow: overflow)
}

/// Set the x-axis ID this reference dot binds to.
/// Matches recharts ReferenceDot `xAxisId` prop (default: "0").
pub fn dot_x_axis_id(
  config config: ReferenceDotConfig(msg),
  id id: String,
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, x_axis_id: id)
}

/// Set the y-axis ID this reference dot binds to.
/// Matches recharts ReferenceDot `yAxisId` prop (default: "0").
pub fn dot_y_axis_id(
  config config: ReferenceDotConfig(msg),
  id id: String,
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, y_axis_id: id)
}

/// Set a custom shape renderer for the reference dot.
/// When provided, the renderer function is called instead of the default
/// circle rendering.  Matches recharts ReferenceDot `shape` prop.
pub fn dot_custom_shape(
  config config: ReferenceDotConfig(msg),
  renderer renderer: fn(ReferenceDotProps) -> Element(msg),
) -> ReferenceDotConfig(msg) {
  ReferenceDotConfig(..config, custom_shape: Some(renderer))
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a reference line.
/// For horizontal: draws across full plot width at the y value.
/// For vertical: draws across full plot height at the x category position.
/// The `position` field controls placement within a category axis band
/// (start, middle, end).
/// When a segment is set with 2+ points, draws a line between those data
/// points instead of using the direction-based full-span approach.
/// When custom_shape is set, delegates rendering to the custom function.
pub fn render_reference_line(
  config config: ReferenceLineConfig(msg),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  plot_x plot_x: Float,
  plot_y plot_y: Float,
  plot_width plot_width: Float,
  plot_height plot_height: Float,
  clip_path_id clip_path_id: String,
) -> Element(msg) {
  // Check segment first: if 2+ points, draw between them
  let #(x1, y1, x2, y2, is_segment) = case config.segment {
    [#(sx1, sy1), #(sx2, sy2), ..] -> {
      let px1 = scale.apply(x_scale, sx1)
      let py1 = scale.apply(y_scale, sy1)
      let px2 = scale.apply(x_scale, sx2)
      let py2 = scale.apply(y_scale, sy2)
      #(px1, py1, px2, py2, True)
    }
    _ ->
      case config.direction {
        Horizontal -> {
          let y_coord = scale.linear_apply(y_scale, config.value)
          #(plot_x, y_coord, plot_x +. plot_width, y_coord, False)
        }
        Vertical -> {
          let x_coord = scale.point_apply(x_scale, config.category)
          let offset = position_offset(config.position, x_scale)
          let x_pos = x_coord +. offset
          #(x_pos, plot_y, x_pos, plot_y +. plot_height, False)
        }
      }
  }

  // Check discard: if outside plot area, skip rendering
  case config.if_overflow {
    Discard -> {
      let in_range = case is_segment {
        True ->
          point_in_plot(x1, y1, plot_x, plot_y, plot_width, plot_height)
          && point_in_plot(x2, y2, plot_x, plot_y, plot_width, plot_height)
        False ->
          case config.direction {
            Horizontal -> y1 >=. plot_y && y1 <=. plot_y +. plot_height
            Vertical -> x1 >=. plot_x && x1 <=. plot_x +. plot_width
          }
      }
      case in_range {
        False -> element.none()
        True ->
          render_reference_line_inner(config, x1, y1, x2, y2, clip_path_id)
      }
    }
    _ -> render_reference_line_inner(config, x1, y1, x2, y2, clip_path_id)
  }
}

/// Inner rendering for reference line after overflow check.
fn render_reference_line_inner(
  config: ReferenceLineConfig(msg),
  x1: Float,
  y1: Float,
  x2: Float,
  y2: Float,
  clip_path_id: String,
) -> Element(msg) {
  let line_el = case config.custom_shape {
    Some(renderer) ->
      renderer(ReferenceLineProps(
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        stroke: config.stroke,
      ))
    None -> {
      let dash_attrs = case config.stroke_dasharray {
        "" -> []
        pattern -> [svg.attr("stroke-dasharray", pattern)]
      }

      svg.line(
        x1: math.fmt(x1),
        y1: math.fmt(y1),
        x2: math.fmt(x2),
        y2: math.fmt(y2),
        attrs: list.append(
          [
            svg.attr("stroke", config.stroke),
            svg.attr("stroke-width", float.to_string(config.stroke_width)),
            svg.attr("fill", config.fill),
          ],
          dash_attrs,
        ),
      )
    }
  }

  let label_el = case config.label {
    "" -> element.none()
    text -> {
      let #(lx, ly, anchor) = case config.direction {
        Horizontal ->
          case config.label_position {
            LabelStart -> #(x1, y1 -. 4.0, "start")
            LabelMiddle -> #({ x1 +. x2 } /. 2.0, y1 -. 4.0, "middle")
            LabelEnd -> #(x2, y2 -. 4.0, "end")
          }
        Vertical ->
          case config.label_position {
            LabelStart -> #(x1 +. 4.0, y2, "start")
            LabelMiddle -> #(x1 +. 4.0, { y1 +. y2 } /. 2.0, "start")
            LabelEnd -> #(x1 +. 4.0, y1, "start")
          }
      }
      svg.text(x: math.fmt(lx), y: math.fmt(ly), content: text, attrs: [
        svg.attr("text-anchor", anchor),
        svg.attr("font-size", "11"),
        svg.attr("fill", "var(--weft-chart-label, currentColor)"),
      ])
    }
  }

  let clip_attrs = case config.if_overflow {
    Hidden -> [svg.attr("clip-path", "url(#" <> clip_path_id <> ")")]
    _ -> []
  }

  svg.g(
    attrs: list.append(
      [svg.attr("class", "recharts-reference-line")],
      clip_attrs,
    ),
    children: [line_el, label_el],
  )
}

/// Render a reference area (shaded rectangle between two values).
/// When custom_shape is set, delegates rendering to the custom function.
pub fn render_reference_area(
  config config: ReferenceAreaConfig(msg),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  plot_x plot_x: Float,
  plot_y plot_y: Float,
  plot_width plot_width: Float,
  plot_height plot_height: Float,
  clip_path_id clip_path_id: String,
) -> Element(msg) {
  let #(rx, ry, rw, rh) = case config.direction {
    Horizontal -> {
      let y1_coord = scale.linear_apply(y_scale, config.value1)
      let y2_coord = scale.linear_apply(y_scale, config.value2)
      let min_y = case y1_coord <. y2_coord {
        True -> y1_coord
        False -> y2_coord
      }
      let max_y = case y1_coord >. y2_coord {
        True -> y1_coord
        False -> y2_coord
      }
      #(plot_x, min_y, plot_width, max_y -. min_y)
    }
    Vertical -> {
      let x1_coord = scale.point_apply(x_scale, config.category1)
      let x2_coord = scale.point_apply(x_scale, config.category2)
      let min_x = case x1_coord <. x2_coord {
        True -> x1_coord
        False -> x2_coord
      }
      let max_x = case x1_coord >. x2_coord {
        True -> x1_coord
        False -> x2_coord
      }
      #(min_x, plot_y, max_x -. min_x, plot_height)
    }
  }

  // Check discard
  case config.if_overflow {
    Discard -> {
      let in_range =
        rect_intersects_plot(
          rx,
          ry,
          rw,
          rh,
          plot_x,
          plot_y,
          plot_width,
          plot_height,
        )
      case in_range {
        False -> element.none()
        True ->
          render_reference_area_inner(config, rx, ry, rw, rh, clip_path_id)
      }
    }
    _ -> render_reference_area_inner(config, rx, ry, rw, rh, clip_path_id)
  }
}

/// Inner rendering for reference area after overflow check.
fn render_reference_area_inner(
  config: ReferenceAreaConfig(msg),
  rx: Float,
  ry: Float,
  rw: Float,
  rh: Float,
  clip_path_id: String,
) -> Element(msg) {
  let rect_el = case config.custom_shape {
    Some(renderer) ->
      renderer(ReferenceAreaProps(
        x: rx,
        y: ry,
        width: rw,
        height: rh,
        fill: config.fill,
      ))
    None -> {
      let stroke_attrs = case config.stroke {
        "none" -> []
        s -> [
          svg.attr("stroke", s),
          svg.attr("stroke-width", float.to_string(config.stroke_width)),
        ]
      }

      svg.el(
        tag: "rect",
        attrs: list.append(
          [
            svg.attr("x", math.fmt(rx)),
            svg.attr("y", math.fmt(ry)),
            svg.attr("width", math.fmt(rw)),
            svg.attr("height", math.fmt(rh)),
            svg.attr("fill", config.fill),
            svg.attr("fill-opacity", float.to_string(config.fill_opacity)),
          ],
          stroke_attrs,
        ),
        children: [],
      )
    }
  }

  let label_el = case config.label {
    "" -> element.none()
    text ->
      svg.text(
        x: math.fmt(rx +. rw /. 2.0),
        y: math.fmt(ry +. rh /. 2.0),
        content: text,
        attrs: [
          svg.attr("text-anchor", "middle"),
          svg.attr("dominant-baseline", "central"),
          svg.attr("font-size", "11"),
          svg.attr("fill", "var(--weft-chart-label, currentColor)"),
        ],
      )
  }

  let clip_attrs = case config.if_overflow {
    Hidden -> [svg.attr("clip-path", "url(#" <> clip_path_id <> ")")]
    _ -> []
  }

  svg.g(
    attrs: list.append(
      [svg.attr("class", "recharts-reference-area")],
      clip_attrs,
    ),
    children: [rect_el, label_el],
  )
}

/// Render a reference dot at a specific data coordinate.
/// When custom_shape is set, delegates rendering to the custom function.
/// Matches recharts ReferenceDot component.
pub fn render_reference_dot(
  config config: ReferenceDotConfig(msg),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  plot_x plot_x: Float,
  plot_y plot_y: Float,
  plot_width plot_width: Float,
  plot_height plot_height: Float,
  clip_path_id clip_path_id: String,
) -> Element(msg) {
  let cx = scale.linear_apply(x_scale, config.x)
  let cy = scale.linear_apply(y_scale, config.y)

  // Check discard: if outside plot area, skip rendering
  case config.if_overflow {
    Discard -> {
      let in_range =
        cx >=. plot_x
        && cx <=. plot_x +. plot_width
        && cy >=. plot_y
        && cy <=. plot_y +. plot_height
      case in_range {
        False -> element.none()
        True -> render_reference_dot_inner(config, cx, cy, clip_path_id)
      }
    }
    _ -> render_reference_dot_inner(config, cx, cy, clip_path_id)
  }
}

/// Inner rendering for reference dot after overflow check.
fn render_reference_dot_inner(
  config: ReferenceDotConfig(msg),
  cx: Float,
  cy: Float,
  clip_path_id: String,
) -> Element(msg) {
  let dot_el = case config.custom_shape {
    Some(renderer) ->
      renderer(ReferenceDotProps(
        cx: cx,
        cy: cy,
        r: config.r,
        fill: config.fill,
        stroke: config.stroke,
      ))
    None ->
      svg.circle(
        cx: math.fmt(cx),
        cy: math.fmt(cy),
        r: float.to_string(config.r),
        attrs: [
          svg.attr("fill", config.fill),
          svg.attr("fill-opacity", float.to_string(config.fill_opacity)),
          svg.attr("stroke", config.stroke),
          svg.attr("stroke-width", float.to_string(config.stroke_width)),
        ],
      )
  }

  let label_el = case config.label {
    "" -> element.none()
    text ->
      svg.text(
        x: math.fmt(cx),
        y: math.fmt(cy -. config.r -. 4.0),
        content: text,
        attrs: [
          svg.attr("text-anchor", "middle"),
          svg.attr("font-size", "11"),
          svg.attr("fill", "var(--weft-chart-label, currentColor)"),
        ],
      )
  }

  let clip_attrs = case config.if_overflow {
    Hidden -> [svg.attr("clip-path", "url(#" <> clip_path_id <> ")")]
    _ -> []
  }

  svg.g(
    attrs: list.append(
      [svg.attr("class", "recharts-reference-dot")],
      clip_attrs,
    ),
    children: [dot_el, label_el],
  )
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Compute the position offset for a reference line within a category band.
/// For BandScale, uses the bandwidth. For PointScale, uses the step between
/// consecutive categories. Returns 0.0 for non-categorical scales.
fn position_offset(position: RefLinePosition, x_scale: Scale) -> Float {
  case position {
    RefLineMiddle -> 0.0
    RefLineStart -> -1.0 *. category_half_step(x_scale)
    RefLineEnd -> category_half_step(x_scale)
  }
}

/// Compute half the step/bandwidth for a categorical scale.
fn category_half_step(s: Scale) -> Float {
  case s {
    scale.BandScale(
      categories:,
      range_start:,
      range_end:,
      padding_inner:,
      padding_outer:,
    ) -> {
      let n = list.length(categories)
      case n == 0 {
        True -> 0.0
        False -> {
          let total = math.abs(range_end -. range_start)
          let outer_total = 2.0 *. padding_outer
          let inner_total = int.to_float(n - 1) *. padding_inner
          let band_total = int.to_float(n)
          let bw = total /. { outer_total +. inner_total +. band_total }
          bw /. 2.0
        }
      }
    }
    scale.PointScale(categories:, range_start:, range_end:, padding:) -> {
      let n = list.length(categories)
      case n <= 1 {
        True -> 0.0
        False -> {
          let total = math.abs(range_end -. range_start)
          let pad_px = total *. padding /. 2.0
          let usable = total -. 2.0 *. pad_px
          let step = usable /. int.to_float(n - 1)
          step /. 2.0
        }
      }
    }
    _ -> 0.0
  }
}

/// Check whether a point lies within the plot bounds.
fn point_in_plot(
  x: Float,
  y: Float,
  plot_x: Float,
  plot_y: Float,
  plot_width: Float,
  plot_height: Float,
) -> Bool {
  x >=. plot_x
  && x <=. plot_x +. plot_width
  && y >=. plot_y
  && y <=. plot_y +. plot_height
}

/// Check whether a rectangle intersects the plot bounds.
fn rect_intersects_plot(
  rx: Float,
  ry: Float,
  rw: Float,
  rh: Float,
  plot_x: Float,
  plot_y: Float,
  plot_width: Float,
  plot_height: Float,
) -> Bool {
  case rw <=. 0.0 || rh <=. 0.0 {
    True -> False
    False -> {
      let rect_right = rx +. rw
      let rect_bottom = ry +. rh
      let plot_right = plot_x +. plot_width
      let plot_bottom = plot_y +. plot_height
      rect_right >. plot_x
      && rx <. plot_right
      && rect_bottom >. plot_y
      && ry <. plot_bottom
    }
  }
}
