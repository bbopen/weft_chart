//// Radial bar chart series component.
////
//// Renders arc segments radiating from a center point.  Each data value
//// maps to a sector arc whose angular extent is proportional to the
//// value.

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import weft
import weft_chart/animation.{type AnimationConfig}
import weft_chart/internal/math
import weft_chart/internal/polar
import weft_chart/internal/svg
import weft_chart/render
import weft_chart/shape

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for a radial bar series.
pub type RadialBarConfig(msg) {
  RadialBarConfig(
    data_key: String,
    inner_radius: Float,
    outer_radius: Float,
    corner_radius: Float,
    show_background: Bool,
    show_label: Bool,
    start_angle: Float,
    end_angle: Float,
    fills: List(String),
    legend_type: shape.LegendIconType,
    force_corner_radius: Bool,
    corner_is_external: Bool,
    min_point_size: Float,
    max_bar_size: Float,
    stack_id: String,
    hide: Bool,
    tooltip_type: shape.TooltipType,
    data: List(Dict(String, Float)),
    custom_label: Option(fn(render.LabelProps) -> Element(msg)),
    angle_axis_id: String,
    radius_axis_id: String,
    custom_shape: Option(fn(render.SectorProps) -> Element(msg)),
    active_shape: Option(fn(render.SectorProps) -> Element(msg)),
    active_index: Int,
    stroke: weft.Color,
    stroke_width: Float,
    css_class: String,
    animation: AnimationConfig,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a radial bar configuration with default settings.
pub fn radial_bar_config(data_key data_key: String) -> RadialBarConfig(msg) {
  RadialBarConfig(
    data_key: data_key,
    inner_radius: 30.0,
    outer_radius: 100.0,
    corner_radius: 0.0,
    show_background: False,
    show_label: False,
    start_angle: 90.0,
    end_angle: -270.0,
    fills: [
      "var(--weft-chart-1, #2563eb)",
      "var(--weft-chart-2, #60a5fa)",
      "var(--weft-chart-3, #93c5fd)",
      "var(--weft-chart-4, #bfdbfe)",
      "var(--weft-chart-5, #dbeafe)",
    ],
    legend_type: shape.RectIcon,
    force_corner_radius: False,
    corner_is_external: False,
    min_point_size: 0.0,
    max_bar_size: 0.0,
    stack_id: "",
    hide: False,
    tooltip_type: shape.DefaultTooltip,
    data: [],
    custom_label: None,
    angle_axis_id: "0",
    radius_axis_id: "0",
    custom_shape: None,
    active_shape: None,
    active_index: -1,
    stroke: weft.css_color(value: "none"),
    stroke_width: 0.0,
    css_class: "",
    animation: animation.line_default(),
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the inner radius.
pub fn radial_bar_inner_radius(
  config: RadialBarConfig(msg),
  radius: Float,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, inner_radius: radius)
}

/// Set the outer radius.
pub fn radial_bar_outer_radius(
  config: RadialBarConfig(msg),
  radius: Float,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, outer_radius: radius)
}

/// Set the corner radius for rounded arc edges.
pub fn radial_bar_corner_radius(
  config: RadialBarConfig(msg),
  radius: Float,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, corner_radius: radius)
}

/// Show background arcs.
pub fn radial_bar_background(
  config: RadialBarConfig(msg),
  show: Bool,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, show_background: show)
}

/// Show value labels.
pub fn radial_bar_label(
  config: RadialBarConfig(msg),
  show: Bool,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, show_label: show)
}

/// Set the start angle in degrees.
pub fn radial_bar_start_angle(
  config: RadialBarConfig(msg),
  angle: Float,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, start_angle: angle)
}

/// Set the end angle in degrees.
pub fn radial_bar_end_angle(
  config: RadialBarConfig(msg),
  angle: Float,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, end_angle: angle)
}

/// Set the fill colors (cycled across data points).
pub fn radial_bar_fills(
  config: RadialBarConfig(msg),
  fills: List(String),
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, fills: fills)
}

/// Set the legend icon type for this series.
/// Matches recharts RadialBar `legendType` prop (default: rect).
pub fn radial_bar_legend_type(
  config: RadialBarConfig(msg),
  icon_type: shape.LegendIconType,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, legend_type: icon_type)
}

/// Force corner radius even on small arcs.
/// Matches recharts RadialBar `forceCornerRadius` prop.
pub fn radial_bar_force_corner_radius(
  config: RadialBarConfig(msg),
  force: Bool,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, force_corner_radius: force)
}

/// Render corners outside the arc bounds.
/// Matches recharts RadialBar `cornerIsExternal` prop.
pub fn radial_bar_corner_is_external(
  config: RadialBarConfig(msg),
  external: Bool,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, corner_is_external: external)
}

/// Set minimum arc angle in degrees for tiny values.
/// Matches recharts RadialBar `minPointSize` prop.
pub fn radial_bar_min_point_size(
  config: RadialBarConfig(msg),
  size: Float,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, min_point_size: size)
}

/// Cap bar thickness when > 0.
/// Matches recharts RadialBar `maxBarSize` prop.
pub fn radial_bar_max_bar_size(
  config: RadialBarConfig(msg),
  size: Float,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, max_bar_size: size)
}

/// Set the stacking group identifier.
/// Matches recharts RadialBar `stackId` prop.
pub fn radial_bar_stack_id(
  config: RadialBarConfig(msg),
  id: String,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, stack_id: id)
}

/// Hide the radial bar from rendering.
/// Matches recharts RadialBar `hide` prop.
pub fn radial_bar_hide(config: RadialBarConfig(msg)) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, hide: True)
}

/// Set the tooltip type to control whether this series appears in tooltips.
/// Matches recharts RadialBar `tooltipType` prop (default: DefaultTooltip).
pub fn radial_bar_tooltip_type(
  config config: RadialBarConfig(msg),
  tooltip_type tooltip_type: shape.TooltipType,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, tooltip_type: tooltip_type)
}

/// Set per-series data for this radial bar.
/// When non-empty, this data is used instead of chart-level data.
/// Matches recharts RadialBar `data` prop behavior.
pub fn radial_bar_data(
  config config: RadialBarConfig(msg),
  data data: List(Dict(String, Float)),
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, data: data)
}

/// Set a custom label render function for radial bar value labels.
/// When provided, replaces the default text label for each bar.
/// Matches recharts RadialBar `label` prop (element/function form).
pub fn radial_bar_custom_label(
  config config: RadialBarConfig(msg),
  renderer renderer: fn(render.LabelProps) -> Element(msg),
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, custom_label: Some(renderer))
}

/// Set the angle axis ID this radial bar binds to.
/// Matches recharts RadialBar `angleAxisId` prop (default: "0").
pub fn radial_bar_angle_axis_id(
  config config: RadialBarConfig(msg),
  id id: String,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, angle_axis_id: id)
}

/// Set the radius axis ID this radial bar binds to.
/// Matches recharts RadialBar `radiusAxisId` prop (default: "0").
pub fn radial_bar_radius_axis_id(
  config config: RadialBarConfig(msg),
  id id: String,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, radius_axis_id: id)
}

/// Set a custom renderer for radial bar segments.
/// When provided, each bar segment is rendered using this function.
/// Matches recharts RadialBar `shape` prop.
pub fn radial_bar_custom_shape(
  config config: RadialBarConfig(msg),
  renderer renderer: fn(render.SectorProps) -> Element(msg),
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, custom_shape: Some(renderer))
}

/// Set a custom renderer for the active (hovered) bar segment.
/// When provided, the active segment is rendered using this function.
/// Matches recharts RadialBar `activeShape` prop.
pub fn radial_bar_active_shape(
  config config: RadialBarConfig(msg),
  renderer renderer: fn(render.SectorProps) -> Element(msg),
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, active_shape: Some(renderer))
}

/// Set the active segment index for custom active shape dispatch.
/// When >= 0, the segment at this index uses the `active_shape` renderer.
/// Matches recharts RadialBar `activeIndex` prop (default: -1 = none).
pub fn radial_bar_active_index(
  config config: RadialBarConfig(msg),
  index index: Int,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, active_index: index)
}

/// Set the stroke color for bar segments.
/// Matches recharts RadialBar `stroke` prop (default: "none").
pub fn radial_bar_stroke(
  config config: RadialBarConfig(msg),
  stroke_value stroke_value: weft.Color,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, stroke: stroke_value)
}

/// Set the stroke width for bar segments.
/// Matches recharts RadialBar `strokeWidth` prop (default: 0.0).
pub fn radial_bar_stroke_width(
  config config: RadialBarConfig(msg),
  width width: Float,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, stroke_width: width)
}

/// Set the CSS class applied to the radial bar group element.
pub fn radial_bar_css_class(
  config config: RadialBarConfig(msg),
  class class: String,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, css_class: class)
}

/// Set the animation configuration for radial bar entry effects.
pub fn radial_bar_animation(
  config config: RadialBarConfig(msg),
  anim anim: AnimationConfig,
) -> RadialBarConfig(msg) {
  RadialBarConfig(..config, animation: anim)
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a radial bar series.
pub fn render_radial_bars(
  config config: RadialBarConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  cx cx: Float,
  cy cy: Float,
  domain_max domain_max: Float,
) -> Element(msg) {
  case config.hide {
    True -> element.none()
    False -> {
      let n = list.length(categories)
      case n == 0 {
        True -> element.none()
        False -> {
          let radius_range = config.outer_radius -. config.inner_radius
          let raw_bar_height = radius_range /. int.to_float(n)
          let bar_height = case config.max_bar_size >. 0.0 {
            True -> float.min(raw_bar_height, config.max_bar_size)
            False -> raw_bar_height
          }
          let total_angle = config.end_angle -. config.start_angle

          let bar_els =
            list.index_map(list.zip(categories, data), fn(pair, index) {
              let #(_cat, values) = pair
              let value = case dict.get(values, config.data_key) {
                Ok(v) -> v
                Error(_) -> 0.0
              }

              let inner_r =
                config.inner_radius +. int.to_float(index) *. bar_height
              let outer_r = inner_r +. bar_height *. 0.8
              let fill_color = cycle_fill(config.fills, index)

              // Background arc
              let bg_el = case config.show_background {
                False -> element.none()
                True -> {
                  let bg_d =
                    make_sector_path(
                      config: config,
                      cx: cx,
                      cy: cy,
                      inner_r: inner_r,
                      outer_r: outer_r,
                      start: config.start_angle,
                      end: config.start_angle +. total_angle,
                    )
                  svg.path(d: bg_d, attrs: [
                    svg.attr("fill", "var(--weft-chart-radial-bg, #f4f4f5)"),
                    svg.attr("opacity", "0.3"),
                  ])
                }
              }

              // Data arc
              let ratio = case domain_max <=. 0.0 {
                True -> 0.0
                False -> value /. domain_max
              }
              let raw_delta = total_angle *. ratio
              let delta_angle = case
                float.absolute_value(raw_delta) <. config.min_point_size
                && config.min_point_size >. 0.0
                && value >. 0.0
              {
                True -> {
                  let sign = case total_angle <. 0.0 {
                    True -> -1.0
                    False -> 1.0
                  }
                  sign *. config.min_point_size
                }
                False -> raw_delta
              }
              let data_angle = config.start_angle +. delta_angle

              // Dispatch to active_shape/custom_shape renderers if provided
              let sector_props =
                render.SectorProps(
                  cx: cx,
                  cy: cy,
                  inner_radius: inner_r,
                  outer_radius: outer_r,
                  start_angle: config.start_angle,
                  end_angle: data_angle,
                  index: index,
                  fill: weft.css_color(value: fill_color),
                  stroke: config.stroke,
                )
              let is_active =
                config.active_index >= 0 && config.active_index == index
              let data_el = case is_active, config.active_shape {
                True, Some(renderer) -> renderer(sector_props)
                _, _ ->
                  case config.custom_shape {
                    Some(renderer) -> renderer(sector_props)
                    None -> {
                      let stroke_attrs = stroke_attributes(config)
                      let data_d =
                        make_sector_path(
                          config: config,
                          cx: cx,
                          cy: cy,
                          inner_r: inner_r,
                          outer_r: outer_r,
                          start: config.start_angle,
                          end: data_angle,
                        )
                      case config.animation.active {
                        False ->
                          svg.path(d: data_d, attrs: [
                            svg.attr("fill", fill_color),
                            ..stroke_attrs
                          ])
                        True -> {
                          let sa = config.start_angle
                          let path_fn = fn(progress) {
                            let animated_end =
                              sa +. progress *. { data_angle -. sa }
                            make_sector_path(
                              config: config,
                              cx: cx,
                              cy: cy,
                              inner_r: inner_r,
                              outer_r: outer_r,
                              start: sa,
                              end: animated_end,
                            )
                          }
                          let initial_d =
                            make_sector_path(
                              config: config,
                              cx: cx,
                              cy: cy,
                              inner_r: inner_r,
                              outer_r: outer_r,
                              start: sa,
                              end: sa +. 0.001,
                            )
                          let animate_el =
                            animation.animate_path(
                              path_at_progress: path_fn,
                              config: config.animation,
                              steps: 30,
                            )
                          svg.path_with_children(
                            d: initial_d,
                            attrs: [
                              svg.attr("fill", fill_color),
                              ..stroke_attrs
                            ],
                            children: [animate_el],
                          )
                        }
                      }
                    }
                  }
              }

              // Label
              let label_el = case config.show_label {
                False -> element.none()
                True -> {
                  let mid_r = { inner_r +. outer_r } /. 2.0
                  let mid_a = polar.mid_angle(config.start_angle, data_angle)
                  let #(lx, ly) =
                    polar.to_cartesian(
                      cx: cx,
                      cy: cy,
                      radius: mid_r,
                      angle_degrees: mid_a,
                    )
                  case config.custom_label {
                    Some(renderer) ->
                      renderer(render.LabelProps(
                        x: lx,
                        y: ly,
                        width: outer_r -. inner_r,
                        height: 0.0,
                        index: index,
                        value: float.to_string(value),
                        offset: 0.0,
                        position: "center",
                        fill: weft.css_color(
                          value: "var(--weft-chart-label, currentColor)",
                        ),
                      ))
                    None ->
                      svg.text(
                        x: math.fmt(lx),
                        y: math.fmt(ly),
                        content: float.to_string(value),
                        attrs: [
                          svg.attr("text-anchor", "middle"),
                          svg.attr("dominant-baseline", "central"),
                          svg.attr("font-size", "10"),
                          svg.attr(
                            "fill",
                            "var(--weft-chart-label, currentColor)",
                          ),
                        ],
                      )
                  }
                }
              }

              svg.g(attrs: [], children: [bg_el, data_el, label_el])
            })

          let class_attr = case config.css_class {
            "" -> "recharts-radial-bar"
            c -> "recharts-radial-bar " <> c
          }
          svg.g(attrs: [svg.attr("class", class_attr)], children: bar_els)
        }
      }
    }
  }
}

fn make_sector_path(
  config config: RadialBarConfig(msg),
  cx cx: Float,
  cy cy: Float,
  inner_r inner_r: Float,
  outer_r outer_r: Float,
  start start: Float,
  end end: Float,
) -> String {
  case config.corner_radius >. 0.0 {
    True ->
      polar.sector_path_with_corners(
        cx: cx,
        cy: cy,
        inner_radius: inner_r,
        outer_radius: outer_r,
        corner_radius: config.corner_radius,
        force_corner_radius: config.force_corner_radius,
        corner_is_external: config.corner_is_external,
        start_angle: start,
        end_angle: end,
      )
    False ->
      polar.sector_path(
        cx: cx,
        cy: cy,
        inner_radius: inner_r,
        outer_radius: outer_r,
        start_angle: start,
        end_angle: end,
      )
  }
}

fn stroke_attributes(config: RadialBarConfig(msg)) -> List(Attribute(msg)) {
  let stroke_css = weft.color_to_css(color: config.stroke)
  case stroke_css != "none" && config.stroke_width >. 0.0 {
    True -> [
      svg.attr("stroke", stroke_css),
      svg.attr("stroke-width", float.to_string(config.stroke_width)),
    ]
    False -> []
  }
}

fn cycle_fill(fills: List(String), index: Int) -> String {
  let n = list.length(fills)
  case n == 0 {
    True -> "currentColor"
    False -> {
      let target = index % n
      find_at(fills, target, 0, "currentColor")
    }
  }
}

fn find_at(
  items: List(String),
  target: Int,
  current: Int,
  default: String,
) -> String {
  case items {
    [] -> default
    [first, ..rest] ->
      case current == target {
        True -> first
        False -> find_at(rest, target, current + 1, default)
      }
  }
}
