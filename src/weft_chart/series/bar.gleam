//// Bar series component.
////
//// Renders rectangular bars for each data point.  Supports stacking
//// via `stack_id`, per-corner rounded radius (using SVG path with arc
//// commands matching recharts getRectanglePath), background bars,
//// labels, minimum bar height, and multiple bar positioning.
//// Matches the recharts Bar component rendering logic.

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import weft
import weft_chart/animation.{type AnimationConfig}
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

/// Controls how minimum bar size is determined.
/// Matches recharts Bar `minPointSize` prop which accepts either
/// a number or a callback `(value, index) -> number`.
pub type MinPointSize {
  /// Fixed minimum point size in pixels.
  FixedMinPointSize(size: Float)
  /// Dynamic minimum point size computed per bar.
  DynamicMinPointSize(f: fn(Float, Int) -> Float)
}

/// Per-item fill/stroke customization for individual bars.
/// Matches recharts Cell component behavior.
pub type CellConfig {
  CellConfig(
    fill: weft.Color,
    stroke: weft.Color,
    fill_opacity: Float,
    stroke_width: Float,
  )
}

/// Configuration for a bar series.
pub type BarConfig(msg) {
  BarConfig(
    data_key: String,
    name: String,
    fill: weft.Color,
    radius: Float,
    radius_corners: #(Float, Float, Float, Float),
    has_custom_corners: Bool,
    stack_id: String,
    bar_size: Int,
    max_bar_size: Int,
    min_point_size: MinPointSize,
    show_background: Bool,
    background_fill: weft.Color,
    show_label: Bool,
    stroke: weft.Color,
    stroke_width: Float,
    hide: Bool,
    legend_type: shape.LegendIconType,
    tooltip_type: shape.TooltipType,
    cells: List(CellConfig),
    unit: String,
    x_axis_id: String,
    y_axis_id: String,
    custom_label: Option(fn(render.LabelProps) -> Element(msg)),
    custom_shape: Option(fn(render.BarShapeProps) -> Element(msg)),
    active_bar: Option(fn(render.BarShapeProps) -> Element(msg)),
    active_index: Option(Int),
    css_class: String,
    animation: AnimationConfig,
    data_override: Option(List(Dict(String, Float))),
  )
}

/// Position information for a bar within a multi-bar group.
/// Computed by the chart container for side-by-side bar layout.
pub type BarPosition {
  BarPosition(offset: Float, width: Float)
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a bar configuration with default settings.
/// Matches recharts Bar defaults.
pub fn bar_config(
  data_key data_key: String,
  meta meta: common.SeriesMeta,
) -> BarConfig(msg) {
  bar_meta(
    config: BarConfig(
      data_key: data_key,
      name: "",
      fill: weft.css_color(value: "var(--weft-chart-bar-fill, currentColor)"),
      radius: 0.0,
      radius_corners: #(0.0, 0.0, 0.0, 0.0),
      has_custom_corners: False,
      stack_id: "",
      bar_size: 0,
      max_bar_size: 0,
      min_point_size: FixedMinPointSize(0.0),
      show_background: False,
      background_fill: weft.css_color(value: "var(--weft-chart-bar-bg, #eee)"),
      show_label: False,
      stroke: weft.css_color(value: ""),
      stroke_width: 0.0,
      hide: False,
      legend_type: shape.RectIcon,
      tooltip_type: shape.DefaultTooltip,
      cells: [],
      unit: "",
      x_axis_id: "0",
      y_axis_id: "0",
      custom_label: None,
      custom_shape: None,
      active_bar: None,
      active_index: None,
      css_class: "",
      animation: animation.bar_default(),
      data_override: None,
    ),
    meta: meta,
  )
}

/// Apply shared series metadata to an existing bar configuration.
pub fn bar_meta(
  config config: BarConfig(msg),
  meta meta: common.SeriesMeta,
) -> BarConfig(msg) {
  BarConfig(
    data_key: config.data_key,
    name: meta.name,
    fill: config.fill,
    radius: config.radius,
    radius_corners: config.radius_corners,
    has_custom_corners: config.has_custom_corners,
    stack_id: config.stack_id,
    bar_size: config.bar_size,
    max_bar_size: config.max_bar_size,
    min_point_size: config.min_point_size,
    show_background: config.show_background,
    background_fill: config.background_fill,
    show_label: config.show_label,
    stroke: config.stroke,
    stroke_width: config.stroke_width,
    hide: meta.hide,
    legend_type: config.legend_type,
    tooltip_type: meta.tooltip_type,
    cells: config.cells,
    unit: meta.unit,
    x_axis_id: meta.x_axis_id,
    y_axis_id: meta.y_axis_id,
    custom_label: config.custom_label,
    custom_shape: config.custom_shape,
    active_bar: config.active_bar,
    active_index: config.active_index,
    css_class: meta.css_class,
    animation: config.animation,
    data_override: config.data_override,
  )
}

/// Create a cell configuration for per-item bar customization.
/// The stroke defaults to empty (inherits from config).
/// Matches recharts Cell component.
pub fn cell_config(fill fill: weft.Color) -> CellConfig {
  CellConfig(
    fill: fill,
    stroke: weft.css_color(value: ""),
    fill_opacity: 1.0,
    stroke_width: 1.0,
  )
}

/// Create a cell configuration with full customization options.
/// Matches recharts Cell component with fillOpacity and strokeWidth.
pub fn cell_config_full(
  fill fill: weft.Color,
  stroke stroke: weft.Color,
  fill_opacity fill_opacity: Float,
  stroke_width stroke_width: Float,
) -> CellConfig {
  CellConfig(
    fill: fill,
    stroke: stroke,
    fill_opacity: fill_opacity,
    stroke_width: stroke_width,
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the fill color.
pub fn bar_fill(
  config: BarConfig(msg),
  fill_value: weft.Color,
) -> BarConfig(msg) {
  BarConfig(..config, fill: fill_value)
}

/// Set uniform corner radius for all corners.
pub fn bar_radius(config: BarConfig(msg), radius: Float) -> BarConfig(msg) {
  BarConfig(..config, radius: radius)
}

/// Set individual corner radii (top-left, top-right, bottom-right, bottom-left).
/// Matches recharts Bar radius=[tl, tr, br, bl] prop.
pub fn bar_radius_corners(
  config: BarConfig(msg),
  tl tl: Float,
  tr tr: Float,
  br br: Float,
  bl bl: Float,
) -> BarConfig(msg) {
  BarConfig(
    ..config,
    radius_corners: #(tl, tr, br, bl),
    has_custom_corners: True,
  )
}

/// Set the stack ID for grouped stacking.
pub fn bar_stack_id(config: BarConfig(msg), id: String) -> BarConfig(msg) {
  BarConfig(..config, stack_id: id)
}

/// Set the bar width in pixels.
pub fn bar_size(config: BarConfig(msg), size: Int) -> BarConfig(msg) {
  BarConfig(..config, bar_size: size)
}

/// Set the maximum bar width.
pub fn bar_max_size(config: BarConfig(msg), size: Int) -> BarConfig(msg) {
  BarConfig(..config, max_bar_size: size)
}

/// Set a fixed minimum bar height for very small values.
/// Matches recharts Bar `minPointSize` prop (number form).
pub fn bar_min_point_size(
  config: BarConfig(msg),
  size size: Float,
) -> BarConfig(msg) {
  BarConfig(..config, min_point_size: FixedMinPointSize(size))
}

/// Set a dynamic minimum bar height computed per bar.
/// The callback receives the bar value and index.
/// Matches recharts Bar `minPointSize` prop (callback form).
pub fn bar_min_point_size_fn(
  config config: BarConfig(msg),
  f f: fn(Float, Int) -> Float,
) -> BarConfig(msg) {
  BarConfig(..config, min_point_size: DynamicMinPointSize(f))
}

/// Show background bars behind data bars.
pub fn bar_background(config: BarConfig(msg), show: Bool) -> BarConfig(msg) {
  BarConfig(..config, show_background: show)
}

/// Set the background bar fill color.
/// Matches recharts default: #eee.
pub fn bar_background_fill(
  config: BarConfig(msg),
  fill_value: weft.Color,
) -> BarConfig(msg) {
  BarConfig(..config, background_fill: fill_value)
}

/// Show value labels on bars.
pub fn bar_label(config: BarConfig(msg), show: Bool) -> BarConfig(msg) {
  BarConfig(..config, show_label: show)
}

/// Set the legend icon type for this series.
/// Matches recharts Bar `legendType` prop (default: rect).
pub fn bar_legend_type(
  config: BarConfig(msg),
  icon_type: shape.LegendIconType,
) -> BarConfig(msg) {
  BarConfig(..config, legend_type: icon_type)
}

/// Set the bar border stroke color.
/// Matches recharts Bar `stroke` prop (default: none).
pub fn bar_stroke(config: BarConfig(msg), stroke: weft.Color) -> BarConfig(msg) {
  BarConfig(..config, stroke: stroke)
}

/// Set the bar border stroke width.
/// Matches recharts Bar `strokeWidth` prop (default: 0).
pub fn bar_stroke_width(config: BarConfig(msg), width: Float) -> BarConfig(msg) {
  BarConfig(..config, stroke_width: width)
}

/// Set per-item cell configurations for individual bar customization.
/// When non-empty, each bar uses the corresponding cell's fill/stroke.
/// Bars beyond the cell list length fall back to the config fill/stroke.
/// Matches recharts Cell component behavior on Bar.
pub fn bar_cells(
  config config: BarConfig(msg),
  cells cells: List(CellConfig),
) -> BarConfig(msg) {
  BarConfig(..config, cells: cells)
}

/// Set a custom label render function for bar value labels.
/// When provided, replaces the default text label for each bar.
/// Matches recharts Bar `label` prop (element/function form).
pub fn bar_custom_label(
  config config: BarConfig(msg),
  renderer renderer: fn(render.LabelProps) -> Element(msg),
) -> BarConfig(msg) {
  BarConfig(..config, custom_label: Some(renderer))
}

/// Set a custom shape render function for bar rectangles.
/// When provided, replaces the default rectangle for each bar.
/// Matches recharts Bar `shape` prop (element/function form).
pub fn bar_custom_shape(
  config config: BarConfig(msg),
  renderer renderer: fn(render.BarShapeProps) -> Element(msg),
) -> BarConfig(msg) {
  BarConfig(..config, custom_shape: Some(renderer))
}

/// Set a custom render function for the active (highlighted) bar.
/// When `active_index` matches a bar's index, this renderer is used
/// instead of the default rectangle.
/// Matches recharts Bar `activeBar` prop.
pub fn bar_active_bar(
  config config: BarConfig(msg),
  renderer renderer: fn(render.BarShapeProps) -> Element(msg),
) -> BarConfig(msg) {
  BarConfig(..config, active_bar: Some(renderer))
}

/// Set the index of the bar to render in active state.
/// When set, the bar at this index uses the `active_bar` renderer
/// if provided, or default active styling otherwise.
/// Matches recharts Bar `activeIndex` prop.
pub fn bar_active_index(
  config config: BarConfig(msg),
  index index: Int,
) -> BarConfig(msg) {
  BarConfig(..config, active_index: Some(index))
}

/// Set the animation configuration for bar entry effects.
pub fn bar_animation(
  config config: BarConfig(msg),
  anim anim: AnimationConfig,
) -> BarConfig(msg) {
  BarConfig(..config, animation: anim)
}

/// Set per-bar data that overrides chart-level data for this series.
/// When set, this bar series uses the provided dataset instead of
/// the chart-level data.  Matches recharts Bar `data` prop.
pub fn bar_data_override(
  config config: BarConfig(msg),
  data data: List(Dict(String, Float)),
) -> BarConfig(msg) {
  BarConfig(..config, data_override: Some(data))
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a bar series given the data and scales.
/// Accepts optional bar_position for multi-bar side-by-side layout.
/// The layout parameter controls coordinate mapping: Horizontal (default)
/// renders vertical bars, Vertical renders horizontal bars.
pub fn render_bars(
  config config: BarConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  baseline_y baseline_y: Float,
  layout layout: layout.LayoutDirection,
) -> Element(msg) {
  // When hidden, skip rendering but the series still participates in
  // domain/legend calculation (handled by the chart container).
  case config.hide {
    True -> element.none()
    False -> {
      // Use per-bar data override when provided
      let effective_data = case config.data_override {
        Some(override) -> override
        None -> data
      }
      render_bars_positioned(
        config: config,
        data: effective_data,
        categories: categories,
        x_scale: x_scale,
        y_scale: y_scale,
        baseline_y: baseline_y,
        position: BarPosition(offset: 0.0, width: 0.0),
        has_position: False,
        layout: layout,
      )
    }
  }
}

/// Render a bar series with explicit position for multi-bar layout.
/// The layout parameter controls coordinate mapping: Horizontal (default)
/// renders vertical bars, Vertical renders horizontal bars.
pub fn render_bars_positioned(
  config config: BarConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  baseline_y baseline_y: Float,
  position position: BarPosition,
  has_position has_position: Bool,
  layout layout: layout.LayoutDirection,
) -> Element(msg) {
  // When hidden, skip rendering but the series still participates in
  // domain/legend calculation (handled by the chart container).
  case config.hide {
    True -> element.none()
    False -> {
      // Use per-bar data override when provided
      let effective_data = case config.data_override {
        Some(override) -> override
        None -> data
      }
      render_bars_positioned_visible(
        config,
        effective_data,
        categories,
        x_scale,
        y_scale,
        baseline_y,
        position,
        has_position,
        layout,
      )
    }
  }
}

/// Internal rendering for visible bars with explicit position.
fn render_bars_positioned_visible(
  config: BarConfig(msg),
  data: List(Dict(String, Float)),
  categories: List(String),
  x_scale: Scale,
  y_scale: Scale,
  baseline_y: Float,
  position: BarPosition,
  has_position: Bool,
  bar_layout: layout.LayoutDirection,
) -> Element(msg) {
  // For Vertical layout, the category scale is y_scale (band) and
  // value scale is x_scale (linear). For Horizontal, the reverse.
  let cat_scale = case bar_layout {
    layout.Horizontal -> x_scale
    layout.Vertical -> y_scale
  }
  let bw = scale.bandwidth(cat_scale)

  // Determine bar thickness and offset within the category band
  let #(bar_thickness, bar_offset) = case has_position {
    True -> #(position.width, position.offset)
    False -> {
      let w = case config.bar_size > 0 {
        True -> int.to_float(config.bar_size)
        False -> {
          // Match recharts default: 10% category gap on each side
          let offset = bw *. 0.1
          bw -. 2.0 *. offset
        }
      }
      #(w, { bw -. w } /. 2.0)
    }
  }

  let bar_thickness_clamped = case config.max_bar_size > 0 {
    True ->
      case bar_thickness >. int.to_float(config.max_bar_size) {
        True -> int.to_float(config.max_bar_size)
        False -> bar_thickness
      }
    False -> bar_thickness
  }

  let bar_els =
    list.zip(categories, data)
    |> list.index_map(fn(pair, index) { #(pair, index) })
    |> list.filter_map(fn(item) {
      let #(#(cat, values), index) = item
      case dict.get(values, config.data_key) {
        Ok(value) -> {
          let is_negative = value <. 0.0

          // Compute bar geometry based on layout direction
          let #(bar_x, bar_y, bar_w, raw_bar_dim) = case bar_layout {
            layout.Horizontal -> {
              let #(band_start, _band_w) = scale.band_apply(x_scale, cat)
              let bx = band_start +. bar_offset
              let value_y = scale.linear_apply(y_scale, value)
              let #(by, raw_h) = case is_negative {
                True -> #(baseline_y, value_y -. baseline_y)
                False -> #(value_y, baseline_y -. value_y)
              }
              #(bx, by, bar_thickness_clamped, raw_h)
            }
            layout.Vertical -> {
              // Horizontal bars: category on Y-axis, value on X-axis
              let #(band_start, _band_w) = scale.band_apply(y_scale, cat)
              let by = band_start +. bar_offset
              let value_x = scale.linear_apply(x_scale, value)
              let #(bx, raw_w) = case is_negative {
                True -> #(value_x, baseline_y -. value_x)
                False -> #(baseline_y, value_x -. baseline_y)
              }
              #(bx, by, raw_w, bar_thickness_clamped)
            }
          }

          // Apply minimum size
          let min_size = case config.min_point_size {
            FixedMinPointSize(size:) -> size
            DynamicMinPointSize(f:) -> f(value, index)
          }
          let bar_h = case raw_bar_dim <. min_size {
            True -> min_size
            False -> raw_bar_dim
          }

          // Final dimensions: width and height depend on layout
          let #(final_w, final_h) = case bar_layout {
            layout.Horizontal -> #(bar_w, bar_h)
            layout.Vertical -> #(bar_w, bar_h)
          }

          let #(center_x, center_y) = #(
            bar_x +. final_w /. 2.0,
            bar_y +. final_h /. 2.0,
          )

          // Per-item cell fill/stroke override (recharts Cell component)
          let #(bar_fill, bar_stroke_color, cell_fill_opacity, cell_stroke_w) = case
            get_cell_at(config.cells, index)
          {
            Ok(cell) -> {
              let f = cell.fill
              let s = case weft.color_to_css(color: cell.stroke) {
                "" -> config.stroke
                _ -> cell.stroke
              }
              #(f, s, cell.fill_opacity, cell.stroke_width)
            }
            Error(_) -> #(config.fill, config.stroke, 1.0, config.stroke_width)
          }

          // Background bar (full band extent)
          let bg_el = case config.show_background {
            False -> element.none()
            True ->
              case bar_layout {
                layout.Horizontal ->
                  render_bar_rect(
                    bar_x,
                    0.0,
                    final_w,
                    baseline_y,
                    0.0,
                    #(0.0, 0.0, 0.0, 0.0),
                    False,
                    weft.color_to_css(color: config.background_fill),
                    "",
                    0.0,
                    1.0,
                  )
                layout.Vertical ->
                  render_bar_rect(
                    0.0,
                    bar_y,
                    baseline_y,
                    final_h,
                    0.0,
                    #(0.0, 0.0, 0.0, 0.0),
                    False,
                    weft.color_to_css(color: config.background_fill),
                    "",
                    0.0,
                    1.0,
                  )
              }
          }

          // Data bar with proper corner radius.
          // For negative values, flip corners: top corners become bottom
          // and vice versa, matching recharts negative bar rendering.
          let #(effective_corners, effective_has_custom) = case is_negative {
            False -> #(config.radius_corners, config.has_custom_corners)
            True ->
              case config.has_custom_corners {
                True -> {
                  let #(tl, tr, br, bl) = config.radius_corners
                  #(#(bl, br, tr, tl), True)
                }
                False ->
                  case config.radius >. 0.0 {
                    True -> #(#(0.0, 0.0, config.radius, config.radius), True)
                    False -> #(config.radius_corners, False)
                  }
              }
          }
          // Determine if this bar is the active one
          let is_active = case config.active_index {
            Some(active_idx) -> active_idx == index
            None -> False
          }
          let bar_el = case is_active, config.active_bar {
            True, Some(renderer) ->
              renderer(render.BarShapeProps(
                x: bar_x,
                y: bar_y,
                width: final_w,
                height: final_h,
                index: index,
                value: value,
                data_key: config.data_key,
                fill: bar_fill,
                stroke: bar_stroke_color,
                radius: config.radius,
              ))
            _, _ ->
              case config.custom_shape {
                Some(renderer) ->
                  renderer(render.BarShapeProps(
                    x: bar_x,
                    y: bar_y,
                    width: final_w,
                    height: final_h,
                    index: index,
                    value: value,
                    data_key: config.data_key,
                    fill: bar_fill,
                    stroke: bar_stroke_color,
                    radius: config.radius,
                  ))
                None -> {
                  // Animated rendering only for simple rects (no corners).
                  // Rounded/custom-corner bars use path-based shapes that
                  // cannot host SMIL <animate> children directly.
                  let use_animation =
                    config.animation.active
                    && !effective_has_custom
                    && config.radius <=. 0.0
                  case use_animation {
                    True ->
                      render_bar_rect_animated(
                        bar_x,
                        bar_y,
                        final_w,
                        final_h,
                        weft.color_to_css(color: bar_fill),
                        weft.color_to_css(color: bar_stroke_color),
                        cell_stroke_w,
                        cell_fill_opacity,
                        bar_layout,
                        baseline_y,
                        config.animation,
                      )
                    False ->
                      render_bar_rect(
                        bar_x,
                        bar_y,
                        final_w,
                        final_h,
                        case is_negative {
                          True -> 0.0
                          False -> config.radius
                        },
                        effective_corners,
                        effective_has_custom,
                        weft.color_to_css(color: bar_fill),
                        weft.color_to_css(color: bar_stroke_color),
                        cell_stroke_w,
                        cell_fill_opacity,
                      )
                  }
                }
              }
          }

          // Value label positioning depends on layout direction
          let label_el = case config.show_label {
            False -> element.none()
            True ->
              case config.custom_label {
                Some(renderer) -> {
                  let position = case bar_layout {
                    layout.Horizontal ->
                      case is_negative {
                        True -> "bottom"
                        False -> "top"
                      }
                    layout.Vertical ->
                      case is_negative {
                        True -> "left"
                        False -> "right"
                      }
                  }
                  renderer(render.LabelProps(
                    x: bar_x,
                    y: bar_y,
                    width: final_w,
                    height: final_h,
                    index: index,
                    value: format_bar_value(value),
                    offset: 4.0,
                    position: position,
                    fill: weft.css_color(
                      value: "var(--weft-chart-label, currentColor)",
                    ),
                  ))
                }
                None ->
                  case bar_layout {
                    layout.Horizontal -> {
                      let label_y = case is_negative {
                        True -> bar_y +. final_h +. 14.0
                        False -> bar_y -. 4.0
                      }
                      svg.text(
                        x: math.fmt(center_x),
                        y: math.fmt(label_y),
                        content: format_bar_value(value),
                        attrs: [
                          svg.attr("text-anchor", "middle"),
                          svg.attr("font-size", "11"),
                          svg.attr(
                            "fill",
                            "var(--weft-chart-label, currentColor)",
                          ),
                        ],
                      )
                    }
                    layout.Vertical -> {
                      let label_x = case is_negative {
                        True -> bar_x -. 4.0
                        False -> bar_x +. final_w +. 4.0
                      }
                      svg.text(
                        x: math.fmt(label_x),
                        y: math.fmt(center_y +. 4.0),
                        content: format_bar_value(value),
                        attrs: [
                          svg.attr("text-anchor", case is_negative {
                            True -> "end"
                            False -> "start"
                          }),
                          svg.attr("font-size", "11"),
                          svg.attr(
                            "fill",
                            "var(--weft-chart-label, currentColor)",
                          ),
                        ],
                      )
                    }
                  }
              }
          }

          Ok(svg.g(attrs: [], children: [bg_el, bar_el, label_el]))
        }
        Error(_) -> Error(Nil)
      }
    })

  let class_value = case config.css_class {
    "" -> "recharts-bar"
    cls -> "recharts-bar " <> cls
  }
  svg.g(attrs: [svg.attr("class", class_value)], children: bar_els)
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Render a bar rectangle with proper corner radius handling.
/// Uses shape.rectangle for uniform radius, shape.rectangle_with_corners
/// for per-corner radii, matching the recharts Rectangle component.
/// When stroke is non-empty, wraps in a `<g>` with stroke attributes
/// matching recharts Bar `stroke`/`strokeWidth` props.
fn render_bar_rect(
  x: Float,
  y: Float,
  width: Float,
  height: Float,
  uniform_radius: Float,
  corners: #(Float, Float, Float, Float),
  has_custom_corners: Bool,
  fill: String,
  stroke: String,
  stroke_w: Float,
  fill_opacity: Float,
) -> Element(msg) {
  let opacity_attrs = case fill_opacity == 1.0 {
    True -> []
    False -> [svg.attr("fill-opacity", float.to_string(fill_opacity))]
  }
  let rect_el = case has_custom_corners {
    True -> {
      let #(tl, tr, br, bl) = corners
      shape.rectangle_with_corners(
        x: x,
        y: y,
        width: width,
        height: height,
        top_left: tl,
        top_right: tr,
        bottom_right: br,
        bottom_left: bl,
        fill: fill,
      )
    }
    False ->
      shape.rectangle(
        x: x,
        y: y,
        width: width,
        height: height,
        radius: uniform_radius,
        fill: fill,
      )
  }
  let stroke_and_opacity =
    list.flatten([
      case stroke {
        "" -> []
        _ -> [
          svg.attr("stroke", stroke),
          svg.attr("stroke-width", float.to_string(stroke_w)),
        ]
      },
      opacity_attrs,
    ])
  case stroke_and_opacity {
    [] -> rect_el
    attrs -> svg.g(attrs: attrs, children: [rect_el])
  }
}

/// Get a cell configuration at a given index, or Error if out of range.
fn get_cell_at(cells: List(CellConfig), index: Int) -> Result(CellConfig, Nil) {
  case cells, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], n -> get_cell_at(rest, n - 1)
  }
}

/// Render an animated bar rectangle using SMIL <animate> children.
/// Animates height/y for horizontal layout or width/x for vertical layout,
/// growing from the baseline position.
fn render_bar_rect_animated(
  x: Float,
  y: Float,
  width: Float,
  height: Float,
  fill: String,
  stroke: String,
  stroke_w: Float,
  fill_opacity: Float,
  bar_layout: layout.LayoutDirection,
  baseline_y: Float,
  anim: AnimationConfig,
) -> Element(msg) {
  let opacity_attrs = case fill_opacity == 1.0 {
    True -> []
    False -> [svg.attr("fill-opacity", float.to_string(fill_opacity))]
  }
  let stroke_attrs = case stroke {
    "" -> []
    _ -> [
      svg.attr("stroke", stroke),
      svg.attr("stroke-width", float.to_string(stroke_w)),
    ]
  }
  let anims = case bar_layout {
    layout.Horizontal -> [
      animation.animate_attribute(
        name: "height",
        from: 0.0,
        to: height,
        config: anim,
      ),
      animation.animate_attribute(
        name: "y",
        from: baseline_y,
        to: y,
        config: anim,
      ),
    ]
    layout.Vertical -> [
      animation.animate_attribute(
        name: "width",
        from: 0.0,
        to: width,
        config: anim,
      ),
      animation.animate_attribute(
        name: "x",
        from: baseline_y,
        to: x,
        config: anim,
      ),
    ]
  }
  svg.rect_with_children(
    x: math.fmt(x),
    y: math.fmt(y),
    width: math.fmt(width),
    height: math.fmt(height),
    attrs: list.flatten([
      [svg.attr("fill", fill)],
      stroke_attrs,
      opacity_attrs,
    ]),
    children: anims,
  )
}

/// Format a bar value as a label string.
fn format_bar_value(value: Float) -> String {
  let rounded = float.round(value)
  case value == int.to_float(rounded) {
    True -> int.to_string(rounded)
    False -> math.fmt(value)
  }
}
