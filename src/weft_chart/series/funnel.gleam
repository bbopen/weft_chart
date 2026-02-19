//// Funnel series component.
////
//// Renders a vertical funnel visualization where each segment is a
//// trapezoid.  Data flows from largest (top) to smallest (bottom).
//// Matches the recharts Funnel component.

import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import lustre/event
import weft_chart/animation.{type AnimationConfig}
import weft_chart/internal/math
import weft_chart/internal/svg
import weft_chart/render
import weft_chart/shape

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Controls the shape of the last (bottom) funnel segment.
/// Matches recharts `lastShapeType` prop.
pub type FunnelLastShape {
  /// Bottom segment tapers to a point (default).
  TriangleLastShape
  /// Bottom segment maintains parallel sides.
  RectangleLastShape
}

/// Position of segment labels relative to the trapezoid.
/// Mirrors recharts `<LabelList position="..." />`.
pub type FunnelLabelPosition {
  /// Labels rendered centered inside each trapezoid segment (default).
  InsideFunnelLabel
  /// Labels rendered to the right of each segment, outside the trapezoid.
  RightFunnelLabel
}

/// Configuration for a funnel series.
pub type FunnelConfig(msg) {
  FunnelConfig(
    data_key: String,
    name_key: String,
    fills: List(String),
    stroke: String,
    stroke_width: Float,
    is_animation_active: Bool,
    reversed: Bool,
    trap_gap: Float,
    /// Shape of the bottom funnel segment.
    last_shape_type: FunnelLastShape,
    legend_type: shape.LegendIconType,
    hide: Bool,
    show_label: Bool,
    /// Position of labels (inside or right of segment).
    label_position: FunnelLabelPosition,
    /// When True, shows category name instead of numeric value.
    label_use_name: Bool,
    custom_label: Option(fn(render.LabelProps) -> Element(msg)),
    custom_shape: Option(fn(render.TrapezoidProps) -> Element(msg)),
    active_shape: Option(fn(render.TrapezoidProps) -> Element(msg)),
    active_index: List(Int),
    tooltip_type: shape.TooltipType,
    css_class: String,
    animation: AnimationConfig,
    on_click: Option(fn(Int) -> msg),
    on_mouse_enter: Option(fn(Int) -> msg),
    on_mouse_leave: Option(fn(Int) -> msg),
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a funnel configuration with default settings.
///
/// Matches recharts Funnel defaults: stroke="#fff", legendType=rect,
/// hide=false, isAnimationActive=false (SSR default).
pub fn funnel_config(data_key data_key: String) -> FunnelConfig(msg) {
  FunnelConfig(
    data_key: data_key,
    name_key: "name",
    fills: [
      "var(--weft-chart-1, #2563eb)",
      "var(--weft-chart-2, #60a5fa)",
      "var(--weft-chart-3, #93c5fd)",
      "var(--weft-chart-4, #bfdbfe)",
      "var(--weft-chart-5, #dbeafe)",
    ],
    stroke: "#fff",
    stroke_width: 1.0,
    is_animation_active: False,
    reversed: False,
    trap_gap: 0.0,
    last_shape_type: TriangleLastShape,
    legend_type: shape.RectIcon,
    hide: False,
    show_label: False,
    label_position: InsideFunnelLabel,
    label_use_name: False,
    custom_label: None,
    custom_shape: None,
    active_shape: None,
    active_index: [],
    tooltip_type: shape.DefaultTooltip,
    css_class: "",
    animation: animation.with_active(
      config: animation.pie_default(),
      active: False,
    ),
    on_click: None,
    on_mouse_enter: None,
    on_mouse_leave: None,
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the fill colors for funnel segments (cycled if fewer than data points).
pub fn funnel_fills(
  config: FunnelConfig(msg),
  fills: List(String),
) -> FunnelConfig(msg) {
  FunnelConfig(..config, fills: fills)
}

/// Set the stroke color for segment borders.
pub fn funnel_stroke(
  config: FunnelConfig(msg),
  stroke: String,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, stroke: stroke)
}

/// Set the stroke width for segment borders.
pub fn funnel_stroke_width(
  config: FunnelConfig(msg),
  width: Float,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, stroke_width: width)
}

/// Reverse the funnel direction (smallest on top).
pub fn funnel_reversed(config: FunnelConfig(msg)) -> FunnelConfig(msg) {
  FunnelConfig(..config, reversed: True)
}

/// Set the gap between trapezoid segments in pixels.
pub fn funnel_gap(config: FunnelConfig(msg), gap: Float) -> FunnelConfig(msg) {
  FunnelConfig(..config, trap_gap: gap)
}

/// Set the shape of the last (bottom) funnel segment.
/// `TriangleLastShape` tapers to a point (default).
/// `RectangleLastShape` maintains parallel sides.
/// Matches recharts `lastShapeType` prop.
pub fn funnel_last_shape_type(
  config config: FunnelConfig(msg),
  shape shape: FunnelLastShape,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, last_shape_type: shape)
}

/// Hide this funnel series.
pub fn funnel_hide(config: FunnelConfig(msg)) -> FunnelConfig(msg) {
  FunnelConfig(..config, hide: True)
}

/// Set the name key used for category labels.
pub fn funnel_name_key(
  config: FunnelConfig(msg),
  key: String,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, name_key: key)
}

/// Show or hide value labels on funnel segments.
/// Matches recharts Funnel `label` prop (boolean form).
pub fn funnel_label(
  config config: FunnelConfig(msg),
  show show: Bool,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, show_label: show)
}

/// Set the position of segment labels.
/// `InsideFunnelLabel` renders values centered inside each segment (default).
/// `RightFunnelLabel` renders labels to the right, outside the segment.
/// Mirrors recharts `<LabelList position="right" />`.
pub fn funnel_label_position(
  config: FunnelConfig(msg),
  position position: FunnelLabelPosition,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, label_position: position)
}

/// Show category names instead of numeric values in segment labels.
/// Mirrors recharts `<LabelList dataKey="name" />`.
pub fn funnel_label_name(config: FunnelConfig(msg)) -> FunnelConfig(msg) {
  FunnelConfig(..config, label_use_name: True)
}

/// Set the legend icon type for this funnel series.
pub fn funnel_legend_type(
  config: FunnelConfig(msg),
  icon_type: shape.LegendIconType,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, legend_type: icon_type)
}

/// Set a custom label render function for funnel segment labels.
/// When provided, the renderer is available for future label rendering.
/// Matches recharts Funnel `label` prop (element/function form).
pub fn funnel_custom_label(
  config config: FunnelConfig(msg),
  renderer renderer: fn(render.LabelProps) -> Element(msg),
) -> FunnelConfig(msg) {
  FunnelConfig(..config, custom_label: Some(renderer))
}

/// Set a custom renderer for funnel trapezoid segments.
/// When provided, each segment is rendered using this function.
/// Matches recharts Funnel `shape` prop.
pub fn funnel_custom_shape(
  config config: FunnelConfig(msg),
  renderer renderer: fn(render.TrapezoidProps) -> Element(msg),
) -> FunnelConfig(msg) {
  FunnelConfig(..config, custom_shape: Some(renderer))
}

/// Set a custom renderer for the active (hovered) funnel segment.
/// When provided, the active segment is rendered using this function.
/// Matches recharts Funnel `activeShape` prop.
pub fn funnel_active_shape(
  config config: FunnelConfig(msg),
  renderer renderer: fn(render.TrapezoidProps) -> Element(msg),
) -> FunnelConfig(msg) {
  FunnelConfig(..config, active_shape: Some(renderer))
}

/// Set the active segment indices for custom active shape dispatch.
/// Segments at these indices use the `active_shape` renderer.
/// Matches recharts Funnel `activeIndex` prop which accepts a number or array.
pub fn funnel_active_index(
  config config: FunnelConfig(msg),
  indices indices: List(Int),
) -> FunnelConfig(msg) {
  FunnelConfig(..config, active_index: indices)
}

/// Set the tooltip type to control whether this series appears in tooltips.
/// Matches recharts Funnel `tooltipType` prop (default: DefaultTooltip).
pub fn funnel_tooltip_type(
  config config: FunnelConfig(msg),
  tooltip_type tooltip_type: shape.TooltipType,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, tooltip_type: tooltip_type)
}

/// Set the CSS class applied to the funnel group element.
pub fn funnel_css_class(
  config config: FunnelConfig(msg),
  class class: String,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, css_class: class)
}

/// Set the animation configuration for funnel entry effects.
pub fn funnel_animation(
  config config: FunnelConfig(msg),
  animation anim: AnimationConfig,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, animation: anim)
}

/// Set a click handler for funnel segments.
/// Called with the segment index when clicked.
/// Matches recharts Funnel `onClick` prop.
pub fn funnel_on_click(
  config config: FunnelConfig(msg),
  handler handler: fn(Int) -> msg,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, on_click: Some(handler))
}

/// Set a mouse-enter handler for funnel segments.
/// Called with the segment index on hover.
/// Matches recharts Funnel `onMouseEnter` prop.
pub fn funnel_on_mouse_enter(
  config config: FunnelConfig(msg),
  handler handler: fn(Int) -> msg,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, on_mouse_enter: Some(handler))
}

/// Set a mouse-leave handler for funnel segments.
/// Called with the segment index when the cursor leaves.
/// Matches recharts Funnel `onMouseLeave` prop.
pub fn funnel_on_mouse_leave(
  config config: FunnelConfig(msg),
  handler handler: fn(Int) -> msg,
) -> FunnelConfig(msg) {
  FunnelConfig(..config, on_mouse_leave: Some(handler))
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a funnel series given the data, width, and height.
///
/// Extracts values using `data_key`, sorts by value descending (largest
/// first, unless reversed), computes trapezoid widths proportional to
/// values relative to the maximum, and renders each segment as a
/// trapezoid using `shape.trapezoid_with_stroke`.
///
/// Applies a 50 px horizontal deduction to match recharts'
/// `Funnel.getRealWidthHeight` behaviour (`realWidth - left - right - 50`).
/// weft_chart has no margin-offset system so only the hard-coded 50 px
/// constant is applied.
pub fn render_funnel(
  config config: FunnelConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  width width: Float,
  height height: Float,
) -> Element(msg) {
  case config.hide {
    True -> element.none()
    False -> {
      // Deduct 50 px to match recharts Funnel.getRealWidthHeight:
      // `realWidth = offset.width - left - right - 50` (Funnel.tsx:127).
      // weft_chart has no margin-offset system, so only the hard-coded
      // 50 px constant is applied here.
      let constrained_width = width -. 50.0

      // Extract (original_index, value) pairs from data
      let indexed_values =
        list.index_map(data, fn(d, i) {
          let value = case dict.get(d, config.data_key) {
            Ok(v) -> math.abs(v)
            Error(_) -> 0.0
          }
          #(i, value)
        })

      // Sort by value descending (largest first)
      let sorted =
        list.sort(indexed_values, fn(a, b) {
          // Reverse comparison for descending order
          float.compare(b.1, a.1)
        })

      // Always keep descending sort order (largest first)
      let ordered = sorted

      let n = list.length(ordered)
      case n {
        0 -> element.none()
        _ -> {
          // Find max value for width scaling
          let max_val =
            list.fold(ordered, 0.0, fn(acc, pair) {
              case pair.1 >. acc {
                True -> pair.1
                False -> acc
              }
            })

          // Compute segment height after gaps
          let total_gap = int.to_float(n - 1) *. config.trap_gap
          let seg_height = { height -. total_gap } /. int.to_float(n)
          let safe_seg_height = case seg_height <. 0.0 {
            True -> 0.0
            False -> seg_height
          }

          // Compute widths proportional to value/max_value
          let widths =
            list.map(ordered, fn(pair) {
              case max_val <=. 0.0 {
                True -> constrained_width
                False -> pair.1 /. max_val *. constrained_width
              }
            })

          // Extract original indices for fill cycling
          let orig_indices = list.map(ordered, fn(pair) { pair.0 })

          // Build category names in sorted order (by orig_index into categories)
          let cat_dict =
            list.index_map(categories, fn(name, i) { #(i, name) })
            |> dict.from_list
          let ordered_categories =
            list.map(orig_indices, fn(i) {
              case dict.get(cat_dict, i) {
                Ok(name) -> name
                Error(_) -> ""
              }
            })

          // Build trapezoids and determine label data based on
          // direction.  Reversed mode swaps upper/lower widths and
          // repositions from bottom (narrow→wide, matching recharts).
          let #(trapezoid_els, label_widths, label_values, label_categories) = case
            config.reversed
          {
            False -> {
              let trap_els =
                build_trapezoids(
                  widths: widths,
                  indices: orig_indices,
                  config: config,
                  y: 0.0,
                  width: constrained_width,
                  seg_height: safe_seg_height,
                  segment_index: 0,
                )
              let values = list.map(ordered, fn(pair) { pair.1 })
              #(trap_els, widths, values, ordered_categories)
            }
            True -> {
              let widths_asc = list.reverse(widths)
              let indices_asc = list.reverse(orig_indices)
              let first_upper = case config.last_shape_type {
                TriangleLastShape -> 0.0
                RectangleLastShape ->
                  case widths_asc {
                    [w, ..] -> w
                    [] -> 0.0
                  }
              }
              let upper_widths = [first_upper, ..list.take(widths_asc, n - 1)]
              let pairs = list.zip(upper_widths, widths_asc)
              let trap_els =
                build_trapezoids_pairs(
                  pairs: pairs,
                  indices: indices_asc,
                  config: config,
                  y: 0.0,
                  width: constrained_width,
                  seg_height: safe_seg_height,
                  segment_index: 0,
                )
              let values_asc =
                list.reverse(list.map(ordered, fn(pair) { pair.1 }))
              let cats_asc = list.reverse(ordered_categories)
              #(trap_els, widths_asc, values_asc, cats_asc)
            }
          }

          // Build labels
          let label_els = case config.show_label {
            False -> []
            True ->
              build_labels(
                widths: label_widths,
                values: label_values,
                categories: label_categories,
                config: config,
                y: 0.0,
                width: constrained_width,
                seg_height: safe_seg_height,
                index: 0,
              )
          }

          let class_attr = case config.css_class {
            "" -> "recharts-funnel"
            c -> "recharts-funnel " <> c
          }
          svg.g(
            attrs: [svg.attr("class", class_attr)],
            children: list.append(trapezoid_els, label_els),
          )
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Internal
// ---------------------------------------------------------------------------

fn build_trapezoids(
  widths widths: List(Float),
  indices indices: List(Int),
  config config: FunnelConfig(msg),
  y y: Float,
  width width: Float,
  seg_height seg_height: Float,
  segment_index segment_index: Int,
) -> List(Element(msg)) {
  case widths, indices {
    [], _ -> []
    [upper_w], [orig_index] -> {
      // Last segment: lower_width depends on last_shape_type
      let lower_w = case config.last_shape_type {
        TriangleLastShape -> 0.0
        RectangleLastShape -> upper_w
      }
      let fill_color = cycle_fill(config.fills, orig_index)
      let max_w = case upper_w >. lower_w {
        True -> upper_w
        False -> lower_w
      }
      let seg_x = { width -. max_w } /. 2.0
      let trap_el =
        dispatch_trapezoid(
          config: config,
          x: seg_x,
          y: y,
          upper_width: upper_w,
          lower_width: lower_w,
          height: seg_height,
          fill: fill_color,
          index: segment_index,
        )
      let wrapped = wrap_role_img(trap_el)
      let wrapped = wrap_events(wrapped, config, segment_index)
      [animate_trapezoid(el: wrapped, config: config)]
    }
    [upper_w, lower_w, ..rest_widths], [orig_index, ..rest_indices] -> {
      let fill_color = cycle_fill(config.fills, orig_index)
      // Center each trapezoid within the available width
      let max_w = case upper_w >. lower_w {
        True -> upper_w
        False -> lower_w
      }
      let seg_x = { width -. max_w } /. 2.0
      let trap_el =
        dispatch_trapezoid(
          config: config,
          x: seg_x,
          y: y,
          upper_width: upper_w,
          lower_width: lower_w,
          height: seg_height,
          fill: fill_color,
          index: segment_index,
        )
      let wrapped = wrap_role_img(trap_el)
      let wrapped = wrap_events(wrapped, config, segment_index)
      let next_y = y +. seg_height +. config.trap_gap
      [
        animate_trapezoid(el: wrapped, config: config),
        ..build_trapezoids(
          widths: [lower_w, ..rest_widths],
          indices: rest_indices,
          config: config,
          y: next_y,
          width: width,
          seg_height: seg_height,
          segment_index: segment_index + 1,
        )
      ]
    }
    _, _ -> []
  }
}

fn build_trapezoids_pairs(
  pairs pairs: List(#(Float, Float)),
  indices indices: List(Int),
  config config: FunnelConfig(msg),
  y y: Float,
  width width: Float,
  seg_height seg_height: Float,
  segment_index segment_index: Int,
) -> List(Element(msg)) {
  case pairs, indices {
    [], _ -> []
    [#(upper_w, lower_w), ..rest_pairs], [orig_index, ..rest_indices] -> {
      let fill_color = cycle_fill(config.fills, orig_index)
      let max_w = case upper_w >. lower_w {
        True -> upper_w
        False -> lower_w
      }
      let seg_x = { width -. max_w } /. 2.0
      let trap_el =
        dispatch_trapezoid(
          config: config,
          x: seg_x,
          y: y,
          upper_width: upper_w,
          lower_width: lower_w,
          height: seg_height,
          fill: fill_color,
          index: segment_index,
        )
      let wrapped = wrap_role_img(trap_el)
      let wrapped = wrap_events(wrapped, config, segment_index)
      let next_y = y +. seg_height +. config.trap_gap
      [
        animate_trapezoid(el: wrapped, config: config),
        ..build_trapezoids_pairs(
          pairs: rest_pairs,
          indices: rest_indices,
          config: config,
          y: next_y,
          width: width,
          seg_height: seg_height,
          segment_index: segment_index + 1,
        )
      ]
    }
    _, _ -> []
  }
}

fn wrap_role_img(el: Element(msg)) -> Element(msg) {
  svg.g(
    attrs: [
      svg.attr("class", "recharts-funnel-trapezoid"),
      svg.attr("role", "img"),
    ],
    children: [el],
  )
}

fn wrap_events(
  el: Element(msg),
  config: FunnelConfig(msg),
  index: Int,
) -> Element(msg) {
  case config.on_click, config.on_mouse_enter, config.on_mouse_leave {
    None, None, None -> el
    _, _, _ -> {
      let click_attrs = case config.on_click {
        None -> []
        Some(handler) -> [
          event.on("click", decode.success(handler(index))),
        ]
      }
      let enter_attrs = case config.on_mouse_enter {
        None -> []
        Some(handler) -> [
          event.on("mouseenter", decode.success(handler(index))),
        ]
      }
      let leave_attrs = case config.on_mouse_leave {
        None -> []
        Some(handler) -> [
          event.on("mouseleave", decode.success(handler(index))),
        ]
      }
      let cursor_attr = [svg.attr("cursor", "pointer")]
      svg.g(
        attrs: list.flatten([cursor_attr, click_attrs, enter_attrs, leave_attrs]),
        children: [el],
      )
    }
  }
}

fn dispatch_trapezoid(
  config config: FunnelConfig(msg),
  x x: Float,
  y y: Float,
  upper_width upper_width: Float,
  lower_width lower_width: Float,
  height height: Float,
  fill fill: String,
  index index: Int,
) -> Element(msg) {
  let props =
    render.TrapezoidProps(
      x: x,
      y: y,
      width: upper_width,
      height: height,
      upper_width: upper_width,
      lower_width: lower_width,
      index: index,
    )
  let is_active = list.contains(config.active_index, index)
  case is_active, config.active_shape {
    True, Some(renderer) -> renderer(props)
    _, _ ->
      case config.custom_shape {
        Some(renderer) -> renderer(props)
        None ->
          shape.trapezoid_with_stroke(
            x: x,
            y: y,
            upper_width: upper_width,
            lower_width: lower_width,
            height: height,
            fill: fill,
            stroke: config.stroke,
            stroke_width: config.stroke_width,
          )
      }
  }
}

fn animate_trapezoid(
  el el: Element(msg),
  config config: FunnelConfig(msg),
) -> Element(msg) {
  case config.animation.active {
    False -> el
    True ->
      svg.g(attrs: [svg.attr("opacity", "0")], children: [
        el,
        animation.animate_attribute(
          name: "opacity",
          from: 0.0,
          to: 1.0,
          config: config.animation,
        ),
      ])
  }
}

fn build_labels(
  widths widths: List(Float),
  values values: List(Float),
  categories categories: List(String),
  config config: FunnelConfig(msg),
  y y: Float,
  width width: Float,
  seg_height seg_height: Float,
  index index: Int,
) -> List(Element(msg)) {
  case widths, values {
    [], _ -> []
    _, [] -> []
    [w, ..rest_widths], [value, ..rest_values] -> {
      // Determine label text: category name or numeric value
      let content = case config.label_use_name {
        True ->
          case categories {
            [name, ..] -> name
            [] -> format_funnel_value(value)
          }
        False -> format_funnel_value(value)
      }
      let rest_cats = case categories {
        [_, ..rest] -> rest
        [] -> []
      }
      let cx = width /. 2.0
      let cy = y +. seg_height /. 2.0
      // Determine x, anchor by label_position
      let #(lx, anchor, pos_str) = case config.label_position {
        InsideFunnelLabel -> #(cx, "middle", "center")
        RightFunnelLabel -> #(cx +. w /. 2.0 +. 8.0, "start", "right")
      }
      let label_el = case config.custom_label {
        Some(renderer) ->
          renderer(render.LabelProps(
            x: lx,
            y: cy,
            width: w,
            height: seg_height,
            index: index,
            value: content,
            offset: 0.0,
            position: pos_str,
            fill: "var(--weft-chart-label, currentColor)",
          ))
        None ->
          svg.text(x: math.fmt(lx), y: math.fmt(cy), content: content, attrs: [
            svg.attr("text-anchor", anchor),
            svg.attr("dominant-baseline", "central"),
            svg.attr("font-size", "11"),
            svg.attr("fill", "var(--weft-chart-label, currentColor)"),
          ])
      }
      let next_y = y +. seg_height +. config.trap_gap
      [
        label_el,
        ..build_labels(
          widths: rest_widths,
          values: rest_values,
          categories: rest_cats,
          config: config,
          y: next_y,
          width: width,
          seg_height: seg_height,
          index: index + 1,
        )
      ]
    }
  }
}

fn format_funnel_value(value: Float) -> String {
  let rounded = float.round(value)
  case value == int.to_float(rounded) {
    True -> int.to_string(rounded)
    False -> math.fmt(value)
  }
}

fn cycle_fill(fills: List(String), index: Int) -> String {
  let n = list.length(fills)
  case n == 0 {
    True -> "#808080"
    False -> {
      let target = index % n
      find_at(fills, target, 0, "#808080")
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
