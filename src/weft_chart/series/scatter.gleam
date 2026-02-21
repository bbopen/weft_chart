//// Scatter series component.
////
//// Renders data points as symbols (circles, squares, etc.) at numeric X/Y
//// coordinates.  Supports size encoding via a Z data key, connecting lines
//// between points, and configurable symbol types.  Matches the recharts
//// Scatter component.

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element.{type Element}
import weft
import weft_chart/animation.{type AnimationConfig}
import weft_chart/internal/math
import weft_chart/internal/svg
import weft_chart/render
import weft_chart/scale.{type Scale}
import weft_chart/shape

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Symbol shape for scatter points.
pub type SymbolType {
  /// Circle symbol (default).
  CircleSymbol
  /// Square symbol.
  SquareSymbol
  /// Diamond symbol.
  DiamondSymbol
  /// Triangle symbol.
  TriangleSymbol
  /// Cross symbol (two intersecting rectangles).
  CrossSymbol
  /// Five-pointed star symbol.
  StarSymbol
  /// Y-shape (Mercedes/wye) symbol with three arms at 120-degree intervals.
  WyeSymbol
}

/// Line type for scatter connecting lines.
pub type ScatterLineType {
  /// Direct joint line between consecutive points (default).
  JointLine
  /// Best-fit/regression line through all points.
  FittingLine
}

/// Configuration for a scatter series.
pub type ScatterConfig(msg) {
  ScatterConfig(
    x_data_key: String,
    y_data_key: String,
    z_data_key: String,
    name: String,
    fill: weft.Color,
    stroke: weft.Color,
    stroke_width: Float,
    symbol_type: SymbolType,
    default_size: Float,
    show_line: Bool,
    hide: Bool,
    legend_type: shape.LegendIconType,
    tooltip_type: shape.TooltipType,
    line_type: ScatterLineType,
    line_joint_type: String,
    show_label: Bool,
    data: List(Dict(String, Float)),
    x_axis_id: String,
    y_axis_id: String,
    custom_dot: Option(fn(render.DotProps) -> Element(msg)),
    custom_label: Option(fn(render.LabelProps) -> Element(msg)),
    active_shape: Option(fn(render.DotProps) -> Element(msg)),
    active_index: Option(Int),
    css_class: String,
    animation: AnimationConfig,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a scatter configuration with default settings.
/// Matches recharts Scatter defaults: circle symbol, size=64.
pub fn scatter_config(
  x_data_key x_data_key: String,
  y_data_key y_data_key: String,
) -> ScatterConfig(msg) {
  ScatterConfig(
    x_data_key: x_data_key,
    y_data_key: y_data_key,
    z_data_key: "",
    name: "",
    fill: weft.css_color(value: "var(--weft-chart-scatter-fill, #8884d8)"),
    stroke: weft.css_color(value: ""),
    stroke_width: 0.0,
    symbol_type: CircleSymbol,
    default_size: 64.0,
    show_line: False,
    hide: False,
    legend_type: shape.CircleIcon,
    tooltip_type: shape.DefaultTooltip,
    line_type: JointLine,
    line_joint_type: "linear",
    show_label: False,
    data: [],
    x_axis_id: "0",
    y_axis_id: "0",
    custom_dot: None,
    custom_label: None,
    active_shape: None,
    active_index: None,
    css_class: "",
    animation: animation.scatter_default(),
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the fill color.
pub fn scatter_fill(
  config config: ScatterConfig(msg),
  fill fill: weft.Color,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, fill: fill)
}

/// Set the stroke color.
pub fn scatter_stroke(
  config config: ScatterConfig(msg),
  stroke stroke: weft.Color,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, stroke: stroke)
}

/// Set the stroke width.
pub fn scatter_stroke_width(
  config config: ScatterConfig(msg),
  width width: Float,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, stroke_width: width)
}

/// Set the display name for tooltip/legend.
pub fn scatter_name(
  config config: ScatterConfig(msg),
  name name: String,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, name: name)
}

/// Set the symbol type.
pub fn scatter_symbol(
  config config: ScatterConfig(msg),
  symbol symbol: SymbolType,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, symbol_type: symbol)
}

/// Set the default symbol size in square pixels.
/// Matches recharts Scatter size prop (default: 64).
pub fn scatter_size(
  config config: ScatterConfig(msg),
  size size: Float,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, default_size: size)
}

/// Set the z-axis data key for size encoding.
/// When set, symbol size varies based on data values.
pub fn scatter_z_data_key(
  config config: ScatterConfig(msg),
  key key: String,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, z_data_key: key)
}

/// Show or hide connecting line between scatter points.
pub fn scatter_show_line(
  config config: ScatterConfig(msg),
  show show: Bool,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, show_line: show)
}

/// Hide the scatter from rendering.
pub fn scatter_hide(config config: ScatterConfig(msg)) -> ScatterConfig(msg) {
  ScatterConfig(..config, hide: True)
}

/// Set the legend icon type.
pub fn scatter_legend_type(
  config config: ScatterConfig(msg),
  icon_type icon_type: shape.LegendIconType,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, legend_type: icon_type)
}

/// Set the line type for connecting scatter points.
/// Matches recharts Scatter `lineType` prop (default: joint).
pub fn scatter_line_type(
  config config: ScatterConfig(msg),
  type_ type_: ScatterLineType,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, line_type: type_)
}

/// Set the curve type name for joint lines.
/// Matches recharts Scatter `lineJointType` prop (default: "linear").
pub fn scatter_line_joint_type(
  config config: ScatterConfig(msg),
  type_ type_: String,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, line_joint_type: type_)
}

/// Set the tooltip type to control whether this series appears in tooltips.
/// Matches recharts Scatter `tooltipType` prop (default: DefaultTooltip).
pub fn scatter_tooltip_type(
  config config: ScatterConfig(msg),
  type_ type_: shape.TooltipType,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, tooltip_type: type_)
}

/// Set per-series data for this scatter.
/// When non-empty, this data is used instead of chart-level data.
/// Matches recharts Scatter `data` prop behavior.
pub fn scatter_data(
  config config: ScatterConfig(msg),
  data data: List(Dict(String, Float)),
) -> ScatterConfig(msg) {
  ScatterConfig(..config, data: data)
}

/// Show or hide value labels at each data point.
/// When True, the y-axis value is rendered above each point.
pub fn scatter_label(
  config config: ScatterConfig(msg),
  show show: Bool,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, show_label: show)
}

/// Set the x-axis ID this scatter series binds to.
/// Matches recharts Scatter `xAxisId` prop (default: "0").
pub fn scatter_x_axis_id(
  config config: ScatterConfig(msg),
  id id: String,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, x_axis_id: id)
}

/// Set the y-axis ID this scatter series binds to.
/// Matches recharts Scatter `yAxisId` prop (default: "0").
pub fn scatter_y_axis_id(
  config config: ScatterConfig(msg),
  id id: String,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, y_axis_id: id)
}

/// Set a custom dot render function for scatter data points.
/// When provided, replaces the default symbol for each visible point.
/// Matches recharts Scatter `shape` prop (element/function form).
pub fn scatter_custom_dot(
  config config: ScatterConfig(msg),
  renderer renderer: fn(render.DotProps) -> Element(msg),
) -> ScatterConfig(msg) {
  ScatterConfig(..config, custom_dot: Some(renderer))
}

/// Set a custom label render function for scatter data point labels.
/// When provided, replaces the default text label for each data point.
/// Matches recharts Scatter `label` prop (element/function form).
pub fn scatter_custom_label(
  config config: ScatterConfig(msg),
  renderer renderer: fn(render.LabelProps) -> Element(msg),
) -> ScatterConfig(msg) {
  ScatterConfig(..config, custom_label: Some(renderer))
}

/// Set a custom render function for the active (highlighted) scatter marker.
/// When `active_index` matches a point's index, this renderer is used
/// instead of the default symbol.
/// Matches recharts Scatter `activeShape` prop.
pub fn scatter_active_shape(
  config config: ScatterConfig(msg),
  renderer renderer: fn(render.DotProps) -> Element(msg),
) -> ScatterConfig(msg) {
  ScatterConfig(..config, active_shape: Some(renderer))
}

/// Set the index of the point to render in active state.
/// When set, the point at this index uses the `active_shape` renderer
/// if provided, or default active styling otherwise.
/// Matches recharts Scatter `activeIndex` prop.
pub fn scatter_active_index(
  config config: ScatterConfig(msg),
  index index: Int,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, active_index: Some(index))
}

/// Set the CSS class attribute on the scatter series group element.
/// Maps to the SVG `class` attribute.
/// Matches recharts Scatter `className` prop.
pub fn scatter_css_class(
  config config: ScatterConfig(msg),
  class class: String,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, css_class: class)
}

/// Set the animation configuration for scatter entry effects.
pub fn scatter_animation(
  config config: ScatterConfig(msg),
  anim anim: AnimationConfig,
) -> ScatterConfig(msg) {
  ScatterConfig(..config, animation: anim)
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a scatter series given the data and scales.
/// When z_domain_min == z_domain_max == 0.0 and z_range_min == z_range_max == 0.0,
/// raw z values are used as sizes (backward compatible behavior).
/// Otherwise, z values are linearly mapped from the z domain to the z range.
pub fn render_scatter(
  config config: ScatterConfig(msg),
  data data: List(Dict(String, Float)),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
) -> Element(msg) {
  render_scatter_with_z(
    config: config,
    data: data,
    x_scale: x_scale,
    y_scale: y_scale,
    z_domain_min: 0.0,
    z_domain_max: 0.0,
    z_range_min: 0.0,
    z_range_max: 0.0,
  )
}

/// Render a scatter series with explicit z-axis domain and range for size mapping.
/// When z_range_min == z_range_max == 0.0, raw z values are used directly.
/// Otherwise, z values are linearly interpolated from z domain to z range.
/// Matches recharts ZAxis component behavior.
pub fn render_scatter_with_z(
  config config: ScatterConfig(msg),
  data data: List(Dict(String, Float)),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  z_domain_min z_domain_min: Float,
  z_domain_max z_domain_max: Float,
  z_range_min z_range_min: Float,
  z_range_max z_range_max: Float,
) -> Element(msg) {
  let has_z_scale =
    z_range_min != 0.0
    || z_range_max != 0.0
    || z_domain_min != 0.0
    || z_domain_max != 0.0
  case config.hide {
    True -> element.none()
    False -> {
      // Compute point positions
      let points =
        list.filter_map(data, fn(d) {
          case dict.get(d, config.x_data_key), dict.get(d, config.y_data_key) {
            Ok(x_val), Ok(y_val) -> {
              let cx = scale.apply(x_scale, x_val)
              let cy = scale.apply(y_scale, y_val)
              let size = case config.z_data_key {
                "" -> config.default_size
                key ->
                  case dict.get(d, key) {
                    Ok(z_val) ->
                      case has_z_scale {
                        True ->
                          z_linear_interpolate(
                            z_val,
                            z_domain_min,
                            z_domain_max,
                            z_range_min,
                            z_range_max,
                          )
                        False -> z_val
                      }
                    Error(_) -> config.default_size
                  }
              }
              // radius = sqrt(size / pi) for area-proportional circles
              let radius = math.sqrt(size /. math.pi)
              Ok(#(cx, cy, radius, y_val))
            }
            _, _ -> Error(Nil)
          }
        })

      // Render symbols
      let symbol_els =
        list.index_map(points, fn(point, idx) {
          let #(cx, cy, radius, y_val) = point
          let dot_props =
            render.DotProps(
              cx: cx,
              cy: cy,
              r: radius,
              index: idx,
              value: y_val,
              data_key: config.y_data_key,
              fill: config.fill,
              stroke: config.stroke,
            )
          // Check if this point is active
          let is_active = case config.active_index {
            Some(active_idx) -> active_idx == idx
            None -> False
          }
          case is_active, config.active_shape {
            True, Some(renderer) -> renderer(dot_props)
            _, _ ->
              case config.custom_dot {
                Some(renderer) -> renderer(dot_props)
                None ->
                  render_symbol(
                    symbol: config.symbol_type,
                    cx: cx,
                    cy: cy,
                    radius: radius,
                    fill: weft.color_to_css(color: config.fill),
                    stroke: weft.color_to_css(color: config.stroke),
                    stroke_width: config.stroke_width,
                  )
              }
          }
        })

      // Render connecting line if enabled
      let line_el = case config.show_line {
        False -> element.none()
        True -> {
          let point_pairs =
            list.map(points, fn(p) {
              let #(cx, cy, _, _) = p
              #(cx, cy)
            })
          case point_pairs {
            [] -> element.none()
            [_] -> element.none()
            _ -> {
              let path = case config.line_type {
                JointLine -> Some(points_to_path(point_pairs))
                FittingLine -> fitting_line_path(point_pairs)
              }
              case path {
                None -> element.none()
                Some(d) ->
                  svg.el(
                    tag: "path",
                    attrs: [
                      svg.attr("d", d),
                      svg.attr("fill", "none"),
                      svg.attr("stroke", weft.color_to_css(color: config.fill)),
                      svg.attr("stroke-width", "1"),
                      svg.attr("class", "recharts-scatter-line"),
                    ],
                    children: [],
                  )
              }
            }
          }
        }
      }

      // Value labels
      let label_els = case config.show_label {
        False -> []
        True ->
          case config.custom_label {
            Some(renderer) ->
              list.index_map(points, fn(point, idx) {
                let #(cx, cy, radius, y_val) = point
                renderer(render.LabelProps(
                  x: cx,
                  y: cy -. radius -. 4.0,
                  width: 0.0,
                  height: 0.0,
                  index: idx,
                  value: format_scatter_value(y_val),
                  offset: radius +. 4.0,
                  position: "top",
                  fill: weft.css_color(
                    value: "var(--weft-chart-label, currentColor)",
                  ),
                ))
              })
            None ->
              list.map(points, fn(point) {
                let #(cx, cy, radius, y_val) = point
                svg.text(
                  x: math.fmt(cx),
                  y: math.fmt(cy -. radius -. 4.0),
                  content: format_scatter_value(y_val),
                  attrs: [
                    svg.attr("text-anchor", "middle"),
                    svg.attr("font-size", "11"),
                    svg.attr("fill", "var(--weft-chart-label, currentColor)"),
                  ],
                )
              })
          }
      }

      let scatter_class_value = case config.css_class {
        "" -> "recharts-scatter"
        cls -> "recharts-scatter " <> cls
      }
      case config.animation.active {
        False ->
          svg.g(
            attrs: [svg.attr("class", scatter_class_value)],
            children: list.flatten([[line_el], symbol_els, label_els]),
          )
        True ->
          svg.g(
            attrs: [
              svg.attr("class", scatter_class_value),
              svg.attr("opacity", "0"),
            ],
            children: list.flatten([
              [line_el],
              symbol_els,
              label_els,
              [
                animation.animate_attribute(
                  name: "opacity",
                  from: 0.0,
                  to: 1.0,
                  config: config.animation,
                ),
              ],
            ]),
          )
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Symbol rendering
// ---------------------------------------------------------------------------

fn render_symbol(
  symbol symbol: SymbolType,
  cx cx: Float,
  cy cy: Float,
  radius radius: Float,
  fill fill: String,
  stroke stroke: String,
  stroke_width stroke_width: Float,
) -> Element(msg) {
  let stroke_attrs = case stroke {
    "" -> []
    s -> [
      svg.attr("stroke", s),
      svg.attr("stroke-width", math.fmt(stroke_width)),
    ]
  }
  case symbol {
    CircleSymbol ->
      svg.circle(
        cx: math.fmt(cx),
        cy: math.fmt(cy),
        r: math.fmt(radius),
        attrs: list.flatten([
          [svg.attr("fill", fill), svg.attr("class", "recharts-scatter-symbol")],
          stroke_attrs,
        ]),
      )
    SquareSymbol -> {
      let side = radius *. 2.0
      svg.el(
        tag: "rect",
        attrs: list.flatten([
          [
            svg.attr("x", math.fmt(cx -. radius)),
            svg.attr("y", math.fmt(cy -. radius)),
            svg.attr("width", math.fmt(side)),
            svg.attr("height", math.fmt(side)),
            svg.attr("fill", fill),
            svg.attr("class", "recharts-scatter-symbol"),
          ],
          stroke_attrs,
        ]),
        children: [],
      )
    }
    DiamondSymbol -> {
      let d =
        "M"
        <> math.fmt(cx)
        <> ","
        <> math.fmt(cy -. radius)
        <> "L"
        <> math.fmt(cx +. radius)
        <> ","
        <> math.fmt(cy)
        <> "L"
        <> math.fmt(cx)
        <> ","
        <> math.fmt(cy +. radius)
        <> "L"
        <> math.fmt(cx -. radius)
        <> ","
        <> math.fmt(cy)
        <> "Z"
      svg.el(
        tag: "path",
        attrs: list.flatten([
          [
            svg.attr("d", d),
            svg.attr("fill", fill),
            svg.attr("class", "recharts-scatter-symbol"),
          ],
          stroke_attrs,
        ]),
        children: [],
      )
    }
    TriangleSymbol -> {
      let h = radius *. 1.732
      let d =
        "M"
        <> math.fmt(cx)
        <> ","
        <> math.fmt(cy -. radius)
        <> "L"
        <> math.fmt(cx +. h /. 2.0)
        <> ","
        <> math.fmt(cy +. radius /. 2.0)
        <> "L"
        <> math.fmt(cx -. h /. 2.0)
        <> ","
        <> math.fmt(cy +. radius /. 2.0)
        <> "Z"
      svg.el(
        tag: "path",
        attrs: list.flatten([
          [
            svg.attr("d", d),
            svg.attr("fill", fill),
            svg.attr("class", "recharts-scatter-symbol"),
          ],
          stroke_attrs,
        ]),
        children: [],
      )
    }
    CrossSymbol -> {
      // Two intersecting rectangles centered at (cx, cy)
      let arm = radius *. 2.0
      let thickness = radius /. 2.5
      let half_t = thickness /. 2.0
      let half_a = arm /. 2.0
      // Vertical bar
      let v_bar =
        svg.el(
          tag: "rect",
          attrs: [
            svg.attr("x", math.fmt(cx -. half_t)),
            svg.attr("y", math.fmt(cy -. half_a)),
            svg.attr("width", math.fmt(thickness)),
            svg.attr("height", math.fmt(arm)),
          ],
          children: [],
        )
      // Horizontal bar
      let h_bar =
        svg.el(
          tag: "rect",
          attrs: [
            svg.attr("x", math.fmt(cx -. half_a)),
            svg.attr("y", math.fmt(cy -. half_t)),
            svg.attr("width", math.fmt(arm)),
            svg.attr("height", math.fmt(thickness)),
          ],
          children: [],
        )
      svg.g(
        attrs: list.flatten([
          [
            svg.attr("fill", fill),
            svg.attr("class", "recharts-scatter-symbol"),
          ],
          stroke_attrs,
        ]),
        children: [v_bar, h_bar],
      )
    }
    StarSymbol -> {
      // 5-pointed star: 10-point polygon alternating outer/inner radius
      let inner = radius *. 0.382
      let star_indices =
        int.range(from: 0, to: 10, with: [], run: fn(acc, i) { [i, ..acc] })
        |> list.reverse
      let points_str =
        list.map(star_indices, fn(i) {
          // Angle in degrees: start at top (-90), step 36 degrees
          let angle_deg = int.to_float(i) *. 36.0 -. 90.0
          let angle_rad = math.to_radians(angle_deg)
          let r = case i % 2 == 0 {
            True -> radius
            False -> inner
          }
          let px = cx +. r *. math.cos(angle_rad)
          let py = cy +. r *. math.sin(angle_rad)
          math.fmt(px) <> "," <> math.fmt(py)
        })
        |> string.join(" ")
      svg.el(
        tag: "polygon",
        attrs: list.flatten([
          [
            svg.attr("points", points_str),
            svg.attr("fill", fill),
            svg.attr("class", "recharts-scatter-symbol"),
          ],
          stroke_attrs,
        ]),
        children: [],
      )
    }
    WyeSymbol -> {
      // Y-shape: three arms radiating from center at 120-degree intervals
      // Arms at 90 (up), 210, and 330 degrees
      let thickness = radius /. 3.0
      let half_t = thickness /. 2.0
      let arm_angles = [90.0, 210.0, 330.0]
      let d =
        list.map(arm_angles, fn(angle_deg) {
          let angle_rad = math.to_radians(angle_deg)
          let perp_rad = math.to_radians(angle_deg +. 90.0)
          // Tip of arm
          let tip_x = cx +. radius *. math.cos(angle_rad)
          let tip_y = cy -. radius *. math.sin(angle_rad)
          // Perpendicular offsets for thickness
          let dx = half_t *. math.cos(perp_rad)
          let dy = half_t *. math.sin(perp_rad)
          // Four corners: center-left, center-right, tip-right, tip-left
          "M"
          <> math.fmt(cx +. dx)
          <> ","
          <> math.fmt(cy -. dy)
          <> "L"
          <> math.fmt(tip_x +. dx)
          <> ","
          <> math.fmt(tip_y -. dy)
          <> "L"
          <> math.fmt(tip_x -. dx)
          <> ","
          <> math.fmt(tip_y +. dy)
          <> "L"
          <> math.fmt(cx -. dx)
          <> ","
          <> math.fmt(cy +. dy)
          <> "Z"
        })
        |> string.join("")
      svg.el(
        tag: "path",
        attrs: list.flatten([
          [
            svg.attr("d", d),
            svg.attr("fill", fill),
            svg.attr("class", "recharts-scatter-symbol"),
          ],
          stroke_attrs,
        ]),
        children: [],
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Format a scatter value as a label string.
fn format_scatter_value(value: Float) -> String {
  let rounded = float.round(value)
  case value == int.to_float(rounded) {
    True -> int.to_string(rounded)
    False -> math.fmt(value)
  }
}

fn points_to_path(points: List(#(Float, Float))) -> String {
  case points {
    [] -> ""
    [#(x, y), ..rest] -> {
      let start = "M" <> math.fmt(x) <> "," <> math.fmt(y)
      list.fold(rest, start, fn(acc, p) {
        acc <> "L" <> math.fmt(p.0) <> "," <> math.fmt(p.1)
      })
    }
  }
}

/// Build a least-squares fitting line path for scatter points.
///
/// Returns None when there are fewer than 2 points.
fn fitting_line_path(points: List(#(Float, Float))) -> Option(String) {
  case regression_endpoints(points) {
    None -> None
    Some(#(x1, y1, x2, y2)) ->
      Some(
        "M"
        <> math.fmt(x1)
        <> ","
        <> math.fmt(y1)
        <> "L"
        <> math.fmt(x2)
        <> ","
        <> math.fmt(y2),
      )
  }
}

/// Compute fitting-line endpoints spanning the observed x-domain.
///
/// Uses ordinary least squares. If x variance is near zero, falls back
/// to a vertical line through mean x and y min/max.
fn regression_endpoints(
  points: List(#(Float, Float)),
) -> Option(#(Float, Float, Float, Float)) {
  case points {
    [] -> None
    [_] -> None
    [first, ..rest] -> {
      let #(fx, fy) = first
      let #(sum_x, sum_y, sum_xx, sum_xy, min_x, max_x, min_y, max_y) =
        list.fold(
          rest,
          #(fx, fy, fx *. fx, fx *. fy, fx, fx, fy, fy),
          fn(acc, point) {
            let #(sx, sy, sxx, sxy, lo_x, hi_x, lo_y, hi_y) = acc
            let #(x, y) = point
            #(
              sx +. x,
              sy +. y,
              sxx +. x *. x,
              sxy +. x *. y,
              float.min(lo_x, x),
              float.max(hi_x, x),
              float.min(lo_y, y),
              float.max(hi_y, y),
            )
          },
        )
      let n = int.to_float(list.length(points))
      let denom = n *. sum_xx -. sum_x *. sum_x
      case float.absolute_value(denom) <. 0.0000001 {
        True -> {
          let mean_x = sum_x /. n
          Some(#(mean_x, min_y, mean_x, max_y))
        }
        False -> {
          let slope = { n *. sum_xy -. sum_x *. sum_y } /. denom
          let intercept = { sum_y -. slope *. sum_x } /. n
          Some(#(
            min_x,
            slope *. min_x +. intercept,
            max_x,
            slope *. max_x +. intercept,
          ))
        }
      }
    }
  }
}

/// Linearly interpolate a z value from domain to range.
/// When domain span is zero, returns the midpoint of the range.
fn z_linear_interpolate(
  value: Float,
  domain_min: Float,
  domain_max: Float,
  range_min: Float,
  range_max: Float,
) -> Float {
  let domain_span = domain_max -. domain_min
  case domain_span == 0.0 {
    True -> { range_min +. range_max } /. 2.0
    False -> {
      let t = { value -. domain_min } /. domain_span
      range_min +. t *. { range_max -. range_min }
    }
  }
}
