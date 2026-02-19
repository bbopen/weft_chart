//// Line series component.
////
//// Renders a stroked curve through data points.  Unlike Area, the path
//// has no fill — only a visible stroke.  Supports dots at data points,
//// custom dash patterns, and multiple curve types.  When `connect_nulls`
//// is False (the default), missing data points break the line into
//// separate segments, matching the recharts Line behavior.

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import weft_chart/animation.{type AnimationConfig}
import weft_chart/curve
import weft_chart/internal/layout
import weft_chart/internal/math
import weft_chart/internal/svg
import weft_chart/render
import weft_chart/scale.{type Scale}
import weft_chart/shape

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for a line series.
pub type LineConfig(msg) {
  LineConfig(
    data_key: String,
    name: String,
    curve_type: curve.CurveType,
    stroke: String,
    stroke_width: Float,
    stroke_dasharray: String,
    connect_nulls: Bool,
    show_dot: Bool,
    dot_radius: Float,
    fill: String,
    hide: Bool,
    legend_type: shape.LegendIconType,
    tooltip_type: shape.TooltipType,
    show_label: Bool,
    unit: String,
    x_axis_id: String,
    y_axis_id: String,
    custom_dot: Option(fn(render.DotProps) -> Element(msg)),
    custom_label: Option(fn(render.LabelProps) -> Element(msg)),
    active_dot: Option(fn(render.DotProps) -> Element(msg)),
    active_index: Option(Int),
    css_class: String,
    animate_new_values: Bool,
    animation: AnimationConfig,
    clip_dot: Bool,
  )
}

/// Internal type for data points that may be missing.
type MaybePoint {
  ValidPoint(x: Float, y: Float)
  MissingPoint
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a line configuration with default settings.
/// When `name` is empty, `data_key` is used for tooltip/legend display.
pub fn line_config(data_key data_key: String) -> LineConfig(msg) {
  LineConfig(
    data_key: data_key,
    name: "",
    curve_type: curve.Linear,
    stroke: "var(--weft-chart-line-stroke, currentColor)",
    stroke_width: 2.0,
    stroke_dasharray: "",
    connect_nulls: False,
    show_dot: True,
    dot_radius: 3.0,
    fill: "#fff",
    hide: False,
    legend_type: shape.LineIcon,
    tooltip_type: shape.DefaultTooltip,
    show_label: False,
    unit: "",
    x_axis_id: "0",
    y_axis_id: "0",
    custom_dot: None,
    custom_label: None,
    active_dot: None,
    active_index: None,
    css_class: "",
    animate_new_values: True,
    animation: animation.line_default(),
    clip_dot: True,
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the curve interpolation type.
pub fn line_curve_type(
  config: LineConfig(msg),
  type_: curve.CurveType,
) -> LineConfig(msg) {
  LineConfig(..config, curve_type: type_)
}

/// Set the stroke color.
pub fn line_stroke(
  config: LineConfig(msg),
  stroke_value: String,
) -> LineConfig(msg) {
  LineConfig(..config, stroke: stroke_value)
}

/// Set the stroke width.
pub fn line_stroke_width(
  config: LineConfig(msg),
  width: Float,
) -> LineConfig(msg) {
  LineConfig(..config, stroke_width: width)
}

/// Set the stroke dash pattern (e.g. "5 5" for dashed).
pub fn line_stroke_dasharray(
  config: LineConfig(msg),
  pattern: String,
) -> LineConfig(msg) {
  LineConfig(..config, stroke_dasharray: pattern)
}

/// Connect null/missing data points instead of breaking the line.
pub fn line_connect_nulls(config: LineConfig(msg)) -> LineConfig(msg) {
  LineConfig(..config, connect_nulls: True)
}

/// Show or hide dots at data points.
pub fn line_dot(config: LineConfig(msg), show: Bool) -> LineConfig(msg) {
  LineConfig(..config, show_dot: show)
}

/// Set the dot radius.
pub fn line_dot_radius(
  config: LineConfig(msg),
  radius: Float,
) -> LineConfig(msg) {
  LineConfig(..config, dot_radius: radius)
}

/// Hide the line from rendering while keeping it in domain/legend calculation.
/// Matches recharts Line `hide` prop.
pub fn line_hide(config config: LineConfig(msg)) -> LineConfig(msg) {
  LineConfig(..config, hide: True)
}

/// Set the display name for tooltip and legend.
/// Matches recharts Line `name` prop.  When empty, `data_key` is used.
pub fn line_name(config: LineConfig(msg), name: String) -> LineConfig(msg) {
  LineConfig(..config, name: name)
}

/// Set the legend icon type for this series.
/// Matches recharts Line `legendType` prop (default: line).
pub fn line_legend_type(
  config: LineConfig(msg),
  icon_type: shape.LegendIconType,
) -> LineConfig(msg) {
  LineConfig(..config, legend_type: icon_type)
}

/// Set the fill color for dots at data points.
/// Matches recharts Line `fill` prop (default: "#fff").
pub fn line_fill(
  config config: LineConfig(msg),
  fill fill: String,
) -> LineConfig(msg) {
  LineConfig(..config, fill: fill)
}

/// Set the tooltip type to control whether this series appears in tooltips.
/// Matches recharts Line `tooltipType` prop (default: DefaultTooltip).
pub fn line_tooltip_type(
  config config: LineConfig(msg),
  type_ type_: shape.TooltipType,
) -> LineConfig(msg) {
  LineConfig(..config, tooltip_type: type_)
}

/// Show or hide value labels at each data point.
/// When True, the numeric value is rendered above each point.
pub fn line_label(
  config config: LineConfig(msg),
  show show: Bool,
) -> LineConfig(msg) {
  LineConfig(..config, show_label: show)
}

/// Set the unit string for tooltip display.
/// Matches recharts Line `unit` prop (default: "").
pub fn line_unit(
  config config: LineConfig(msg),
  unit unit: String,
) -> LineConfig(msg) {
  LineConfig(..config, unit: unit)
}

/// Set the x-axis ID this line series binds to.
/// Matches recharts Line `xAxisId` prop (default: "0").
pub fn line_x_axis_id(
  config config: LineConfig(msg),
  id id: String,
) -> LineConfig(msg) {
  LineConfig(..config, x_axis_id: id)
}

/// Set the y-axis ID this line series binds to.
/// Matches recharts Line `yAxisId` prop (default: "0").
pub fn line_y_axis_id(
  config config: LineConfig(msg),
  id id: String,
) -> LineConfig(msg) {
  LineConfig(..config, y_axis_id: id)
}

/// Set a custom dot render function for line data points.
/// When provided, replaces the default circle for each visible dot.
/// Matches recharts Line `dot` prop (element/function form).
pub fn line_custom_dot(
  config config: LineConfig(msg),
  renderer renderer: fn(render.DotProps) -> Element(msg),
) -> LineConfig(msg) {
  LineConfig(..config, custom_dot: Some(renderer))
}

/// Set a custom label render function for line data point labels.
/// When provided, replaces the default text label for each data point.
/// Matches recharts Line `label` prop (element/function form).
pub fn line_custom_label(
  config config: LineConfig(msg),
  renderer renderer: fn(render.LabelProps) -> Element(msg),
) -> LineConfig(msg) {
  LineConfig(..config, custom_label: Some(renderer))
}

/// Set a custom render function for the active (highlighted) dot.
/// When `active_index` matches a dot's index, this renderer is used
/// instead of the default dot.
/// Matches recharts Line `activeDot` prop.
pub fn line_active_dot(
  config config: LineConfig(msg),
  renderer renderer: fn(render.DotProps) -> Element(msg),
) -> LineConfig(msg) {
  LineConfig(..config, active_dot: Some(renderer))
}

/// Set the index of the dot to render in active state.
/// When set, the dot at this index uses the `active_dot` renderer
/// if provided, or default active styling otherwise.
/// Matches recharts Line `activeIndex` prop (from tooltip hover).
pub fn line_active_index(
  config config: LineConfig(msg),
  index index: Int,
) -> LineConfig(msg) {
  LineConfig(..config, active_index: Some(index))
}

/// Set the CSS class attribute on the line series group element.
/// Maps to the SVG `class` attribute.
/// Matches recharts Line `className` prop.
pub fn line_css_class(
  config config: LineConfig(msg),
  class class: String,
) -> LineConfig(msg) {
  LineConfig(..config, css_class: class)
}

/// Set whether to animate new data values when data updates.
/// When True, new data points animate in from offscreen.
/// Matches recharts Line `animateNewValues` prop (default: True).
pub fn line_animate_new_values(
  config config: LineConfig(msg),
  animate animate: Bool,
) -> LineConfig(msg) {
  LineConfig(..config, animate_new_values: animate)
}

/// Set whether dots are clipped to the chart area.
/// When True (default), dots at data points near the edge of the chart
/// are clipped along with the line path, matching recharts `clipDot={true}`.
/// When False, dots render outside the clip region.
pub fn line_clip_dot(
  config config: LineConfig(msg),
  clip clip: Bool,
) -> LineConfig(msg) {
  LineConfig(..config, clip_dot: clip)
}

/// Set the animation configuration for line entry effects.
pub fn line_animation(
  config config: LineConfig(msg),
  anim anim: AnimationConfig,
) -> LineConfig(msg) {
  LineConfig(..config, animation: anim)
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a line series given the data and scales.
/// The layout parameter controls coordinate mapping: Horizontal (default)
/// maps categories to X and values to Y; Vertical swaps them.
pub fn render_line(
  config config: LineConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  layout line_layout: layout.LayoutDirection,
) -> Element(msg) {
  // When hidden, skip rendering but the series still participates in
  // domain/legend calculation (handled by the chart container).
  case config.hide {
    True -> element.none()
    False ->
      render_line_visible(
        config,
        data,
        categories,
        x_scale,
        y_scale,
        line_layout,
      )
  }
}

/// Render a line series and return path and dot elements separately.
/// The first element contains the line paths and labels (to be clipped),
/// the second element contains the dots (clipping controlled by caller).
/// When hidden, both elements are `element.none()`.
pub fn render_line_parts(
  config config: LineConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  layout line_layout: layout.LayoutDirection,
) -> #(Element(msg), Element(msg)) {
  case config.hide {
    True -> #(element.none(), element.none())
    False ->
      render_line_parts_visible(
        config,
        data,
        categories,
        x_scale,
        y_scale,
        line_layout,
      )
  }
}

/// Internal rendering for a visible line series.
fn render_line_visible(
  config: LineConfig(msg),
  data: List(Dict(String, Float)),
  categories: List(String),
  x_scale: Scale,
  y_scale: Scale,
  line_layout: layout.LayoutDirection,
) -> Element(msg) {
  let #(path_el, dots_el) =
    render_line_parts_visible(
      config,
      data,
      categories,
      x_scale,
      y_scale,
      line_layout,
    )
  let class_value = case config.css_class {
    "" -> "recharts-line"
    cls -> "recharts-line " <> cls
  }
  svg.g(attrs: [svg.attr("class", class_value)], children: [path_el, dots_el])
}

/// Internal rendering that returns separate path and dot groups.
fn render_line_parts_visible(
  config: LineConfig(msg),
  data: List(Dict(String, Float)),
  categories: List(String),
  x_scale: Scale,
  y_scale: Scale,
  line_layout: layout.LayoutDirection,
) -> #(Element(msg), Element(msg)) {
  // Map data to points, preserving nulls for gap detection.
  // When Vertical, swap coordinate mapping: categories on Y, values on X.
  let maybe_points =
    list.zip(categories, data)
    |> list.map(fn(pair) {
      let #(cat, values) = pair
      case dict.get(values, config.data_key) {
        Ok(value) ->
          case line_layout {
            layout.Horizontal -> {
              let x = scale.point_apply(x_scale, cat)
              let y = scale.linear_apply(y_scale, value)
              ValidPoint(x: x, y: y)
            }
            layout.Vertical -> {
              let x = scale.linear_apply(x_scale, value)
              let y = scale.point_apply(y_scale, cat)
              ValidPoint(x: x, y: y)
            }
          }
        Error(_) -> MissingPoint
      }
    })

  let all_valid = extract_valid_points(maybe_points)

  case all_valid {
    [] -> #(element.none(), element.none())
    _ -> {
      // Determine segments based on connect_nulls
      let segments = case config.connect_nulls {
        True -> [all_valid]
        False -> split_segments(maybe_points)
      }

      // Build stroke attributes
      let dash_attrs = case config.stroke_dasharray {
        "" -> []
        pattern -> [svg.attr("stroke-dasharray", pattern)]
      }
      let stroke_attrs =
        list.append(
          [
            svg.attr("stroke", config.stroke),
            svg.attr("fill", "none"),
            svg.attr("stroke-width", float.to_string(config.stroke_width)),
          ],
          dash_attrs,
        )

      // Render each segment as a separate path
      let line_els =
        list.filter_map(segments, fn(seg) {
          case seg {
            [] -> Error(Nil)
            _ -> {
              let d = curve.path(curve_type: config.curve_type, points: seg)
              case config.animation.active {
                False -> Ok(svg.path(d: d, attrs: stroke_attrs))
                True -> {
                  let path_len = curve.approximate_path_length(points: seg)
                  let len_str = math.fmt(path_len)
                  let reveal_attrs =
                    list.flatten([
                      [
                        svg.attr("stroke-dasharray", len_str),
                        svg.attr("stroke-dashoffset", len_str),
                      ],
                      stroke_attrs,
                    ])
                  Ok(
                    svg.path_with_children(d: d, attrs: reveal_attrs, children: [
                      animation.animate_stroke_reveal(
                        path_length: path_len,
                        config: config.animation,
                      ),
                    ]),
                  )
                }
              }
            }
          }
        })

      // Dots (show all valid points regardless of segments)
      let valid_values =
        extract_valid_values(maybe_points, data, config.data_key)
      let dot_els = case config.show_dot {
        False -> []
        True ->
          list.index_map(list.zip(all_valid, valid_values), fn(pair, idx) {
            let #(#(px, py), value) = pair
            let dot_props =
              render.DotProps(
                cx: px,
                cy: py,
                r: config.dot_radius,
                index: idx,
                value: value,
                data_key: config.data_key,
                fill: config.fill,
                stroke: config.stroke,
              )
            // Check if this dot is active
            let is_active = case config.active_index {
              Some(active_idx) -> active_idx == idx
              None -> False
            }
            case is_active, config.active_dot {
              True, Some(renderer) -> renderer(dot_props)
              _, _ ->
                case config.custom_dot {
                  Some(renderer) -> renderer(dot_props)
                  None ->
                    svg.circle(
                      cx: math.fmt(px),
                      cy: math.fmt(py),
                      r: float.to_string(config.dot_radius),
                      attrs: [
                        svg.attr("fill", config.fill),
                        svg.attr("stroke", config.stroke),
                        svg.attr("stroke-width", "2"),
                      ],
                    )
                }
            }
          })
      }

      // Value labels
      let label_els = case config.show_label {
        False -> []
        True ->
          case config.custom_label {
            Some(renderer) ->
              list.index_map(list.zip(all_valid, valid_values), fn(pair, idx) {
                let #(#(px, py), value) = pair
                renderer(render.LabelProps(
                  x: px,
                  y: py -. 10.0,
                  width: 0.0,
                  height: 0.0,
                  index: idx,
                  value: format_line_value(value),
                  offset: 10.0,
                  position: "top",
                  fill: "var(--weft-chart-label, currentColor)",
                ))
              })
            None ->
              list.zip(all_valid, valid_values)
              |> list.map(fn(pair) {
                let #(#(px, py), value) = pair
                svg.text(
                  x: math.fmt(px),
                  y: math.fmt(py -. 10.0),
                  content: format_line_value(value),
                  attrs: [
                    svg.attr("text-anchor", "middle"),
                    svg.attr("font-size", "11"),
                    svg.attr("fill", "var(--weft-chart-label, currentColor)"),
                  ],
                )
              })
          }
      }

      // Path group: line paths + labels (to be clipped)
      let path_el =
        svg.g(
          attrs: [svg.attr("class", "recharts-line-paths")],
          children: list.flatten([line_els, label_els]),
        )

      // Dot group: rendered separately so caller can control clipping
      let dots_el =
        svg.g(
          attrs: [svg.attr("class", "recharts-line-dots")],
          children: dot_els,
        )

      #(path_el, dots_el)
    }
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Extract only the valid (non-missing) points as coordinate tuples.
fn extract_valid_points(maybe_points: List(MaybePoint)) -> List(#(Float, Float)) {
  list.filter_map(maybe_points, fn(mp) {
    case mp {
      ValidPoint(x:, y:) -> Ok(#(x, y))
      MissingPoint -> Error(Nil)
    }
  })
}

/// Extract values for valid (non-missing) points, preserving order.
fn extract_valid_values(
  maybe_points: List(MaybePoint),
  data: List(Dict(String, Float)),
  data_key: String,
) -> List(Float) {
  list.zip(maybe_points, data)
  |> list.filter_map(fn(pair) {
    let #(mp, values) = pair
    case mp {
      ValidPoint(..) -> dict.get(values, data_key)
      MissingPoint -> Error(Nil)
    }
  })
}

/// Format a line value as a label string.
fn format_line_value(value: Float) -> String {
  let rounded = float.round(value)
  case value == int.to_float(rounded) {
    True -> int.to_string(rounded)
    False -> math.fmt(value)
  }
}

/// Split a list of maybe-points into contiguous segments of valid points.
/// Each MissingPoint creates a break between segments.
fn split_segments(maybe_points: List(MaybePoint)) -> List(List(#(Float, Float))) {
  let #(segments, current) =
    list.fold(maybe_points, #([], []), fn(state, mp) {
      let #(done, acc) = state
      case mp {
        ValidPoint(x:, y:) -> #(done, [#(x, y), ..acc])
        MissingPoint ->
          case acc {
            [] -> #(done, [])
            _ -> #([list.reverse(acc), ..done], [])
          }
      }
    })

  let all = case current {
    [] -> segments
    _ -> [list.reverse(current), ..segments]
  }

  list.reverse(all)
}
