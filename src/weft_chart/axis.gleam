//// Axis components for cartesian charts.
////
//// XAxis renders tick marks and labels along the horizontal axis.
//// YAxis renders along the vertical axis.  Both produce SVG `<g>`
//// elements containing `<line>` and `<text>` sub-elements.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element.{type Element}
import weft_chart/internal/math
import weft_chart/internal/svg
import weft_chart/render
import weft_chart/scale.{type Scale, type ScaleTick}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Axis type: category (discrete labels) or number (continuous values).
pub type AxisType {
  /// Discrete category labels (e.g. month names).
  CategoryAxis
  /// Continuous numeric values.
  NumberAxis
}

/// Tick interval strategy matching recharts `interval` prop.
///
/// Controls which ticks are visible when there are too many to display
/// without overlap.
pub type AxisInterval {
  /// Show every (N+1)th tick.  `EveryNth(0)` shows all ticks.
  EveryNth(n: Int)
  /// Hide ticks from the end that would collide; always show the first tick.
  PreserveStart
  /// Hide ticks from the start that would collide; always show the last tick.
  /// This is the recharts default.
  PreserveEnd
  /// Always show first and last ticks; hide colliding intermediate ticks.
  PreserveStartEnd
  /// Calculate an equidistant step ensuring the first tick is visible.
  EquidistantPreserveStart
}

/// Scale type for numeric axes.
/// Matches recharts axis `scale` prop.
pub type ScaleType {
  /// Automatically resolved at render time based on axis type.
  /// Currently uses LinearScaleType behavior.
  AutoScaleType
  /// Linear scale (default).
  LinearScaleType
  /// Logarithmic scale with configurable base.
  LogScaleType(base: Float)
  /// Square root scale (power 0.5).
  SqrtScaleType
  /// Power scale with configurable exponent.
  PowerScaleType(exponent: Float)
  /// Time scale for epoch-millisecond domains.
  TimeScaleType
  /// Ordinal scale for discrete category-to-value mappings.
  OrdinalScaleType
  /// Identity scale where output equals input.
  IdentityScaleType
  /// Band scale for grouped bar charts.
  BandScaleType
  /// Point scale for discrete data points.
  PointScaleType
}

/// Tick override allowing either numeric or category string ticks.
/// Used by the `ticks_override` field on axis configs to provide
/// explicit tick values instead of auto-generation.
pub type TickOverride {
  /// Numeric tick values override.
  NumericTicks(ticks: List(Float))
  /// Category/string tick values override.
  CategoryTicks(ticks: List(String))
}

/// Padding mode for category axes.
/// Matches recharts XAxis `padding` prop which accepts either
/// explicit pixel values or the string modes "gap" / "no-gap".
pub type PaddingMode {
  /// Explicit left/right padding in pixels (default: 0, 0).
  ExplicitPadding(left: Int, right: Int)
  /// Automatic gap padding: half the category bandwidth on each side.
  GapPadding
  /// No gap padding (zero on each side).
  NoGapPadding
}

/// Where the axis is positioned relative to the chart.
pub type AxisOrientation {
  /// Top edge (XAxis).
  Top
  /// Bottom edge (XAxis, default).
  Bottom
  /// Left edge (YAxis, default).
  Left
  /// Right edge (YAxis).
  Right
}

/// Axis role used by the additive axis v2 API.
pub type AxisRole {
  /// Horizontal axis role (x-axis semantics).
  XAxisRole
  /// Vertical axis role (y-axis semantics).
  YAxisRole
}

/// Shared axis configuration for the additive axis v2 API.
///
/// Convert to concrete `XAxisConfig`/`YAxisConfig` using `axis_to_x` or
/// `axis_to_y`.
pub type AxisBaseConfig(msg) {
  AxisBaseConfig(
    role: AxisRole,
    data_key: String,
    type_: AxisType,
    orientation: AxisOrientation,
    show_tick_line: Bool,
    show_axis_line: Bool,
    tick_margin: Int,
    tick_count: Int,
    tick_formatter: fn(String, Int) -> String,
    padding_left: Int,
    padding_right: Int,
    padding_top: Int,
    padding_bottom: Int,
    padding: PaddingMode,
    hidden: Bool,
    reversed: Bool,
    mirror: Bool,
    tick_size: Int,
    allow_decimals: Bool,
    angle: Float,
    min_tick_gap: Int,
    ticks_override: Option(TickOverride),
    label: String,
    interval: AxisInterval,
    allow_data_overflow: Bool,
    domain_min: Float,
    domain_max: Float,
    has_custom_domain: Bool,
    unit: String,
    scale_type: ScaleType,
    width: Int,
    height: Int,
    name: String,
    allow_duplicated_category: Bool,
    axis_line_stroke: String,
    axis_line_stroke_width: Float,
    tick_line_stroke: String,
    tick_line_stroke_width: Float,
    axis_line_stroke_dasharray: String,
    tick_line_stroke_dasharray: String,
    axis_id: String,
    custom_tick: Option(fn(render.TickProps) -> Element(msg)),
    include_hidden: Bool,
  )
}

/// Configuration for an x-axis.
pub type XAxisConfig(msg) {
  XAxisConfig(
    data_key: String,
    type_: AxisType,
    orientation: AxisOrientation,
    show_tick_line: Bool,
    show_axis_line: Bool,
    tick_margin: Int,
    tick_count: Int,
    tick_formatter: fn(String, Int) -> String,
    padding_left: Int,
    padding_right: Int,
    padding: PaddingMode,
    hidden: Bool,
    reversed: Bool,
    mirror: Bool,
    tick_size: Int,
    allow_decimals: Bool,
    angle: Float,
    min_tick_gap: Int,
    ticks_override: Option(TickOverride),
    label: String,
    interval: AxisInterval,
    allow_data_overflow: Bool,
    domain_min: Float,
    domain_max: Float,
    has_custom_domain: Bool,
    unit: String,
    scale_type: ScaleType,
    height: Int,
    name: String,
    allow_duplicated_category: Bool,
    axis_line_stroke: String,
    axis_line_stroke_width: Float,
    tick_line_stroke: String,
    tick_line_stroke_width: Float,
    axis_line_stroke_dasharray: String,
    tick_line_stroke_dasharray: String,
    axis_id: String,
    custom_tick: Option(fn(render.TickProps) -> Element(msg)),
    include_hidden: Bool,
  )
}

/// Configuration for a y-axis.
pub type YAxisConfig(msg) {
  YAxisConfig(
    data_key: String,
    type_: AxisType,
    orientation: AxisOrientation,
    show_tick_line: Bool,
    show_axis_line: Bool,
    tick_count: Int,
    tick_formatter: fn(String, Int) -> String,
    domain_min: Float,
    domain_max: Float,
    has_custom_domain: Bool,
    hidden: Bool,
    reversed: Bool,
    mirror: Bool,
    tick_size: Int,
    allow_decimals: Bool,
    tick_margin: Int,
    ticks_override: Option(TickOverride),
    label: String,
    padding_top: Int,
    padding_bottom: Int,
    min_tick_gap: Int,
    angle: Float,
    interval: AxisInterval,
    allow_data_overflow: Bool,
    unit: String,
    scale_type: ScaleType,
    width: Int,
    name: String,
    allow_duplicated_category: Bool,
    axis_line_stroke: String,
    axis_line_stroke_width: Float,
    tick_line_stroke: String,
    tick_line_stroke_width: Float,
    axis_line_stroke_dasharray: String,
    tick_line_stroke_dasharray: String,
    axis_id: String,
    custom_tick: Option(fn(render.TickProps) -> Element(msg)),
    include_hidden: Bool,
  )
}

/// Configuration for a z-axis (size encoding for scatter charts).
/// The z-axis maps data values to a size range for scatter points.
/// Matches recharts ZAxis component defaults: range [64, 64].
pub type ZAxisConfig {
  ZAxisConfig(
    data_key: String,
    range_min: Float,
    range_max: Float,
    name: String,
    unit: String,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a shared axis v2 configuration for the requested role.
pub fn axis_base_config(role role: AxisRole) -> AxisBaseConfig(msg) {
  case role {
    XAxisRole ->
      AxisBaseConfig(
        role: XAxisRole,
        data_key: "category",
        type_: CategoryAxis,
        orientation: Bottom,
        show_tick_line: True,
        show_axis_line: True,
        tick_margin: 2,
        tick_count: 5,
        tick_formatter: fn(v, _i) { v },
        padding_left: 0,
        padding_right: 0,
        padding_top: 0,
        padding_bottom: 0,
        padding: ExplicitPadding(left: 0, right: 0),
        hidden: False,
        reversed: False,
        mirror: False,
        tick_size: 6,
        allow_decimals: True,
        angle: 0.0,
        min_tick_gap: 5,
        ticks_override: None,
        label: "",
        interval: PreserveEnd,
        allow_data_overflow: False,
        domain_min: 0.0,
        domain_max: 0.0,
        has_custom_domain: False,
        unit: "",
        scale_type: LinearScaleType,
        width: 60,
        height: 30,
        name: "",
        allow_duplicated_category: True,
        axis_line_stroke: "",
        axis_line_stroke_width: 0.0,
        tick_line_stroke: "",
        tick_line_stroke_width: 0.0,
        axis_line_stroke_dasharray: "",
        tick_line_stroke_dasharray: "",
        axis_id: "0",
        custom_tick: None,
        include_hidden: False,
      )
    YAxisRole ->
      AxisBaseConfig(
        role: YAxisRole,
        data_key: "",
        type_: NumberAxis,
        orientation: Left,
        show_tick_line: True,
        show_axis_line: True,
        tick_margin: 2,
        tick_count: 5,
        tick_formatter: fn(v, _i) { v },
        padding_left: 0,
        padding_right: 0,
        padding_top: 0,
        padding_bottom: 0,
        padding: ExplicitPadding(left: 0, right: 0),
        hidden: False,
        reversed: False,
        mirror: False,
        tick_size: 6,
        allow_decimals: True,
        angle: 0.0,
        min_tick_gap: 5,
        ticks_override: None,
        label: "",
        interval: PreserveEnd,
        allow_data_overflow: False,
        domain_min: 0.0,
        domain_max: 0.0,
        has_custom_domain: False,
        unit: "",
        scale_type: LinearScaleType,
        width: 60,
        height: 30,
        name: "",
        allow_duplicated_category: True,
        axis_line_stroke: "",
        axis_line_stroke_width: 0.0,
        tick_line_stroke: "",
        tick_line_stroke_width: 0.0,
        axis_line_stroke_dasharray: "",
        tick_line_stroke_dasharray: "",
        axis_id: "0",
        custom_tick: None,
        include_hidden: False,
      )
  }
}

/// Create a shared axis v2 configuration for x-axis semantics.
pub fn x_axis_base_config() -> AxisBaseConfig(msg) {
  axis_base_config(role: XAxisRole)
}

/// Create a shared axis v2 configuration for y-axis semantics.
pub fn y_axis_base_config() -> AxisBaseConfig(msg) {
  axis_base_config(role: YAxisRole)
}

/// Convert a shared v2 axis config into an `XAxisConfig`.
pub fn axis_to_x(config config: AxisBaseConfig(msg)) -> XAxisConfig(msg) {
  XAxisConfig(
    data_key: config.data_key,
    type_: config.type_,
    orientation: config.orientation,
    show_tick_line: config.show_tick_line,
    show_axis_line: config.show_axis_line,
    tick_margin: config.tick_margin,
    tick_count: config.tick_count,
    tick_formatter: config.tick_formatter,
    padding_left: config.padding_left,
    padding_right: config.padding_right,
    padding: config.padding,
    hidden: config.hidden,
    reversed: config.reversed,
    mirror: config.mirror,
    tick_size: config.tick_size,
    allow_decimals: config.allow_decimals,
    angle: config.angle,
    min_tick_gap: config.min_tick_gap,
    ticks_override: config.ticks_override,
    label: config.label,
    interval: config.interval,
    allow_data_overflow: config.allow_data_overflow,
    domain_min: config.domain_min,
    domain_max: config.domain_max,
    has_custom_domain: config.has_custom_domain,
    unit: config.unit,
    scale_type: config.scale_type,
    height: config.height,
    name: config.name,
    allow_duplicated_category: config.allow_duplicated_category,
    axis_line_stroke: config.axis_line_stroke,
    axis_line_stroke_width: config.axis_line_stroke_width,
    tick_line_stroke: config.tick_line_stroke,
    tick_line_stroke_width: config.tick_line_stroke_width,
    axis_line_stroke_dasharray: config.axis_line_stroke_dasharray,
    tick_line_stroke_dasharray: config.tick_line_stroke_dasharray,
    axis_id: config.axis_id,
    custom_tick: config.custom_tick,
    include_hidden: config.include_hidden,
  )
}

/// Convert a shared v2 axis config into a `YAxisConfig`.
pub fn axis_to_y(config config: AxisBaseConfig(msg)) -> YAxisConfig(msg) {
  YAxisConfig(
    data_key: config.data_key,
    type_: config.type_,
    orientation: config.orientation,
    show_tick_line: config.show_tick_line,
    show_axis_line: config.show_axis_line,
    tick_count: config.tick_count,
    tick_formatter: config.tick_formatter,
    domain_min: config.domain_min,
    domain_max: config.domain_max,
    has_custom_domain: config.has_custom_domain,
    hidden: config.hidden,
    reversed: config.reversed,
    mirror: config.mirror,
    tick_size: config.tick_size,
    allow_decimals: config.allow_decimals,
    tick_margin: config.tick_margin,
    ticks_override: config.ticks_override,
    label: config.label,
    padding_top: config.padding_top,
    padding_bottom: config.padding_bottom,
    min_tick_gap: config.min_tick_gap,
    angle: config.angle,
    interval: config.interval,
    allow_data_overflow: config.allow_data_overflow,
    unit: config.unit,
    scale_type: config.scale_type,
    width: config.width,
    name: config.name,
    allow_duplicated_category: config.allow_duplicated_category,
    axis_line_stroke: config.axis_line_stroke,
    axis_line_stroke_width: config.axis_line_stroke_width,
    tick_line_stroke: config.tick_line_stroke,
    tick_line_stroke_width: config.tick_line_stroke_width,
    axis_line_stroke_dasharray: config.axis_line_stroke_dasharray,
    tick_line_stroke_dasharray: config.tick_line_stroke_dasharray,
    axis_id: config.axis_id,
    custom_tick: config.custom_tick,
    include_hidden: config.include_hidden,
  )
}

/// Create a z-axis configuration with default settings.
/// Default range is 64-64 matching recharts ZAxis defaults.
pub fn z_axis_config(data_key data_key: String) -> ZAxisConfig {
  ZAxisConfig(
    data_key: data_key,
    range_min: 64.0,
    range_max: 64.0,
    name: "",
    unit: "",
  )
}

/// Create default x-axis configuration.
pub fn x_axis_config() -> XAxisConfig(msg) {
  axis_to_x(config: x_axis_base_config())
}

/// Create default y-axis configuration.
pub fn y_axis_config() -> YAxisConfig(msg) {
  axis_to_y(config: y_axis_base_config())
}

// ---------------------------------------------------------------------------
// Axis v2 shared builders
// ---------------------------------------------------------------------------

/// Set the data key on a shared v2 axis config.
pub fn axis_data_key(
  config config: AxisBaseConfig(msg),
  key key: String,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, data_key: key)
}

/// Set the axis type on a shared v2 axis config.
pub fn axis_type(
  config config: AxisBaseConfig(msg),
  type_ type_: AxisType,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, type_: type_)
}

/// Set orientation on a shared v2 axis config.
pub fn axis_orientation(
  config config: AxisBaseConfig(msg),
  orientation orientation: AxisOrientation,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, orientation: orientation)
}

/// Show or hide tick lines on a shared v2 axis config.
pub fn axis_tick_line(
  config config: AxisBaseConfig(msg),
  show show: Bool,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, show_tick_line: show)
}

/// Show or hide the main axis line on a shared v2 axis config.
pub fn axis_axis_line(
  config config: AxisBaseConfig(msg),
  show show: Bool,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, show_axis_line: show)
}

/// Set tick margin on a shared v2 axis config.
pub fn axis_tick_margin(
  config config: AxisBaseConfig(msg),
  margin margin: Int,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, tick_margin: margin)
}

/// Set tick count hint on a shared v2 axis config.
pub fn axis_tick_count(
  config config: AxisBaseConfig(msg),
  count count: Int,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, tick_count: count)
}

/// Set tick formatter on a shared v2 axis config.
pub fn axis_tick_formatter(
  config config: AxisBaseConfig(msg),
  formatter formatter: fn(String, Int) -> String,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, tick_formatter: formatter)
}

/// Set padding mode on a shared v2 axis config.
///
/// For x-axis role this updates left/right padding. For y-axis role this
/// keeps mode metadata while y-axis padding remains top/bottom based.
pub fn axis_padding_mode(
  config config: AxisBaseConfig(msg),
  mode mode: PaddingMode,
) -> AxisBaseConfig(msg) {
  case mode {
    ExplicitPadding(left:, right:) ->
      AxisBaseConfig(
        ..config,
        padding: mode,
        padding_left: left,
        padding_right: right,
      )
    GapPadding | NoGapPadding -> AxisBaseConfig(..config, padding: mode)
  }
}

/// Set directional padding on a shared v2 axis config.
///
/// For x-axis role sets left/right. For y-axis role sets top/bottom.
pub fn axis_padding(
  config config: AxisBaseConfig(msg),
  start start: Int,
  end end: Int,
) -> AxisBaseConfig(msg) {
  case config.role {
    XAxisRole ->
      AxisBaseConfig(
        ..config,
        padding_left: start,
        padding_right: end,
        padding: ExplicitPadding(left: start, right: end),
      )
    YAxisRole ->
      AxisBaseConfig(..config, padding_top: start, padding_bottom: end)
  }
}

/// Hide or show a shared v2 axis config.
pub fn axis_hide(
  config config: AxisBaseConfig(msg),
  hide hide: Bool,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, hidden: hide)
}

/// Set reversed direction on a shared v2 axis config.
pub fn axis_reversed(
  config config: AxisBaseConfig(msg),
  reversed reversed: Bool,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, reversed: reversed)
}

/// Set whether mirrored ticks are used on a shared v2 axis config.
pub fn axis_mirror(
  config config: AxisBaseConfig(msg),
  mirror mirror: Bool,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, mirror: mirror)
}

/// Set custom domain on a shared v2 axis config.
pub fn axis_domain(
  config config: AxisBaseConfig(msg),
  min min: Float,
  max max: Float,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(
    ..config,
    domain_min: min,
    domain_max: max,
    has_custom_domain: True,
  )
}

/// Set unit text on a shared v2 axis config.
pub fn axis_unit(
  config config: AxisBaseConfig(msg),
  unit unit: String,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, unit: unit)
}

/// Set label text on a shared v2 axis config.
pub fn axis_label(
  config config: AxisBaseConfig(msg),
  text text: String,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, label: text)
}

/// Set display name on a shared v2 axis config.
pub fn axis_name(
  config config: AxisBaseConfig(msg),
  name name: String,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, name: name)
}

/// Set axis id on a shared v2 axis config.
pub fn axis_id(
  config config: AxisBaseConfig(msg),
  id id: String,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, axis_id: id)
}

/// Set include-hidden behavior on a shared v2 axis config.
pub fn axis_include_hidden(
  config config: AxisBaseConfig(msg),
  include include: Bool,
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, include_hidden: include)
}

/// Set role-aware axis size on a shared v2 axis config.
///
/// For x-axis role this sets `height`. For y-axis role this sets `width`.
pub fn axis_size(
  config config: AxisBaseConfig(msg),
  size size: Int,
) -> AxisBaseConfig(msg) {
  case config.role {
    XAxisRole -> AxisBaseConfig(..config, height: size)
    YAxisRole -> AxisBaseConfig(..config, width: size)
  }
}

/// Set custom tick renderer on a shared v2 axis config.
pub fn axis_custom_tick(
  config config: AxisBaseConfig(msg),
  renderer renderer: fn(render.TickProps) -> Element(msg),
) -> AxisBaseConfig(msg) {
  AxisBaseConfig(..config, custom_tick: Some(renderer))
}

// ---------------------------------------------------------------------------
// XAxis builders
// ---------------------------------------------------------------------------

/// Set the data key for the x-axis.
pub fn x_data_key(config: XAxisConfig(msg), key: String) -> XAxisConfig(msg) {
  XAxisConfig(..config, data_key: key)
}

/// Set the axis type.
pub fn x_type(config: XAxisConfig(msg), type_: AxisType) -> XAxisConfig(msg) {
  XAxisConfig(..config, type_: type_)
}

/// Set the axis orientation.
pub fn x_orientation(
  config: XAxisConfig(msg),
  orientation: AxisOrientation,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, orientation: orientation)
}

/// Show or hide tick lines.
pub fn x_tick_line(config: XAxisConfig(msg), show: Bool) -> XAxisConfig(msg) {
  XAxisConfig(..config, show_tick_line: show)
}

/// Show or hide the axis line.
pub fn x_axis_line(config: XAxisConfig(msg), show: Bool) -> XAxisConfig(msg) {
  XAxisConfig(..config, show_axis_line: show)
}

/// Set the tick margin (distance from axis to label).
pub fn x_tick_margin(config: XAxisConfig(msg), margin: Int) -> XAxisConfig(msg) {
  XAxisConfig(..config, tick_margin: margin)
}

/// Set the tick count hint.
pub fn x_tick_count(config: XAxisConfig(msg), count: Int) -> XAxisConfig(msg) {
  XAxisConfig(..config, tick_count: count)
}

/// Set a tick label formatter function.
/// The formatter receives the tick value and its zero-based index.
pub fn x_tick_formatter(
  config: XAxisConfig(msg),
  formatter: fn(String, Int) -> String,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, tick_formatter: formatter)
}

/// Set horizontal padding with explicit pixel values.
/// Backward-compatible builder; sets both the legacy `padding_left`/`padding_right`
/// fields and the `padding` mode to `ExplicitPadding`.
pub fn x_padding(
  config: XAxisConfig(msg),
  left: Int,
  right: Int,
) -> XAxisConfig(msg) {
  XAxisConfig(
    ..config,
    padding_left: left,
    padding_right: right,
    padding: ExplicitPadding(left: left, right: right),
  )
}

/// Set the padding mode for the x-axis.
/// Accepts `ExplicitPadding(left, right)`, `GapPadding`, or `NoGapPadding`.
/// `GapPadding` resolves to half the category bandwidth on each side.
/// `NoGapPadding` resolves to zero padding.
/// Matches recharts XAxis `padding` prop string modes ("gap" / "no-gap").
pub fn x_padding_mode(
  config: XAxisConfig(msg),
  mode: PaddingMode,
) -> XAxisConfig(msg) {
  case mode {
    ExplicitPadding(left:, right:) ->
      XAxisConfig(
        ..config,
        padding: mode,
        padding_left: left,
        padding_right: right,
      )
    GapPadding | NoGapPadding -> XAxisConfig(..config, padding: mode)
  }
}

/// Hide the axis entirely.
pub fn x_hide(config: XAxisConfig(msg)) -> XAxisConfig(msg) {
  XAxisConfig(..config, hidden: True)
}

/// Reverse the x-axis direction.
pub fn x_reversed(config: XAxisConfig(msg)) -> XAxisConfig(msg) {
  XAxisConfig(..config, reversed: True)
}

/// Mirror x-axis ticks to the opposite side.
pub fn x_mirror(config: XAxisConfig(msg)) -> XAxisConfig(msg) {
  XAxisConfig(..config, mirror: True)
}

/// Set the tick line size in pixels.
pub fn x_tick_size(config: XAxisConfig(msg), size: Int) -> XAxisConfig(msg) {
  XAxisConfig(..config, tick_size: size)
}

/// Set whether to allow decimal values in axis ticks.
pub fn x_allow_decimals(
  config: XAxisConfig(msg),
  allow: Bool,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, allow_decimals: allow)
}

/// Set the rotation angle for tick labels in degrees.
pub fn x_angle(config: XAxisConfig(msg), angle: Float) -> XAxisConfig(msg) {
  XAxisConfig(..config, angle: angle)
}

/// Set the minimum gap between ticks in pixels.
pub fn x_min_tick_gap(config: XAxisConfig(msg), gap: Int) -> XAxisConfig(msg) {
  XAxisConfig(..config, min_tick_gap: gap)
}

/// Set explicit numeric tick values, overriding auto-generation.
/// Matches recharts XAxis `ticks` prop with numeric values.
pub fn x_numeric_ticks(
  config: XAxisConfig(msg),
  ticks ts: List(Float),
) -> XAxisConfig(msg) {
  XAxisConfig(..config, ticks_override: Some(NumericTicks(ticks: ts)))
}

/// Set explicit category tick values, overriding auto-generation.
/// Matches recharts XAxis `ticks` prop with string values.
pub fn x_category_ticks(
  config: XAxisConfig(msg),
  ticks ts: List(String),
) -> XAxisConfig(msg) {
  XAxisConfig(..config, ticks_override: Some(CategoryTicks(ticks: ts)))
}

/// Set the axis label text.
/// Matches recharts XAxis `label` prop (string form).
pub fn x_label(config: XAxisConfig(msg), text: String) -> XAxisConfig(msg) {
  XAxisConfig(..config, label: text)
}

/// Set the tick interval strategy.
/// Matches recharts XAxis `interval` prop (default: preserveEnd).
pub fn x_interval(
  config: XAxisConfig(msg),
  interval: AxisInterval,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, interval: interval)
}

/// Allow data to overflow the axis domain without extending it.
/// Matches recharts XAxis `allowDataOverflow` prop (default: false).
pub fn x_allow_data_overflow(
  config: XAxisConfig(msg),
  allow: Bool,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, allow_data_overflow: allow)
}

/// Set a custom domain for the x-axis (numeric axes only).
/// Matches recharts XAxis `domain` prop.
pub fn x_domain(
  config: XAxisConfig(msg),
  min: Float,
  max: Float,
) -> XAxisConfig(msg) {
  XAxisConfig(
    ..config,
    domain_min: min,
    domain_max: max,
    has_custom_domain: True,
  )
}

/// Set the unit string appended to tick labels.
/// Matches recharts XAxis `unit` prop (default: "").
pub fn x_unit(config: XAxisConfig(msg), unit: String) -> XAxisConfig(msg) {
  XAxisConfig(..config, unit: unit)
}

/// Set the scale type for the x-axis.
/// Matches recharts XAxis `scale` prop (default: linear).
pub fn x_scale_type(
  config: XAxisConfig(msg),
  type_: ScaleType,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, scale_type: type_)
}

/// Set the height of the x-axis area in pixels.
/// Matches recharts XAxis `height` prop (default: 30).
/// Controls how much vertical space is reserved for the axis.
pub fn x_height(config: XAxisConfig(msg), height: Int) -> XAxisConfig(msg) {
  XAxisConfig(..config, height: height)
}

/// Set the name for tooltip display.
/// Matches recharts XAxis `name` prop.  Used when the tooltip
/// references this axis.  When empty (default), the data key is used.
pub fn x_name(config: XAxisConfig(msg), name: String) -> XAxisConfig(msg) {
  XAxisConfig(..config, name: name)
}

/// Set whether duplicate categories are allowed on the x-axis.
/// Matches recharts XAxis `allowDuplicatedCategory` prop (default: true).
pub fn x_allow_duplicated_category(
  config: XAxisConfig(msg),
  allow: Bool,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, allow_duplicated_category: allow)
}

/// Set a custom stroke color for the x-axis line.
/// When non-empty, overrides the default CSS variable.
pub fn x_axis_line_stroke(
  config: XAxisConfig(msg),
  stroke: String,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, axis_line_stroke: stroke)
}

/// Set a custom stroke width for the x-axis line.
/// When > 0, overrides the default width.
pub fn x_axis_line_stroke_width(
  config: XAxisConfig(msg),
  width: Float,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, axis_line_stroke_width: width)
}

/// Set a custom stroke color for x-axis tick lines.
/// When non-empty, overrides the default CSS variable.
pub fn x_tick_line_stroke(
  config: XAxisConfig(msg),
  stroke: String,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, tick_line_stroke: stroke)
}

/// Set a custom stroke width for x-axis tick lines.
/// When > 0, overrides the default width.
pub fn x_tick_line_stroke_width(
  config: XAxisConfig(msg),
  width: Float,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, tick_line_stroke_width: width)
}

/// Set the stroke dash pattern for the x-axis line.
/// Matches recharts XAxis `axisLine.strokeDasharray` prop.
/// When non-empty, applies `stroke-dasharray` to the axis line SVG element.
pub fn x_axis_line_stroke_dasharray(
  config: XAxisConfig(msg),
  pattern: String,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, axis_line_stroke_dasharray: pattern)
}

/// Set the stroke dash pattern for x-axis tick lines.
/// Matches recharts XAxis `tickLine.strokeDasharray` prop.
/// When non-empty, applies `stroke-dasharray` to each tick line SVG element.
pub fn x_tick_line_stroke_dasharray(
  config: XAxisConfig(msg),
  pattern: String,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, tick_line_stroke_dasharray: pattern)
}

/// Set the axis ID for the x-axis.
/// Matches recharts XAxis `xAxisId` prop (default: "0").
/// Used for multi-axis support: series and reference elements
/// bind to a specific axis via matching IDs.
pub fn x_axis_id(config: XAxisConfig(msg), id: String) -> XAxisConfig(msg) {
  XAxisConfig(..config, axis_id: id)
}

/// Set a custom tick render function for the x-axis.
/// When provided, replaces the default text label for each tick.
/// Matches recharts XAxis `tick` prop (element/function form).
pub fn x_custom_tick(
  config config: XAxisConfig(msg),
  renderer renderer: fn(render.TickProps) -> Element(msg),
) -> XAxisConfig(msg) {
  XAxisConfig(..config, custom_tick: Some(renderer))
}

/// Set whether hidden series data is included in axis domain computation.
/// When True, hidden series still contribute to the axis range.
/// Matches recharts XAxis `includeHidden` prop (default: false).
pub fn x_include_hidden(
  config config: XAxisConfig(msg),
  include include: Bool,
) -> XAxisConfig(msg) {
  XAxisConfig(..config, include_hidden: include)
}

// ---------------------------------------------------------------------------
// YAxis builders
// ---------------------------------------------------------------------------

/// Set the data key for the y-axis.
pub fn y_data_key(config: YAxisConfig(msg), key: String) -> YAxisConfig(msg) {
  YAxisConfig(..config, data_key: key)
}

/// Set the axis type.
pub fn y_type(config: YAxisConfig(msg), type_: AxisType) -> YAxisConfig(msg) {
  YAxisConfig(..config, type_: type_)
}

/// Set the axis orientation.
pub fn y_orientation(
  config: YAxisConfig(msg),
  orientation: AxisOrientation,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, orientation: orientation)
}

/// Show or hide tick lines.
pub fn y_tick_line(config: YAxisConfig(msg), show: Bool) -> YAxisConfig(msg) {
  YAxisConfig(..config, show_tick_line: show)
}

/// Show or hide the axis line.
pub fn y_axis_line(config: YAxisConfig(msg), show: Bool) -> YAxisConfig(msg) {
  YAxisConfig(..config, show_axis_line: show)
}

/// Set the tick count hint.
pub fn y_tick_count(config: YAxisConfig(msg), count: Int) -> YAxisConfig(msg) {
  YAxisConfig(..config, tick_count: count)
}

/// Set a tick label formatter function.
/// The formatter receives the tick value and its zero-based index.
pub fn y_tick_formatter(
  config: YAxisConfig(msg),
  formatter: fn(String, Int) -> String,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, tick_formatter: formatter)
}

/// Set a custom domain for the y-axis.
pub fn y_domain(
  config: YAxisConfig(msg),
  min: Float,
  max: Float,
) -> YAxisConfig(msg) {
  YAxisConfig(
    ..config,
    domain_min: min,
    domain_max: max,
    has_custom_domain: True,
  )
}

/// Hide the axis entirely.
pub fn y_hide(config: YAxisConfig(msg)) -> YAxisConfig(msg) {
  YAxisConfig(..config, hidden: True)
}

/// Reverse the y-axis direction.
pub fn y_reversed(config: YAxisConfig(msg)) -> YAxisConfig(msg) {
  YAxisConfig(..config, reversed: True)
}

/// Mirror y-axis ticks to the opposite side.
pub fn y_mirror(config: YAxisConfig(msg)) -> YAxisConfig(msg) {
  YAxisConfig(..config, mirror: True)
}

/// Set the tick line size in pixels.
pub fn y_tick_size(config: YAxisConfig(msg), size: Int) -> YAxisConfig(msg) {
  YAxisConfig(..config, tick_size: size)
}

/// Set whether to allow decimal values in axis ticks.
pub fn y_allow_decimals(
  config: YAxisConfig(msg),
  allow: Bool,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, allow_decimals: allow)
}

/// Set the tick margin (distance from axis to label).
pub fn y_tick_margin(config: YAxisConfig(msg), margin: Int) -> YAxisConfig(msg) {
  YAxisConfig(..config, tick_margin: margin)
}

/// Set explicit numeric tick values, overriding auto-generation.
/// Matches recharts YAxis `ticks` prop with numeric values.
pub fn y_numeric_ticks(
  config: YAxisConfig(msg),
  ticks ts: List(Float),
) -> YAxisConfig(msg) {
  YAxisConfig(..config, ticks_override: Some(NumericTicks(ticks: ts)))
}

/// Set explicit category tick values, overriding auto-generation.
/// Matches recharts YAxis `ticks` prop with string values.
pub fn y_category_ticks(
  config: YAxisConfig(msg),
  ticks ts: List(String),
) -> YAxisConfig(msg) {
  YAxisConfig(..config, ticks_override: Some(CategoryTicks(ticks: ts)))
}

/// Set top padding for the y-axis in pixels.
/// Matches recharts YAxis `padding.top` prop (default: 0).
pub fn y_padding_top(config: YAxisConfig(msg), padding: Int) -> YAxisConfig(msg) {
  YAxisConfig(..config, padding_top: padding)
}

/// Set bottom padding for the y-axis in pixels.
/// Matches recharts YAxis `padding.bottom` prop (default: 0).
pub fn y_padding_bottom(
  config: YAxisConfig(msg),
  padding: Int,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, padding_bottom: padding)
}

/// Set the minimum gap between ticks in pixels.
/// Matches recharts CartesianAxis `minTickGap` (default: 5).
pub fn y_min_tick_gap(config: YAxisConfig(msg), gap: Int) -> YAxisConfig(msg) {
  YAxisConfig(..config, min_tick_gap: gap)
}

/// Set the rotation angle for tick labels in degrees.
/// Matches recharts YAxis `angle` prop (default: 0.0).
pub fn y_angle(config: YAxisConfig(msg), angle: Float) -> YAxisConfig(msg) {
  YAxisConfig(..config, angle: angle)
}

/// Set the axis label text.
/// Matches recharts YAxis `label` prop (string form).
pub fn y_label(config: YAxisConfig(msg), text: String) -> YAxisConfig(msg) {
  YAxisConfig(..config, label: text)
}

/// Set the tick interval strategy.
/// Matches recharts YAxis `interval` prop (default: preserveEnd).
pub fn y_interval(
  config: YAxisConfig(msg),
  interval: AxisInterval,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, interval: interval)
}

/// Allow data to overflow the axis domain without extending it.
/// Matches recharts YAxis `allowDataOverflow` prop (default: false).
pub fn y_allow_data_overflow(
  config: YAxisConfig(msg),
  allow: Bool,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, allow_data_overflow: allow)
}

/// Set the unit string appended to tick labels.
/// Matches recharts YAxis `unit` prop (default: "").
pub fn y_unit(config: YAxisConfig(msg), unit: String) -> YAxisConfig(msg) {
  YAxisConfig(..config, unit: unit)
}

/// Set the scale type for the y-axis.
/// Matches recharts YAxis `scale` prop (default: linear).
pub fn y_scale_type(
  config: YAxisConfig(msg),
  type_: ScaleType,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, scale_type: type_)
}

/// Set the width of the y-axis area in pixels.
/// Matches recharts YAxis `width` prop (default: 60).
/// Controls how much horizontal space is reserved for the axis.
pub fn y_width(config: YAxisConfig(msg), width: Int) -> YAxisConfig(msg) {
  YAxisConfig(..config, width: width)
}

/// Set the name for tooltip display.
/// Matches recharts YAxis `name` prop.  Used when the tooltip
/// references this axis.  When empty (default), the data key is used.
pub fn y_name(config: YAxisConfig(msg), name: String) -> YAxisConfig(msg) {
  YAxisConfig(..config, name: name)
}

/// Set whether duplicate categories are allowed on the y-axis.
/// Matches recharts YAxis `allowDuplicatedCategory` prop (default: true).
pub fn y_allow_duplicated_category(
  config: YAxisConfig(msg),
  allow: Bool,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, allow_duplicated_category: allow)
}

/// Set a custom stroke color for the y-axis line.
/// When non-empty, overrides the default CSS variable.
pub fn y_axis_line_stroke(
  config: YAxisConfig(msg),
  stroke: String,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, axis_line_stroke: stroke)
}

/// Set a custom stroke width for the y-axis line.
/// When > 0, overrides the default width.
pub fn y_axis_line_stroke_width(
  config: YAxisConfig(msg),
  width: Float,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, axis_line_stroke_width: width)
}

/// Set a custom stroke color for y-axis tick lines.
/// When non-empty, overrides the default CSS variable.
pub fn y_tick_line_stroke(
  config: YAxisConfig(msg),
  stroke: String,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, tick_line_stroke: stroke)
}

/// Set a custom stroke width for y-axis tick lines.
/// When > 0, overrides the default width.
pub fn y_tick_line_stroke_width(
  config: YAxisConfig(msg),
  width: Float,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, tick_line_stroke_width: width)
}

/// Set the stroke dash pattern for the y-axis line.
/// Matches recharts YAxis `axisLine.strokeDasharray` prop.
/// When non-empty, applies `stroke-dasharray` to the axis line SVG element.
pub fn y_axis_line_stroke_dasharray(
  config: YAxisConfig(msg),
  pattern: String,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, axis_line_stroke_dasharray: pattern)
}

/// Set the stroke dash pattern for y-axis tick lines.
/// Matches recharts YAxis `tickLine.strokeDasharray` prop.
/// When non-empty, applies `stroke-dasharray` to each tick line SVG element.
pub fn y_tick_line_stroke_dasharray(
  config: YAxisConfig(msg),
  pattern: String,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, tick_line_stroke_dasharray: pattern)
}

/// Set the axis ID for the y-axis.
/// Matches recharts YAxis `yAxisId` prop (default: "0").
/// Used for multi-axis support: series and reference elements
/// bind to a specific axis via matching IDs.
pub fn y_axis_id(config: YAxisConfig(msg), id: String) -> YAxisConfig(msg) {
  YAxisConfig(..config, axis_id: id)
}

/// Set a custom tick render function for the y-axis.
/// When provided, replaces the default text label for each tick.
/// Matches recharts YAxis `tick` prop (element/function form).
pub fn y_custom_tick(
  config config: YAxisConfig(msg),
  renderer renderer: fn(render.TickProps) -> Element(msg),
) -> YAxisConfig(msg) {
  YAxisConfig(..config, custom_tick: Some(renderer))
}

/// Set whether hidden series data is included in axis domain computation.
/// When True, hidden series still contribute to the axis range.
/// Matches recharts YAxis `includeHidden` prop (default: false).
pub fn y_include_hidden(
  config config: YAxisConfig(msg),
  include include: Bool,
) -> YAxisConfig(msg) {
  YAxisConfig(..config, include_hidden: include)
}

// ---------------------------------------------------------------------------
// ZAxis builders
// ---------------------------------------------------------------------------

/// Set the size range for z-axis mapping.
/// Scatter point sizes will be linearly interpolated between min and max.
pub fn z_range(
  config config: ZAxisConfig,
  min min: Float,
  max max: Float,
) -> ZAxisConfig {
  ZAxisConfig(..config, range_min: min, range_max: max)
}

/// Set the display name for the z-axis.
pub fn z_name(config config: ZAxisConfig, name name: String) -> ZAxisConfig {
  ZAxisConfig(..config, name: name)
}

/// Set the unit string for the z-axis.
pub fn z_unit(config config: ZAxisConfig, unit unit: String) -> ZAxisConfig {
  ZAxisConfig(..config, unit: unit)
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render an x-axis from its configuration and a computed scale.
pub fn render_x_axis(
  config config: XAxisConfig(msg),
  x_scale x_scale: Scale,
  plot_y plot_y: Float,
  plot_height plot_height: Float,
) -> Element(msg) {
  case config.hidden {
    True -> element.none()
    False -> {
      let axis_y = case config.orientation {
        Bottom -> plot_y +. plot_height
        _ -> plot_y
      }

      let raw_ticks = case config.ticks_override {
        None -> scale.ticks(x_scale, config.tick_count, config.allow_decimals)
        Some(NumericTicks(ticks: ts)) ->
          list.map(ts, fn(v) {
            scale.ScaleTick(
              value: format_tick_value(v),
              coordinate: scale.linear_apply(x_scale, v),
            )
          })
        Some(CategoryTicks(ticks: ts)) -> {
          let #(rs, re) = scale_range(x_scale)
          category_tick_coords(ts, rs, re)
        }
      }
      let tick_list =
        filter_by_interval(raw_ticks, config.interval, config.min_tick_gap)
      let tick_dir = case config.orientation {
        Bottom -> 1.0
        _ -> -1.0
      }

      let axis_line_el = case config.show_axis_line {
        False -> element.none()
        True -> {
          let ticks_first_x = case tick_list {
            [first, ..] -> first.coordinate
            [] -> 0.0
          }
          let ticks_last_x = case list.last(tick_list) {
            Ok(last) -> last.coordinate
            Error(_) -> 0.0
          }
          let al_stroke = case config.axis_line_stroke {
            "" -> "var(--weft-chart-axis, currentColor)"
            s -> s
          }
          let al_stroke_width = case config.axis_line_stroke_width >. 0.0 {
            True -> math.fmt(config.axis_line_stroke_width)
            False -> "1"
          }
          let al_dash_attrs = case config.axis_line_stroke_dasharray {
            "" -> []
            pattern -> [svg.attr("stroke-dasharray", pattern)]
          }
          svg.line(
            x1: math.fmt(ticks_first_x),
            y1: math.fmt(axis_y),
            x2: math.fmt(ticks_last_x),
            y2: math.fmt(axis_y),
            attrs: list.flatten([
              [
                svg.attr("stroke", al_stroke),
                svg.attr("stroke-width", al_stroke_width),
              ],
              al_dash_attrs,
            ]),
          )
        }
      }

      let visible_count = list.length(tick_list)
      let tick_els =
        list.index_map(tick_list, fn(tick, idx) {
          render_x_tick(
            tick: tick,
            config: config,
            axis_y: axis_y,
            tick_dir: tick_dir,
            tick_index: idx,
            visible_count: visible_count,
          )
        })

      let label_el = case config.label {
        "" -> element.none()
        text -> {
          let first_x = case tick_list {
            [first, ..] -> first.coordinate
            [] -> 0.0
          }
          let last_x = case list.last(tick_list) {
            Ok(last) -> last.coordinate
            Error(_) -> 0.0
          }
          let center_x = { first_x +. last_x } /. 2.0
          let label_y_offset =
            int.to_float(config.tick_size + config.tick_margin + 20) *. tick_dir
          svg.text(
            x: math.fmt(center_x),
            y: math.fmt(axis_y +. label_y_offset),
            content: text,
            attrs: [
              svg.attr("text-anchor", "middle"),
              svg.attr("font-size", "12"),
              svg.attr("fill", "var(--weft-chart-axis-label, currentColor)"),
            ],
          )
        }
      }

      svg.g(
        attrs: [svg.attr("class", "recharts-xAxis")],
        children: list.flatten([[axis_line_el], tick_els, [label_el]]),
      )
    }
  }
}

fn render_x_tick(
  tick tick: ScaleTick,
  config config: XAxisConfig(msg),
  axis_y axis_y: Float,
  tick_dir tick_dir: Float,
  tick_index tick_index: Int,
  visible_count visible_count: Int,
) -> Element(msg) {
  let label = config.tick_formatter(tick.value, tick_index) <> config.unit
  let effective_tick_dir = case config.mirror {
    True -> float.negate(tick_dir)
    False -> tick_dir
  }
  let tick_size_f = int.to_float(config.tick_size)
  let tl_stroke = case config.tick_line_stroke {
    "" -> "var(--weft-chart-tick, currentColor)"
    s -> s
  }
  let tl_stroke_width = case config.tick_line_stroke_width >. 0.0 {
    True -> math.fmt(config.tick_line_stroke_width)
    False -> "1"
  }
  let tl_dash_attrs = case config.tick_line_stroke_dasharray {
    "" -> []
    pattern -> [svg.attr("stroke-dasharray", pattern)]
  }
  let tick_line_el = case config.show_tick_line {
    False -> element.none()
    True ->
      svg.line(
        x1: math.fmt(tick.coordinate),
        y1: math.fmt(axis_y),
        x2: math.fmt(tick.coordinate),
        y2: math.fmt(axis_y +. tick_size_f *. effective_tick_dir),
        attrs: list.flatten([
          [
            svg.attr("stroke", tl_stroke),
            svg.attr("stroke-width", tl_stroke_width),
          ],
          tl_dash_attrs,
        ]),
      )
  }

  let margin_offset = int.to_float(config.tick_margin) *. effective_tick_dir
  let tick_offset = tick_size_f *. effective_tick_dir
  let label_y = axis_y +. margin_offset +. tick_offset
  let text_el = case config.custom_tick {
    Some(renderer) -> {
      let props =
        render.TickProps(
          x: tick.coordinate,
          y: label_y,
          index: tick_index,
          value: label,
          text_anchor: "middle",
          vertical_anchor: case config.orientation {
            Bottom -> "start"
            _ -> "end"
          },
          fill: "var(--weft-chart-tick-text, currentColor)",
          visible_ticks_count: visible_count,
        )
      renderer(props)
    }
    None -> {
      let rotation_attrs = case config.angle == 0.0 {
        True -> []
        False -> {
          let transform_value =
            "rotate("
            <> math.fmt(config.angle)
            <> ", "
            <> math.fmt(tick.coordinate)
            <> ", "
            <> math.fmt(label_y)
            <> ")"
          [svg.attr("transform", transform_value)]
        }
      }
      // Use dominant-baseline="hanging" for Bottom so the text top sits at
      // label_y (matching recharts verticalAnchor="start" behaviour).
      // For Top orientation the tick is above the axis; default baseline
      // places the text baseline at label_y so text extends upward correctly.
      let baseline = case config.orientation {
        Bottom -> "hanging"
        _ -> "auto"
      }
      svg.text(
        x: math.fmt(tick.coordinate),
        y: math.fmt(label_y),
        content: label,
        attrs: list.flatten([
          [
            svg.attr("text-anchor", "middle"),
            svg.attr("dominant-baseline", baseline),
            svg.attr("font-size", "12"),
            svg.attr("fill", "var(--weft-chart-tick-text, currentColor)"),
          ],
          rotation_attrs,
        ]),
      )
    }
  }

  svg.g(attrs: [], children: [tick_line_el, text_el])
}

/// Render a y-axis from its configuration and a computed scale.
pub fn render_y_axis(
  config config: YAxisConfig(msg),
  y_scale y_scale: Scale,
  plot_x plot_x: Float,
  plot_width plot_width: Float,
) -> Element(msg) {
  case config.hidden {
    True -> element.none()
    False -> {
      let axis_x = case config.orientation {
        Left -> plot_x
        _ -> plot_x +. plot_width
      }

      let raw_ticks = case config.ticks_override {
        None -> scale.ticks(y_scale, config.tick_count, config.allow_decimals)
        Some(NumericTicks(ticks: ts)) ->
          list.map(ts, fn(v) {
            scale.ScaleTick(
              value: format_tick_value(v),
              coordinate: scale.apply(y_scale, v),
            )
          })
        Some(CategoryTicks(ticks: ts)) -> {
          let #(rs, re) = scale_range(y_scale)
          category_tick_coords(ts, rs, re)
        }
      }
      let tick_list =
        filter_by_interval(raw_ticks, config.interval, config.min_tick_gap)
      let tick_dir = case config.orientation {
        Left -> -1.0
        _ -> 1.0
      }

      let axis_line_el = case config.show_axis_line {
        False -> element.none()
        True -> {
          let ticks_first_y = case tick_list {
            [first, ..] -> first.coordinate
            [] -> 0.0
          }
          let ticks_last_y = case list.last(tick_list) {
            Ok(last) -> last.coordinate
            Error(_) -> 0.0
          }
          let al_stroke = case config.axis_line_stroke {
            "" -> "var(--weft-chart-axis, currentColor)"
            s -> s
          }
          let al_stroke_width = case config.axis_line_stroke_width >. 0.0 {
            True -> math.fmt(config.axis_line_stroke_width)
            False -> "1"
          }
          let al_dash_attrs = case config.axis_line_stroke_dasharray {
            "" -> []
            pattern -> [svg.attr("stroke-dasharray", pattern)]
          }
          svg.line(
            x1: math.fmt(axis_x),
            y1: math.fmt(ticks_first_y),
            x2: math.fmt(axis_x),
            y2: math.fmt(ticks_last_y),
            attrs: list.flatten([
              [
                svg.attr("stroke", al_stroke),
                svg.attr("stroke-width", al_stroke_width),
              ],
              al_dash_attrs,
            ]),
          )
        }
      }

      let visible_count = list.length(tick_list)
      let tick_els =
        list.index_map(tick_list, fn(tick, idx) {
          render_y_tick(
            tick: tick,
            config: config,
            axis_x: axis_x,
            tick_dir: tick_dir,
            tick_index: idx,
            visible_count: visible_count,
          )
        })

      let label_el = case config.label {
        "" -> element.none()
        text -> {
          let first_y = case tick_list {
            [first, ..] -> first.coordinate
            [] -> 0.0
          }
          let last_y = case list.last(tick_list) {
            Ok(last) -> last.coordinate
            Error(_) -> 0.0
          }
          let center_y = { first_y +. last_y } /. 2.0
          let label_x_offset =
            int.to_float(config.tick_size + config.tick_margin + 30) *. tick_dir
          let lx = axis_x +. label_x_offset
          svg.text(
            x: math.fmt(lx),
            y: math.fmt(center_y),
            content: text,
            attrs: [
              svg.attr("text-anchor", "middle"),
              svg.attr("font-size", "12"),
              svg.attr("fill", "var(--weft-chart-axis-label, currentColor)"),
              svg.attr(
                "transform",
                "rotate(-90, "
                  <> math.fmt(lx)
                  <> ", "
                  <> math.fmt(center_y)
                  <> ")",
              ),
            ],
          )
        }
      }

      svg.g(
        attrs: [svg.attr("class", "recharts-yAxis")],
        children: list.flatten([[axis_line_el], tick_els, [label_el]]),
      )
    }
  }
}

fn render_y_tick(
  tick tick: ScaleTick,
  config config: YAxisConfig(msg),
  axis_x axis_x: Float,
  tick_dir tick_dir: Float,
  tick_index tick_index: Int,
  visible_count visible_count: Int,
) -> Element(msg) {
  let label = config.tick_formatter(tick.value, tick_index) <> config.unit
  let effective_tick_dir = case config.mirror {
    True -> float.negate(tick_dir)
    False -> tick_dir
  }
  let tick_size_f = int.to_float(config.tick_size)
  let tl_stroke = case config.tick_line_stroke {
    "" -> "var(--weft-chart-tick, currentColor)"
    s -> s
  }
  let tl_stroke_width = case config.tick_line_stroke_width >. 0.0 {
    True -> math.fmt(config.tick_line_stroke_width)
    False -> "1"
  }
  let tl_dash_attrs = case config.tick_line_stroke_dasharray {
    "" -> []
    pattern -> [svg.attr("stroke-dasharray", pattern)]
  }
  let tick_line_el = case config.show_tick_line {
    False -> element.none()
    True ->
      svg.line(
        x1: math.fmt(axis_x),
        y1: math.fmt(tick.coordinate),
        x2: math.fmt(axis_x +. tick_size_f *. effective_tick_dir),
        y2: math.fmt(tick.coordinate),
        attrs: list.flatten([
          [
            svg.attr("stroke", tl_stroke),
            svg.attr("stroke-width", tl_stroke_width),
          ],
          tl_dash_attrs,
        ]),
      )
  }

  let margin_offset = int.to_float(config.tick_margin) *. effective_tick_dir
  let tick_offset = tick_size_f *. effective_tick_dir
  let label_x = axis_x +. margin_offset +. tick_offset
  let anchor = case config.orientation, config.mirror {
    Left, False -> "end"
    Left, True -> "start"
    _, False -> "start"
    _, True -> "end"
  }
  let text_el = case config.custom_tick {
    Some(renderer) -> {
      let props =
        render.TickProps(
          x: label_x,
          y: tick.coordinate,
          index: tick_index,
          value: label,
          text_anchor: anchor,
          vertical_anchor: "middle",
          fill: "var(--weft-chart-tick-text, currentColor)",
          visible_ticks_count: visible_count,
        )
      renderer(props)
    }
    None -> {
      let rotation_attrs = case config.angle == 0.0 {
        True -> []
        False -> {
          let transform_value =
            "rotate("
            <> math.fmt(config.angle)
            <> ", "
            <> math.fmt(label_x)
            <> ", "
            <> math.fmt(tick.coordinate)
            <> ")"
          [svg.attr("transform", transform_value)]
        }
      }
      svg.text(
        x: math.fmt(label_x),
        y: math.fmt(tick.coordinate),
        content: label,
        attrs: list.flatten([
          [
            svg.attr("text-anchor", anchor),
            svg.attr("dominant-baseline", "central"),
            svg.attr("font-size", "12"),
            svg.attr("fill", "var(--weft-chart-tick-text, currentColor)"),
          ],
          rotation_attrs,
        ]),
      )
    }
  }

  svg.g(attrs: [], children: [tick_line_el, text_el])
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Extract the pixel range (start, end) from any Scale variant.
fn scale_range(s: Scale) -> #(Float, Float) {
  case s {
    scale.LinearScale(range_start:, range_end:, ..) -> #(range_start, range_end)
    scale.LogScale(range_start:, range_end:, ..) -> #(range_start, range_end)
    scale.SqrtScale(range_start:, range_end:, ..) -> #(range_start, range_end)
    scale.PowerScale(range_start:, range_end:, ..) -> #(range_start, range_end)
    scale.TimeScale(range_start:, range_end:, ..) -> #(range_start, range_end)
    scale.BandScale(range_start:, range_end:, ..) -> #(range_start, range_end)
    scale.PointScale(range_start:, range_end:, ..) -> #(range_start, range_end)
    scale.OrdinalScale(..) -> #(0.0, 0.0)
  }
}

/// Compute evenly-spaced coordinates for category tick overrides.
fn category_tick_coords(
  labels: List(String),
  range_start: Float,
  range_end: Float,
) -> List(ScaleTick) {
  let count = list.length(labels)
  case count > 1 {
    True -> {
      let range = range_end -. range_start
      let step = range /. int.to_float(count - 1)
      list.index_map(labels, fn(label, idx) {
        scale.ScaleTick(
          value: label,
          coordinate: range_start +. step *. int.to_float(idx),
        )
      })
    }
    False ->
      list.map(labels, fn(label) {
        scale.ScaleTick(
          value: label,
          coordinate: { range_start +. range_end } /. 2.0,
        )
      })
  }
}

/// Format a float tick value, showing integers without decimal point.
fn format_tick_value(value: Float) -> String {
  let rounded = float.round(value)
  case value == int.to_float(rounded) {
    True -> int.to_string(rounded)
    False -> math.fmt(value)
  }
}

/// Filter ticks by interval strategy (public API for testability).
///
/// Applies the given `AxisInterval` strategy to a list of ticks, using
/// `min_tick_gap` (in pixels) to decide which ticks to hide when they
/// would overlap.  Label widths are estimated at 7 px per character for
/// server-side rendering without DOM access.
pub fn filter_ticks_by_interval(
  ticks ticks: List(ScaleTick),
  interval interval: AxisInterval,
  min_tick_gap min_tick_gap: Int,
) -> List(ScaleTick) {
  filter_by_interval(ticks, interval, min_tick_gap)
}

/// Filter ticks by interval strategy.
///
/// Matches recharts `getTicks` interval filtering:
/// - `EveryNth(0)` shows all ticks
/// - `EveryNth(n)` shows every (n+1)th tick
/// - `PreserveStart` always shows first tick, hides overlapping neighbours
/// - `PreserveEnd` always shows last tick, hides overlapping neighbours
/// - `PreserveStartEnd` always shows first and last, hides overlapping middle
/// - `EquidistantPreserveStart` finds optimal step showing first tick
///
/// Label widths are estimated at 7 px per character for SSR without DOM.
fn filter_by_interval(
  ticks: List(ScaleTick),
  interval: AxisInterval,
  min_tick_gap: Int,
) -> List(ScaleTick) {
  let n = list.length(ticks)
  case n <= 1 {
    True -> ticks
    False ->
      case interval {
        EveryNth(step) ->
          case step <= 0 {
            True -> ticks
            False ->
              list.index_map(ticks, fn(tick, i) { #(tick, i) })
              |> list.filter(fn(pair) { pair.1 % { step + 1 } == 0 })
              |> list.map(fn(pair) { pair.0 })
          }
        PreserveStart -> preserve_start_filter(ticks, min_tick_gap)
        PreserveEnd -> preserve_end_filter(ticks, min_tick_gap)
        PreserveStartEnd -> preserve_start_end_filter(ticks, min_tick_gap)
        EquidistantPreserveStart ->
          equidistant_start_filter(ticks, min_tick_gap)
      }
  }
}

/// Estimate the rendered pixel width of a tick label.
/// Uses ~7 px per character as a heuristic for font-size 12 SVG text.
fn estimate_tick_width(tick: ScaleTick) -> Int {
  string.length(tick.value) * 7
}

/// Preserve start: always show the first tick, then include subsequent
/// ticks only when they are far enough from the last shown tick.
fn preserve_start_filter(
  ticks: List(ScaleTick),
  min_tick_gap: Int,
) -> List(ScaleTick) {
  case ticks {
    [] -> []
    [first, ..rest] -> {
      let #(result_rev, _) =
        list.fold(rest, #([first], first), fn(acc, tick) {
          let #(kept_rev, last_shown) = acc
          let threshold =
            int.to_float(min_tick_gap + estimate_tick_width(last_shown))
          case
            math.abs(tick.coordinate -. last_shown.coordinate) >=. threshold
          {
            True -> #([tick, ..kept_rev], tick)
            False -> acc
          }
        })
      list.reverse(result_rev)
    }
  }
}

/// Preserve end: always show the last tick, then include earlier ticks
/// (processing right-to-left) only when they are far enough from the
/// last shown tick.
fn preserve_end_filter(
  ticks: List(ScaleTick),
  min_tick_gap: Int,
) -> List(ScaleTick) {
  case list.reverse(ticks) {
    [] -> []
    [last, ..rest_rev] -> {
      let #(result, _) =
        list.fold(rest_rev, #([last], last), fn(acc, tick) {
          let #(kept, last_shown) = acc
          let threshold = int.to_float(min_tick_gap + estimate_tick_width(tick))
          case
            math.abs(last_shown.coordinate -. tick.coordinate) >=. threshold
          {
            True -> #([tick, ..kept], tick)
            False -> acc
          }
        })
      // `result` is already in left-to-right order because we prepend
      // while walking right-to-left.
      result
    }
  }
}

/// Preserve start and end: always show the first and last ticks.
/// Middle ticks are kept only when far enough from both the previous
/// shown tick and the final tick.
fn preserve_start_end_filter(
  ticks: List(ScaleTick),
  min_tick_gap: Int,
) -> List(ScaleTick) {
  case ticks {
    [] | [_] -> ticks
    [first, ..rest] -> {
      case list.last(ticks) {
        Error(_) -> ticks
        Ok(last_tick) -> {
          let middle = list.take(rest, list.length(rest) - 1)
          let #(result_rev, _) =
            list.fold(middle, #([first], first), fn(acc, tick) {
              let #(kept_rev, last_shown) = acc
              let left_threshold =
                int.to_float(min_tick_gap + estimate_tick_width(last_shown))
              let right_threshold =
                int.to_float(min_tick_gap + estimate_tick_width(tick))
              let left_ok =
                math.abs(tick.coordinate -. last_shown.coordinate)
                >=. left_threshold
              let right_ok =
                math.abs(last_tick.coordinate -. tick.coordinate)
                >=. right_threshold
              case left_ok && right_ok {
                True -> #([tick, ..kept_rev], tick)
                False -> acc
              }
            })
          list.reverse([last_tick, ..result_rev])
        }
      }
    }
  }
}

/// Equidistant preserve start: find the minimum step `s` (>= 1) such
/// that showing every `s`th tick from the first satisfies the gap
/// constraint, then return ticks at indices 0, s, 2s, ...
fn equidistant_start_filter(
  ticks: List(ScaleTick),
  min_tick_gap: Int,
) -> List(ScaleTick) {
  let n = list.length(ticks)
  case n <= 1 {
    True -> ticks
    False -> {
      let indexed = list.index_map(ticks, fn(tick, i) { #(i, tick) })
      let step = find_valid_step(indexed, min_tick_gap, 1, n)
      indexed
      |> list.filter(fn(pair) { pair.0 % step == 0 })
      |> list.map(fn(pair) { pair.1 })
    }
  }
}

/// Search for the smallest step where all consecutive shown ticks
/// satisfy the minimum gap constraint.
fn find_valid_step(
  indexed_ticks: List(#(Int, ScaleTick)),
  min_tick_gap: Int,
  step: Int,
  n: Int,
) -> Int {
  case step >= n {
    True -> n
    False -> {
      let shown =
        list.filter(indexed_ticks, fn(pair) { pair.0 % step == 0 })
        |> list.map(fn(pair) { pair.1 })
      case check_spacing(shown, min_tick_gap) {
        True -> step
        False -> find_valid_step(indexed_ticks, min_tick_gap, step + 1, n)
      }
    }
  }
}

/// Check that all consecutive pairs in the tick list satisfy the
/// minimum gap plus estimated label width constraint.
fn check_spacing(ticks: List(ScaleTick), min_tick_gap: Int) -> Bool {
  case ticks {
    [] | [_] -> True
    [a, b, ..rest] -> {
      let threshold = int.to_float(min_tick_gap + estimate_tick_width(a))
      case math.abs(b.coordinate -. a.coordinate) >=. threshold {
        True -> check_spacing([b, ..rest], min_tick_gap)
        False -> False
      }
    }
  }
}
