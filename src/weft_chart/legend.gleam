//// Legend component for charts.
////
//// Renders a legend below/above/beside the chart showing series
//// names with colored icons.  Matches the recharts Legend and
//// DefaultLegendContent components including click/hover event
//// handlers and custom content rendering.

import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/event
import weft_chart/internal/math
import weft_chart/internal/svg
import weft_chart/shape

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for a chart legend.
pub type LegendConfig(msg) {
  LegendConfig(
    layout: LegendLayout,
    align: LegendAlign,
    vertical_align: LegendVerticalAlign,
    icon_size: Int,
    icon_type: shape.LegendIconType,
    show_icon: Bool,
    inactive_color: String,
    formatter: fn(String, LegendPayload, Int) -> String,
    width: Float,
    height: Float,
    margin_top: Int,
    margin_right: Int,
    margin_bottom: Int,
    margin_left: Int,
    dedup_payload: Bool,
    /// CSS style string applied to the outer legend wrapper.
    wrapper_style: String,
    /// When set, overrides the auto-generated legend payload.
    payload_override: Option(List(LegendPayload)),
    on_click: Option(fn(String, Int) -> msg),
    on_mouse_enter: Option(fn(String, Int) -> msg),
    on_mouse_leave: Option(fn(String, Int) -> msg),
    custom_content: Option(fn(List(LegendPayload)) -> Element(msg)),
  )
}

/// Legend layout direction.
pub type LegendLayout {
  /// Items flow left-to-right.
  HorizontalLegend
  /// Items stack top-to-bottom.
  VerticalLegend
}

/// Horizontal alignment.
pub type LegendAlign {
  /// Align to left edge.
  AlignLeft
  /// Center horizontally.
  AlignCenter
  /// Align to right edge.
  AlignRight
}

/// Vertical alignment.
pub type LegendVerticalAlign {
  /// Position above the chart.
  AlignTop
  /// Position in the middle (overlay).
  AlignMiddle
  /// Position below the chart.
  AlignBottom
}

/// A legend entry generated from a series component.
pub type LegendPayload {
  LegendPayload(
    value: String,
    color: String,
    icon_type: shape.LegendIconType,
    inactive: Bool,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a default legend configuration.
pub fn legend_config() -> LegendConfig(msg) {
  LegendConfig(
    layout: HorizontalLegend,
    align: AlignCenter,
    vertical_align: AlignBottom,
    icon_size: 14,
    icon_type: shape.RectIcon,
    show_icon: True,
    inactive_color: "#ccc",
    formatter: fn(v, _entry, _i) { v },
    width: 0.0,
    height: 0.0,
    margin_top: 0,
    margin_right: 0,
    margin_bottom: 0,
    margin_left: 0,
    dedup_payload: False,
    wrapper_style: "",
    payload_override: None,
    on_click: None,
    on_mouse_enter: None,
    on_mouse_leave: None,
    custom_content: None,
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the legend layout direction.
pub fn legend_layout(
  config config: LegendConfig(msg),
  layout layout: LegendLayout,
) -> LegendConfig(msg) {
  LegendConfig(..config, layout: layout)
}

/// Set the horizontal alignment.
pub fn legend_align(
  config config: LegendConfig(msg),
  align align: LegendAlign,
) -> LegendConfig(msg) {
  LegendConfig(..config, align: align)
}

/// Set the vertical alignment.
pub fn legend_vertical_align(
  config config: LegendConfig(msg),
  align align: LegendVerticalAlign,
) -> LegendConfig(msg) {
  LegendConfig(..config, vertical_align: align)
}

/// Hide the legend icon.
pub fn legend_hide_icon(config config: LegendConfig(msg)) -> LegendConfig(msg) {
  LegendConfig(..config, show_icon: False)
}

/// Set the legend icon size in pixels.
pub fn legend_icon_size(
  config config: LegendConfig(msg),
  size size: Int,
) -> LegendConfig(msg) {
  LegendConfig(..config, icon_size: size)
}

/// Set the icon type for all legend entries.
pub fn legend_icon_type(
  config config: LegendConfig(msg),
  icon_type icon_type: shape.LegendIconType,
) -> LegendConfig(msg) {
  LegendConfig(..config, icon_type: icon_type)
}

/// Set the formatter for legend entry text.
///
/// The formatter receives the entry value, the full `LegendPayload`, and the
/// entry index.  Matches recharts Legend `formatter(value, entry, index)`.
pub fn legend_formatter(
  config config: LegendConfig(msg),
  formatter formatter: fn(String, LegendPayload, Int) -> String,
) -> LegendConfig(msg) {
  LegendConfig(..config, formatter: formatter)
}

/// Set a fixed legend width.
/// When > 0, overrides auto-computed width.
pub fn legend_width(
  config config: LegendConfig(msg),
  width width: Float,
) -> LegendConfig(msg) {
  LegendConfig(..config, width: width)
}

/// Set a fixed legend height.
/// When > 0, overrides auto-computed height.
pub fn legend_height(
  config config: LegendConfig(msg),
  height height: Float,
) -> LegendConfig(msg) {
  LegendConfig(..config, height: height)
}

/// Set legend margin on all four sides.
/// Matches recharts Legend `margin` prop.
pub fn legend_margin(
  config config: LegendConfig(msg),
  top top: Int,
  right right: Int,
  bottom bottom: Int,
  left left: Int,
) -> LegendConfig(msg) {
  LegendConfig(
    ..config,
    margin_top: top,
    margin_right: right,
    margin_bottom: bottom,
    margin_left: left,
  )
}

/// Deduplicate legend entries by value (name).
/// When True, only the first entry for each unique name is kept.
/// Matches recharts Legend `payloadUniqBy` prop behavior when set to `value`.
pub fn legend_dedup_payload(
  config config: LegendConfig(msg),
  dedup dedup: Bool,
) -> LegendConfig(msg) {
  LegendConfig(..config, dedup_payload: dedup)
}

/// Set the color used for inactive legend entries.
pub fn legend_inactive_color(
  config config: LegendConfig(msg),
  color color: String,
) -> LegendConfig(msg) {
  LegendConfig(..config, inactive_color: color)
}

/// Set a click handler for legend items.
/// The handler receives the series name and item index.
/// Matches recharts DefaultLegendContent `onClick` prop.
pub fn legend_on_click(
  config config: LegendConfig(msg),
  handler handler: fn(String, Int) -> msg,
) -> LegendConfig(msg) {
  LegendConfig(..config, on_click: Some(handler))
}

/// Set a mouse enter handler for legend items.
/// The handler receives the series name and item index.
/// Matches recharts DefaultLegendContent `onMouseEnter` prop.
pub fn legend_on_mouse_enter(
  config config: LegendConfig(msg),
  handler handler: fn(String, Int) -> msg,
) -> LegendConfig(msg) {
  LegendConfig(..config, on_mouse_enter: Some(handler))
}

/// Set a mouse leave handler for legend items.
/// The handler receives the series name and item index.
/// Matches recharts DefaultLegendContent `onMouseLeave` prop.
pub fn legend_on_mouse_leave(
  config config: LegendConfig(msg),
  handler handler: fn(String, Int) -> msg,
) -> LegendConfig(msg) {
  LegendConfig(..config, on_mouse_leave: Some(handler))
}

/// Set a custom content renderer for the legend.
/// When set, the function receives the legend payload entries and renders
/// a custom element instead of the default legend content.
/// Matches recharts Legend `content` prop.
pub fn legend_custom_content(
  config config: LegendConfig(msg),
  renderer renderer: fn(List(LegendPayload)) -> Element(msg),
) -> LegendConfig(msg) {
  LegendConfig(..config, custom_content: Some(renderer))
}

/// Set a CSS style string applied to the outer legend wrapper element.
/// Matches recharts Legend `wrapperStyle` prop.
pub fn legend_wrapper_style(
  config config: LegendConfig(msg),
  style style: String,
) -> LegendConfig(msg) {
  LegendConfig(..config, wrapper_style: style)
}

/// Override the auto-generated legend payload with a custom list.
/// When set, these entries are used instead of series-derived entries.
/// Matches recharts Legend `payload` prop.
pub fn legend_payload_override(
  config config: LegendConfig(msg),
  payload payload: List(LegendPayload),
) -> LegendConfig(msg) {
  LegendConfig(..config, payload_override: Some(payload))
}

// ---------------------------------------------------------------------------
// Layout estimation
// ---------------------------------------------------------------------------

/// Estimate the legend height in pixels for layout purposes.
///
/// Used by chart containers to reserve space in the plot area before
/// the legend is rendered.  Mirrors `compute_legend_height` but works
/// without a payload so it can be called at margin-computation time.
///
/// - `HorizontalLegend`: returns `icon_size + 16` (matches one row of items).
/// - `VerticalLegend`: returns `0` because the height depends on the number
///   of entries, which is not known at layout time.
///
/// If `config.height` is set to a positive value the caller's explicit
/// height is returned instead of the estimate.
pub fn legend_estimated_height(config config: LegendConfig(msg)) -> Int {
  case config.height >. 0.0 {
    True -> float.round(config.height)
    False ->
      case config.layout {
        HorizontalLegend -> config.icon_size + 16
        VerticalLegend -> 0
      }
  }
}

/// Estimate the legend width in pixels for layout purposes.
///
/// Returns 0 for HorizontalLegend. For VerticalLegend, returns
/// `config.width` if set (> 0), otherwise 150 (recharts default).
pub fn legend_estimated_width(config config: LegendConfig(msg)) -> Int {
  case config.layout {
    HorizontalLegend -> 0
    VerticalLegend ->
      case config.width >. 0.0 {
        True -> float.round(config.width)
        False -> 150
      }
  }
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a legend from configuration and payload entries.
///
/// Produces an SVG foreignObject containing HTML legend items,
/// matching the recharts DefaultLegendContent structure.
/// When custom_content is set, delegates to the custom renderer.
/// When event handlers are set, attaches lustre event attributes.
/// Entries with `NoneIcon` icon type are suppressed entirely.
pub fn render_legend(
  config config: LegendConfig(msg),
  payload payload: List(LegendPayload),
  chart_width chart_width: Float,
  chart_height chart_height: Float,
) -> Element(msg) {
  // Use payload_override when set, otherwise use passed-in payload
  let base_payload = case config.payload_override {
    Some(entries) -> entries
    None -> payload
  }

  // Filter out NoneIcon entries
  let filtered_payload =
    list.filter(base_payload, fn(entry) {
      case entry.icon_type {
        shape.NoneIcon -> False
        _ -> True
      }
    })

  // Deduplicate entries by value when configured
  let effective_payload = case config.dedup_payload {
    False -> filtered_payload
    True -> dedup_legend_entries(filtered_payload)
  }

  case effective_payload {
    [] -> element.none()
    _ -> {
      // Use custom content if provided
      case config.custom_content {
        Some(renderer) -> {
          let legend_height = compute_legend_height(config, effective_payload)
          let legend_y = compute_legend_y(config, chart_height, legend_height)
          let base_attrs = [
            svg.attr("x", "0"),
            svg.attr("y", math.fmt(legend_y)),
            svg.attr("width", math.fmt(chart_width)),
            svg.attr("height", math.fmt(legend_height)),
            svg.attr("class", "recharts-legend-wrapper"),
          ]
          let attrs = case config.wrapper_style {
            "" -> base_attrs
            s -> list.append(base_attrs, [svg.attr("style", s)])
          }
          svg.el(tag: "foreignObject", attrs: attrs, children: [
            renderer(effective_payload),
          ])
        }
        None ->
          render_default_legend(
            config: config,
            payload: effective_payload,
            chart_width: chart_width,
            chart_height: chart_height,
          )
      }
    }
  }
}

/// Render the default legend content with icons and text.
fn render_default_legend(
  config config: LegendConfig(msg),
  payload payload: List(LegendPayload),
  chart_width chart_width: Float,
  chart_height chart_height: Float,
) -> Element(msg) {
  let legend_height = compute_legend_height(config, payload)
  let legend_y = compute_legend_y(config, chart_height, legend_height)

  let text_align = case config.align {
    AlignLeft -> "left"
    AlignCenter -> "center"
    AlignRight -> "right"
  }

  let list_display = case config.layout {
    HorizontalLegend -> "inline-block"
    VerticalLegend -> "block"
  }

  // Render each legend item as an HTML element inside foreignObject
  let items =
    list.index_map(payload, fn(entry, index) {
      let color = case entry.inactive {
        True -> config.inactive_color
        False -> entry.color
      }

      let icon_el = case config.show_icon {
        False -> element.none()
        True ->
          svg.el(
            tag: "svg",
            attrs: [
              svg.attr("width", int.to_string(config.icon_size)),
              svg.attr("height", int.to_string(config.icon_size)),
              svg.attr("viewBox", "0 0 32 32"),
              attribute.style("display", "inline-block"),
              attribute.style("vertical-align", "middle"),
              attribute.style("margin-right", "4px"),
            ],
            children: [
              shape.legend_icon(
                icon_type: entry.icon_type,
                x: 0.0,
                y: 0.0,
                size: 32.0,
                color: color,
              ),
            ],
          )
      }

      let text_el =
        svg.xhtml(
          tag: "span",
          attrs: [
            attribute.style("color", color),
            attribute.style("font-size", "12px"),
            attribute.style("vertical-align", "middle"),
          ],
          children: [
            element.text(config.formatter(entry.value, entry, index)),
          ],
        )

      let inactive_class = case entry.inactive {
        True -> " inactive"
        False -> ""
      }

      // Build event handler attributes
      let event_attrs =
        build_event_attrs(
          config: config,
          entry_value: entry.value,
          index: index,
        )

      let base_attrs = [
        attribute.style("display", list_display),
        attribute.style("margin-right", "10px"),
        attribute.style("list-style", "none"),
        attribute.style("padding", "0"),
        attribute.style("cursor", case config.on_click {
          Some(_) -> "pointer"
          None -> "default"
        }),
        svg.attr("class", "recharts-legend-item" <> inactive_class),
        ..event_attrs
      ]

      svg.xhtml(tag: "li", attrs: base_attrs, children: [icon_el, text_el])
    })

  let list_el =
    svg.xhtml(
      tag: "ul",
      attrs: [
        attribute.style("padding", "0"),
        attribute.style("margin", "0"),
        attribute.style("text-align", text_align),
        svg.attr("class", "recharts-default-legend"),
      ],
      children: items,
    )

  let base_attrs = [
    svg.attr("x", "0"),
    svg.attr("y", math.fmt(legend_y)),
    svg.attr("width", math.fmt(chart_width)),
    svg.attr("height", math.fmt(legend_height)),
    svg.attr("class", "recharts-legend-wrapper"),
  ]
  let attrs = case config.wrapper_style {
    "" -> base_attrs
    s -> list.append(base_attrs, [svg.attr("style", s)])
  }
  svg.el(tag: "foreignObject", attrs: attrs, children: [list_el])
}

// ---------------------------------------------------------------------------
// Event helpers
// ---------------------------------------------------------------------------

/// Build event handler attributes for a legend item.
fn build_event_attrs(
  config config: LegendConfig(msg),
  entry_value entry_value: String,
  index index: Int,
) -> List(attribute.Attribute(msg)) {
  let click_attrs = case config.on_click {
    None -> []
    Some(handler) -> [
      event.on("click", decode.success(handler(entry_value, index))),
    ]
  }
  let enter_attrs = case config.on_mouse_enter {
    None -> []
    Some(handler) -> [
      event.on("mouseenter", decode.success(handler(entry_value, index))),
    ]
  }
  let leave_attrs = case config.on_mouse_leave {
    None -> []
    Some(handler) -> [
      event.on("mouseleave", decode.success(handler(entry_value, index))),
    ]
  }
  list.flatten([click_attrs, enter_attrs, leave_attrs])
}

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------

/// Compute legend container height based on layout and entry count.
fn compute_legend_height(
  config: LegendConfig(msg),
  payload: List(LegendPayload),
) -> Float {
  let icon_sz = int.to_float(config.icon_size)
  case config.layout {
    HorizontalLegend -> icon_sz +. 16.0
    VerticalLegend ->
      int.to_float(list.length(payload)) *. { icon_sz +. 8.0 } +. 8.0
  }
}

/// Compute legend Y position based on vertical alignment.
fn compute_legend_y(
  config: LegendConfig(msg),
  chart_height: Float,
  legend_height: Float,
) -> Float {
  case config.vertical_align {
    AlignTop -> 0.0
    AlignBottom -> chart_height -. legend_height
    AlignMiddle -> { chart_height -. legend_height } /. 2.0
  }
}

/// Deduplicate legend entries by value (name), keeping the first occurrence.
fn dedup_legend_entries(entries: List(LegendPayload)) -> List(LegendPayload) {
  let #(result, _) =
    list.fold(entries, #([], []), fn(acc, entry) {
      let #(kept, seen_names) = acc
      case list.contains(seen_names, entry.value) {
        True -> #(kept, seen_names)
        False -> #(list.append(kept, [entry]), [entry.value, ..seen_names])
      }
    })
  result
}
