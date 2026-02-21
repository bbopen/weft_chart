//// Tooltip component for charts.
////
//// Renders hover-activated tooltip overlays on data points using
//// transparent hit zones and foreignObject HTML content.  Matches
//// the recharts Tooltip component behavior including position,
//// offset, cursor styling, custom content, and trigger mode.

import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/event
import weft
import weft_chart/internal/math
import weft_chart/internal/svg

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for a chart tooltip.
pub type TooltipConfig(msg) {
  TooltipConfig(
    show_cursor: Bool,
    cursor_type: CursorType,
    show_active_dot: Bool,
    hide_label: Bool,
    hide_indicator: Bool,
    indicator: IndicatorType,
    label_formatter: fn(String, List(TooltipEntry)) -> String,
    value_formatter: fn(Float, String) -> String,
    separator: String,
    offset: Int,
    has_custom_position: Bool,
    position_x: Float,
    position_y: Float,
    allow_escape_x: Bool,
    allow_escape_y: Bool,
    item_sorter: fn(TooltipEntry) -> Float,
    include_hidden: Bool,
    filter_null: Bool,
    default_index: Int,
    shared: Bool,
    reverse_x: Bool,
    reverse_y: Bool,
    dedup_payload: Bool,
    custom_content: Option(fn(TooltipPayload) -> Element(msg)),
    trigger: TooltipTrigger,
    content_style: Option(String),
    item_style: Option(String),
    label_style: Option(String),
    wrapper_style: String,
    animation_duration: Int,
    active_index: Option(Int),
    on_tooltip_enter: Option(fn(Int) -> msg),
    on_tooltip_leave: Option(fn() -> msg),
    cursor_stroke_dasharray: String,
  )
}

/// Visual indicator style shown next to tooltip values.
pub type IndicatorType {
  /// Small circle dot.
  DotIndicator
  /// Thin vertical line segment.
  LineIndicator
  /// Dashed vertical line segment.
  DashedIndicator
}

/// Cursor line style shown on hover.
pub type CursorType {
  /// Vertical line cursor (default for line/area).
  VerticalCursor
  /// Horizontal line cursor.
  HorizontalCursor
  /// Rectangle highlight (for bar charts).
  RectangleCursor
  /// Crosshair cursor — a full-height vertical line and a full-width
  /// horizontal line intersecting at the data point.  Matches recharts
  /// Cross component used for ScatterChart.
  CrossCursor
  /// No cursor.
  NoCursor
}

/// Trigger mode for tooltip activation.
/// Matches recharts Tooltip `trigger` prop.
pub type TooltipTrigger {
  /// Tooltip activates on mouse hover (default).
  HoverTrigger
  /// Tooltip activates on click.
  ClickTrigger
}

/// Hit-zone geometry for tooltip hover detection.
pub type ZoneMode {
  /// Full-height vertical strip centered on payload.x.
  /// Used for line, area, and bar charts where each x position
  /// corresponds to a vertical column of data.
  ColumnZone
  /// Full-width horizontal strip centered on payload.y.
  /// Used for vertical-layout cartesian charts where categories
  /// are positioned on the y-axis.
  RowZone
  /// Small square centered on the payload's (x, y) position.
  /// Used for scatter charts where each point is at an arbitrary
  /// 2-D position and full-height strips would cause incorrect
  /// trigger behaviour when points are close vertically.
  PointZone
}

/// Data needed to render a tooltip at a specific data point.
///
/// `zone_width` and `zone_height` specify per-payload hit zone dimensions.
/// When both are `0.0` (the default), the global `zone_width` parameter passed
/// to `render_tooltips` is used instead.  Non-zero values override the global
/// parameter for that specific payload, enabling variable-size hit zones such
/// as those needed for treemap cells.
pub type TooltipPayload {
  TooltipPayload(
    label: String,
    entries: List(TooltipEntry),
    x: Float,
    y: Float,
    active_dots: List(Float),
    /// Per-payload hit zone width in pixels. `0.0` means use the global zone_width.
    zone_width: Float,
    /// Per-payload hit zone height in pixels. `0.0` means use the global zone_width.
    zone_height: Float,
  )
}

/// Controls whether a tooltip entry is rendered.
pub type TooltipEntryType {
  /// Entry is visible in the tooltip.
  VisibleEntry
  /// Entry is suppressed entirely (not rendered).
  NoneEntry
}

/// A single series entry within a tooltip.
pub type TooltipEntry {
  TooltipEntry(
    name: String,
    value: Float,
    color: weft.Color,
    unit: String,
    /// When true, this entry is hidden from the tooltip unless include_hidden is set.
    hidden: Bool,
    /// When NoneEntry, this entry is never rendered regardless of hidden flag.
    entry_type: TooltipEntryType,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create default tooltip configuration.
/// Matches recharts Tooltip defaults: offset=10, vertical cursor,
/// animation_duration=400, trigger=hover.
pub fn tooltip_config() -> TooltipConfig(msg) {
  TooltipConfig(
    show_cursor: True,
    cursor_type: VerticalCursor,
    show_active_dot: False,
    hide_label: False,
    hide_indicator: True,
    indicator: DotIndicator,
    label_formatter: fn(v, _entries) { v },
    value_formatter: fn(v, _name) { format_value(v) },
    separator: " : ",
    offset: 10,
    has_custom_position: False,
    position_x: 0.0,
    position_y: 0.0,
    allow_escape_x: False,
    allow_escape_y: False,
    item_sorter: fn(_) { 0.0 },
    include_hidden: False,
    filter_null: True,
    default_index: -1,
    shared: True,
    reverse_x: False,
    reverse_y: False,
    dedup_payload: False,
    custom_content: None,
    trigger: HoverTrigger,
    content_style: None,
    item_style: None,
    label_style: None,
    wrapper_style: "",
    animation_duration: 400,
    active_index: None,
    on_tooltip_enter: None,
    on_tooltip_leave: None,
    cursor_stroke_dasharray: "",
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Show or hide the cursor line on hover.
pub fn tooltip_cursor(
  config config: TooltipConfig(msg),
  show show: Bool,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, show_cursor: show)
}

/// Set the cursor type.
pub fn tooltip_cursor_type(
  config config: TooltipConfig(msg),
  type_ type_: CursorType,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, cursor_type: type_)
}

/// Set the stroke-dasharray on the cursor line(s).
/// Use `"3 3"` for a dashed crosshair matching the recharts scatter demo
/// (`cursor: { strokeDasharray: "3 3" }`).  Empty string (default) gives
/// solid lines.
pub fn tooltip_cursor_dasharray(
  config config: TooltipConfig(msg),
  dasharray dasharray: String,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, cursor_stroke_dasharray: dasharray)
}

/// Show an active dot at the data point position on hover.
/// When True, a small circle is rendered at (payload.x, payload.y) for the
/// hovered data point.  Enabled for line and area charts (where recharts
/// renders an activeDot); disabled by default for bar and pie charts.
/// Matches recharts `activeDot` prop existence on Line/Area.
pub fn tooltip_show_active_dot(
  config config: TooltipConfig(msg),
  show show: Bool,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, show_active_dot: show)
}

/// Hide the category label in the tooltip.
pub fn tooltip_hide_label(
  config config: TooltipConfig(msg),
) -> TooltipConfig(msg) {
  TooltipConfig(..config, hide_label: True)
}

/// Hide the color indicator dot/line.
pub fn tooltip_hide_indicator(
  config config: TooltipConfig(msg),
) -> TooltipConfig(msg) {
  TooltipConfig(..config, hide_indicator: True)
}

/// Set the indicator style.
pub fn tooltip_indicator(
  config config: TooltipConfig(msg),
  type_ type_: IndicatorType,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, indicator: type_)
}

/// Set a label formatter function that receives the label and the full entry list.
/// Matches recharts Tooltip `labelFormatter(label, payload)` prop.
pub fn tooltip_label_formatter(
  config config: TooltipConfig(msg),
  formatter formatter: fn(String, List(TooltipEntry)) -> String,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, label_formatter: formatter)
}

/// Set a value formatter function.
pub fn tooltip_value_formatter(
  config config: TooltipConfig(msg),
  formatter formatter: fn(Float, String) -> String,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, value_formatter: formatter)
}

/// Set the separator between name and value in tooltip entries.
/// Matches recharts Tooltip separator prop (default: " : ").
pub fn tooltip_separator(
  config config: TooltipConfig(msg),
  separator separator: String,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, separator: separator)
}

/// Set the tooltip offset from the cursor position.
/// Matches recharts Tooltip offset prop (default: 10).
pub fn tooltip_offset(
  config config: TooltipConfig(msg),
  offset offset: Int,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, offset: offset)
}

/// Set a fixed position for the tooltip popup.
/// Matches recharts Tooltip position prop.
pub fn tooltip_position(
  config config: TooltipConfig(msg),
  x x: Float,
  y y: Float,
) -> TooltipConfig(msg) {
  TooltipConfig(
    ..config,
    has_custom_position: True,
    position_x: x,
    position_y: y,
  )
}

/// Allow tooltip to escape the chart boundary on the X axis.
/// Matches recharts Tooltip `allowEscapeViewBox.x` prop (default: False).
pub fn tooltip_allow_escape_x(
  config config: TooltipConfig(msg),
  allow allow: Bool,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, allow_escape_x: allow)
}

/// Allow tooltip to escape the chart boundary on the Y axis.
/// Matches recharts Tooltip `allowEscapeViewBox.y` prop (default: False).
pub fn tooltip_allow_escape_y(
  config config: TooltipConfig(msg),
  allow allow: Bool,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, allow_escape_y: allow)
}

/// Set an item sorter function for tooltip entries.
/// Entries are sorted by the value returned from this function.
/// Matches recharts Tooltip `itemSorter` prop (default: no sorting).
pub fn tooltip_item_sorter(
  config config: TooltipConfig(msg),
  sorter sorter: fn(TooltipEntry) -> Float,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, item_sorter: sorter)
}

/// Include entries from hidden series in the tooltip.
/// Matches recharts Tooltip `includeHidden` prop (default: False).
pub fn tooltip_include_hidden(
  config config: TooltipConfig(msg),
  include include: Bool,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, include_hidden: include)
}

/// Filter null/missing values from tooltip entries.
/// When True (default), entries where the data point lacks a value for the
/// series key are excluded from the tooltip.  When False, all series entries
/// appear even if missing.  Matches recharts Tooltip `filterNull` prop.
pub fn tooltip_filter_null(
  config config: TooltipConfig(msg),
  filter filter: Bool,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, filter_null: filter)
}

/// Set the default active data index for the tooltip.
/// When >= 0, the tooltip for that data index is rendered as if hovered
/// (visible without mouse interaction).  Useful for SSR or initial state.
/// Matches recharts Tooltip `defaultIndex` prop (default: -1 meaning none).
pub fn tooltip_default_index(
  config config: TooltipConfig(msg),
  index index: Int,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, default_index: index)
}

/// Set whether the tooltip shows all series entries for a category.
/// When True (default for cartesian charts), tooltip shows entries from all
/// series at the hovered category.  When False, each tooltip shows only the
/// single hovered series entry.
/// Matches recharts Tooltip `shared` prop (default: True).
pub fn tooltip_shared(
  config config: TooltipConfig(msg),
  shared shared: Bool,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, shared: shared)
}

/// Deduplicate tooltip entries by name.
/// When True, only the first entry for each unique name is kept,
/// removing duplicates from the tooltip payload.
/// Matches recharts Tooltip `payloadUniqBy` prop behavior when set to `name`.
pub fn tooltip_dedup_payload(
  config config: TooltipConfig(msg),
  dedup dedup: Bool,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, dedup_payload: dedup)
}

/// Set the reverse direction for tooltip positioning.
/// When `reverse_x` is True, the tooltip is positioned to the left of the
/// data point.  When `reverse_y` is True, the tooltip is positioned below
/// the data point.  Matches recharts Tooltip `reverseDirection` prop.
pub fn tooltip_reverse_direction(
  config config: TooltipConfig(msg),
  reverse_x reverse_x: Bool,
  reverse_y reverse_y: Bool,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, reverse_x: reverse_x, reverse_y: reverse_y)
}

/// Set a custom content renderer for the tooltip.
/// When set, the function receives the tooltip payload and renders a
/// custom element instead of the default tooltip content.
/// Matches recharts Tooltip `content` prop.
pub fn tooltip_custom_content(
  config config: TooltipConfig(msg),
  renderer renderer: fn(TooltipPayload) -> Element(msg),
) -> TooltipConfig(msg) {
  TooltipConfig(..config, custom_content: Some(renderer))
}

/// Set the tooltip trigger mode.
/// Matches recharts Tooltip `trigger` prop (default: HoverTrigger).
pub fn tooltip_trigger(
  config config: TooltipConfig(msg),
  trigger trigger: TooltipTrigger,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, trigger: trigger)
}

/// Set inline CSS for the tooltip container.
/// Matches recharts Tooltip `contentStyle` prop.
pub fn tooltip_content_style(
  config config: TooltipConfig(msg),
  style style: String,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, content_style: Some(style))
}

/// Set inline CSS for each tooltip item.
/// Matches recharts Tooltip `itemStyle` prop.
pub fn tooltip_item_style(
  config config: TooltipConfig(msg),
  style style: String,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, item_style: Some(style))
}

/// Set inline CSS for the tooltip label.
/// Matches recharts Tooltip `labelStyle` prop.
pub fn tooltip_label_style(
  config config: TooltipConfig(msg),
  style style: String,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, label_style: Some(style))
}

/// Set CSS style string for the outer tooltip wrapper element.
/// Matches recharts Tooltip `wrapperStyle` prop.
pub fn tooltip_wrapper_style(
  config config: TooltipConfig(msg),
  style style: String,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, wrapper_style: style)
}

/// Create a tooltip entry with default hidden=False and entry_type=VisibleEntry.
pub fn tooltip_entry(
  name name: String,
  value value: Float,
  color color: weft.Color,
  unit unit: String,
) -> TooltipEntry {
  TooltipEntry(
    name: name,
    value: value,
    color: color,
    unit: unit,
    hidden: False,
    entry_type: VisibleEntry,
  )
}

/// Set the hidden flag on a tooltip entry.
/// When true, this entry is hidden from the tooltip unless include_hidden is set.
pub fn tooltip_entry_hidden(
  entry entry: TooltipEntry,
  hidden hidden: Bool,
) -> TooltipEntry {
  TooltipEntry(..entry, hidden: hidden)
}

/// Suppress a tooltip entry so it is never rendered.
/// Sets entry_type to NoneEntry, matching recharts payload `type: "none"`.
pub fn tooltip_entry_suppress(entry entry: TooltipEntry) -> TooltipEntry {
  TooltipEntry(..entry, entry_type: NoneEntry)
}

/// Set the CSS transition duration in milliseconds for tooltip animation.
/// Matches recharts Tooltip `animationDuration` prop (default: 400).
pub fn tooltip_animation_duration(
  config config: TooltipConfig(msg),
  duration duration: Int,
) -> TooltipConfig(msg) {
  TooltipConfig(..config, animation_duration: duration)
}

/// Set the state-driven active data index for the tooltip.
/// When `Some(i)`, the tooltip for data point `i` is rendered visible
/// regardless of CSS hover state.  When `None`, visibility falls back
/// to CSS hover or `default_index`.
/// Use with `on_tooltip_enter` / `on_tooltip_leave` for state-driven
/// tooltip control from a Lustre model.
pub fn tooltip_active_index(
  config config: TooltipConfig(msg),
  index index: Option(Int),
) -> TooltipConfig(msg) {
  TooltipConfig(..config, active_index: index)
}

/// Set a handler called when the mouse enters a tooltip hit zone.
/// The handler receives the data point index and should produce a
/// message that updates the model's active index.
/// When `Some`, tooltip visibility is state-driven (by `active_index`)
/// rather than CSS hover.
pub fn tooltip_on_enter(
  config config: TooltipConfig(msg),
  handler handler: Option(fn(Int) -> msg),
) -> TooltipConfig(msg) {
  TooltipConfig(..config, on_tooltip_enter: handler)
}

/// Set a handler called when the mouse leaves a tooltip hit zone.
/// The handler should produce a message that clears the active index.
/// When `Some`, tooltip visibility is state-driven (by `active_index`)
/// rather than CSS hover.
pub fn tooltip_on_leave(
  config config: TooltipConfig(msg),
  handler handler: Option(fn() -> msg),
) -> TooltipConfig(msg) {
  TooltipConfig(..config, on_tooltip_leave: handler)
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render tooltip hit zones and popup content for a list of data points.
/// Render tooltip overlays for a list of payloads.
///
/// `zone_extra_attrs` provides additional attributes (such as click handlers)
/// to merge onto each hit-zone rect.  The list should be parallel to
/// `payloads`: one inner list per payload.  If shorter than `payloads`, the
/// missing entries get no extra attributes.
pub fn render_tooltips(
  config config: TooltipConfig(msg),
  payloads payloads: List(TooltipPayload),
  plot_x plot_x: Float,
  plot_y plot_y: Float,
  plot_width plot_width: Float,
  plot_height plot_height: Float,
  zone_width zone_width: Float,
  zone_mode zone_mode: ZoneMode,
  zone_extra_attrs zone_extra_attrs: List(List(Attribute(msg))),
) -> Element(msg) {
  let tooltip_els =
    list.index_map(payloads, fn(payload, index) {
      let extra = case list_at(zone_extra_attrs, index) {
        Ok(attrs) -> attrs
        Error(_) -> []
      }
      render_single_tooltip(
        config: config,
        payload: payload,
        index: index,
        plot_x: plot_x,
        plot_y: plot_y,
        plot_width: plot_width,
        plot_height: plot_height,
        zone_width: zone_width,
        zone_mode: zone_mode,
        zone_extra_attrs: extra,
      )
    })

  let wrapper_attrs = case config.wrapper_style {
    "" -> [svg.attr("class", "recharts-tooltip-wrapper")]
    style -> [
      svg.attr("class", "recharts-tooltip-wrapper"),
      svg.attr("style", style),
    ]
  }

  svg.g(attrs: wrapper_attrs, children: tooltip_els)
}

fn render_single_tooltip(
  config config: TooltipConfig(msg),
  payload payload: TooltipPayload,
  index index: Int,
  plot_x plot_x: Float,
  plot_y plot_y: Float,
  plot_width plot_width: Float,
  plot_height plot_height: Float,
  zone_width zone_width: Float,
  zone_mode zone_mode: ZoneMode,
  zone_extra_attrs zone_extra_attrs: List(Attribute(msg)),
) -> Element(msg) {
  // Use per-payload zone dimensions when non-zero; fall back to global zone_width.
  let effective_zone_w = case payload.zone_width >. 0.0 {
    True -> payload.zone_width
    False -> zone_width
  }
  let effective_zone_h = case payload.zone_height >. 0.0 {
    True -> payload.zone_height
    False -> effective_zone_w
  }
  let half_zone_w = effective_zone_w /. 2.0
  let half_zone_h = effective_zone_h /. 2.0
  // Compute hit zone bounds by mode.
  let #(zone_actual_x, zone_actual_y, zone_actual_width, zone_actual_height) = case
    zone_mode
  {
    // ColumnZone: full-height vertical strip (line/bar/area).
    ColumnZone -> #(
      payload.x -. half_zone_w,
      plot_y,
      effective_zone_w,
      plot_height,
    )
    // RowZone: full-width horizontal strip (vertical cartesian layout).
    RowZone -> #(plot_x, payload.y -. half_zone_h, plot_width, effective_zone_h)
    // PointZone: small square (or rect) centered on the point.
    PointZone -> #(
      payload.x -. half_zone_w,
      payload.y -. half_zone_h,
      effective_zone_w,
      effective_zone_h,
    )
  }

  // Determine if tooltip is state-driven (event handlers present)
  let is_state_driven = case config.on_tooltip_enter {
    Some(_) -> True
    None -> False
  }

  // Resolve active index for state-driven mode:
  // active_index takes precedence; default_index is fallback.
  let resolved_active_index = case config.active_index {
    Some(i) -> Some(i)
    None ->
      case config.default_index >= 0 {
        True -> Some(config.default_index)
        False -> None
      }
  }

  // Tooltip popup dimensions — estimate width based on content
  let entry_count = list.length(payload.entries)
  let tw = 140.0
  let th = 24.0 +. int.to_float(entry_count) *. 18.0

  let offset_px = int.to_float(config.offset)

  // Popup positioning with independent X/Y escape support.
  // Uses recharts flip-then-clamp strategy: if the tooltip overflows on the
  // preferred side, flip it to the opposite side, then clamp to the plot area.
  let #(tx, ty) = case config.has_custom_position {
    True -> #(config.position_x, config.position_y)
    False -> {
      let tx = case config.allow_escape_x {
        True ->
          case config.reverse_x {
            False -> payload.x +. offset_px
            True -> payload.x -. tw -. offset_px
          }
        False ->
          case config.reverse_x {
            False -> {
              let raw_x = payload.x +. offset_px
              case raw_x +. tw >. plot_x +. plot_width {
                True -> float.max(payload.x -. tw -. offset_px, plot_x)
                False -> float.max(raw_x, plot_x)
              }
            }
            True -> {
              let raw_x = payload.x -. tw -. offset_px
              case raw_x <. plot_x {
                True ->
                  float.min(payload.x +. offset_px, plot_x +. plot_width -. tw)
                False -> float.min(raw_x, plot_x +. plot_width -. tw)
              }
            }
          }
      }
      let ty = case config.allow_escape_y {
        True ->
          case config.reverse_y {
            False -> payload.y +. offset_px
            True -> payload.y -. th -. offset_px
          }
        False ->
          case config.reverse_y {
            False -> {
              let raw_y = payload.y +. offset_px
              case raw_y +. th >. plot_y +. plot_height {
                True -> float.max(payload.y -. th -. offset_px, plot_y)
                False -> float.max(raw_y, plot_y)
              }
            }
            True -> {
              let raw_y = payload.y -. th -. offset_px
              case raw_y <. plot_y {
                True ->
                  float.min(payload.y +. offset_px, plot_y +. plot_height -. th)
                False -> float.min(raw_y, plot_y +. plot_height -. th)
              }
            }
          }
      }
      #(tx, ty)
    }
  }

  // Animation transition CSS
  let transition_css =
    "opacity "
    <> int.to_string(config.animation_duration)
    <> "ms ease, transform "
    <> int.to_string(config.animation_duration)
    <> "ms ease"

  // Build event attributes for hit zone
  let enter_attrs = case config.on_tooltip_enter {
    None -> []
    Some(handler) -> [
      event.on("mouseenter", decode.success(handler(index))),
    ]
  }
  let leave_attrs = case config.on_tooltip_leave {
    None -> []
    Some(handler) -> [
      event.on("mouseleave", decode.success(handler())),
    ]
  }
  let zone_event_attrs = list.flatten([enter_attrs, leave_attrs])

  // Hit zone
  let zone_el =
    svg.rect(
      x: math.fmt(zone_actual_x),
      y: math.fmt(zone_actual_y),
      width: math.fmt(zone_actual_width),
      height: math.fmt(zone_actual_height),
      attrs: list.flatten([
        [
          svg.attr("fill", "transparent"),
          svg.attr("pointer-events", "all"),
          svg.attr("class", "chart-tooltip-zone"),
        ],
        zone_event_attrs,
        zone_extra_attrs,
      ]),
    )

  // Determine visibility: state-driven vs CSS hover
  // When state-driven, only show cursor/dot/popup for active_index match
  let is_active = case is_state_driven {
    True ->
      case resolved_active_index {
        Some(active) -> active == index
        None -> False
      }
    False -> True
  }

  // For CSS-hover mode, optionally force one default hotspot active.
  let is_default_active = case is_state_driven {
    True -> False
    False ->
      case resolved_active_index {
        Some(active) -> active == index
        None -> False
      }
  }

  // Build dasharray attr list (empty when no dasharray configured).
  let dash_attrs = case config.cursor_stroke_dasharray {
    "" -> []
    da -> [svg.attr("stroke-dasharray", da)]
  }

  // Cursor (hidden when state-driven and not active)
  let cursor_el = case config.show_cursor, is_active {
    False, _ -> element.none()
    _, False -> element.none()
    True, True ->
      case config.cursor_type {
        NoCursor -> element.none()
        VerticalCursor ->
          svg.line(
            x1: math.fmt(payload.x),
            y1: math.fmt(plot_y),
            x2: math.fmt(payload.x),
            y2: math.fmt(plot_y +. plot_height),
            attrs: list.flatten([
              [
                svg.attr("stroke", "var(--weft-chart-cursor, #d4d4d8)"),
                svg.attr("stroke-width", "1"),
                svg.attr("class", "chart-tooltip-cursor"),
              ],
              dash_attrs,
            ]),
          )
        HorizontalCursor ->
          svg.line(
            x1: math.fmt(zone_actual_x),
            y1: math.fmt(payload.y),
            x2: math.fmt(zone_actual_x +. zone_actual_width),
            y2: math.fmt(payload.y),
            attrs: list.flatten([
              [
                svg.attr("stroke", "var(--weft-chart-cursor, #d4d4d8)"),
                svg.attr("stroke-width", "1"),
                svg.attr("class", "chart-tooltip-cursor"),
              ],
              dash_attrs,
            ]),
          )
        RectangleCursor ->
          svg.rect(
            x: math.fmt(zone_actual_x),
            y: math.fmt(zone_actual_y),
            width: math.fmt(zone_actual_width),
            height: math.fmt(zone_actual_height),
            attrs: [
              svg.attr("fill", "var(--weft-chart-cursor, #d4d4d8)"),
              svg.attr("opacity", "0.3"),
              svg.attr("class", "chart-tooltip-cursor"),
            ],
          )
        CrossCursor -> {
          // Crosshair: vertical line at payload.x (full plot height) +
          // horizontal line at payload.y (full plot width).
          // Matches recharts Cross component path:
          //   M{x},{top}v{height}M{left},{y}h{width}
          let d =
            "M"
            <> math.fmt(payload.x)
            <> ","
            <> math.fmt(plot_y)
            <> "v"
            <> math.fmt(plot_height)
            <> "M"
            <> math.fmt(plot_x)
            <> ","
            <> math.fmt(payload.y)
            <> "h"
            <> math.fmt(plot_width)
          svg.el(
            tag: "path",
            attrs: list.flatten([
              [
                svg.attr("d", d),
                svg.attr("stroke", "var(--weft-chart-cursor, #ccc)"),
                svg.attr("stroke-width", "1"),
                svg.attr("fill", "none"),
                svg.attr("pointer-events", "none"),
                svg.attr("class", "chart-tooltip-cursor"),
              ],
              dash_attrs,
            ]),
            children: [],
          )
        }
      }
  }

  // Active dots at each series' data point — only when show_active_dot is enabled.
  // Line/area charts set show_active_dot True; bar/pie leave it False.
  // Renders one dot per entry, parallel to payload.active_dots list.
  let dot_els = case config.show_active_dot, is_active {
    True, True ->
      list.filter_map(list.zip(payload.entries, payload.active_dots), fn(pair) {
        let #(entry, dot_y) = pair
        case entry.entry_type {
          NoneEntry -> skip()
          VisibleEntry ->
            include(case zone_mode {
              RowZone ->
                svg.circle(
                  cx: math.fmt(dot_y),
                  cy: math.fmt(payload.y),
                  r: "4",
                  attrs: [
                    svg.attr("fill", weft.color_to_css(color: entry.color)),
                    svg.attr("stroke", "white"),
                    svg.attr("stroke-width", "2"),
                    svg.attr("class", "chart-tooltip-dot"),
                  ],
                )
              _ ->
                svg.circle(
                  cx: math.fmt(payload.x),
                  cy: math.fmt(dot_y),
                  r: "4",
                  attrs: [
                    svg.attr("fill", weft.color_to_css(color: entry.color)),
                    svg.attr("stroke", "white"),
                    svg.attr("stroke-width", "2"),
                    svg.attr("class", "chart-tooltip-dot"),
                  ],
                )
            })
        }
      })
    _, _ -> []
  }

  // Popup content — use custom_content when provided
  let popup_content = case config.custom_content {
    Some(renderer) -> renderer(payload)
    None -> render_default_tooltip_content(config: config, payload: payload)
  }

  // When state-driven, only show popup for active index.
  // When CSS-hover, always render popup (CSS :hover controls visibility).
  let popup_el = case is_active {
    True ->
      svg.el(
        tag: "foreignObject",
        attrs: [
          svg.attr("x", math.fmt(tx)),
          svg.attr("y", math.fmt(ty)),
          svg.attr("width", math.fmt(tw)),
          svg.attr("height", math.fmt(th +. 16.0)),
          svg.attr("pointer-events", "none"),
          svg.attr("class", "chart-tooltip-popup"),
          attribute.style("transition", transition_css),
        ],
        children: [popup_content],
      )
    False ->
      case is_state_driven {
        True -> element.none()
        False ->
          svg.el(
            tag: "foreignObject",
            attrs: [
              svg.attr("x", math.fmt(tx)),
              svg.attr("y", math.fmt(ty)),
              svg.attr("width", math.fmt(tw)),
              svg.attr("height", math.fmt(th +. 16.0)),
              svg.attr("pointer-events", "none"),
              svg.attr("class", "chart-tooltip-popup"),
              attribute.style("transition", transition_css),
            ],
            children: [popup_content],
          )
      }
  }

  svg.g(
    attrs: [
      svg.attr("class", case is_default_active {
        True -> "chart-hotspot chart-default-active"
        False -> "chart-hotspot"
      }),
    ],
    children: list.flatten([
      [zone_el],
      [cursor_el],
      dot_els,
      [popup_el],
    ]),
  )
}

/// Render the default tooltip content with label and entries.
fn render_default_tooltip_content(
  config config: TooltipConfig(msg),
  payload payload: TooltipPayload,
) -> Element(msg) {
  // Filter entries: skip NoneEntry entries, skip hidden entries unless include_hidden
  let visible_entries =
    list.filter(payload.entries, fn(entry) {
      case entry.entry_type {
        NoneEntry -> False
        VisibleEntry ->
          case entry.hidden {
            True -> config.include_hidden
            False -> True
          }
      }
    })

  // Label element with optional label_style
  let label_el = case config.hide_label {
    True -> element.none()
    False -> {
      let label_attrs = [
        attribute.style("font-size", "11px"),
        attribute.style("font-weight", "600"),
        attribute.style("margin-bottom", "4px"),
        attribute.style("color", "var(--weft-chart-tooltip-fg, currentColor)"),
        ..style_attrs(config.label_style)
      ]
      svg.xhtml(tag: "div", attrs: label_attrs, children: [
        element.text(config.label_formatter(payload.label, visible_entries)),
      ])
    }
  }

  // Sort entries using item_sorter
  let sorted_entries =
    list.sort(visible_entries, fn(a, b) {
      float.compare(config.item_sorter(a), config.item_sorter(b))
    })

  // Deduplicate entries by name when configured
  let deduped_entries = case config.dedup_payload {
    False -> sorted_entries
    True -> dedup_entries_by_name(sorted_entries)
  }

  let entry_els =
    list.map(deduped_entries, fn(entry) {
      let indicator_el = case config.hide_indicator {
        True -> element.none()
        False ->
          render_indicator(
            config.indicator,
            weft.color_to_css(color: entry.color),
          )
      }

      let item_attrs = [
        attribute.style("display", "flex"),
        attribute.style("align-items", "center"),
        attribute.style("font-size", "11px"),
        attribute.style("line-height", "1.4"),
        attribute.style("color", weft.color_to_css(color: entry.color)),
        ..style_attrs(config.item_style)
      ]

      svg.xhtml(tag: "div", attrs: item_attrs, children: [
        indicator_el,
        svg.xhtml(tag: "span", attrs: [], children: [
          element.text(entry.name),
        ]),
        svg.xhtml(tag: "span", attrs: [], children: [
          element.text(config.separator),
        ]),
        svg.xhtml(
          tag: "span",
          attrs: [attribute.style("font-weight", "500")],
          children: [
            element.text(
              config.value_formatter(entry.value, entry.name) <> entry.unit,
            ),
          ],
        ),
      ])
    })

  let container_attrs = [
    attribute.style("padding", "8px 10px"),
    attribute.style(
      "border",
      "1px solid var(--weft-chart-tooltip-border, #e4e4e7)",
    ),
    attribute.style("border-radius", "8px"),
    attribute.style("background", "var(--weft-chart-tooltip-bg, #ffffff)"),
    attribute.style("box-shadow", "0 1px 3px rgba(0,0,0,0.1)"),
    ..style_attrs(config.content_style)
  ]

  svg.xhtml(tag: "div", attrs: container_attrs, children: [
    label_el,
    ..entry_els
  ])
}

/// Build style attributes from an optional inline CSS string.
fn style_attrs(style: Option(String)) -> List(attribute.Attribute(msg)) {
  case style {
    None -> []
    Some(css) -> [svg.attr("style", css)]
  }
}

// ---------------------------------------------------------------------------
// Indicator rendering
// ---------------------------------------------------------------------------

/// Render the indicator element for a tooltip entry.
fn render_indicator(indicator: IndicatorType, color: String) -> Element(msg) {
  case indicator {
    DotIndicator ->
      svg.xhtml(
        tag: "span",
        attrs: [
          attribute.style("display", "inline-block"),
          attribute.style("width", "8px"),
          attribute.style("height", "8px"),
          attribute.style("border-radius", "50%"),
          attribute.style("background", color),
          attribute.style("margin-right", "6px"),
          attribute.style("flex-shrink", "0"),
        ],
        children: [],
      )
    LineIndicator ->
      svg.xhtml(
        tag: "span",
        attrs: [
          attribute.style("display", "inline-block"),
          attribute.style("width", "2px"),
          attribute.style("height", "14px"),
          attribute.style("background", color),
          attribute.style("margin-right", "6px"),
          attribute.style("flex-shrink", "0"),
        ],
        children: [],
      )
    DashedIndicator ->
      svg.xhtml(
        tag: "span",
        attrs: [
          attribute.style("display", "inline-block"),
          attribute.style("width", "2px"),
          attribute.style("height", "14px"),
          attribute.style(
            "background",
            "repeating-linear-gradient(to bottom, "
              <> color
              <> " 0px, "
              <> color
              <> " 3px, transparent 3px, transparent 6px)",
          ),
          attribute.style("margin-right", "6px"),
          attribute.style("flex-shrink", "0"),
        ],
        children: [],
      )
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn format_value(value: Float) -> String {
  let rounded = float.round(value)
  case value == int.to_float(rounded) {
    True -> int.to_string(rounded)
    False -> math.fmt(value)
  }
}

/// Deduplicate tooltip entries by name, keeping the first occurrence.
fn dedup_entries_by_name(entries: List(TooltipEntry)) -> List(TooltipEntry) {
  let #(result, _) =
    list.fold(entries, #([], []), fn(acc, entry) {
      let #(kept, seen_names) = acc
      case list.contains(seen_names, entry.name) {
        True -> #(kept, seen_names)
        False -> #(list.append(kept, [entry]), [entry.name, ..seen_names])
      }
    })
  result
}

fn include(value: a) -> Result(a, Nil) {
  Ok(value)
}

fn skip() -> Result(a, Nil) {
  Error(Nil)
}

/// Safe list index access.
fn list_at(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> skip()
    [first, ..], 0 -> include(first)
    [_, ..rest], n if n > 0 -> list_at(rest, n - 1)
    _, _ -> skip()
  }
}
