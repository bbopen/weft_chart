//// Radar chart series component.
////
//// Renders a polygon connecting data values on radial axes.  Each
//// vertex corresponds to a category axis spoke, with the distance from
//// center proportional to the data value.

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import weft_chart/animation.{type AnimationConfig}
import weft_chart/internal/math
import weft_chart/internal/polar
import weft_chart/internal/svg
import weft_chart/render
import weft_chart/shape

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for a radar series.
pub type RadarConfig(msg) {
  RadarConfig(
    data_key: String,
    name: String,
    fill: String,
    fill_opacity: Float,
    stroke: String,
    stroke_width: Float,
    show_dot: Bool,
    dot_radius: Float,
    legend_type: shape.LegendIconType,
    connect_nulls: Bool,
    unit: String,
    is_range: Bool,
    base_data_key: String,
    hide: Bool,
    tooltip_type: shape.TooltipType,
    show_label: Bool,
    custom_dot: Option(fn(render.DotProps) -> Element(msg)),
    custom_label: Option(fn(render.LabelProps) -> Element(msg)),
    angle_axis_id: String,
    radius_axis_id: String,
    custom_shape: Option(fn(List(#(Float, Float))) -> Element(msg)),
    active_dot: Option(fn(render.DotProps) -> Element(msg)),
    active_index: Option(Int),
    css_class: String,
    animation: AnimationConfig,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a radar configuration with default settings.
pub fn radar_config(data_key data_key: String) -> RadarConfig(msg) {
  RadarConfig(
    data_key: data_key,
    name: "",
    fill: "var(--weft-chart-radar-fill, currentColor)",
    fill_opacity: 0.3,
    stroke: "var(--weft-chart-radar-stroke, currentColor)",
    stroke_width: 2.0,
    show_dot: False,
    dot_radius: 3.0,
    legend_type: shape.RectIcon,
    connect_nulls: False,
    unit: "",
    is_range: False,
    base_data_key: "",
    hide: False,
    tooltip_type: shape.DefaultTooltip,
    show_label: False,
    custom_dot: None,
    custom_label: None,
    angle_axis_id: "0",
    radius_axis_id: "0",
    custom_shape: None,
    active_dot: None,
    active_index: None,
    css_class: "",
    animation: animation.line_default(),
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the fill color.
pub fn radar_fill(
  config: RadarConfig(msg),
  fill_value: String,
) -> RadarConfig(msg) {
  RadarConfig(..config, fill: fill_value)
}

/// Set the fill opacity.
pub fn radar_fill_opacity(
  config: RadarConfig(msg),
  opacity: Float,
) -> RadarConfig(msg) {
  RadarConfig(..config, fill_opacity: opacity)
}

/// Set the stroke color.
pub fn radar_stroke(
  config: RadarConfig(msg),
  stroke_value: String,
) -> RadarConfig(msg) {
  RadarConfig(..config, stroke: stroke_value)
}

/// Set the stroke width.
pub fn radar_stroke_width(
  config: RadarConfig(msg),
  width: Float,
) -> RadarConfig(msg) {
  RadarConfig(..config, stroke_width: width)
}

/// Show or hide dots at data points.
pub fn radar_dot(config: RadarConfig(msg), show: Bool) -> RadarConfig(msg) {
  RadarConfig(..config, show_dot: show)
}

/// Set the dot radius.
pub fn radar_dot_radius(
  config: RadarConfig(msg),
  radius: Float,
) -> RadarConfig(msg) {
  RadarConfig(..config, dot_radius: radius)
}

/// Set the legend icon type for this series.
/// Matches recharts Radar `legendType` prop (default: rect).
pub fn radar_legend_type(
  config: RadarConfig(msg),
  icon_type: shape.LegendIconType,
) -> RadarConfig(msg) {
  RadarConfig(..config, legend_type: icon_type)
}

/// Set the display name for tooltip and legend.
/// Matches recharts Radar `name` prop.  When empty, `data_key` is used.
pub fn radar_name(config: RadarConfig(msg), name: String) -> RadarConfig(msg) {
  RadarConfig(..config, name: name)
}

/// Set the unit string for tooltip display.
/// Matches recharts Radar `unit` prop.
pub fn radar_unit(
  config: RadarConfig(msg),
  unit_value: String,
) -> RadarConfig(msg) {
  RadarConfig(..config, unit: unit_value)
}

/// Enable range radar rendering between two values per spoke.
/// Sets `is_range` to True and configures the base data key for
/// the inner polygon.  The outer polygon uses `data_key`.
pub fn radar_range(
  config: RadarConfig(msg),
  base_key: String,
) -> RadarConfig(msg) {
  RadarConfig(..config, is_range: True, base_data_key: base_key)
}

/// Connect null/missing data points instead of using zero.
/// When True, missing vertices are skipped and adjacent valid ones are
/// connected directly.  When False (default), missing vertices render
/// at value 0.0.  Matches recharts Radar `connectNulls` prop.
pub fn radar_connect_nulls(config: RadarConfig(msg)) -> RadarConfig(msg) {
  RadarConfig(..config, connect_nulls: True)
}

/// Hide the radar from rendering while keeping it in domain/legend calculation.
/// Matches recharts Radar `hide` prop.
pub fn radar_hide(
  config config: RadarConfig(msg),
  hide hide: Bool,
) -> RadarConfig(msg) {
  RadarConfig(..config, hide: hide)
}

/// Set the tooltip type to control whether this series appears in tooltips.
/// Matches recharts Radar `tooltipType` prop (default: DefaultTooltip).
pub fn radar_tooltip_type(
  config config: RadarConfig(msg),
  tooltip_type tooltip_type: shape.TooltipType,
) -> RadarConfig(msg) {
  RadarConfig(..config, tooltip_type: tooltip_type)
}

/// Show or hide value labels at each radar vertex.
/// When True, the numeric value is rendered near each data point.
/// Matches recharts Radar `label` prop.
pub fn radar_label(
  config config: RadarConfig(msg),
  show show: Bool,
) -> RadarConfig(msg) {
  RadarConfig(..config, show_label: show)
}

/// Set a custom dot render function for radar vertices.
/// When provided, replaces the default circle for each visible dot.
/// Matches recharts Radar `dot` prop (element/function form).
pub fn radar_custom_dot(
  config config: RadarConfig(msg),
  renderer renderer: fn(render.DotProps) -> Element(msg),
) -> RadarConfig(msg) {
  RadarConfig(..config, custom_dot: Some(renderer))
}

/// Set a custom label render function for radar vertex labels.
/// When provided, replaces the default text label for each vertex.
/// Matches recharts Radar `label` prop (element/function form).
pub fn radar_custom_label(
  config config: RadarConfig(msg),
  renderer renderer: fn(render.LabelProps) -> Element(msg),
) -> RadarConfig(msg) {
  RadarConfig(..config, custom_label: Some(renderer))
}

/// Set the angle axis ID this radar binds to.
/// Matches recharts Radar `angleAxisId` prop (default: "0").
pub fn radar_angle_axis_id(
  config config: RadarConfig(msg),
  id id: String,
) -> RadarConfig(msg) {
  RadarConfig(..config, angle_axis_id: id)
}

/// Set the radius axis ID this radar binds to.
/// Matches recharts Radar `radiusAxisId` prop (default: "0").
pub fn radar_radius_axis_id(
  config config: RadarConfig(msg),
  id id: String,
) -> RadarConfig(msg) {
  RadarConfig(..config, radius_axis_id: id)
}

/// Set a custom polygon renderer for the radar shape.
/// When provided, receives the list of vertex coordinates and returns
/// a custom SVG element instead of the default filled polygon.
/// Matches recharts Radar `shape` prop.
pub fn radar_custom_shape(
  config config: RadarConfig(msg),
  renderer renderer: fn(List(#(Float, Float))) -> Element(msg),
) -> RadarConfig(msg) {
  RadarConfig(..config, custom_shape: Some(renderer))
}

/// Set a custom renderer for the active (hovered) dot on radar vertices.
/// When provided, replaces the default dot for the active data point.
/// Matches recharts Radar `activeDot` prop (element/function form).
pub fn radar_active_dot(
  config config: RadarConfig(msg),
  renderer renderer: fn(render.DotProps) -> Element(msg),
) -> RadarConfig(msg) {
  RadarConfig(..config, active_dot: Some(renderer))
}

/// Set the index of the active (highlighted) dot on the radar.
/// When set, the dot at this index uses the `active_dot` renderer
/// if provided, or default active styling otherwise.
/// Matches recharts Radar `activeIndex` prop (from tooltip hover).
pub fn radar_active_index(
  config config: RadarConfig(msg),
  index index: Int,
) -> RadarConfig(msg) {
  RadarConfig(..config, active_index: Some(index))
}

/// Set the CSS class applied to the radar group element.
pub fn radar_css_class(
  config config: RadarConfig(msg),
  class class: String,
) -> RadarConfig(msg) {
  RadarConfig(..config, css_class: class)
}

/// Set the animation configuration for radar entry effects.
pub fn radar_animation(
  config config: RadarConfig(msg),
  anim anim: AnimationConfig,
) -> RadarConfig(msg) {
  RadarConfig(..config, animation: anim)
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a radar series.
pub fn render_radar(
  config config: RadarConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  cx cx: Float,
  cy cy: Float,
  max_radius max_radius: Float,
  domain_max domain_max: Float,
) -> Element(msg) {
  case config.hide {
    True -> element.none()
    False ->
      render_radar_visible(
        config,
        data,
        categories,
        cx,
        cy,
        max_radius,
        domain_max,
      )
  }
}

/// Internal rendering for a visible radar series.
fn render_radar_visible(
  config: RadarConfig(msg),
  data: List(Dict(String, Float)),
  categories: List(String),
  cx: Float,
  cy: Float,
  max_radius: Float,
  domain_max: Float,
) -> Element(msg) {
  let n = list.length(categories)
  case n == 0 {
    True -> element.none()
    False -> {
      let angle_step = 360.0 /. int.to_float(n)

      // Compute polygon vertices, handling connect_nulls
      let indexed_data =
        list.index_map(list.zip(categories, data), fn(pair, index) {
          #(pair, index)
        })
      let vertices = case config.connect_nulls {
        False ->
          // Default: missing keys use 0.0
          list.map(indexed_data, fn(item) {
            let #(#(_cat, values), index) = item
            let value = case dict.get(values, config.data_key) {
              Ok(v) -> v
              Error(_) -> 0.0
            }
            let ratio = case domain_max <=. 0.0 {
              True -> 0.0
              False -> value /. domain_max
            }
            let radius = ratio *. max_radius
            let angle = int.to_float(index) *. angle_step
            polar.to_cartesian(
              cx: cx,
              cy: cy,
              radius: radius,
              angle_degrees: angle,
            )
          })
        True ->
          // connect_nulls: skip missing vertices entirely
          list.filter_map(indexed_data, fn(item) {
            let #(#(_cat, values), index) = item
            case dict.get(values, config.data_key) {
              Ok(value) -> {
                let ratio = case domain_max <=. 0.0 {
                  True -> 0.0
                  False -> value /. domain_max
                }
                let radius = ratio *. max_radius
                let angle = int.to_float(index) *. angle_step
                Ok(polar.to_cartesian(
                  cx: cx,
                  cy: cy,
                  radius: radius,
                  angle_degrees: angle,
                ))
              }
              Error(_) -> Error(Nil)
            }
          })
      }

      // Build polygon path — use custom_shape if provided
      let polygon_d = build_polygon_d(vertices)

      let polygon_el = case config.custom_shape {
        Some(renderer) -> renderer(vertices)
        None ->
          case config.animation.active {
            False ->
              svg.path(d: polygon_d, attrs: [
                svg.attr("fill", config.fill),
                svg.attr("fill-opacity", float.to_string(config.fill_opacity)),
                svg.attr("stroke", config.stroke),
                svg.attr("stroke-width", float.to_string(config.stroke_width)),
              ])
            True -> {
              let path_fn = fn(progress) {
                let animated =
                  list.map(vertices, fn(pt) {
                    #(
                      cx +. progress *. { pt.0 -. cx },
                      cy +. progress *. { pt.1 -. cy },
                    )
                  })
                build_polygon_d(animated)
              }
              let initial_d =
                build_polygon_d(list.map(vertices, fn(_) { #(cx, cy) }))
              let animate_el =
                animation.animate_path(
                  path_at_progress: path_fn,
                  config: config.animation,
                  steps: 30,
                )
              svg.path_with_children(
                d: initial_d,
                attrs: [
                  svg.attr("fill", config.fill),
                  svg.attr("fill-opacity", float.to_string(config.fill_opacity)),
                  svg.attr("stroke", config.stroke),
                  svg.attr("stroke-width", float.to_string(config.stroke_width)),
                ],
                children: [animate_el],
              )
            }
          }
      }

      // Dots
      let dot_els = case config.show_dot {
        False -> []
        True ->
          list.index_map(vertices, fn(pt, idx) {
            let dot_props =
              render.DotProps(
                cx: pt.0,
                cy: pt.1,
                r: config.dot_radius,
                index: idx,
                value: 0.0,
                data_key: config.data_key,
                fill: config.stroke,
                stroke: "var(--weft-chart-bg, #ffffff)",
              )
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
                      cx: math.fmt(pt.0),
                      cy: math.fmt(pt.1),
                      r: float.to_string(config.dot_radius),
                      attrs: [
                        svg.attr("fill", config.stroke),
                        svg.attr("stroke", "var(--weft-chart-bg, #ffffff)"),
                        svg.attr("stroke-width", "2"),
                      ],
                    )
                }
            }
          })
      }

      // Value labels at each vertex
      let label_els = case config.show_label {
        False -> []
        True ->
          case config.custom_label {
            Some(renderer) ->
              list.zip(vertices, list.zip(categories, data))
              |> list.index_map(fn(pair, idx) {
                let #(#(vx, vy), #(_cat, values)) = pair
                let value = case dict.get(values, config.data_key) {
                  Ok(v) -> v
                  Error(_) -> 0.0
                }
                renderer(render.LabelProps(
                  x: vx,
                  y: vy -. 8.0,
                  width: 0.0,
                  height: 0.0,
                  index: idx,
                  value: format_radar_value(value),
                  offset: 8.0,
                  position: "top",
                  fill: "var(--weft-chart-label, currentColor)",
                ))
              })
            None ->
              list.zip(vertices, list.zip(categories, data))
              |> list.filter_map(fn(pair) {
                let #(#(vx, vy), #(_cat, values)) = pair
                case dict.get(values, config.data_key) {
                  Ok(value) ->
                    Ok(
                      svg.text(
                        x: math.fmt(vx),
                        y: math.fmt(vy -. 8.0),
                        content: format_radar_value(value),
                        attrs: [
                          svg.attr("text-anchor", "middle"),
                          svg.attr("font-size", "11"),
                          svg.attr(
                            "fill",
                            "var(--weft-chart-label, currentColor)",
                          ),
                        ],
                      ),
                    )
                  Error(_) -> Error(Nil)
                }
              })
          }
      }

      let class_attr = case config.css_class {
        "" -> "recharts-radar"
        c -> "recharts-radar " <> c
      }
      svg.g(
        attrs: [svg.attr("class", class_attr)],
        children: list.flatten([[polygon_el], dot_els, label_els]),
      )
    }
  }
}

/// Format a radar value as a label string.
fn format_radar_value(value: Float) -> String {
  let rounded = float.round(value)
  case value == int.to_float(rounded) {
    True -> int.to_string(rounded)
    False -> math.fmt(value)
  }
}

/// Build an SVG polygon path string from a list of points.
fn build_polygon_d(points: List(#(Float, Float))) -> String {
  case points {
    [] -> ""
    [#(x0, y0), ..rest] -> {
      let start = "M" <> math.fmt(x0) <> "," <> math.fmt(y0)
      let segments =
        list.fold(rest, start, fn(acc, pt) {
          acc <> "L" <> math.fmt(pt.0) <> "," <> math.fmt(pt.1)
        })
      segments <> "Z"
    }
  }
}
