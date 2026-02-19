//// Area series component.
////
//// Renders a filled area between a curve and a baseline.  Supports
//// stacking via `stack_id`, gradient fills, and natural/monotone/step
//// curve interpolation.  When `connect_nulls` is False (the default),
//// missing data points break the area into separate segments, matching
//// the recharts Area behavior.

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
import weft_chart/series/common
import weft_chart/shape

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for an area series.
pub type AreaConfig(msg) {
  AreaConfig(
    data_key: String,
    name: String,
    curve_type: curve.CurveType,
    fill: String,
    fill_opacity: Float,
    stroke: String,
    stroke_width: Float,
    stack_id: String,
    connect_nulls: Bool,
    show_dot: Bool,
    dot_radius: Float,
    gradient_id: String,
    gradient_stops: List(GradientStop),
    base_value: AreaBaseValue,
    hide: Bool,
    legend_type: shape.LegendIconType,
    is_range: Bool,
    base_data_key: String,
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

/// How the area baseline is determined.
pub type AreaBaseValue {
  /// Automatically select 0 when domain crosses zero, domain max when all
  /// negative, domain min when all positive.  This is the default.
  Auto
  /// Use the minimum of the y-axis domain.
  DataMin
  /// Use the maximum of the y-axis domain.
  DataMax
  /// Use a fixed numeric value.
  FixedBase(value: Float)
}

/// A gradient stop for area fill.
pub type GradientStop {
  GradientStop(offset: String, color: String, opacity: Float)
}

/// Internal type for data points that may be missing.
type MaybePoint {
  ValidPoint(x: Float, y: Float)
  MissingPoint
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create an area configuration with default settings.
/// When `name` is empty, `data_key` is used for tooltip/legend display.
pub fn area_config(data_key data_key: String) -> AreaConfig(msg) {
  area_config_v2(data_key: data_key, meta: common.series_meta())
}

/// Create an area configuration using shared series metadata.
pub fn area_config_v2(
  data_key data_key: String,
  meta meta: common.SeriesMeta,
) -> AreaConfig(msg) {
  area_meta(
    config: AreaConfig(
      data_key: data_key,
      name: "",
      curve_type: curve.Linear,
      fill: "var(--weft-chart-area-fill, currentColor)",
      fill_opacity: 0.6,
      stroke: "var(--weft-chart-area-stroke, currentColor)",
      stroke_width: 2.0,
      stack_id: "",
      connect_nulls: False,
      show_dot: False,
      dot_radius: 3.0,
      gradient_id: "",
      gradient_stops: [],
      base_value: Auto,
      hide: False,
      legend_type: shape.LineIcon,
      is_range: False,
      base_data_key: "",
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
    ),
    meta: meta,
  )
}

/// Apply shared series metadata to an existing area configuration.
pub fn area_meta(
  config config: AreaConfig(msg),
  meta meta: common.SeriesMeta,
) -> AreaConfig(msg) {
  AreaConfig(
    data_key: config.data_key,
    name: meta.name,
    curve_type: config.curve_type,
    fill: config.fill,
    fill_opacity: config.fill_opacity,
    stroke: config.stroke,
    stroke_width: config.stroke_width,
    stack_id: config.stack_id,
    connect_nulls: config.connect_nulls,
    show_dot: config.show_dot,
    dot_radius: config.dot_radius,
    gradient_id: config.gradient_id,
    gradient_stops: config.gradient_stops,
    base_value: config.base_value,
    hide: meta.hide,
    legend_type: config.legend_type,
    is_range: config.is_range,
    base_data_key: config.base_data_key,
    tooltip_type: meta.tooltip_type,
    show_label: config.show_label,
    unit: meta.unit,
    x_axis_id: meta.x_axis_id,
    y_axis_id: meta.y_axis_id,
    custom_dot: config.custom_dot,
    custom_label: config.custom_label,
    active_dot: config.active_dot,
    active_index: config.active_index,
    css_class: meta.css_class,
    animate_new_values: config.animate_new_values,
    animation: config.animation,
    clip_dot: config.clip_dot,
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the curve interpolation type.
pub fn curve_type(
  config: AreaConfig(msg),
  type_: curve.CurveType,
) -> AreaConfig(msg) {
  AreaConfig(..config, curve_type: type_)
}

/// Set the fill color or gradient reference.
pub fn fill(config: AreaConfig(msg), fill_value: String) -> AreaConfig(msg) {
  AreaConfig(..config, fill: fill_value)
}

/// Set the fill opacity.
pub fn fill_opacity(config: AreaConfig(msg), opacity: Float) -> AreaConfig(msg) {
  AreaConfig(..config, fill_opacity: opacity)
}

/// Set the stroke color.
pub fn stroke(config: AreaConfig(msg), stroke_value: String) -> AreaConfig(msg) {
  AreaConfig(..config, stroke: stroke_value)
}

/// Set the stroke width.
pub fn stroke_width(config: AreaConfig(msg), width: Float) -> AreaConfig(msg) {
  AreaConfig(..config, stroke_width: width)
}

/// Set the stack ID for stacking multiple areas.
pub fn stack_id(config: AreaConfig(msg), id: String) -> AreaConfig(msg) {
  AreaConfig(..config, stack_id: id)
}

/// Connect null/missing data points instead of breaking the line.
pub fn connect_nulls(config: AreaConfig(msg)) -> AreaConfig(msg) {
  AreaConfig(..config, connect_nulls: True)
}

/// Show or hide dots at data points.
pub fn dot(config: AreaConfig(msg), show: Bool) -> AreaConfig(msg) {
  AreaConfig(..config, show_dot: show)
}

/// Set the dot radius.
pub fn dot_radius(config: AreaConfig(msg), radius: Float) -> AreaConfig(msg) {
  AreaConfig(..config, dot_radius: radius)
}

/// Set the base value for the area fill.
/// Matches recharts Area baseValue prop.
pub fn base_value(
  config: AreaConfig(msg),
  base: AreaBaseValue,
) -> AreaConfig(msg) {
  AreaConfig(..config, base_value: base)
}

/// Hide the area from rendering while keeping it in domain/legend calculation.
/// Matches recharts Area `hide` prop.
pub fn hide(config config: AreaConfig(msg)) -> AreaConfig(msg) {
  AreaConfig(..config, hide: True)
}

/// Set the display name for tooltip and legend.
/// Matches recharts Area `name` prop.  When empty, `data_key` is used.
pub fn area_name(config: AreaConfig(msg), name: String) -> AreaConfig(msg) {
  AreaConfig(..config, name: name)
}

/// Add a gradient fill definition.
pub fn gradient_fill(
  config: AreaConfig(msg),
  id: String,
  stops: List(GradientStop),
) -> AreaConfig(msg) {
  AreaConfig(..config, gradient_id: id, gradient_stops: stops)
}

/// Set the legend icon type for this series.
/// Matches recharts Area `legendType` prop (default: line).
pub fn legend_type(
  config: AreaConfig(msg),
  icon_type: shape.LegendIconType,
) -> AreaConfig(msg) {
  AreaConfig(..config, legend_type: icon_type)
}

/// Configure this area as a range area with a base data key.
/// Sets `is_range` to True and `base_data_key` to the given key.
/// When rendered, the area is filled between the `data_key` values
/// (top) and the `base_data_key` values (bottom), creating a band.
/// Matches recharts Area `isRange` behavior.
pub fn area_range(config: AreaConfig(msg), base_key: String) -> AreaConfig(msg) {
  AreaConfig(..config, is_range: True, base_data_key: base_key)
}

/// Set the tooltip type to control whether this series appears in tooltips.
/// Matches recharts Area `tooltipType` prop (default: DefaultTooltip).
pub fn area_tooltip_type(
  config config: AreaConfig(msg),
  type_ type_: shape.TooltipType,
) -> AreaConfig(msg) {
  AreaConfig(..config, tooltip_type: type_)
}

/// Show or hide value labels at each data point.
/// When True, the numeric value is rendered above each point.
pub fn area_label(
  config config: AreaConfig(msg),
  show show: Bool,
) -> AreaConfig(msg) {
  AreaConfig(..config, show_label: show)
}

/// Set the unit string for tooltip display.
/// Matches recharts Area `unit` prop (default: "").
pub fn area_unit(
  config config: AreaConfig(msg),
  unit unit: String,
) -> AreaConfig(msg) {
  AreaConfig(..config, unit: unit)
}

/// Set the x-axis ID this area series binds to.
/// Matches recharts Area `xAxisId` prop (default: "0").
pub fn area_x_axis_id(
  config config: AreaConfig(msg),
  id id: String,
) -> AreaConfig(msg) {
  AreaConfig(..config, x_axis_id: id)
}

/// Set the y-axis ID this area series binds to.
/// Matches recharts Area `yAxisId` prop (default: "0").
pub fn area_y_axis_id(
  config config: AreaConfig(msg),
  id id: String,
) -> AreaConfig(msg) {
  AreaConfig(..config, y_axis_id: id)
}

/// Set a custom dot render function for area data points.
/// When provided, replaces the default circle for each visible dot.
/// Matches recharts Area `dot` prop (element/function form).
pub fn area_custom_dot(
  config config: AreaConfig(msg),
  renderer renderer: fn(render.DotProps) -> Element(msg),
) -> AreaConfig(msg) {
  AreaConfig(..config, custom_dot: Some(renderer))
}

/// Set a custom label render function for area data point labels.
/// When provided, replaces the default text label for each data point.
/// Matches recharts Area `label` prop (element/function form).
pub fn area_custom_label(
  config config: AreaConfig(msg),
  renderer renderer: fn(render.LabelProps) -> Element(msg),
) -> AreaConfig(msg) {
  AreaConfig(..config, custom_label: Some(renderer))
}

/// Set a custom render function for the active (highlighted) dot.
/// When `active_index` matches a dot's index, this renderer is used
/// instead of the default dot.
/// Matches recharts Area `activeDot` prop.
pub fn area_active_dot(
  config config: AreaConfig(msg),
  renderer renderer: fn(render.DotProps) -> Element(msg),
) -> AreaConfig(msg) {
  AreaConfig(..config, active_dot: Some(renderer))
}

/// Set the index of the dot to render in active state.
/// When set, the dot at this index uses the `active_dot` renderer
/// if provided, or default active styling otherwise.
/// Matches recharts Area `activeIndex` prop (from tooltip hover).
pub fn area_active_index(
  config config: AreaConfig(msg),
  index index: Int,
) -> AreaConfig(msg) {
  AreaConfig(..config, active_index: Some(index))
}

/// Set the CSS class attribute on the area series group element.
/// Maps to the SVG `class` attribute.
/// Matches recharts Area `className` prop.
pub fn area_css_class(
  config config: AreaConfig(msg),
  class class: String,
) -> AreaConfig(msg) {
  AreaConfig(..config, css_class: class)
}

/// Set whether to animate new data values when data updates.
/// When True, new data points animate in from offscreen.
/// Matches recharts Area `animateNewValues` prop (default: True).
pub fn area_animate_new_values(
  config config: AreaConfig(msg),
  animate animate: Bool,
) -> AreaConfig(msg) {
  AreaConfig(..config, animate_new_values: animate)
}

/// Set whether dots are clipped to the chart area.
/// When True (default), dots at data points near the edge of the chart
/// are clipped along with the area path, matching recharts `clipDot={true}`.
/// When False, dots render outside the clip region.
pub fn area_clip_dot(
  config config: AreaConfig(msg),
  clip clip: Bool,
) -> AreaConfig(msg) {
  AreaConfig(..config, clip_dot: clip)
}

/// Set the animation configuration for area entry effects.
pub fn area_animation(
  config config: AreaConfig(msg),
  anim anim: AnimationConfig,
) -> AreaConfig(msg) {
  AreaConfig(..config, animation: anim)
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render an area series given the data and scales.
/// The layout parameter controls coordinate mapping: Horizontal (default)
/// maps categories to X and values to Y; Vertical swaps them.
pub fn render_area(
  config config: AreaConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  baseline_y baseline_y: Float,
  layout area_layout: layout.LayoutDirection,
) -> Element(msg) {
  // When hidden, skip rendering but the series still participates in
  // domain/legend calculation (handled by the chart container).
  case config.hide {
    True -> element.none()
    False ->
      render_area_visible(
        config,
        data,
        categories,
        x_scale,
        y_scale,
        baseline_y,
        area_layout,
      )
  }
}

/// Internal rendering for a visible area series.
fn render_area_visible(
  config: AreaConfig(msg),
  data: List(Dict(String, Float)),
  categories: List(String),
  x_scale: Scale,
  y_scale: Scale,
  baseline_y: Float,
  area_layout: layout.LayoutDirection,
) -> Element(msg) {
  // Map data to points, preserving nulls for gap detection.
  // When Vertical, swap coordinate mapping: categories on Y, values on X.
  let maybe_points =
    list.zip(categories, data)
    |> list.map(fn(pair) {
      let #(cat, values) = pair
      case dict.get(values, config.data_key) {
        Ok(value) ->
          case area_layout {
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

  // Extract valid points for rendering
  let all_valid_points = extract_valid_points(maybe_points)

  case all_valid_points {
    [] -> element.none()
    _ -> {
      // Gradient definition
      let gradient_el = render_gradient(config)

      // Determine segments based on connect_nulls
      let segments = case config.connect_nulls {
        True -> [all_valid_points]
        False -> split_segments(maybe_points)
      }

      // Render each segment as area fill + stroke
      let segment_els =
        list.flat_map(segments, fn(seg) {
          case seg {
            [] -> []
            _ -> {
              let area_d =
                curve.area_path(
                  curve_type: config.curve_type,
                  points: seg,
                  baseline: curve.FlatBaseline(y: baseline_y),
                )
              let area_el =
                svg.path(d: area_d, attrs: [
                  svg.attr("fill", config.fill),
                  svg.attr("fill-opacity", float.to_string(config.fill_opacity)),
                ])

              let stroke_d =
                curve.path(curve_type: config.curve_type, points: seg)
              let stroke_el =
                svg.path(d: stroke_d, attrs: [
                  svg.attr("stroke", config.stroke),
                  svg.attr("fill", "none"),
                  svg.attr("stroke-width", float.to_string(config.stroke_width)),
                ])

              [area_el, stroke_el]
            }
          }
        })

      // Dots (always show all valid points regardless of connect_nulls)
      let valid_values_for_dots =
        extract_valid_values(maybe_points, data, config.data_key)
      let dot_els = case config.show_dot {
        False -> []
        True ->
          list.index_map(
            list.zip(all_valid_points, valid_values_for_dots),
            fn(pair, idx) {
              let #(#(px, py), value) = pair
              let dot_props =
                render.DotProps(
                  cx: px,
                  cy: py,
                  r: config.dot_radius,
                  index: idx,
                  value: value,
                  data_key: config.data_key,
                  fill: config.stroke,
                  stroke: "var(--weft-chart-bg, #ffffff)",
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
                        r: math.fmt(config.dot_radius),
                        attrs: [
                          svg.attr("fill", config.stroke),
                          svg.attr("stroke", "var(--weft-chart-bg, #ffffff)"),
                          svg.attr("stroke-width", "2"),
                        ],
                      )
                  }
              }
            },
          )
      }

      // Value labels
      let valid_values =
        extract_valid_values(maybe_points, data, config.data_key)
      let label_els = case config.show_label {
        False -> []
        True ->
          case config.custom_label {
            Some(renderer) ->
              list.index_map(
                list.zip(all_valid_points, valid_values),
                fn(pair, idx) {
                  let #(#(px, py), value) = pair
                  renderer(render.LabelProps(
                    x: px,
                    y: py -. 10.0,
                    width: 0.0,
                    height: 0.0,
                    index: idx,
                    value: format_area_value(value),
                    offset: 10.0,
                    position: "top",
                    fill: "var(--weft-chart-label, currentColor)",
                  ))
                },
              )
            None ->
              list.zip(all_valid_points, valid_values)
              |> list.map(fn(pair) {
                let #(#(px, py), value) = pair
                svg.text(
                  x: math.fmt(px),
                  y: math.fmt(py -. 10.0),
                  content: format_area_value(value),
                  attrs: [
                    svg.attr("text-anchor", "middle"),
                    svg.attr("font-size", "11"),
                    svg.attr("fill", "var(--weft-chart-label, currentColor)"),
                  ],
                )
              })
          }
      }

      let area_class_value = case config.css_class {
        "" -> "recharts-area"
        cls -> "recharts-area " <> cls
      }
      case config.animation.active {
        False ->
          svg.g(
            attrs: [svg.attr("class", area_class_value)],
            children: list.flatten([
              [gradient_el],
              segment_els,
              dot_els,
              label_els,
            ]),
          )
        True -> {
          let clip_id = "area-clip-" <> config.data_key
          let clip_el =
            animation.animate_clip_rect(
              clip_id: clip_id,
              x: 0.0,
              y: 0.0,
              width: 10_000.0,
              height: 10_000.0,
              config: config.animation,
              direction: area_layout,
            )
          svg.g(
            attrs: [svg.attr("class", area_class_value)],
            children: list.flatten([
              [gradient_el],
              [svg.defs([clip_el])],
              [
                svg.g(
                  attrs: [
                    svg.attr("clip-path", "url(#" <> clip_id <> ")"),
                  ],
                  children: list.flatten([
                    segment_els,
                    dot_els,
                    label_els,
                  ]),
                ),
              ],
            ]),
          )
        }
      }
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

/// Format an area value as a label string.
fn format_area_value(value: Float) -> String {
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

  // Don't forget the last segment
  let all = case current {
    [] -> segments
    _ -> [list.reverse(current), ..segments]
  }

  list.reverse(all)
}

/// Render gradient defs if configured.
fn render_gradient(config: AreaConfig(msg)) -> Element(msg) {
  case config.gradient_id {
    "" -> element.none()
    id ->
      svg.defs([
        svg.linear_gradient(
          id: id,
          stops: list.map(config.gradient_stops, fn(stop) {
            svg.gradient_stop(
              offset: stop.offset,
              color: stop.color,
              opacity: float.to_string(stop.opacity),
            )
          }),
        ),
      ])
  }
}
