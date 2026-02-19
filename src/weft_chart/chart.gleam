//// Chart container components.
////
//// Each chart type sets up the coordinate system, computes scales from
//// data, and renders its children (series, axes, grid, tooltip, legend)
//// into a composed SVG element.  Supports stacking via shared stackId
//// values, multiple bar side-by-side layout with barGap/barCategoryGap,
//// and stackOffset modes matching the recharts stacking algorithm.

import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/event as lustre_event
import weft_chart/a11y
import weft_chart/axis
import weft_chart/brush
import weft_chart/curve
import weft_chart/error_bar
import weft_chart/event.{type ChartEvent}
import weft_chart/grid
import weft_chart/internal/layout
import weft_chart/internal/math
import weft_chart/internal/svg
import weft_chart/legend
import weft_chart/polar_axis
import weft_chart/reference
import weft_chart/scale
import weft_chart/series/area
import weft_chart/series/bar
import weft_chart/series/funnel
import weft_chart/series/line
import weft_chart/series/pie
import weft_chart/series/radar
import weft_chart/series/radial_bar
import weft_chart/series/sankey
import weft_chart/series/scatter
import weft_chart/series/sunburst
import weft_chart/series/treemap
import weft_chart/shape
import weft_chart/tooltip

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A data point with a category label and named numeric values.
pub type DataPoint {
  DataPoint(category: String, values: Dict(String, Float))
}

/// A child element within a chart composition.
pub type ChartChild(msg) {
  /// Chart margin configuration.
  MarginChild(margin: layout.Margin)
  /// Cartesian grid.
  GridChild(config: grid.CartesianGridConfig)
  /// Polar grid.
  PolarGridChild(config: grid.PolarGridConfig)
  /// Polar angle axis (category labels around perimeter).
  PolarAngleAxisChild(config: polar_axis.PolarAngleAxisConfig)
  /// Polar radius axis (value ticks along radial line).
  PolarRadiusAxisChild(config: polar_axis.PolarRadiusAxisConfig)
  /// X-axis.
  XAxisChild(config: axis.XAxisConfig(msg))
  /// Y-axis.
  YAxisChild(config: axis.YAxisConfig(msg))
  /// Area series.
  AreaChild(config: area.AreaConfig(msg))
  /// Bar series.
  BarChild(config: bar.BarConfig(msg))
  /// Line series.
  LineChild(config: line.LineConfig(msg))
  /// Pie series.
  PieChild(config: pie.PieConfig(msg))
  /// Radar series.
  RadarChild(config: radar.RadarConfig(msg))
  /// Radial bar series.
  RadialBarChild(config: radial_bar.RadialBarConfig(msg))
  /// Scatter series.
  ScatterChild(config: scatter.ScatterConfig(msg))
  /// Funnel series.
  FunnelChild(config: funnel.FunnelConfig(msg))
  /// Treemap series.
  TreemapChild(config: treemap.TreemapConfig(msg))
  /// Sunburst series.
  SunburstChild(config: sunburst.SunburstConfig)
  /// Sankey series.
  SankeyChild(config: sankey.SankeyConfig(msg))
  /// Tooltip.
  TooltipChild(config: tooltip.TooltipConfig(msg))
  /// Legend.
  LegendChild(config: legend.LegendConfig(msg))
  /// Reference line annotation.
  ReferenceLineChild(config: reference.ReferenceLineConfig(msg))
  /// Reference area annotation.
  ReferenceAreaChild(config: reference.ReferenceAreaConfig(msg))
  /// Reference dot annotation.
  ReferenceDotChild(config: reference.ReferenceDotConfig(msg))
  /// Error bar indicator for a series.
  ErrorBarChild(config: error_bar.ErrorBarConfig, series_data_key: String)
  /// Z-axis for size encoding in scatter charts.
  ZAxisChild(config: axis.ZAxisConfig)
  /// Stack offset configuration.
  StackOffsetChild(offset: StackOffsetType)
  /// Chart-level bar layout configuration.
  BarLayoutChild(
    bar_category_gap: Float,
    bar_gap: Float,
    chart_bar_size: BarSize,
  )
  /// Chart-level maximum bar width in pixels.
  MaxBarSizeChild(size: Int)
  /// Reverse stack order for stacked series.
  ReverseStackChild(reverse: Bool)
  /// Chart layout direction.
  LayoutChild(layout: layout.LayoutDirection)
  /// SVG title element for accessibility.
  TitleChild(text: String)
  /// SVG desc element for accessibility.
  DescChild(text: String)
  /// ARIA role attribute for the outer SVG element.
  RoleChild(role: String)
  /// CSS class attribute for the outer SVG element.
  ClassChild(class: String)
  /// HTML id attribute for the outer SVG element.
  IdChild(id: String)
  /// Inline style attribute for the outer SVG element.
  StyleChild(style: String)
  /// Sync ID for linking multiple charts.
  SyncIdChild(id: String)
  /// Sync method for linked charts.
  SyncMethodChild(method: SyncMethod)
  /// Compact mode for sparkline-style rendering.
  CompactChild
  /// Chart-level event handler.
  EventChild(handler: ChartEvent(msg))
  /// Throttle hint for chart mouse events (milliseconds).
  ThrottleChild(delay_ms: Int)
  /// Accessibility layer configuration.
  AccessibilityChild(config: a11y.A11yConfig(msg))
  /// Brush (range-selector) for zooming/panning.
  BrushChild(config: brush.BrushConfig(msg))
}

/// Stack offset type matching recharts stackOffset prop.
/// Maps to recharts STACK_OFFSET_MAP keys.
pub type StackOffsetType {
  /// Simple cumulative stacking (default).  Maps to d3 stackOffsetNone.
  StackOffsetNone
  /// Normalize all series to sum to 1.0 (100% stacked).  Maps to d3 stackOffsetExpand.
  StackOffsetExpand
  /// Positive values above zero, negative below.  Maps to recharts offsetSign.
  StackOffsetSign
  /// Like sign but clamps negative values to zero.  Maps to recharts offsetPositive.
  StackOffsetPositive
  /// Minimize weighted wiggle of layers.  Maps to d3 stackOffsetWiggle.
  StackOffsetWiggle
  /// Center the stream around zero baseline.  Maps to d3 stackOffsetSilhouette.
  StackOffsetSilhouette
}

/// Chart-level bar size configuration.
/// Allows fixed pixel size or percentage of available space.
pub type BarSize {
  /// Fixed bar width in pixels.
  FixedBarSize(size: Int)
  /// Bar width as a percentage of available category space (0.0 to 1.0).
  PercentBarSize(percent: Float)
}

/// Synchronization method for linked charts.
pub type SyncMethod {
  /// Sync tooltip/cursor by data index.
  SyncByIndex
  /// Sync tooltip/cursor by data value.
  SyncByValue
}

// ---------------------------------------------------------------------------
// Child constructors
// ---------------------------------------------------------------------------

/// Create a margin child.
pub fn margin(
  top top: Int,
  right right: Int,
  bottom bottom: Int,
  left left: Int,
) -> ChartChild(msg) {
  MarginChild(margin: layout.Margin(
    top: top,
    right: right,
    bottom: bottom,
    left: left,
  ))
}

/// Create a cartesian grid child.
pub fn cartesian_grid(config: grid.CartesianGridConfig) -> ChartChild(msg) {
  GridChild(config: config)
}

/// Create a polar grid child.
pub fn polar_grid(config: grid.PolarGridConfig) -> ChartChild(msg) {
  PolarGridChild(config: config)
}

/// Create a polar angle axis child.
pub fn polar_angle_axis(
  config: polar_axis.PolarAngleAxisConfig,
) -> ChartChild(msg) {
  PolarAngleAxisChild(config: config)
}

/// Create a polar radius axis child.
pub fn polar_radius_axis(
  config: polar_axis.PolarRadiusAxisConfig,
) -> ChartChild(msg) {
  PolarRadiusAxisChild(config: config)
}

/// Create an x-axis child.
pub fn x_axis(config: axis.XAxisConfig(msg)) -> ChartChild(msg) {
  XAxisChild(config: config)
}

/// Create a y-axis child.
pub fn y_axis(config: axis.YAxisConfig(msg)) -> ChartChild(msg) {
  YAxisChild(config: config)
}

/// Create a z-axis child for size encoding in scatter charts.
/// Matches recharts ZAxis component.
pub fn z_axis(config config: axis.ZAxisConfig) -> ChartChild(msg) {
  ZAxisChild(config: config)
}

/// Create an area series child.
pub fn area(config: area.AreaConfig(msg)) -> ChartChild(msg) {
  AreaChild(config: config)
}

/// Create a bar series child.
pub fn bar(config: bar.BarConfig(msg)) -> ChartChild(msg) {
  BarChild(config: config)
}

/// Create a line series child.
pub fn line(config: line.LineConfig(msg)) -> ChartChild(msg) {
  LineChild(config: config)
}

/// Create a pie series child.
pub fn pie_series(config: pie.PieConfig(msg)) -> ChartChild(msg) {
  PieChild(config: config)
}

/// Create a radar series child.
pub fn radar_series(config: radar.RadarConfig(msg)) -> ChartChild(msg) {
  RadarChild(config: config)
}

/// Create a radial bar series child.
pub fn radial_bar_series(
  config: radial_bar.RadialBarConfig(msg),
) -> ChartChild(msg) {
  RadialBarChild(config: config)
}

/// Create a scatter series child.
/// Matches recharts Scatter component.
pub fn scatter_series(config: scatter.ScatterConfig(msg)) -> ChartChild(msg) {
  ScatterChild(config: config)
}

/// Create a funnel series child.
/// Matches recharts Funnel component.
pub fn funnel_series(config: funnel.FunnelConfig(msg)) -> ChartChild(msg) {
  FunnelChild(config: config)
}

/// Create a treemap chart child from a treemap configuration.
pub fn treemap_series(
  config config: treemap.TreemapConfig(msg),
) -> ChartChild(msg) {
  TreemapChild(config: config)
}

/// Create a sunburst chart child from a sunburst configuration.
pub fn sunburst_series(
  config config: sunburst.SunburstConfig,
) -> ChartChild(msg) {
  SunburstChild(config: config)
}

/// Create a sankey chart child from a sankey configuration.
pub fn sankey_series(config config: sankey.SankeyConfig(msg)) -> ChartChild(msg) {
  SankeyChild(config: config)
}

/// Create a tooltip child.
pub fn chart_tooltip(
  config config: tooltip.TooltipConfig(msg),
) -> ChartChild(msg) {
  TooltipChild(config: config)
}

/// Create a legend child.
pub fn chart_legend(config config: legend.LegendConfig(msg)) -> ChartChild(msg) {
  LegendChild(config: config)
}

/// Add a brush (range-selector) to a composed or bar chart.
pub fn chart_brush(config config: brush.BrushConfig(msg)) -> ChartChild(msg) {
  BrushChild(config:)
}

/// Create a reference line child.
/// Matches recharts ReferenceLine component.
pub fn reference_line(
  config: reference.ReferenceLineConfig(msg),
) -> ChartChild(msg) {
  ReferenceLineChild(config: config)
}

/// Create a reference area child.
/// Matches recharts ReferenceArea component.
pub fn reference_area(
  config: reference.ReferenceAreaConfig(msg),
) -> ChartChild(msg) {
  ReferenceAreaChild(config: config)
}

/// Create a reference dot child.
/// Matches recharts ReferenceDot component.
pub fn chart_reference_dot(
  config: reference.ReferenceDotConfig(msg),
) -> ChartChild(msg) {
  ReferenceDotChild(config: config)
}

/// Create an error bar child for a series.
/// Matches recharts ErrorBar component.
/// The `series_data_key` identifies which series the error bars belong to.
pub fn chart_error_bar(
  config config: error_bar.ErrorBarConfig,
  series_data_key series_data_key: String,
) -> ChartChild(msg) {
  ErrorBarChild(config: config, series_data_key: series_data_key)
}

/// Set the stack offset type for stacked series.
/// Matches recharts BarChart/AreaChart stackOffset prop.
pub fn stack_offset(offset: StackOffsetType) -> ChartChild(msg) {
  StackOffsetChild(offset: offset)
}

/// Reverse the stacking order for stacked series.
/// When True, the data keys within each stack group are reversed before
/// computing cumulative stacked values, matching recharts `reverseStackOrder`
/// prop on BarChart/AreaChart.
pub fn reverse_stack_order(reverse: Bool) -> ChartChild(msg) {
  ReverseStackChild(reverse: reverse)
}

/// Set chart-level bar layout configuration.
/// Matches recharts BarChart `barCategoryGap`, `barGap`, and `barSize` props.
/// - `bar_category_gap`: percentage of band width reserved as padding (default: 0.1 = 10%)
/// - `bar_gap`: pixel gap between bars in a group (default: 4.0)
/// - `chart_bar_size`: chart-level bar width override; FixedBarSize(0) means auto
pub fn bar_layout(
  bar_category_gap bar_category_gap: Float,
  bar_gap bar_gap: Float,
  chart_bar_size chart_bar_size: BarSize,
) -> ChartChild(msg) {
  BarLayoutChild(
    bar_category_gap: bar_category_gap,
    bar_gap: bar_gap,
    chart_bar_size: chart_bar_size,
  )
}

/// Set a chart-level maximum bar width in pixels.
/// Computed bar widths are clamped to this maximum.
/// Matches recharts `maxBarSize` prop.
pub fn max_bar_size(size size: Int) -> ChartChild(msg) {
  MaxBarSizeChild(size: size)
}

/// Set the chart layout direction.
/// Horizontal (default): categories on X, values on Y.
/// Vertical: categories on Y, values on X (horizontal bar charts).
pub fn chart_layout(layout layout: layout.LayoutDirection) -> ChartChild(msg) {
  LayoutChild(layout: layout)
}

/// Set an accessible title for the chart SVG.
/// Renders as `<title>` element inside the SVG for screen readers.
pub fn chart_title(text text: String) -> ChartChild(msg) {
  TitleChild(text: text)
}

/// Set an accessible description for the chart SVG.
/// Renders as `<desc>` element inside the SVG for screen readers.
pub fn chart_desc(text text: String) -> ChartChild(msg) {
  DescChild(text: text)
}

/// Set the ARIA role attribute on the outer SVG element.
/// Default is "img".  Matches recharts `role` prop.
pub fn role(role role: String) -> ChartChild(msg) {
  RoleChild(role: role)
}

/// Set a CSS class on the outer SVG element.
/// Matches recharts `className` prop.
pub fn class(class class: String) -> ChartChild(msg) {
  ClassChild(class: class)
}

/// Set an HTML id on the outer SVG element.
/// Matches recharts `id` prop.
pub fn id(id id: String) -> ChartChild(msg) {
  IdChild(id: id)
}

/// Set an inline style on the outer SVG element.
/// Matches recharts `style` prop.
pub fn style(style style: String) -> ChartChild(msg) {
  StyleChild(style: style)
}

/// Set a sync ID for linking multiple charts.
/// Charts with the same sync ID share tooltip/cursor state.
/// Emitted as `data-sync-id` attribute on the SVG element.
pub fn sync_id(id id: String) -> ChartChild(msg) {
  SyncIdChild(id: id)
}

/// Set the synchronization method for linked charts.
/// Emitted as `data-sync-method` attribute on the SVG element.
pub fn sync_method(method method: SyncMethod) -> ChartChild(msg) {
  SyncMethodChild(method: method)
}

/// Enable compact mode for sparkline-style rendering.
/// When present, minimizes margins and flags for hiding non-essential
/// elements (axis labels, legend).
pub fn compact() -> ChartChild(msg) {
  CompactChild
}

/// Attach a chart-level event handler.
/// Matches recharts onClick/onMouseEnter/onMouseLeave/onMouseMove props
/// on chart container components.
pub fn chart_event(handler handler: ChartEvent(msg)) -> ChartChild(msg) {
  EventChild(handler: handler)
}

/// Set a throttle hint for chart mouse events.
/// Emitted as `data-throttle-ms` attribute on the outer SVG for use by
/// client-side throttle scripts.  Since pure SVG cannot throttle events,
/// this is an advisory hint.
/// Matches recharts throttleDelay prop.
pub fn throttle(delay_ms delay_ms: Int) -> ChartChild(msg) {
  ThrottleChild(delay_ms: delay_ms)
}

/// Add an accessibility layer to the chart.
/// When enabled, sets tabindex, role, aria-label, and keyboard event handlers
/// on the outer SVG element.  Matches recharts accessibilityLayer prop.
pub fn accessibility(config config: a11y.A11yConfig(msg)) -> ChartChild(msg) {
  AccessibilityChild(config: config)
}

// ---------------------------------------------------------------------------
// Cartesian chart containers
// ---------------------------------------------------------------------------

/// Render an area chart.
pub fn area_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_cartesian(
    data: data,
    width: width,
    height: height,
    children: children,
    chart_type: AreaChartType,
  )
}

/// Render a bar chart.
/// Matches recharts BarChart defaults: barCategoryGap=10%,
/// barGap=4px between bars in same category.
pub fn bar_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_cartesian(
    data: data,
    width: width,
    height: height,
    children: children,
    chart_type: BarChartType,
  )
}

/// Render a line chart.
pub fn line_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_cartesian(
    data: data,
    width: width,
    height: height,
    children: children,
    chart_type: LineChartType,
  )
}

/// Render a scatter chart with numeric X and Y axes.
/// Matches recharts ScatterChart: uses LinearScale on both axes.
pub fn scatter_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_scatter_chart(
    data: data,
    width: width,
    height: height,
    children: children,
  )
}

/// Render a composed chart mixing Line, Bar, Area, and Scatter series.
/// Matches recharts ComposedChart: uses band scale when Bar children
/// are present, point scale otherwise.
///
/// Supports `ScatterChild` with optional `ZAxisChild` for z-dimension dot
/// sizing, mirroring recharts' inclusion of ZAxis in ComposedChart
/// `axisComponents`.
pub fn composed_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_cartesian(
    data: data,
    width: width,
    height: height,
    children: children,
    chart_type: ComposedChartType,
  )
}

// ---------------------------------------------------------------------------
// Polar chart containers
// ---------------------------------------------------------------------------

/// Render a pie chart.
pub fn pie_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_polar(
    data: data,
    width: width,
    height: height,
    children: children,
    chart_type: PieChartType,
  )
}

/// Render a radar chart.
pub fn radar_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_polar(
    data: data,
    width: width,
    height: height,
    children: children,
    chart_type: RadarChartType,
  )
}

/// Render a radial bar chart.
pub fn radial_bar_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_polar(
    data: data,
    width: width,
    height: height,
    children: children,
    chart_type: RadialBarChartType,
  )
}

/// Render a funnel chart.
/// Matches recharts FunnelChart: renders funnel children within an SVG.
pub fn funnel_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_funnel_chart(
    data: data,
    width: width,
    height: height,
    children: children,
  )
}

/// Render a treemap chart.
pub fn treemap_chart(
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_treemap_chart(width: width, height: height, children: children)
}

/// Render a sunburst chart.
pub fn sunburst_chart(
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_sunburst_chart(width: width, height: height, children: children)
}

/// Render a sankey chart.
pub fn sankey_chart(
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  render_sankey_chart(width: width, height: height, children: children)
}

// ---------------------------------------------------------------------------
// Internal: Cartesian rendering
// ---------------------------------------------------------------------------

type CartesianChartType {
  AreaChartType
  BarChartType
  ComposedChartType
  LineChartType
}

fn render_cartesian(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
  chart_type chart_type: CartesianChartType,
) -> Element(msg) {
  // Extract margin, adjust for axis dimensions, reserve legend space,
  // and compute plot area.
  let chart_margin =
    find_margin(children)
    |> adjust_margin_for_axes(children)
    |> adjust_margin_for_legend(children)
    |> adjust_margin_for_brush(children)
  let plot =
    layout.plot_area(width: width, height: height, margin: chart_margin)

  // Extract categories and values
  let categories = list.map(data, fn(dp) { dp.category })
  let values_list = list.map(data, fn(dp) { dp.values })

  // Collect all data keys from series children
  let data_keys = collect_data_keys(children)

  // In ComposedChart, ScatterChild may carry its own data prop that is
  // separate from chart-level data.  Include those values in values_list
  // and their y_data_key in data_keys so the y-domain covers scatter points
  // that fall outside the bar/line/area range (recharts includes all series
  // data in getDomainOfItemsWithSameAxis — generateCategoricalChart.tsx:570).
  let #(values_list, data_keys) = case chart_type {
    ComposedChartType ->
      list.fold(children, #(values_list, data_keys), fn(acc, child) {
        case child {
          ScatterChild(config:) ->
            case config.data {
              // Empty: scatter uses chart-level data, already included
              [] -> acc
              own_data -> {
                let #(vl, dk) = acc
                let new_vl = list.append(vl, own_data)
                let new_dk = case list.contains(dk, config.y_data_key) {
                  True -> dk
                  False -> [config.y_data_key, ..dk]
                }
                #(new_vl, new_dk)
              }
            }
          _ -> acc
        }
      })
    _ -> #(values_list, data_keys)
  }

  // Compute stacked data if applicable
  let raw_stack_groups = collect_stack_groups(children)
  let stack_groups = case find_reverse_stack_order(children) {
    True ->
      list.map(raw_stack_groups, fn(group) {
        StackGroup(..group, data_keys: list.reverse(group.data_keys))
      })
    False -> raw_stack_groups
  }
  let offset_type = find_stack_offset(children)
  let stacked_data =
    compute_stacked_values(values_list, stack_groups, data_keys, offset_type)

  // Collect multi-axis configurations
  let y_configs = collect_y_axis_configs(children)
  let data_keys_by_y_axis = collect_data_keys_by_y_axis(children)

  // Determine layout direction
  let chart_layout = find_layout(children)

  // Check axis configs for reversed prop (primary axis)
  // Recharts reversed: swap range endpoints (CartesianUtils.ts:86-87)
  let x_reversed = find_x_reversed(children)
  let _y_reversed = find_y_reversed(children)

  let #(x_range_start_raw, x_range_end_raw) = case x_reversed {
    True -> #(plot.x +. plot.width, plot.x)
    False -> #(plot.x, plot.x +. plot.width)
  }

  // Resolve x-axis padding mode and adjust range endpoints
  let x_padding_mode = find_x_padding_mode(children)
  let #(x_range_start, x_range_end) =
    resolve_x_padding(
      x_padding_mode,
      x_range_start_raw,
      x_range_end_raw,
      list.length(categories),
    )

  // Build scales -- when Vertical layout, the category scale maps to Y-range
  // and the value scale maps to X-range (bars extend horizontally).
  let x_is_numeric = find_x_is_numeric(children)

  // Category scale range depends on layout direction
  let #(cat_range_start, cat_range_end) = case chart_layout {
    layout.Horizontal -> #(x_range_start, x_range_end)
    layout.Vertical -> #(plot.y, plot.y +. plot.height)
  }

  // Determine whether to use band or point scale for categories
  let use_band = case chart_type {
    BarChartType -> True
    ComposedChartType -> has_bar_children(children)
    _ -> False
  }

  let x_scale = case chart_layout {
    layout.Horizontal ->
      case x_is_numeric {
        True -> {
          let x_values =
            list.flat_map(values_list, fn(vals) {
              list.filter_map(data_keys, fn(key) { dict.get(vals, key) })
            })
          let x_data_domain = scale.auto_domain(x_values)
          let #(has_x_domain, x_dm_min, x_dm_max, x_allow_overflow) =
            find_x_domain_config(children)
          let x_domain_final = case has_x_domain {
            True ->
              case x_allow_overflow {
                True -> #(x_dm_min, x_dm_max)
                False -> #(
                  math.list_min([x_dm_min, x_data_domain.0]),
                  math.list_max([x_dm_max, x_data_domain.1]),
                )
              }
            False -> x_data_domain
          }
          scale.linear(
            domain_min: x_domain_final.0,
            domain_max: x_domain_final.1,
            range_start: x_range_start,
            range_end: x_range_end,
          )
        }
        False ->
          case use_band {
            True ->
              scale.band(
                categories: categories,
                range_start: cat_range_start,
                range_end: cat_range_end,
                padding_inner: 0.1,
                padding_outer: 0.1,
              )
            False ->
              scale.point(
                categories: categories,
                range_start: cat_range_start,
                range_end: cat_range_end,
                padding: 0.05,
              )
          }
      }
    layout.Vertical -> {
      // Vertical layout: x-axis shows values (linear scale, X-range)
      let all_vals =
        list.flat_map(values_list, fn(vals) {
          list.filter_map(data_keys, fn(key) { dict.get(vals, key) })
        })
      let x_data_domain = scale.auto_domain_from_zero(all_vals)
      let #(has_x_domain, x_dm_min, x_dm_max, x_allow_overflow) =
        find_x_domain_config(children)
      let x_domain_final = case has_x_domain {
        True ->
          case x_allow_overflow {
            True -> #(x_dm_min, x_dm_max)
            False -> #(
              math.list_min([x_dm_min, x_data_domain.0]),
              math.list_max([x_dm_max, x_data_domain.1]),
            )
          }
        False -> x_data_domain
      }
      scale.linear(
        domain_min: x_domain_final.0,
        domain_max: x_domain_final.1,
        range_start: x_range_start,
        range_end: x_range_end,
      )
    }
  }

  // Build y-scales based on layout
  let #(y_scales, y_scale) = case chart_layout {
    layout.Horizontal -> {
      // Standard: y-axis shows values (linear scale, Y-range)
      let ys =
        build_y_scales(
          y_configs,
          data_keys_by_y_axis,
          data_keys,
          values_list,
          stacked_data,
          offset_type,
          plot.y,
          plot.height,
          children,
        )
      #(ys, get_scale(ys, "0"))
    }
    layout.Vertical -> {
      // Vertical: y-axis shows categories (band/point scale, Y-range)
      let cat_y_scale = case use_band {
        True ->
          scale.band(
            categories: categories,
            range_start: cat_range_start,
            range_end: cat_range_end,
            padding_inner: 0.1,
            padding_outer: 0.1,
          )
        False ->
          scale.point(
            categories: categories,
            range_start: cat_range_start,
            range_end: cat_range_end,
            padding: 0.05,
          )
      }
      let ys = dict.from_list([#("0", cat_y_scale)])
      #(ys, cat_y_scale)
    }
  }

  // Zero-line for bar charts: when domain includes negatives,
  // bars should grow from the zero line, not the plot edge.
  // Matches recharts Bar rendering where baseline = yAxis.scale(0).
  let all_values =
    list.flat_map(values_list, fn(vals) {
      list.filter_map(data_keys, fn(key) { dict.get(vals, key) })
    })
  let has_negative = list.any(all_values, fn(v) { v <. 0.0 })
  let baseline_y = case chart_layout {
    layout.Horizontal ->
      case has_negative {
        True -> {
          let zero_y = scale.apply(y_scale, 0.0)
          math.clamp(zero_y, plot.y, plot.y +. plot.height)
        }
        False -> plot.y +. plot.height
      }
    layout.Vertical ->
      case has_negative {
        True -> {
          // For vertical layout, zero line on the X-axis
          let zero_x = scale.apply(x_scale, 0.0)
          math.clamp(zero_x, plot.x, plot.x +. plot.width)
        }
        False -> plot.x
      }
  }

  // Clip path for allowDataOverflow and reference element hidden overflow
  let clip_path_id = "weft-chart-clip"

  // Compute multi-bar positions for side-by-side layout
  // For Vertical layout, use y_scale (the category/band scale) for positions
  let bar_cat_scale = case chart_layout {
    layout.Horizontal -> x_scale
    layout.Vertical -> y_scale
  }
  let bar_positions = compute_bar_positions(children, bar_cat_scale, plot.width)

  // Build legend payload from series children
  let legend_payload = build_legend_payload(children)

  // Extract ZAxis config and compute z-domain for ScatterChild series.
  // Mirrors the same pattern used in render_scatter_chart so that
  // ZAxisChild works in ComposedChart, matching recharts ComposedChart.tsx
  // which includes ZAxis in its axisComponents array.
  let z_axis_config_cartesian = find_z_axis_config(children)
  let #(
    cartesian_z_domain_min,
    cartesian_z_domain_max,
    cartesian_z_range_min,
    cartesian_z_range_max,
  ) = case z_axis_config_cartesian {
    Ok(zc) -> {
      let z_values =
        list.filter_map(values_list, fn(vals) { dict.get(vals, zc.data_key) })
      let z_dom = scale.auto_domain(z_values)
      #(z_dom.0, z_dom.1, zc.range_min, zc.range_max)
    }
    Error(_) -> #(0.0, 0.0, 0.0, 0.0)
  }

  // Render non-tooltip children first (grid < series < axes < reference).
  // Tooltip children are collected separately and appended last so they
  // paint on top of all series in SVG document order.
  let rendered_children =
    list.filter_map(children, fn(child) {
      case child {
        MarginChild(..) -> Error(Nil)

        GridChild(config:) -> {
          // When sync_with_ticks is enabled, compute axis tick coords
          // and pass them to the grid so grid lines align with axis ticks.
          let effective_config = case config.sync_with_ticks {
            False -> config
            True -> {
              let x_ticks = scale.ticks(x_scale, 5, True)
              let x_tick_coords = list.map(x_ticks, fn(t) { t.coordinate })
              let y_ticks = scale.ticks(y_scale, 5, True)
              let y_tick_coords = list.map(y_ticks, fn(t) { t.coordinate })
              grid.grid_sync_tick_coords(
                config:,
                x_coords: x_tick_coords,
                y_coords: y_tick_coords,
              )
            }
          }
          Ok(grid.render_cartesian_grid(
            config: effective_config,
            x_scale: x_scale,
            y_scale: y_scale,
            plot_x: plot.x,
            plot_y: plot.y,
            plot_width: plot.width,
            plot_height: plot.height,
          ))
        }

        XAxisChild(config:) ->
          Ok(axis.render_x_axis(
            config: config,
            x_scale: x_scale,
            plot_y: plot.y,
            plot_height: plot.height,
          ))

        YAxisChild(config:) -> {
          let axis_y_scale = get_scale(y_scales, config.axis_id)
          let offset =
            compute_y_axis_offset(config.axis_id, config.orientation, y_configs)
          let effective_plot_x = case config.orientation {
            axis.Left -> plot.x -. offset
            _ -> plot.x
          }
          let effective_plot_width = case config.orientation {
            axis.Right -> plot.width +. offset
            _ -> plot.width
          }
          Ok(axis.render_y_axis(
            config: config,
            y_scale: axis_y_scale,
            plot_x: effective_plot_x,
            plot_width: effective_plot_width,
          ))
        }

        AreaChild(config:) -> {
          let area_y_scale = get_scale(y_scales, config.y_axis_id)
          // Determine baseline: range area > stacked > base_value > flat
          let area_baseline = case config.is_range, config.base_data_key {
            True, base_key if base_key != "" -> {
              // Range area: use base_data_key values as per-point baseline
              let baseline_points =
                list.zip(categories, values_list)
                |> list.map(fn(pair) {
                  let #(cat, values) = pair
                  let x = scale.point_apply(x_scale, cat)
                  let y = case dict.get(values, base_key) {
                    Ok(v) -> scale.apply(area_y_scale, v)
                    Error(_) -> baseline_y
                  }
                  #(x, y)
                })
              curve.PointBaseline(points: baseline_points)
            }
            _, _ ->
              case config.stack_id {
                "" -> {
                  // Resolve base_value matching recharts Area.getBaseValue
                  let base_y =
                    resolve_area_base_value(
                      config.base_value,
                      area_y_scale,
                      baseline_y,
                    )
                  curve.FlatBaseline(y: base_y)
                }
                sid ->
                  case dict.get(stacked_data, sid) {
                    Ok(per_key) ->
                      case dict.get(per_key, config.data_key) {
                        Ok(baselines) ->
                          build_stacked_area_baseline(
                            baselines,
                            categories,
                            x_scale,
                            area_y_scale,
                            baseline_y,
                          )
                        Error(_) -> curve.FlatBaseline(y: baseline_y)
                      }
                    Error(_) -> curve.FlatBaseline(y: baseline_y)
                  }
              }
          }
          let #(path_el, dots_el) =
            render_area_with_baseline(
              config: config,
              data: values_list,
              categories: categories,
              x_scale: x_scale,
              y_scale: area_y_scale,
              baseline: area_baseline,
              stacked_data: stacked_data,
              layout: chart_layout,
            )
          // Path is always clipped; dots depend on clip_dot
          let clipped_path = clip_series(path_el, clip_path_id)
          let final_dots = case config.clip_dot {
            True -> clip_series(dots_el, clip_path_id)
            False -> dots_el
          }
          Ok(
            svg.g(attrs: [svg.attr("class", "recharts-area")], children: [
              clipped_path,
              final_dots,
            ]),
          )
        }

        BarChild(config:) -> {
          let bar_y_scale = get_scale(y_scales, config.y_axis_id)
          // Look up bar position for multi-bar layout
          let position = dict.get(bar_positions, config.data_key)
          case position {
            Ok(pos) ->
              Ok(clip_series(
                bar.render_bars_positioned(
                  config: config,
                  data: values_list,
                  categories: categories,
                  x_scale: x_scale,
                  y_scale: bar_y_scale,
                  baseline_y: baseline_y,
                  position: pos,
                  has_position: True,
                  layout: chart_layout,
                ),
                clip_path_id,
              ))
            Error(_) ->
              Ok(clip_series(
                bar.render_bars(
                  config: config,
                  data: values_list,
                  categories: categories,
                  x_scale: x_scale,
                  y_scale: bar_y_scale,
                  baseline_y: baseline_y,
                  layout: chart_layout,
                ),
                clip_path_id,
              ))
          }
        }

        LineChild(config:) -> {
          let line_y_scale = get_scale(y_scales, config.y_axis_id)
          let #(path_el, dots_el) =
            line.render_line_parts(
              config: config,
              data: values_list,
              categories: categories,
              x_scale: x_scale,
              y_scale: line_y_scale,
              layout: chart_layout,
            )
          // Path is always clipped; dots depend on clip_dot
          let clipped_path = clip_series(path_el, clip_path_id)
          let final_dots = case config.clip_dot {
            True -> clip_series(dots_el, clip_path_id)
            False -> dots_el
          }
          let class_value = case config.css_class {
            "" -> "recharts-line"
            cls -> "recharts-line " <> cls
          }
          Ok(
            svg.g(attrs: [svg.attr("class", class_value)], children: [
              clipped_path,
              final_dots,
            ]),
          )
        }

        // Tooltip is handled in a separate pass after all other children
        // so it is always the last element in SVG document order and paints
        // on top of all series (bars, lines, areas, etc.).
        TooltipChild(..) -> Error(Nil)

        LegendChild(config:) ->
          Ok(legend.render_legend(
            config: config,
            payload: legend_payload,
            chart_width: int.to_float(width),
            chart_height: int.to_float(height),
          ))

        ReferenceLineChild(config:) -> {
          let ref_y_scale = get_scale(y_scales, config.y_axis_id)
          Ok(reference.render_reference_line(
            config: config,
            x_scale: x_scale,
            y_scale: ref_y_scale,
            plot_x: plot.x,
            plot_y: plot.y,
            plot_width: plot.width,
            plot_height: plot.height,
            clip_path_id: clip_path_id,
          ))
        }

        ReferenceAreaChild(config:) -> {
          let ref_y_scale = get_scale(y_scales, config.y_axis_id)
          Ok(reference.render_reference_area(
            config: config,
            x_scale: x_scale,
            y_scale: ref_y_scale,
            plot_x: plot.x,
            plot_y: plot.y,
            plot_width: plot.width,
            plot_height: plot.height,
            clip_path_id: clip_path_id,
          ))
        }

        ReferenceDotChild(config:) -> {
          let ref_y_scale = get_scale(y_scales, config.y_axis_id)
          Ok(reference.render_reference_dot(
            config: config,
            x_scale: x_scale,
            y_scale: ref_y_scale,
            plot_x: plot.x,
            plot_y: plot.y,
            plot_width: plot.width,
            plot_height: plot.height,
            clip_path_id: clip_path_id,
          ))
        }

        ErrorBarChild(config:, series_data_key:) -> {
          let eb_y_scale = get_scale(y_scales, config.y_axis_id)
          Ok(error_bar.render_error_bars(
            config: config,
            data: values_list,
            categories: categories,
            x_scale: x_scale,
            y_scale: eb_y_scale,
            series_data_key: series_data_key,
          ))
        }

        BrushChild(config:) ->
          Ok(brush.render(
            config: config,
            plot_x: plot.x,
            plot_width: plot.width,
            plot_bottom: plot.y +. plot.height,
          ))

        // Configuration-only children don't render
        ZAxisChild(..) -> Error(Nil)
        StackOffsetChild(..) -> Error(Nil)
        BarLayoutChild(..) -> Error(Nil)
        ReverseStackChild(..) -> Error(Nil)
        LayoutChild(..) -> Error(Nil)
        // Polar and funnel children don't render in cartesian charts
        PieChild(..) -> Error(Nil)
        RadarChild(..) -> Error(Nil)
        RadialBarChild(..) -> Error(Nil)
        FunnelChild(..) -> Error(Nil)

        // Scatter renders in ComposedChart using the cartesian x/y scales.
        // ZAxisChild (if present) controls dot sizing via z-domain/range.
        ScatterChild(config:) -> {
          let scatter_data = case config.data {
            [] -> values_list
            own_data -> own_data
          }
          Ok(scatter.render_scatter_with_z(
            config: config,
            data: scatter_data,
            x_scale: x_scale,
            y_scale: y_scale,
            z_domain_min: cartesian_z_domain_min,
            z_domain_max: cartesian_z_domain_max,
            z_range_min: cartesian_z_range_min,
            z_range_max: cartesian_z_range_max,
          ))
        }
        TreemapChild(..) -> Error(Nil)
        SunburstChild(..) -> Error(Nil)
        SankeyChild(..) -> Error(Nil)
        PolarGridChild(..) -> Error(Nil)
        PolarAngleAxisChild(..) -> Error(Nil)
        PolarRadiusAxisChild(..) -> Error(Nil)
        TitleChild(..) -> Error(Nil)
        DescChild(..) -> Error(Nil)
        RoleChild(..) -> Error(Nil)
        ClassChild(..) -> Error(Nil)
        IdChild(..) -> Error(Nil)
        StyleChild(..) -> Error(Nil)
        SyncIdChild(..) -> Error(Nil)
        SyncMethodChild(..) -> Error(Nil)
        CompactChild -> Error(Nil)
        MaxBarSizeChild(..) -> Error(Nil)
        EventChild(..) -> Error(Nil)
        ThrottleChild(..) -> Error(Nil)
        AccessibilityChild(..) -> Error(Nil)
      }
    })

  // Render tooltip children in a second pass so they appear last in SVG
  // document order (painted on top of all series) and are never wrapped in
  // the clip-path group.  This matches recharts, which renders the tooltip
  // as an HTML <div> positioned above the SVG entirely.
  let rendered_tooltips =
    list.filter_map(children, fn(child) {
      case child {
        TooltipChild(config:) -> {
          // Auto-set cursor type per chart type, matching recharts:
          // BarChart → RectangleCursor, LineChart/AreaChart → VerticalCursor
          // ComposedChart → RectangleCursor when bars present
          let effective_config = case chart_type {
            BarChartType ->
              tooltip.tooltip_cursor_type(config, tooltip.RectangleCursor)
            ComposedChartType ->
              case has_bar_children(children) {
                True ->
                  tooltip.tooltip_cursor_type(config, tooltip.RectangleCursor)
                False -> config
              }
            LineChartType | AreaChartType -> config
          }
          let series_info = collect_series_display_info(children)
          let y_unit = find_y_unit(children)
          let payloads =
            build_tooltip_payloads(
              data,
              series_info,
              x_scale,
              y_scale,
              categories,
              config.include_hidden,
              y_unit,
            )
          let zone_w = case list.length(categories) <= 1 {
            True -> plot.width
            False -> plot.width /. int.to_float(list.length(categories))
          }
          Ok(
            tooltip.render_tooltips(
              config: effective_config,
              payloads: payloads,
              plot_x: plot.x,
              plot_y: plot.y,
              plot_width: plot.width,
              plot_height: plot.height,
              zone_width: zone_w,
              zone_mode: tooltip.ColumnZone,
              zone_extra_attrs: [],
            ),
          )
        }
        _ -> Error(Nil)
      }
    })

  // In ComposedChart, scatter series with their own data produce per-point
  // tooltip hit zones (PointZone), matching recharts which includes scatter
  // tooltips alongside category-based tooltips.
  let rendered_scatter_tooltips = case chart_type {
    ComposedChartType -> {
      let scatter_configs =
        list.filter_map(children, fn(child) {
          case child {
            ScatterChild(config:) ->
              case config.data {
                [] -> Error(Nil)
                _own_data -> Ok(config)
              }
            _ -> Error(Nil)
          }
        })
      case scatter_configs {
        [] -> []
        _ ->
          list.filter_map(children, fn(child) {
            case child {
              TooltipChild(config:) -> {
                let x_name = find_x_name(children)
                let x_unit = find_x_unit(children)
                let y_name = find_y_name(children)
                let y_unit = find_y_unit(children)
                let z_config = find_z_axis_config(children)
                let scatter_payloads =
                  build_scatter_tooltip_payloads(
                    scatter_configs,
                    x_scale,
                    y_scale,
                    x_name,
                    x_unit,
                    y_name,
                    y_unit,
                    z_config,
                    config.include_hidden,
                  )
                let scatter_config =
                  tooltip.TooltipConfig(
                    ..config,
                    cursor_type: tooltip.CrossCursor,
                  )
                Ok(
                  tooltip.render_tooltips(
                    config: scatter_config,
                    payloads: scatter_payloads,
                    plot_x: plot.x,
                    plot_y: plot.y,
                    plot_width: plot.width,
                    plot_height: plot.height,
                    zone_width: 20.0,
                    zone_mode: tooltip.PointZone,
                    zone_extra_attrs: [],
                  ),
                )
              }
              _ -> Error(Nil)
            }
          })
      }
    }
    _ -> []
  }

  // Build clipPath definition for the plot area
  let clip_defs =
    svg.defs([
      svg.clip_path(id: clip_path_id, children: [
        svg.rect(
          x: math.fmt(plot.x),
          y: math.fmt(plot.y),
          width: math.fmt(plot.width),
          height: math.fmt(plot.height),
          attrs: [],
        ),
      ]),
    ])

  // Tooltip CSS
  let style_el =
    svg.el(tag: "style", attrs: [], children: [
      element.text(tooltip_css()),
    ])

  build_svg(
    width: width,
    height: height,
    svg_children: list.flatten([
      [clip_defs, style_el],
      rendered_children,
      rendered_tooltips,
      rendered_scatter_tooltips,
    ]),
    children: children,
  )
}

// ---------------------------------------------------------------------------
// Internal: Polar rendering
// ---------------------------------------------------------------------------

type PolarChartType {
  PieChartType
  RadarChartType
  RadialBarChartType
}

fn render_polar(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
  chart_type _chart_type: PolarChartType,
) -> Element(msg) {
  let w = int.to_float(width)
  let h = int.to_float(height)
  // Reserve vertical space for a bottom- or top-aligned legend so the
  // polar chart does not overlap it.
  let legend_offset =
    int.to_float(find_legend_height_offset(children, legend.AlignBottom))
    +. int.to_float(find_legend_height_offset(children, legend.AlignTop))
  let h_inner = h -. legend_offset
  let cx = w /. 2.0
  let cy = h_inner /. 2.0
  let max_radius = math.list_min([cx, cy]) *. 0.8

  let categories = list.map(data, fn(dp) { dp.category })
  let values_list = list.map(data, fn(dp) { dp.values })
  let data_keys = collect_data_keys(children)

  // Domain for radar/radial bar
  let all_values =
    list.flat_map(values_list, fn(vals) {
      list.filter_map(data_keys, fn(key) { dict.get(vals, key) })
    })
  let domain_max = math.list_max(all_values)

  // Compute angles for polar grid
  let n_cats = list.length(categories)
  let angle_step = case n_cats == 0 {
    True -> 0.0
    False -> 360.0 /. int.to_float(n_cats)
  }
  let polar_angles =
    list.index_map(categories, fn(_cat, i) { int.to_float(i) *. angle_step })

  // Default radii for polar grid (5 concentric rings)
  let n_rings = 5
  let polar_radii =
    int.range(from: 1, to: n_rings + 1, with: [], run: fn(acc, i) {
      [max_radius *. int.to_float(i) /. int.to_float(n_rings), ..acc]
    })
    |> list.reverse

  // Build legend payload
  let legend_payload = build_legend_payload(children)

  // Build pie tooltip payloads from each PieChild's sector centroids.
  // Matches recharts tooltipPosition = polarToCartesian(cx, cy, middleRadius, midAngle).
  let pie_tooltip_payloads =
    list.flat_map(children, fn(child) {
      case child {
        PieChild(config:) -> {
          let #(pie_data, pie_cats) = case config.data {
            [] -> #(values_list, categories)
            own_data -> {
              let cats =
                list.index_map(own_data, fn(_d, i) {
                  case
                    list.filter_map(own_data, fn(d) {
                      dict.get(d, config.name_key)
                    })
                  {
                    [] -> "item-" <> int.to_string(i)
                    names ->
                      case list_at(names, i) {
                        Ok(n) -> float_to_cat(n)
                        Error(_) -> "item-" <> int.to_string(i)
                      }
                  }
                })
              #(own_data, cats)
            }
          }
          list.map(
            pie.pie_sector_infos(
              config: config,
              data: pie_data,
              categories: pie_cats,
              width: w,
              height: h,
            ),
            fn(info) {
              tooltip.TooltipPayload(
                x: info.centroid_x,
                y: info.centroid_y,
                label: "",
                active_dots: [],
                entries: [
                  tooltip.TooltipEntry(
                    name: info.category,
                    value: info.value,
                    color: info.fill,
                    unit: "",
                    hidden: False,
                    entry_type: tooltip.VisibleEntry,
                  ),
                ],
                zone_width: 0.0,
                zone_height: 0.0,
              )
            },
          )
        }
        _ -> []
      }
    })

  // Render pie tooltips if a TooltipChild is present.
  let pie_zone_width =
    list.fold(children, 60.0, fn(acc, child) {
      case child {
        PieChild(config:) -> {
          let max_r = float.min(w, h) /. 2.0
          let r = case config.outer_radius <=. 1.0 {
            True -> config.outer_radius *. max_r
            False -> float.min(config.outer_radius, max_r)
          }
          float.max(acc, r)
        }
        _ -> acc
      }
    })

  let rendered_pie_tooltips =
    list.filter_map(children, fn(child) {
      case child {
        TooltipChild(config:) ->
          case pie_tooltip_payloads {
            [] -> Error(Nil)
            payloads -> {
              // Pie charts have no cursor — recharts shows no line/cross on hover,
              // only the tooltip popup itself.
              let config =
                tooltip.TooltipConfig(..config, cursor_type: tooltip.NoCursor)
              Ok(
                tooltip.render_tooltips(
                  config: config,
                  payloads: payloads,
                  plot_x: 0.0,
                  plot_y: 0.0,
                  plot_width: w,
                  plot_height: h,
                  zone_width: pie_zone_width,
                  zone_mode: tooltip.PointZone,
                  zone_extra_attrs: [],
                ),
              )
            }
          }
        _ -> Error(Nil)
      }
    })

  // Tooltip CSS (needed if any tooltip children exist)
  let pie_style_els = case
    list.any(children, fn(c) {
      case c {
        TooltipChild(..) -> True
        _ -> False
      }
    })
  {
    False -> []
    True -> [
      svg.el(tag: "style", attrs: [], children: [element.text(tooltip_css())]),
    ]
  }

  let rendered_children =
    list.filter_map(children, fn(child) {
      case child {
        PolarGridChild(config:) ->
          Ok(grid.render_polar_grid(
            config: config,
            cx: cx,
            cy: cy,
            inner_radius: 0.0,
            outer_radius: max_radius,
            angles: polar_angles,
            radii: polar_radii,
          ))

        PolarAngleAxisChild(config:) ->
          Ok(polar_axis.render_angle_axis(
            config: config,
            cx: cx,
            cy: cy,
            radius: max_radius,
            categories: categories,
            angles: polar_angles,
          ))

        PolarRadiusAxisChild(config:) ->
          Ok(polar_axis.render_radius_axis(
            config: config,
            cx: cx,
            cy: cy,
            inner_radius: 0.0,
            outer_radius: max_radius,
            domain_max: domain_max,
          ))

        PieChild(config:) -> {
          // When the pie has its own data, use it instead of chart-level data.
          // Matches recharts Pie `data` prop behavior.
          let #(pie_data, pie_cats) = case config.data {
            [] -> #(values_list, categories)
            own_data -> {
              let cats =
                list.index_map(own_data, fn(_d, i) {
                  case
                    list.filter_map(own_data, fn(d) {
                      dict.get(d, config.name_key)
                    })
                  {
                    [] -> "item-" <> int.to_string(i)
                    names ->
                      case list_at(names, i) {
                        Ok(n) -> float_to_cat(n)
                        Error(_) -> "item-" <> int.to_string(i)
                      }
                  }
                })
              #(own_data, cats)
            }
          }
          Ok(pie.render_pie(
            config: config,
            data: pie_data,
            categories: pie_cats,
            width: w,
            height: h,
          ))
        }

        RadarChild(config:) ->
          Ok(radar.render_radar(
            config: config,
            data: values_list,
            categories: categories,
            cx: cx,
            cy: cy,
            max_radius: max_radius,
            domain_max: domain_max,
          ))

        RadialBarChild(config:) -> {
          // When the radial bar has its own data, use it instead of chart-level data.
          // Matches recharts RadialBar `data` prop behavior.
          let #(rb_data, rb_cats) = case config.data {
            [] -> #(values_list, categories)
            own_data -> {
              let cats =
                list.index_map(own_data, fn(_d, i) {
                  "item-" <> int.to_string(i)
                })
              #(own_data, cats)
            }
          }
          Ok(radial_bar.render_radial_bars(
            config: config,
            data: rb_data,
            categories: rb_cats,
            cx: cx,
            cy: cy,
            domain_max: domain_max,
          ))
        }

        LegendChild(config:) ->
          Ok(legend.render_legend(
            config: config,
            payload: legend_payload,
            chart_width: w,
            chart_height: h,
          ))

        // Non-polar and configuration-only children are skipped
        MarginChild(..) -> Error(Nil)
        ZAxisChild(..) -> Error(Nil)
        StackOffsetChild(..) -> Error(Nil)
        BarLayoutChild(..) -> Error(Nil)
        ReverseStackChild(..) -> Error(Nil)
        LayoutChild(..) -> Error(Nil)
        GridChild(..) -> Error(Nil)
        XAxisChild(..) -> Error(Nil)
        YAxisChild(..) -> Error(Nil)
        AreaChild(..) -> Error(Nil)
        BarChild(..) -> Error(Nil)
        LineChild(..) -> Error(Nil)
        ScatterChild(..) -> Error(Nil)
        FunnelChild(..) -> Error(Nil)
        TreemapChild(..) -> Error(Nil)
        SunburstChild(..) -> Error(Nil)
        SankeyChild(..) -> Error(Nil)
        ReferenceLineChild(..) -> Error(Nil)
        ReferenceAreaChild(..) -> Error(Nil)
        ReferenceDotChild(..) -> Error(Nil)
        ErrorBarChild(..) -> Error(Nil)
        TooltipChild(..) -> Error(Nil)
        TitleChild(..) -> Error(Nil)
        DescChild(..) -> Error(Nil)
        RoleChild(..) -> Error(Nil)
        ClassChild(..) -> Error(Nil)
        IdChild(..) -> Error(Nil)
        StyleChild(..) -> Error(Nil)
        SyncIdChild(..) -> Error(Nil)
        SyncMethodChild(..) -> Error(Nil)
        CompactChild -> Error(Nil)
        MaxBarSizeChild(..) -> Error(Nil)
        EventChild(..) -> Error(Nil)
        ThrottleChild(..) -> Error(Nil)
        AccessibilityChild(..) -> Error(Nil)
        BrushChild(..) -> Error(Nil)
      }
    })

  build_svg(
    width: width,
    height: height,
    svg_children: list.flatten([
      pie_style_els,
      rendered_children,
      rendered_pie_tooltips,
    ]),
    children: children,
  )
}

// ---------------------------------------------------------------------------
// Internal: Scatter chart rendering
// ---------------------------------------------------------------------------

fn render_scatter_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  let chart_margin =
    find_margin(children)
    |> adjust_margin_for_axes(children)
    |> adjust_margin_for_legend(children)
    |> adjust_margin_for_brush(children)
  let plot =
    layout.plot_area(width: width, height: height, margin: chart_margin)

  let _categories = list.map(data, fn(dp) { dp.category })
  let values_list = list.map(data, fn(dp) { dp.values })

  // Collect scatter configs for domain computation
  let scatter_configs =
    list.filter_map(children, fn(child) {
      case child {
        ScatterChild(config:) -> Ok(config)
        _ -> Error(Nil)
      }
    })

  let x_data_keys = list.map(scatter_configs, fn(c) { c.x_data_key })
  let y_data_keys = list.map(scatter_configs, fn(c) { c.y_data_key })

  // Build a combined values list: chart-level data + per-series data from each
  // scatter config.  recharts Scatter accepts its own `data` prop; we must
  // include those rows when computing axis domains so the scale covers all points.
  let all_values_list =
    list.append(values_list, list.flat_map(scatter_configs, fn(c) { c.data }))

  // Compute x/y domains from scatter data keys across all data sources
  let x_values =
    list.flat_map(all_values_list, fn(vals) {
      list.filter_map(x_data_keys, fn(key) { dict.get(vals, key) })
    })
  let y_values =
    list.flat_map(all_values_list, fn(vals) {
      list.filter_map(y_data_keys, fn(key) { dict.get(vals, key) })
    })

  let x_data_domain = scale.auto_domain_from_zero(x_values)
  let y_data_domain = scale.auto_domain_from_zero(y_values)

  // Axis reversal
  let x_reversed = find_x_reversed(children)
  let y_reversed = find_y_reversed(children)

  let #(x_range_start, x_range_end) = case x_reversed {
    True -> #(plot.x +. plot.width, plot.x)
    False -> #(plot.x, plot.x +. plot.width)
  }
  let #(y_range_start, y_range_end) = case y_reversed {
    True -> #(plot.y, plot.y +. plot.height)
    False -> #(plot.y +. plot.height, plot.y)
  }

  // Custom x domain
  let #(has_x_domain, x_dm_min, x_dm_max, x_allow_overflow) =
    find_x_domain_config(children)
  let x_domain_final = case has_x_domain {
    True ->
      case x_allow_overflow {
        True -> #(x_dm_min, x_dm_max)
        False -> #(
          math.list_min([x_dm_min, x_data_domain.0]),
          math.list_max([x_dm_max, x_data_domain.1]),
        )
      }
    False -> x_data_domain
  }

  // Custom y domain
  let y_allow_overflow = find_y_allow_data_overflow(children)
  let y_domain_final = find_y_domain(children, y_data_domain, y_allow_overflow)

  // Build scales — scatter always uses numeric x-axis
  let x_scale =
    scale.linear(
      domain_min: x_domain_final.0,
      domain_max: x_domain_final.1,
      range_start: x_range_start,
      range_end: x_range_end,
    )

  let y_scale_type = find_y_scale_type(children)
  let y_scale = case y_scale_type {
    axis.LinearScaleType ->
      scale.linear(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
      )
    axis.LogScaleType(base:) ->
      scale.log(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
        base: base,
      )
    axis.SqrtScaleType ->
      scale.sqrt_scale(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
      )
    axis.PowerScaleType(exponent:) ->
      scale.power(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
        exponent: exponent,
      )
    axis.TimeScaleType ->
      scale.time(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
      )
    axis.OrdinalScaleType
    | axis.AutoScaleType
    | axis.IdentityScaleType
    | axis.BandScaleType
    | axis.PointScaleType ->
      scale.linear(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
      )
  }

  // Extract ZAxis config if present
  let z_axis_config = find_z_axis_config(children)

  // Compute z-domain from data when ZAxis is present
  let #(z_domain_min, z_domain_max, z_range_min_val, z_range_max_val) = case
    z_axis_config
  {
    Ok(zc) -> {
      let z_values =
        list.filter_map(all_values_list, fn(vals) {
          dict.get(vals, zc.data_key)
        })
      let z_dom = scale.auto_domain(z_values)
      #(z_dom.0, z_dom.1, zc.range_min, zc.range_max)
    }
    Error(_) -> #(0.0, 0.0, 0.0, 0.0)
  }

  // Build legend payload
  let legend_payload = build_legend_payload(children)

  // Clip path
  let clip_path_id = "weft-chart-clip"

  // Render children
  let rendered_children =
    list.filter_map(children, fn(child) {
      case child {
        MarginChild(..) -> Error(Nil)

        GridChild(config:) -> {
          let effective_config = case config.sync_with_ticks {
            False -> config
            True -> {
              let x_ticks = scale.ticks(x_scale, 5, True)
              let x_tick_coords = list.map(x_ticks, fn(t) { t.coordinate })
              let y_ticks = scale.ticks(y_scale, 5, True)
              let y_tick_coords = list.map(y_ticks, fn(t) { t.coordinate })
              grid.grid_sync_tick_coords(
                config:,
                x_coords: x_tick_coords,
                y_coords: y_tick_coords,
              )
            }
          }
          Ok(grid.render_cartesian_grid(
            config: effective_config,
            x_scale: x_scale,
            y_scale: y_scale,
            plot_x: plot.x,
            plot_y: plot.y,
            plot_width: plot.width,
            plot_height: plot.height,
          ))
        }

        XAxisChild(config:) ->
          Ok(axis.render_x_axis(
            config: config,
            x_scale: x_scale,
            plot_y: plot.y,
            plot_height: plot.height,
          ))

        YAxisChild(config:) ->
          Ok(axis.render_y_axis(
            config: config,
            y_scale: y_scale,
            plot_x: plot.x,
            plot_width: plot.width,
          ))

        ScatterChild(config:) -> {
          // When the scatter has its own data, use it instead of chart-level data.
          // Matches recharts Scatter `data` prop behavior.
          let scatter_data = case config.data {
            [] -> values_list
            own_data -> own_data
          }
          // Scatter dots are not clipped — recharts lets dots extend beyond
          // the plot boundary so points near the edge show as full circles.
          Ok(scatter.render_scatter_with_z(
            config: config,
            data: scatter_data,
            x_scale: x_scale,
            y_scale: y_scale,
            z_domain_min: z_domain_min,
            z_domain_max: z_domain_max,
            z_range_min: z_range_min_val,
            z_range_max: z_range_max_val,
          ))
        }

        // Tooltip is handled in a separate pass after all other children
        // so it is always the last element in SVG document order and paints
        // on top of all series.
        TooltipChild(..) -> Error(Nil)

        LegendChild(config:) ->
          Ok(legend.render_legend(
            config: config,
            payload: legend_payload,
            chart_width: int.to_float(width),
            chart_height: int.to_float(height),
          ))

        ReferenceLineChild(config:) ->
          Ok(reference.render_reference_line(
            config: config,
            x_scale: x_scale,
            y_scale: y_scale,
            plot_x: plot.x,
            plot_y: plot.y,
            plot_width: plot.width,
            plot_height: plot.height,
            clip_path_id: clip_path_id,
          ))

        ReferenceAreaChild(config:) ->
          Ok(reference.render_reference_area(
            config: config,
            x_scale: x_scale,
            y_scale: y_scale,
            plot_x: plot.x,
            plot_y: plot.y,
            plot_width: plot.width,
            plot_height: plot.height,
            clip_path_id: clip_path_id,
          ))

        ReferenceDotChild(config:) ->
          Ok(reference.render_reference_dot(
            config: config,
            x_scale: x_scale,
            y_scale: y_scale,
            plot_x: plot.x,
            plot_y: plot.y,
            plot_width: plot.width,
            plot_height: plot.height,
            clip_path_id: clip_path_id,
          ))

        // Configuration-only and non-scatter children are skipped
        ZAxisChild(..) -> Error(Nil)
        StackOffsetChild(..) -> Error(Nil)
        BarLayoutChild(..) -> Error(Nil)
        ReverseStackChild(..) -> Error(Nil)
        LayoutChild(..) -> Error(Nil)
        AreaChild(..) -> Error(Nil)
        BarChild(..) -> Error(Nil)
        LineChild(..) -> Error(Nil)
        ErrorBarChild(..) -> Error(Nil)
        PieChild(..) -> Error(Nil)
        RadarChild(..) -> Error(Nil)
        RadialBarChild(..) -> Error(Nil)
        FunnelChild(..) -> Error(Nil)
        TreemapChild(..) -> Error(Nil)
        SunburstChild(..) -> Error(Nil)
        SankeyChild(..) -> Error(Nil)
        PolarGridChild(..) -> Error(Nil)
        PolarAngleAxisChild(..) -> Error(Nil)
        PolarRadiusAxisChild(..) -> Error(Nil)
        TitleChild(..) -> Error(Nil)
        DescChild(..) -> Error(Nil)
        RoleChild(..) -> Error(Nil)
        ClassChild(..) -> Error(Nil)
        IdChild(..) -> Error(Nil)
        StyleChild(..) -> Error(Nil)
        SyncIdChild(..) -> Error(Nil)
        SyncMethodChild(..) -> Error(Nil)
        CompactChild -> Error(Nil)
        MaxBarSizeChild(..) -> Error(Nil)
        EventChild(..) -> Error(Nil)
        ThrottleChild(..) -> Error(Nil)
        AccessibilityChild(..) -> Error(Nil)
        BrushChild(..) -> Error(Nil)
      }
    })

  // Render tooltip children last so they paint on top of all series.
  let rendered_tooltips =
    list.filter_map(children, fn(child) {
      case child {
        TooltipChild(config:) -> {
          // Scatter charts always use a crosshair cursor — matches recharts
          // Cross component which renders two perpendicular lines.
          let config =
            tooltip.TooltipConfig(..config, cursor_type: tooltip.CrossCursor)
          let x_name = find_x_name(children)
          let x_unit = find_x_unit(children)
          let y_name = find_y_name(children)
          let y_unit = find_y_unit(children)
          let z_config = find_z_axis_config(children)
          let payloads =
            build_scatter_tooltip_payloads(
              scatter_configs,
              x_scale,
              y_scale,
              x_name,
              x_unit,
              y_name,
              y_unit,
              z_config,
              config.include_hidden,
            )
          let zone_w = 20.0
          Ok(
            tooltip.render_tooltips(
              config: config,
              payloads: payloads,
              plot_x: plot.x,
              plot_y: plot.y,
              plot_width: plot.width,
              plot_height: plot.height,
              zone_width: zone_w,
              zone_mode: tooltip.PointZone,
              zone_extra_attrs: [],
            ),
          )
        }
        _ -> Error(Nil)
      }
    })

  // Clip path definition
  let clip_defs =
    svg.defs([
      svg.clip_path(id: clip_path_id, children: [
        svg.rect(
          x: math.fmt(plot.x),
          y: math.fmt(plot.y),
          width: math.fmt(plot.width),
          height: math.fmt(plot.height),
          attrs: [],
        ),
      ]),
    ])

  let style_el =
    svg.el(tag: "style", attrs: [], children: [
      element.text(tooltip_css()),
    ])

  build_svg(
    width: width,
    height: height,
    svg_children: list.flatten([
      [clip_defs, style_el],
      rendered_children,
      rendered_tooltips,
    ]),
    children: children,
  )
}

/// Build tooltip payloads for scatter charts.
/// Each data point in each series produces one payload at that point's
/// screen position.  Entry labels use axis names when provided; otherwise
/// fall back to the data key.  Hidden series are suppressed unless
/// include_hidden is set.
fn build_scatter_tooltip_payloads(
  scatter_configs: List(scatter.ScatterConfig(msg)),
  x_scale: scale.Scale,
  y_scale: scale.Scale,
  x_name: String,
  x_unit: String,
  y_name: String,
  y_unit: String,
  z_config: Result(axis.ZAxisConfig, Nil),
  include_hidden: Bool,
) -> List(tooltip.TooltipPayload) {
  let resolve = fn(name: String, fallback: String) -> String {
    case name {
      "" -> fallback
      n -> n
    }
  }
  let #(z_name, z_unit) = case z_config {
    Ok(cfg) -> #(cfg.name, cfg.unit)
    Error(_) -> #("", "")
  }
  list.flat_map(scatter_configs, fn(sc) {
    case sc.hide, include_hidden {
      // Suppress all points from hidden series unless include_hidden is set.
      True, False -> []
      _, _ ->
        list.map(sc.data, fn(dp) {
          let x_val = case dict.get(dp, sc.x_data_key) {
            Ok(v) -> v
            Error(_) -> 0.0
          }
          let y_val = case dict.get(dp, sc.y_data_key) {
            Ok(v) -> v
            Error(_) -> 0.0
          }
          let px = scale.apply(x_scale, x_val)
          let py = scale.apply(y_scale, y_val)
          let x_entry =
            tooltip.TooltipEntry(
              name: resolve(x_name, sc.x_data_key),
              value: x_val,
              color: sc.fill,
              unit: x_unit,
              hidden: sc.hide,
              entry_type: tooltip.VisibleEntry,
            )
          let y_entry =
            tooltip.TooltipEntry(
              name: resolve(y_name, sc.y_data_key),
              value: y_val,
              color: sc.fill,
              unit: y_unit,
              hidden: sc.hide,
              entry_type: tooltip.VisibleEntry,
            )
          let z_entries = case sc.z_data_key {
            "" -> []
            z_key ->
              case dict.get(dp, z_key) {
                Ok(z_val) -> [
                  tooltip.TooltipEntry(
                    name: resolve(z_name, z_key),
                    value: z_val,
                    color: sc.fill,
                    unit: z_unit,
                    hidden: sc.hide,
                    entry_type: tooltip.VisibleEntry,
                  ),
                ]
                Error(_) -> []
              }
          }
          // recharts scatter tooltip shows no label header — the series name
          // is displayed in the legend, not repeated in the tooltip popup.
          tooltip.TooltipPayload(
            label: "",
            entries: list.flatten([[x_entry, y_entry], z_entries]),
            x: px,
            y: py,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        })
    }
  })
}

// ---------------------------------------------------------------------------
// Internal: Funnel chart rendering
// ---------------------------------------------------------------------------

fn render_funnel_chart(
  data data: List(DataPoint),
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  let w = int.to_float(width)
  let h = int.to_float(height)
  let values_list = list.map(data, fn(dp) { dp.values })

  // Build legend payload
  let legend_payload = build_legend_payload(children)

  // Collect funnel configs for tooltip payload building
  let funnel_configs =
    list.filter_map(children, fn(child) {
      case child {
        FunnelChild(config:) -> Ok(config)
        _ -> Error(Nil)
      }
    })

  let rendered_children =
    list.filter_map(children, fn(child) {
      case child {
        FunnelChild(config:) ->
          Ok(funnel.render_funnel(
            config: config,
            data: values_list,
            categories: list.map(data, fn(dp) { dp.category }),
            width: w,
            height: h,
          ))

        LegendChild(config:) ->
          Ok(legend.render_legend(
            config: config,
            payload: legend_payload,
            chart_width: w,
            chart_height: h,
          ))

        // Non-funnel children are skipped in funnel charts
        _ -> Error(Nil)
      }
    })

  // Render tooltip in a second pass so it paints on top of all series.
  // Funnel segments use per-segment hit zones covering the full constrained
  // width x segment height, matching recharts Funnel tooltip positioning
  // (Funnel.tsx: tooltipPosition = { x: x + upperWidth/2, y: y + rowHeight/2 }).
  let rendered_tooltips =
    list.filter_map(children, fn(child) {
      case child {
        TooltipChild(config:) -> {
          // Funnel has no cartesian cursor — suppress cursor rendering
          let effective_config =
            tooltip.TooltipConfig(
              ..config,
              show_cursor: False,
              cursor_type: tooltip.NoCursor,
            )
          let payloads =
            build_funnel_tooltip_payloads(
              configs: funnel_configs,
              data: data,
              width: w,
              height: h,
            )
          Ok(
            tooltip.render_tooltips(
              config: effective_config,
              payloads: payloads,
              plot_x: 0.0,
              plot_y: 0.0,
              plot_width: w,
              plot_height: h,
              zone_width: 1.0,
              zone_mode: tooltip.PointZone,
              zone_extra_attrs: [],
            ),
          )
        }
        _ -> Error(Nil)
      }
    })

  let style_el =
    svg.el(tag: "style", attrs: [], children: [element.text(tooltip_css())])

  build_svg(
    width: width,
    height: height,
    svg_children: list.flatten([
      [style_el],
      rendered_children,
      rendered_tooltips,
    ]),
    children: children,
  )
}

/// Build tooltip payloads for funnel chart segments.
///
/// Mirrors the segment geometry from `render_funnel` (sort order, gap
/// arithmetic, 50 px width deduction) and produces one `TooltipPayload`
/// per segment whose hit zone covers the full constrained width x
/// segment height.  The label comes from `DataPoint.category`, matching
/// recharts' `nameKey` behaviour (recharts Funnel.tsx line 149).
fn build_funnel_tooltip_payloads(
  configs configs: List(funnel.FunnelConfig(msg)),
  data data: List(DataPoint),
  width width: Float,
  height height: Float,
) -> List(tooltip.TooltipPayload) {
  // Match render_funnel: 50px deduction (Funnel.tsx getRealWidthHeight line 127)
  let constrained_width = width -. 50.0
  let cx = constrained_width /. 2.0

  list.flat_map(configs, fn(config) {
    case config.hide {
      True -> []
      False -> {
        // Build (orig_index, category, value) triples from data
        let indexed =
          list.index_map(data, fn(dp, i) {
            let v = case dict.get(dp.values, config.data_key) {
              Ok(val) -> math.abs(val)
              Error(_) -> 0.0
            }
            #(i, dp.category, v)
          })

        // Sort descending by value — matches render_funnel sort order
        let sorted = list.sort(indexed, fn(a, b) { float.compare(b.2, a.2) })

        let n = list.length(sorted)
        case n {
          0 -> []
          _ -> {
            let total_gap = int.to_float(n - 1) *. config.trap_gap
            let seg_height = { height -. total_gap } /. int.to_float(n)
            let safe_seg = case seg_height <. 0.0 {
              True -> 0.0
              False -> seg_height
            }

            // Reversed mode: visual top-to-bottom order goes narrow to wide
            let ordered = case config.reversed {
              False -> sorted
              True -> list.reverse(sorted)
            }

            list.index_map(ordered, fn(t, seg_i) {
              let #(orig_i, category, value) = t
              let seg_y = int.to_float(seg_i) *. { safe_seg +. config.trap_gap }
              let cy = seg_y +. safe_seg /. 2.0

              // Cycle fill colours by original data index (matches render_funnel)
              let fill_color = funnel_cycle_fill(config.fills, orig_i)

              let entry =
                tooltip.TooltipEntry(
                  name: config.data_key,
                  value: value,
                  color: fill_color,
                  unit: "",
                  hidden: False,
                  entry_type: tooltip.VisibleEntry,
                )

              tooltip.TooltipPayload(
                label: category,
                entries: [entry],
                x: cx,
                y: cy,
                active_dots: [],
                // Zone covers the full constrained width x segment height
                zone_width: constrained_width,
                zone_height: safe_seg,
              )
            })
          }
        }
      }
    }
  })
}

// Cycle through a fill colour list by index, matching funnel.gleam cycle_fill.
fn funnel_cycle_fill(fills: List(String), index: Int) -> String {
  let n = list.length(fills)
  case n == 0 {
    True -> "#808080"
    False -> funnel_find_at(fills, index % n, 0)
  }
}

fn funnel_find_at(items: List(String), target: Int, current: Int) -> String {
  case items {
    [] -> "#808080"
    [head, ..tail] ->
      case current == target {
        True -> head
        False -> funnel_find_at(tail, target, current + 1)
      }
  }
}

fn render_treemap_chart(
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  let legend_payload = build_legend_payload(children)

  // Find the first treemap config for building tooltip payloads
  let treemap_config =
    list.find_map(children, fn(child) {
      case child {
        TreemapChild(config:) -> Ok(config)
        _ -> Error(Nil)
      }
    })

  let rendered_children =
    list.filter_map(children, fn(child) {
      case child {
        TreemapChild(config:) ->
          Ok(treemap.render_treemap(
            config: config,
            width: width,
            height: height,
          ))

        LegendChild(config:) ->
          Ok(legend.render_legend(
            config: config,
            payload: legend_payload,
            chart_width: int.to_float(width),
            chart_height: int.to_float(height),
          ))

        _ -> Error(Nil)
      }
    })

  let w = int.to_float(width)
  let h = int.to_float(height)

  let rendered_tooltips =
    list.filter_map(children, fn(child) {
      case child {
        TooltipChild(config:) -> {
          case treemap_config {
            Error(_) -> Error(Nil)
            Ok(tm_config) -> {
              // Treemap has no cartesian cursor — suppress it
              let config =
                tooltip.TooltipConfig(
                  ..config,
                  show_cursor: False,
                  cursor_type: tooltip.NoCursor,
                )
              let payloads =
                treemap.build_treemap_tooltip_payloads(
                  config: tm_config,
                  width: width,
                  height: height,
                )
              // Build per-zone click attrs when treemap has on_click.
              // The tooltip zones sit on top of treemap cells in SVG
              // z-order, so we forward click events through the zone
              // rects to the treemap's on_click handler.
              let click_attrs =
                build_treemap_zone_click_attrs(
                  config: tm_config,
                  width: width,
                  height: height,
                )
              Ok(tooltip.render_tooltips(
                config: config,
                payloads: payloads,
                plot_x: 0.0,
                plot_y: 0.0,
                plot_width: w,
                plot_height: h,
                zone_width: 1.0,
                zone_mode: tooltip.PointZone,
                zone_extra_attrs: click_attrs,
              ))
            }
          }
        }
        _ -> Error(Nil)
      }
    })

  let style_el =
    svg.el(tag: "style", attrs: [], children: [
      element.text(tooltip_css()),
    ])

  build_svg(
    width: width,
    height: height,
    svg_children: list.flatten([
      [style_el],
      rendered_children,
      rendered_tooltips,
    ]),
    children: children,
  )
}

// Build per-zone click attributes for treemap tooltip zones.
// Returns one List(Attribute) per tooltip payload, parallel to
// `build_treemap_tooltip_payloads`.  Each list contains a click handler
// that forwards to the treemap's `on_click` with the corresponding node,
// plus a cursor style so the user sees a pointer.
fn build_treemap_zone_click_attrs(
  config config: treemap.TreemapConfig(msg),
  width width: Int,
  height height: Int,
) -> List(List(Attribute(msg))) {
  case config.on_click {
    None -> []
    Some(handler) -> {
      let nodes =
        treemap.tooltip_payload_nodes(
          config: config,
          width: width,
          height: height,
        )
      list.map(nodes, fn(node) {
        [
          lustre_event.on("click", decode.success(handler(node))),
          attribute.style("cursor", "pointer"),
        ]
      })
    }
  }
}

fn render_sunburst_chart(
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  let w = int.to_float(width)
  let h = int.to_float(height)
  let legend_payload = build_legend_payload(children)

  // Build tooltip payloads from each sector centroid — same PointZone pattern as PieChart.
  let sunburst_tooltip_payloads =
    list.flat_map(children, fn(child) {
      case child {
        SunburstChild(config:) ->
          list.map(
            sunburst.sunburst_sector_infos(
              config: config,
              width: width,
              height: height,
            ),
            fn(info) {
              tooltip.TooltipPayload(
                x: info.centroid_x,
                y: info.centroid_y,
                label: "",
                active_dots: [],
                entries: [
                  tooltip.TooltipEntry(
                    name: info.name,
                    value: info.value,
                    color: info.fill,
                    unit: "",
                    hidden: False,
                    entry_type: tooltip.VisibleEntry,
                  ),
                ],
                zone_width: 0.0,
                zone_height: 0.0,
              )
            },
          )
        _ -> []
      }
    })

  // Zone width = resolved outer_radius of the sunburst (same as pie pattern).
  let sunburst_zone_width =
    list.fold(children, float.min(w, h) /. 2.0, fn(acc, child) {
      case child {
        SunburstChild(config:) ->
          case config.outer_radius <=. 0.0 {
            True -> float.min(w, h) /. 2.0
            False -> config.outer_radius
          }
        _ -> acc
      }
    })

  let rendered_sunburst_tooltips =
    list.filter_map(children, fn(child) {
      case child {
        TooltipChild(config:) ->
          case sunburst_tooltip_payloads {
            [] -> Error(Nil)
            payloads -> {
              let config =
                tooltip.TooltipConfig(..config, cursor_type: tooltip.NoCursor)
              Ok(
                tooltip.render_tooltips(
                  config: config,
                  payloads: payloads,
                  plot_x: 0.0,
                  plot_y: 0.0,
                  plot_width: w,
                  plot_height: h,
                  zone_width: sunburst_zone_width,
                  zone_mode: tooltip.PointZone,
                  zone_extra_attrs: [],
                ),
              )
            }
          }
        _ -> Error(Nil)
      }
    })

  let sunburst_style_els = case
    list.any(children, fn(c) {
      case c {
        TooltipChild(..) -> True
        _ -> False
      }
    })
  {
    False -> []
    True -> [
      svg.el(tag: "style", attrs: [], children: [element.text(tooltip_css())]),
    ]
  }

  let rendered_children =
    list.filter_map(children, fn(child) {
      case child {
        SunburstChild(config:) ->
          Ok(sunburst.render_sunburst(
            config: config,
            width: width,
            height: height,
          ))

        LegendChild(config:) ->
          Ok(legend.render_legend(
            config: config,
            payload: legend_payload,
            chart_width: w,
            chart_height: h,
          ))

        _ -> Error(Nil)
      }
    })

  build_svg(
    width: width,
    height: height,
    svg_children: list.flatten([
      sunburst_style_els,
      rendered_children,
      rendered_sunburst_tooltips,
    ]),
    children: children,
  )
}

fn render_sankey_chart(
  width width: Int,
  height height: Int,
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  let legend_payload = build_legend_payload(children)
  let w = int.to_float(width)
  let h = int.to_float(height)

  // Build PointZone tooltip payloads from node centroids and link midpoints.
  // Nodes use the node name; links use "source - target" (matching recharts).
  let sankey_tooltip_payloads =
    list.flat_map(children, fn(child) {
      case child {
        SankeyChild(config:) -> {
          let to_payload = fn(info: sankey.SankeyHitInfo) {
            tooltip.TooltipPayload(
              x: info.centroid_x,
              y: info.centroid_y,
              label: "",
              active_dots: [],
              entries: [
                tooltip.TooltipEntry(
                  name: info.name,
                  value: info.value,
                  color: info.fill,
                  unit: "",
                  hidden: False,
                  entry_type: tooltip.VisibleEntry,
                ),
              ],
              zone_width: info.node_width,
              zone_height: info.node_height,
            )
          }
          let node_payloads =
            list.map(
              sankey.sankey_hit_infos(
                config: config,
                width: width,
                height: height,
              ),
              to_payload,
            )
          let link_payloads =
            list.map(
              sankey.sankey_link_hit_infos(
                config: config,
                width: width,
                height: height,
              ),
              to_payload,
            )
          list.append(node_payloads, link_payloads)
        }
        _ -> []
      }
    })

  let sankey_style_els = case
    list.any(children, fn(c) {
      case c {
        TooltipChild(..) -> True
        _ -> False
      }
    })
  {
    False -> []
    True -> [
      svg.el(tag: "style", attrs: [], children: [element.text(tooltip_css())]),
    ]
  }

  let rendered_sankey_tooltips =
    list.filter_map(children, fn(child) {
      case child {
        TooltipChild(config:) ->
          case sankey_tooltip_payloads {
            [] -> Error(Nil)
            payloads ->
              Ok(
                tooltip.render_tooltips(
                  config: tooltip.TooltipConfig(
                    ..config,
                    cursor_type: tooltip.NoCursor,
                  ),
                  payloads: payloads,
                  plot_x: 0.0,
                  plot_y: 0.0,
                  plot_width: w,
                  plot_height: h,
                  zone_width: 0.0,
                  zone_mode: tooltip.PointZone,
                  zone_extra_attrs: [],
                ),
              )
          }
        _ -> Error(Nil)
      }
    })

  let rendered_children =
    list.filter_map(children, fn(child) {
      case child {
        SankeyChild(config:) ->
          Ok(sankey.render_sankey(config: config, width: width, height: height))

        LegendChild(config:) ->
          Ok(legend.render_legend(
            config: config,
            payload: legend_payload,
            chart_width: w,
            chart_height: h,
          ))

        _ -> Error(Nil)
      }
    })

  build_svg(
    width: width,
    height: height,
    svg_children: list.flatten([
      sankey_style_els,
      rendered_children,
      rendered_sankey_tooltips,
    ]),
    children: children,
  )
}

// ---------------------------------------------------------------------------
// SVG wrapper
// ---------------------------------------------------------------------------

fn find_title(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      TitleChild(text:) -> text
      _ -> acc
    }
  })
}

fn find_desc(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      DescChild(text:) -> text
      _ -> acc
    }
  })
}

fn find_role(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      RoleChild(role:) -> role
      _ -> acc
    }
  })
}

fn find_class(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      ClassChild(class:) -> class
      _ -> acc
    }
  })
}

fn find_id(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      IdChild(id:) -> id
      _ -> acc
    }
  })
}

fn find_style(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      StyleChild(style:) -> style
      _ -> acc
    }
  })
}

fn find_sync_id(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      SyncIdChild(id:) -> id
      _ -> acc
    }
  })
}

fn find_sync_method(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      SyncMethodChild(method:) ->
        case method {
          SyncByIndex -> "index"
          SyncByValue -> "value"
        }
      _ -> acc
    }
  })
}

fn find_compact(children: List(ChartChild(msg))) -> Bool {
  list.any(children, fn(child) {
    case child {
      CompactChild -> True
      _ -> False
    }
  })
}

fn find_max_bar_size(children: List(ChartChild(msg))) -> Int {
  list.fold(children, 0, fn(acc, child) {
    case child {
      MaxBarSizeChild(size:) -> size
      _ -> acc
    }
  })
}

fn find_throttle(children: List(ChartChild(msg))) -> Option(Int) {
  list.fold(children, None, fn(acc, child) {
    case child {
      ThrottleChild(delay_ms:) -> Some(delay_ms)
      _ -> acc
    }
  })
}

fn find_a11y(children: List(ChartChild(msg))) -> Option(a11y.A11yConfig(msg)) {
  list.fold(children, None, fn(acc, child) {
    case child {
      AccessibilityChild(config:) -> Some(config)
      _ -> acc
    }
  })
}

fn collect_a11y_attrs(config: a11y.A11yConfig(msg)) -> List(Attribute(msg)) {
  case config.enabled {
    False -> []
    True -> {
      let tab_attr = [
        svg.attr("tabindex", int.to_string(config.tab_index)),
      ]
      let label_attr = case config.description {
        None -> []
        Some(desc) -> [svg.attr("aria-label", desc)]
      }
      let focus_attr = case config.on_focus {
        None -> []
        Some(handler) -> [
          lustre_event.on("focus", decode.success(handler())),
        ]
      }
      let blur_attr = case config.on_blur {
        None -> []
        Some(handler) -> [
          lustre_event.on("blur", decode.success(handler())),
        ]
      }
      let keydown_attr = case config.on_key_down {
        None -> []
        Some(handler) -> [
          lustre_event.on("keydown", {
            use key <- decode.field("key", decode.string)
            decode.success(handler(key))
          }),
        ]
      }
      list.flatten([tab_attr, label_attr, focus_attr, blur_attr, keydown_attr])
    }
  }
}

fn collect_a11y_children(config: a11y.A11yConfig(msg)) -> List(Element(msg)) {
  case config.enabled {
    False -> []
    True ->
      case config.live_region_content {
        None -> []
        Some(content) -> [a11y.live_region(content: content)]
      }
  }
}

fn collect_event_attrs(children: List(ChartChild(msg))) -> List(Attribute(msg)) {
  list.flat_map(children, fn(child) {
    case child {
      EventChild(handler:) -> chart_event_to_attrs(handler)
      _ -> []
    }
  })
}

fn chart_event_to_attrs(evt: ChartEvent(msg)) -> List(Attribute(msg)) {
  // Build a default ChartEventData (0, "", 0.0, 0.0) since we cannot
  // decode DOM mouse coordinates in pure Gleam without FFI.
  // The handler receives a zero-valued payload; client-side code can
  // enrich it via data attributes or JavaScript interop.
  let default_data =
    event.ChartEventData(
      active_index: 0,
      active_data_key: "",
      chart_x: 0.0,
      chart_y: 0.0,
    )
  case evt {
    event.OnClick(handler:) -> [
      lustre_event.on("click", decode.success(handler(default_data))),
    ]
    event.OnMouseEnter(handler:) -> [
      lustre_event.on("mouseenter", decode.success(handler(default_data))),
    ]
    event.OnMouseLeave(handler:) -> [
      lustre_event.on("mouseleave", decode.success(handler())),
    ]
    event.OnMouseMove(handler:) -> [
      lustre_event.on("mousemove", decode.success(handler(default_data))),
    ]
  }
}

/// Wrap an element in a group with clip-path for series clipping.
fn clip_series(el: Element(msg), clip_id: String) -> Element(msg) {
  svg.g(attrs: [svg.attr("clip-path", "url(#" <> clip_id <> ")")], children: [
    el,
  ])
}

/// Build the outer SVG wrapper using attributes extracted from children.
fn build_svg(
  width width: Int,
  height height: Int,
  svg_children svg_children: List(Element(msg)),
  children children: List(ChartChild(msg)),
) -> Element(msg) {
  let a11y_config = find_a11y(children)
  let #(a11y_attrs, a11y_children, a11y_role) = case a11y_config {
    None -> #([], [], "")
    Some(config) -> #(
      collect_a11y_attrs(config),
      collect_a11y_children(config),
      case config.enabled {
        True -> config.role
        False -> ""
      },
    )
  }
  // A11y role overrides RoleChild when present and non-empty
  let effective_role = case a11y_role {
    "" -> find_role(children)
    r -> r
  }
  wrap_svg(
    width: width,
    height: height,
    children: svg_children,
    title: find_title(children),
    desc: find_desc(children),
    svg_role: effective_role,
    svg_class: find_class(children),
    svg_id: find_id(children),
    svg_style: find_style(children),
    svg_sync_id: find_sync_id(children),
    svg_sync_method: find_sync_method(children),
    event_attrs: collect_event_attrs(children),
    throttle_ms: find_throttle(children),
    a11y_attrs: a11y_attrs,
    a11y_children: a11y_children,
  )
}

fn wrap_svg(
  width width: Int,
  height height: Int,
  children children: List(Element(msg)),
  title title: String,
  desc desc: String,
  svg_role svg_role: String,
  svg_class svg_class: String,
  svg_id svg_id: String,
  svg_style svg_style: String,
  svg_sync_id svg_sync_id: String,
  svg_sync_method svg_sync_method: String,
  event_attrs event_attrs: List(Attribute(msg)),
  throttle_ms throttle_ms: Option(Int),
  a11y_attrs a11y_attrs: List(Attribute(msg)),
  a11y_children a11y_children: List(Element(msg)),
) -> Element(msg) {
  let w = int.to_string(width)
  let h = int.to_string(height)
  let title_els = case title {
    "" -> []
    t -> [svg.el(tag: "title", attrs: [], children: [element.text(t)])]
  }
  let desc_els = case desc {
    "" -> []
    d -> [svg.el(tag: "desc", attrs: [], children: [element.text(d)])]
  }
  let effective_role = case svg_role {
    "" -> "img"
    r -> r
  }
  let effective_style = case svg_style {
    "" -> "display:block;"
    s -> "display:block;" <> s
  }
  let base_attrs = [
    svg.attr("viewBox", "0 0 " <> w <> " " <> h),
    svg.attr("width", w),
    svg.attr("height", h),
    svg.attr("overflow", "visible"),
    svg.attr("preserveAspectRatio", "xMidYMid meet"),
    svg.attr("role", effective_role),
    svg.attr("style", effective_style),
  ]
  let attrs_with_class = case svg_class {
    "" -> base_attrs
    c -> list.append(base_attrs, [svg.attr("class", c)])
  }
  let attrs_with_id = case svg_id {
    "" -> attrs_with_class
    i -> list.append(attrs_with_class, [svg.attr("id", i)])
  }
  let attrs_with_sync = case svg_sync_id {
    "" -> attrs_with_id
    sid -> list.append(attrs_with_id, [svg.attr("data-sync-id", sid)])
  }
  let attrs_with_method = case svg_sync_method {
    "" -> attrs_with_sync
    sm -> list.append(attrs_with_sync, [svg.attr("data-sync-method", sm)])
  }
  let attrs_with_throttle = case throttle_ms {
    None -> attrs_with_method
    Some(ms) ->
      list.append(attrs_with_method, [
        svg.attr("data-throttle-ms", int.to_string(ms)),
      ])
  }
  let attrs_with_events = list.append(attrs_with_throttle, event_attrs)
  let final_attrs = list.append(attrs_with_events, a11y_attrs)
  svg.el(
    tag: "svg",
    attrs: final_attrs,
    children: list.flatten([title_els, desc_els, children, a11y_children]),
  )
}

// ---------------------------------------------------------------------------
// Multi-bar positioning (matching recharts combineAllBarPositions)
// ---------------------------------------------------------------------------

/// Compute bar positions for side-by-side layout when multiple Bar
/// children share the same chart.  Matches recharts barGap (default: 4px)
/// and barCategoryGap (default: 10%) behavior.
fn compute_bar_positions(
  children: List(ChartChild(msg)),
  x_scale: scale.Scale,
  plot_width: Float,
) -> Dict(String, bar.BarPosition) {
  // Collect (data_key, per_series_bar_size) pairs for non-stacked bars
  let bar_key_sizes = collect_bar_key_sizes(children)
  let n_bars = list.length(bar_key_sizes)
  let chart_max_bar = find_max_bar_size(children)

  case n_bars < 1 {
    // No bars: no positioning needed
    True -> dict.new()
    False -> {
      let bw = scale.bandwidth(x_scale)
      // Read chart-level bar layout, or use recharts defaults
      let #(category_gap_pct, bar_gap, chart_bar_size) =
        find_bar_layout(children)

      // Available width after category gap
      let available = bw *. { 1.0 -. category_gap_pct }
      // Total gap space between bars
      let total_gap = int.to_float(n_bars - 1) *. bar_gap

      // Check whether chart-level has a fixed size override
      let has_chart_fixed = case chart_bar_size {
        FixedBarSize(size:) -> size > 0
        PercentBarSize(_) -> True
      }

      // Auto-computed width (used when no fixed size applies)
      let auto_w = { available -. total_gap } /. int.to_float(n_bars)

      // Compute per-bar widths. Per-series bar_size takes precedence over the
      // chart-level auto-computed width when no chart-level override is set.
      // This matches recharts getBarSizeList / getBarPosition behaviour where
      // a Bar's own barSize prop is used as an exact pixel width.
      let per_bar_widths =
        list.map(bar_key_sizes, fn(ks) {
          let #(_key, per_size) = ks
          case has_chart_fixed {
            True ->
              case chart_bar_size {
                FixedBarSize(size:) ->
                  case size > 0 {
                    True -> int.to_float(size)
                    False -> auto_w
                  }
                PercentBarSize(percent:) -> plot_width *. percent
              }
            False ->
              case per_size > 0 {
                True -> int.to_float(per_size)
                False -> auto_w
              }
          }
        })

      // Truncate to integer when > 1.0 (matching recharts originalSize >>= 0)
      let per_bar_widths =
        list.map(per_bar_widths, fn(w) {
          case w >. 1.0 {
            True -> int.to_float(float.truncate(w))
            False -> w
          }
        })

      // Clamp to maxBarSize if set
      let per_bar_widths = case chart_max_bar > 0 {
        False -> per_bar_widths
        True -> {
          let max_f = int.to_float(chart_max_bar)
          list.map(per_bar_widths, fn(w) {
            case w >. max_f {
              True -> max_f
              False -> w
            }
          })
        }
      }

      // Clamp to minimum 1.0
      let per_bar_widths =
        list.map(per_bar_widths, fn(w) {
          case w <. 1.0 {
            True -> 1.0
            False -> w
          }
        })

      // Total width of the bar group (for centering calculation)
      let total_bars_w =
        list.fold(per_bar_widths, 0.0, fn(acc, w) { acc +. w }) +. total_gap

      // Determine whether to use fixed centering or percentage-gap offset.
      // Any per-series or chart-level fixed size triggers center mode.
      let has_any_fixed =
        has_chart_fixed || list.any(bar_key_sizes, fn(ks) { ks.1 > 0 })

      let start_offset = case has_any_fixed {
        True -> { bw -. total_bars_w } /. 2.0
        False -> bw *. category_gap_pct /. 2.0
      }

      // Assign positions sequentially, each bar using its own width
      let #(positions, _) =
        list.fold(
          list.zip(bar_key_sizes, per_bar_widths),
          #(dict.new(), start_offset),
          fn(acc, item) {
            let #(d, current_offset) = acc
            let #(#(key, _per_size), w) = item
            let new_d =
              dict.insert(
                d,
                key,
                bar.BarPosition(offset: current_offset, width: w),
              )
            #(new_d, current_offset +. w +. bar_gap)
          },
        )
      positions
    }
  }
}

/// Find chart-level bar layout configuration from children.
/// Returns #(bar_category_gap, bar_gap, chart_bar_size) with recharts defaults.
fn find_bar_layout(children: List(ChartChild(msg))) -> #(Float, Float, BarSize) {
  list.fold(children, #(0.1, 4.0, FixedBarSize(size: 0)), fn(acc, child) {
    case child {
      BarLayoutChild(bar_category_gap:, bar_gap:, chart_bar_size:) -> #(
        bar_category_gap,
        bar_gap,
        chart_bar_size,
      )
      _ -> acc
    }
  })
}

/// Collect (data_key, bar_size) pairs from non-stacked Bar children.
/// Used by compute_bar_positions to respect per-series barSize props,
/// matching recharts getBarSizeList behaviour.
fn collect_bar_key_sizes(
  children: List(ChartChild(msg)),
) -> List(#(String, Int)) {
  list.filter_map(children, fn(child) {
    case child {
      BarChild(config:) ->
        case config.stack_id {
          "" -> Ok(#(config.data_key, config.bar_size))
          _ -> Error(Nil)
        }
      _ -> Error(Nil)
    }
  })
}

// ---------------------------------------------------------------------------
// Stacking computation (matching recharts getStackedData)
// ---------------------------------------------------------------------------

/// Stack group: stackId -> list of data keys in that group.
type StackGroup {
  StackGroup(stack_id: String, data_keys: List(String))
}

/// Collect stack groups from series children.
fn collect_stack_groups(children: List(ChartChild(msg))) -> List(StackGroup) {
  let stacked_items =
    list.filter_map(children, fn(child) {
      case child {
        AreaChild(config:) ->
          case config.stack_id {
            "" -> Error(Nil)
            sid -> Ok(#(sid, config.data_key))
          }
        BarChild(config:) ->
          case config.stack_id {
            "" -> Error(Nil)
            sid -> Ok(#(sid, config.data_key))
          }
        _ -> Error(Nil)
      }
    })

  // Group by stack_id
  let grouped =
    list.fold(stacked_items, dict.new(), fn(acc, item) {
      let #(sid, key) = item
      let existing = case dict.get(acc, sid) {
        Ok(keys) -> keys
        Error(_) -> []
      }
      dict.insert(acc, sid, list.append(existing, [key]))
    })

  dict.fold(grouped, [], fn(acc, sid, keys) {
    [StackGroup(stack_id: sid, data_keys: keys), ..acc]
  })
}

/// Compute stacked values for all stack groups.
/// Returns: stackId -> dataKey -> list of (baseline, top) pairs per data point.
/// Dispatches to the appropriate offset algorithm matching recharts
/// STACK_OFFSET_MAP: none, sign, expand, positive.
fn compute_stacked_values(
  data: List(Dict(String, Float)),
  groups: List(StackGroup),
  _all_keys: List(String),
  offset_type: StackOffsetType,
) -> Dict(String, Dict(String, List(#(Float, Float)))) {
  list.fold(groups, dict.new(), fn(acc, group) {
    let per_key = case offset_type {
      StackOffsetNone -> offset_none(data, group.data_keys)
      StackOffsetSign -> offset_sign(data, group.data_keys)
      StackOffsetExpand -> offset_expand(data, group.data_keys)
      StackOffsetPositive -> offset_positive(data, group.data_keys)
      StackOffsetWiggle -> offset_wiggle(data, group.data_keys)
      StackOffsetSilhouette -> offset_silhouette(data, group.data_keys)
    }
    dict.insert(acc, group.stack_id, per_key)
  })
}

/// Cumulative stacking (d3 stackOffsetNone).
/// Each series starts where the previous one ended.
fn offset_none(
  data: List(Dict(String, Float)),
  keys: List(String),
) -> Dict(String, List(#(Float, Float))) {
  let init =
    list.fold(keys, dict.new(), fn(acc, key) { dict.insert(acc, key, []) })

  let result =
    list.fold(data, init, fn(acc, values) {
      let #(new_acc, _) =
        list.fold(keys, #(acc, 0.0), fn(state, key) {
          let #(current, running) = state
          let value = case dict.get(values, key) {
            Ok(v) -> v
            Error(_) -> 0.0
          }
          let top = running +. value
          let updated = case dict.get(current, key) {
            Ok(pairs) -> dict.insert(current, key, [#(running, top), ..pairs])
            Error(_) -> dict.insert(current, key, [#(running, top)])
          }
          #(updated, top)
        })
      new_acc
    })

  dict.map_values(result, fn(_key, pairs) { list.reverse(pairs) })
}

/// Diverging stacking (recharts offsetSign).
/// Positive values stack above zero, negative values stack below zero.
/// Direct port of recharts ChartUtils.ts offsetSign.
fn offset_sign(
  data: List(Dict(String, Float)),
  keys: List(String),
) -> Dict(String, List(#(Float, Float))) {
  let init =
    list.fold(keys, dict.new(), fn(acc, key) { dict.insert(acc, key, []) })

  let result =
    list.fold(data, init, fn(acc, values) {
      let #(new_acc, _, _) =
        list.fold(keys, #(acc, 0.0, 0.0), fn(state, key) {
          let #(current, positive, negative) = state
          let value = case dict.get(values, key) {
            Ok(v) -> v
            Error(_) -> 0.0
          }
          case value >=. 0.0 {
            True -> {
              let top = positive +. value
              let updated = case dict.get(current, key) {
                Ok(pairs) ->
                  dict.insert(current, key, [#(positive, top), ..pairs])
                Error(_) -> dict.insert(current, key, [#(positive, top)])
              }
              #(updated, top, negative)
            }
            False -> {
              let top = negative +. value
              let updated = case dict.get(current, key) {
                Ok(pairs) ->
                  dict.insert(current, key, [#(negative, top), ..pairs])
                Error(_) -> dict.insert(current, key, [#(negative, top)])
              }
              #(updated, positive, top)
            }
          }
        })
      new_acc
    })

  dict.map_values(result, fn(_key, pairs) { list.reverse(pairs) })
}

/// Normalized stacking (d3 stackOffsetExpand).
/// Values at each data point are normalized to sum to 1.0,
/// then cumulative stacking is applied.
fn offset_expand(
  data: List(Dict(String, Float)),
  keys: List(String),
) -> Dict(String, List(#(Float, Float))) {
  // Step 1: Normalize values at each data point to sum to 1.0
  let normalized =
    list.map(data, fn(values) {
      let total =
        list.fold(keys, 0.0, fn(acc, key) {
          case dict.get(values, key) {
            Ok(v) -> acc +. v
            Error(_) -> acc
          }
        })
      case total == 0.0 {
        True -> values
        False ->
          list.fold(keys, values, fn(acc, key) {
            case dict.get(values, key) {
              Ok(val) -> dict.insert(acc, key, val /. total)
              Error(_) -> acc
            }
          })
      }
    })

  // Step 2: Apply cumulative stacking
  offset_none(normalized, keys)
}

/// Positive-only stacking (recharts offsetPositive).
/// Like sign offset but negative values are clamped to [0, 0].
/// Direct port of recharts ChartUtils.ts offsetPositive.
fn offset_positive(
  data: List(Dict(String, Float)),
  keys: List(String),
) -> Dict(String, List(#(Float, Float))) {
  let init =
    list.fold(keys, dict.new(), fn(acc, key) { dict.insert(acc, key, []) })

  let result =
    list.fold(data, init, fn(acc, values) {
      let #(new_acc, _) =
        list.fold(keys, #(acc, 0.0), fn(state, key) {
          let #(current, positive) = state
          let value = case dict.get(values, key) {
            Ok(v) -> v
            Error(_) -> 0.0
          }
          case value >=. 0.0 {
            True -> {
              let top = positive +. value
              let updated = case dict.get(current, key) {
                Ok(pairs) ->
                  dict.insert(current, key, [#(positive, top), ..pairs])
                Error(_) -> dict.insert(current, key, [#(positive, top)])
              }
              #(updated, top)
            }
            False -> {
              let updated = case dict.get(current, key) {
                Ok(pairs) -> dict.insert(current, key, [#(0.0, 0.0), ..pairs])
                Error(_) -> dict.insert(current, key, [#(0.0, 0.0)])
              }
              #(updated, positive)
            }
          }
        })
      new_acc
    })

  dict.map_values(result, fn(_key, pairs) { list.reverse(pairs) })
}

/// Silhouette stacking (d3 stackOffsetSilhouette).
/// Centers the stream around zero: baseline[j] = -sum(all values at j) / 2.
fn offset_silhouette(
  data: List(Dict(String, Float)),
  keys: List(String),
) -> Dict(String, List(#(Float, Float))) {
  let none_result = offset_none(data, keys)
  let totals =
    list.map(data, fn(values) {
      list.fold(keys, 0.0, fn(acc, key) {
        case dict.get(values, key) {
          Ok(v) -> acc +. v
          Error(_) -> acc
        }
      })
    })
  dict.map_values(none_result, fn(_key, pairs) {
    list.zip(pairs, totals)
    |> list.map(fn(pair) {
      let #(#(base, top), total) = pair
      let shift = total /. 2.0
      #(base -. shift, top -. shift)
    })
  })
}

/// Wiggle stacking (d3 stackOffsetWiggle).
/// Minimizes weighted wiggle of layers by adjusting baselines so that
/// the weighted sum of slope changes is minimized.
fn offset_wiggle(
  data: List(Dict(String, Float)),
  keys: List(String),
) -> Dict(String, List(#(Float, Float))) {
  let n = list.length(keys)
  case n < 1 {
    True -> dict.new()
    False -> {
      let none_result = offset_none(data, keys)
      let n_f = int.to_float(n)
      let m = list.length(data)
      case m < 1 {
        True -> none_result
        False -> {
          let values_by_key =
            list.map(keys, fn(key) {
              list.map(data, fn(dp) {
                case dict.get(dp, key) {
                  Ok(v) -> v
                  Error(_) -> 0.0
                }
              })
            })
          let offsets =
            list.index_map(data, fn(_dp, j) {
              let sum_weighted =
                list.index_fold(values_by_key, 0.0, fn(acc, key_vals, i) {
                  let v = list_float_at(key_vals, j)
                  let i_f = int.to_float(i)
                  acc +. v *. { n_f -. i_f -. 0.5 } /. n_f
                })
              let total =
                list.fold(values_by_key, 0.0, fn(acc, key_vals) {
                  acc +. list_float_at(key_vals, j)
                })
              case total == 0.0 {
                True -> 0.0
                False -> 0.0 -. sum_weighted
              }
            })
          dict.map_values(none_result, fn(_key, pairs) {
            list.zip(pairs, offsets)
            |> list.map(fn(pair) {
              let #(#(base, top), shift) = pair
              #(base +. shift, top +. shift)
            })
          })
        }
      }
    }
  }
}

/// Get a float value at index from a list, defaulting to 0.0.
fn list_float_at(items: List(Float), index: Int) -> Float {
  case items, index {
    [], _ -> 0.0
    [first, ..], 0 -> first
    [_, ..rest], n -> list_float_at(rest, n - 1)
  }
}

/// Build stacked area baseline from computed stack data.
fn build_stacked_area_baseline(
  baselines: List(#(Float, Float)),
  categories: List(String),
  x_scale: scale.Scale,
  y_scale: scale.Scale,
  default_y: Float,
) -> curve.Baseline {
  let baseline_points =
    list.zip(categories, baselines)
    |> list.map(fn(pair) {
      let #(cat, #(base, _top)) = pair
      let x = scale.point_apply(x_scale, cat)
      let y = case base == 0.0 {
        True -> default_y
        False -> scale.apply(y_scale, base)
      }
      #(x, y)
    })
  curve.PointBaseline(points: baseline_points)
}

/// A point that may or may not have data (for connect_nulls gap handling).
type MaybeAreaPoint {
  AreaValid(x: Float, y: Float)
  AreaMissing
}

/// Render area with stacking and connect_nulls support.
/// Returns a pair: (path/label elements, dot elements) so the caller
/// can apply clip-path to the path group while leaving dots unclipped
/// when `clip_dot` is False.
fn render_area_with_baseline(
  config config: area.AreaConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  x_scale x_scale: scale.Scale,
  y_scale y_scale: scale.Scale,
  baseline baseline: curve.Baseline,
  stacked_data stacked_data: Dict(String, Dict(String, List(#(Float, Float)))),
  layout layout: layout.LayoutDirection,
) -> #(Element(msg), Element(msg)) {
  // Map to maybe-points preserving nulls for gap detection.
  // When Vertical, swap coordinate mapping: categories on Y, values on X.
  let maybe_points = case config.stack_id {
    "" ->
      list.zip(categories, data)
      |> list.map(fn(pair) {
        let #(cat, values) = pair
        case dict.get(values, config.data_key) {
          Ok(value) ->
            case layout {
              layout.Horizontal -> {
                let x = scale.point_apply(x_scale, cat)
                let y = scale.apply(y_scale, value)
                AreaValid(x: x, y: y)
              }
              layout.Vertical -> {
                let x = scale.apply(x_scale, value)
                let y = scale.point_apply(y_scale, cat)
                AreaValid(x: x, y: y)
              }
            }
          Error(_) -> AreaMissing
        }
      })
    sid ->
      case dict.get(stacked_data, sid) {
        Ok(per_key) ->
          case dict.get(per_key, config.data_key) {
            Ok(baselines) ->
              list.zip(categories, baselines)
              |> list.map(fn(pair) {
                let #(cat, #(_base, top)) = pair
                case layout {
                  layout.Horizontal -> {
                    let x = scale.point_apply(x_scale, cat)
                    let y = scale.apply(y_scale, top)
                    AreaValid(x: x, y: y)
                  }
                  layout.Vertical -> {
                    let x = scale.apply(x_scale, top)
                    let y = scale.point_apply(y_scale, cat)
                    AreaValid(x: x, y: y)
                  }
                }
              })
            Error(_) -> []
          }
        Error(_) -> []
      }
  }

  // Extract all valid points (for dots and connect_nulls=True)
  let all_valid =
    list.filter_map(maybe_points, fn(mp) {
      case mp {
        AreaValid(x:, y:) -> Ok(#(x, y))
        AreaMissing -> Error(Nil)
      }
    })

  case all_valid {
    [] -> #(element.none(), element.none())
    _ -> {
      // Determine segments based on connect_nulls
      let segments = case config.connect_nulls {
        True -> [all_valid]
        False -> split_area_segments(maybe_points)
      }

      // Gradient definition
      let gradient_el = case config.gradient_id {
        "" -> element.none()
        id ->
          svg.defs([
            svg.linear_gradient(
              id: id,
              stops: list.map(config.gradient_stops, fn(stop) {
                svg.gradient_stop(
                  offset: stop.offset,
                  color: stop.color,
                  opacity: math.fmt(stop.opacity),
                )
              }),
            ),
          ])
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
                  baseline: baseline,
                )
              let area_el =
                svg.path(d: area_d, attrs: [
                  svg.attr("fill", config.fill),
                  svg.attr("fill-opacity", math.fmt(config.fill_opacity)),
                ])

              let stroke_d =
                curve.path(curve_type: config.curve_type, points: seg)
              let stroke_el =
                svg.path(d: stroke_d, attrs: [
                  svg.attr("stroke", config.stroke),
                  svg.attr("fill", "none"),
                  svg.attr("stroke-width", math.fmt(config.stroke_width)),
                ])

              [area_el, stroke_el]
            }
          }
        })

      // Dots (all valid points, regardless of segments)
      let dot_els = case config.show_dot {
        False -> []
        True ->
          list.map(all_valid, fn(pt) {
            svg.circle(cx: math.fmt(pt.0), cy: math.fmt(pt.1), r: "3", attrs: [
              svg.attr("fill", config.stroke),
              svg.attr("stroke", "var(--weft-chart-bg, #ffffff)"),
              svg.attr("stroke-width", "2"),
            ])
          })
      }

      // Value labels
      let label_els = case config.show_label {
        False -> []
        True ->
          extract_area_valid_values(maybe_points, data, config.data_key)
          |> list.zip(all_valid, _)
          |> list.map(fn(pair) {
            let #(#(px, py), value) = pair
            svg.text(
              x: math.fmt(px),
              y: math.fmt(py -. 10.0),
              content: format_chart_value(value),
              attrs: [
                svg.attr("text-anchor", "middle"),
                svg.attr("font-size", "11"),
                svg.attr("fill", "var(--weft-chart-label, currentColor)"),
              ],
            )
          })
      }

      // Path group: gradient + segments + labels (always clipped)
      let path_el =
        svg.g(
          attrs: [svg.attr("class", "recharts-area-paths")],
          children: list.flatten([[gradient_el], segment_els, label_els]),
        )

      // Dot group: rendered separately so caller can control clipping
      let dots_el =
        svg.g(
          attrs: [svg.attr("class", "recharts-area-dots")],
          children: dot_els,
        )

      #(path_el, dots_el)
    }
  }
}

/// Split maybe-area-points into contiguous segments of valid points.
/// Each AreaMissing creates a break between segments.
fn split_area_segments(
  maybe_points: List(MaybeAreaPoint),
) -> List(List(#(Float, Float))) {
  let #(segments, current) =
    list.fold(maybe_points, #([], []), fn(state, mp) {
      let #(done, acc) = state
      case mp {
        AreaValid(x:, y:) -> #(done, [#(x, y), ..acc])
        AreaMissing ->
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Extract the layout direction from children, defaulting to Horizontal.
fn find_layout(children: List(ChartChild(msg))) -> layout.LayoutDirection {
  list.fold(children, layout.Horizontal, fn(acc, child) {
    case child {
      LayoutChild(layout:) -> layout
      _ -> acc
    }
  })
}

fn find_margin(children: List(ChartChild(msg))) -> layout.Margin {
  case find_compact(children) {
    True -> layout.Margin(top: 0, right: 0, bottom: 0, left: 0)
    False ->
      list.fold(children, layout.default_margin(), fn(acc, child) {
        case child {
          MarginChild(margin:) -> margin
          _ -> acc
        }
      })
  }
}

/// Adjust chart margin to account for explicit axis width/height.
/// When an axis specifies a non-zero width or height, that space is added
/// to the corresponding margin side.  This matches recharts behavior where
/// XAxis.height and YAxis.width control the space reserved for the axis.
fn adjust_margin_for_axes(
  margin: layout.Margin,
  children: List(ChartChild(msg)),
) -> layout.Margin {
  list.fold(children, margin, fn(acc, child) {
    case child {
      XAxisChild(config:) ->
        case config.height > 0 {
          True ->
            case config.orientation {
              axis.Bottom ->
                layout.Margin(..acc, bottom: acc.bottom + config.height)
              axis.Top -> layout.Margin(..acc, top: acc.top + config.height)
              _ -> acc
            }
          False -> acc
        }
      YAxisChild(config:) ->
        case config.width > 0 {
          True ->
            case config.orientation {
              axis.Left -> layout.Margin(..acc, left: acc.left + config.width)
              axis.Right ->
                layout.Margin(..acc, right: acc.right + config.width)
              _ -> acc
            }
          False -> acc
        }
      _ -> acc
    }
  })
}

fn adjust_margin_for_legend(
  margin: layout.Margin,
  children: List(ChartChild(msg)),
) -> layout.Margin {
  list.fold(children, margin, fn(acc, child) {
    case child {
      LegendChild(config:) ->
        case config.layout {
          legend.HorizontalLegend -> {
            let h = legend.legend_estimated_height(config)
            case config.vertical_align {
              legend.AlignBottom -> layout.Margin(..acc, bottom: acc.bottom + h)
              legend.AlignTop -> layout.Margin(..acc, top: acc.top + h)
              legend.AlignMiddle -> acc
            }
          }
          legend.VerticalLegend -> {
            let w = legend.legend_estimated_width(config)
            case config.align {
              legend.AlignLeft -> layout.Margin(..acc, left: acc.left + w)
              legend.AlignRight -> layout.Margin(..acc, right: acc.right + w)
              legend.AlignCenter -> acc
            }
          }
        }
      _ -> acc
    }
  })
}

fn adjust_margin_for_brush(
  margin: layout.Margin,
  children: List(ChartChild(msg)),
) -> layout.Margin {
  list.fold(children, margin, fn(acc, child) {
    case child {
      BrushChild(config:) -> {
        let h = float.round(config.height)
        layout.Margin(..acc, bottom: acc.bottom + h)
      }
      _ -> acc
    }
  })
}

fn find_legend_height_offset(
  children: List(ChartChild(msg)),
  align: legend.LegendVerticalAlign,
) -> Int {
  list.fold(children, 0, fn(acc, child) {
    case child {
      LegendChild(config:) ->
        case config.vertical_align == align {
          True -> acc + legend.legend_estimated_height(config)
          False -> acc
        }
      _ -> acc
    }
  })
}

fn find_stack_offset(children: List(ChartChild(msg))) -> StackOffsetType {
  list.fold(children, StackOffsetNone, fn(acc, child) {
    case child {
      StackOffsetChild(offset:) -> offset
      _ -> acc
    }
  })
}

/// Extract the reverse stack order setting from children.
fn find_reverse_stack_order(children: List(ChartChild(msg))) -> Bool {
  list.fold(children, False, fn(acc, child) {
    case child {
      ReverseStackChild(reverse:) -> reverse
      _ -> acc
    }
  })
}

fn find_x_reversed(children: List(ChartChild(msg))) -> Bool {
  list.fold(children, False, fn(acc, child) {
    case child {
      XAxisChild(config:) -> config.reversed
      _ -> acc
    }
  })
}

fn find_y_reversed(children: List(ChartChild(msg))) -> Bool {
  list.fold(children, False, fn(acc, child) {
    case child {
      YAxisChild(config:) -> config.reversed
      _ -> acc
    }
  })
}

fn find_y_domain(
  children: List(ChartChild(msg)),
  data_domain: #(Float, Float),
  allow_overflow: Bool,
) -> #(Float, Float) {
  list.fold(children, data_domain, fn(acc, child) {
    case child {
      YAxisChild(config:) ->
        case config.has_custom_domain {
          True ->
            case allow_overflow {
              // allowDataOverflow=true: use custom domain as-is
              True -> #(config.domain_min, config.domain_max)
              // allowDataOverflow=false: extend custom domain to include data
              False -> #(
                math.list_min([config.domain_min, data_domain.0]),
                math.list_max([config.domain_max, data_domain.1]),
              )
            }
          False -> acc
        }
      _ -> acc
    }
  })
}

/// Extract the y-axis unit string for tooltip display.
fn find_y_unit(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      YAxisChild(config:) -> config.unit
      _ -> acc
    }
  })
}

fn find_x_unit(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      XAxisChild(config:) -> config.unit
      _ -> acc
    }
  })
}

fn find_x_name(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      XAxisChild(config:) -> config.name
      _ -> acc
    }
  })
}

fn find_y_name(children: List(ChartChild(msg))) -> String {
  list.fold(children, "", fn(acc, child) {
    case child {
      YAxisChild(config:) -> config.name
      _ -> acc
    }
  })
}

/// Extract the y-axis scale type.
fn find_y_scale_type(children: List(ChartChild(msg))) -> axis.ScaleType {
  list.fold(children, axis.LinearScaleType, fn(acc, child) {
    case child {
      YAxisChild(config:) -> config.scale_type
      _ -> acc
    }
  })
}

// ---------------------------------------------------------------------------
// Multi-axis helpers
// ---------------------------------------------------------------------------

/// Collect all Y-axis configurations keyed by axis_id.
/// When no Y-axis children are present, returns a single default axis.
fn collect_y_axis_configs(
  children: List(ChartChild(msg)),
) -> Dict(String, axis.YAxisConfig(msg)) {
  let configs =
    list.fold(children, dict.new(), fn(acc, child) {
      case child {
        YAxisChild(config:) -> dict.insert(acc, config.axis_id, config)
        _ -> acc
      }
    })
  case dict.size(configs) == 0 {
    True -> dict.from_list([#("0", axis.y_axis_config())])
    False -> configs
  }
}

/// Group data keys by their bound y-axis ID.
/// Used to compute per-axis domains when multiple Y-axes are present.
fn collect_data_keys_by_y_axis(
  children: List(ChartChild(msg)),
) -> Dict(String, List(String)) {
  list.fold(children, dict.new(), fn(acc, child) {
    case child {
      AreaChild(config:) -> dict_append(acc, config.y_axis_id, config.data_key)
      BarChild(config:) -> dict_append(acc, config.y_axis_id, config.data_key)
      LineChild(config:) -> dict_append(acc, config.y_axis_id, config.data_key)
      _ -> acc
    }
  })
}

/// Append a value to the list under a key in a Dict.
fn dict_append(
  d: Dict(String, List(String)),
  key: String,
  value: String,
) -> Dict(String, List(String)) {
  let existing = case dict.get(d, key) {
    Ok(items) -> items
    Error(_) -> []
  }
  dict.insert(d, key, list.append(existing, [value]))
}

/// Build a y-scale for a single Y-axis config, given its bound data keys.
fn build_y_scale_for_axis(
  config: axis.YAxisConfig(msg),
  bound_keys: List(String),
  values_list: List(Dict(String, Float)),
  stacked_data: Dict(String, Dict(String, List(#(Float, Float)))),
  offset_type: StackOffsetType,
  plot_y: Float,
  plot_height: Float,
  children: List(ChartChild(msg)),
  axis_id: String,
) -> scale.Scale {
  // Compute domain from bound series values + stacked extents
  let raw_vals =
    list.flat_map(values_list, fn(vals) {
      list.filter_map(bound_keys, fn(key) { dict.get(vals, key) })
    })
  let stacked_vals = case dict.size(stacked_data) > 0 {
    True ->
      list.flat_map(dict.values(stacked_data), fn(per_key_baselines) {
        list.flat_map(dict.to_list(per_key_baselines), fn(pair) {
          let #(key, baselines) = pair
          case list.contains(bound_keys, key) {
            True -> list.flat_map(baselines, fn(p) { [p.0, p.1] })
            False -> []
          }
        })
      })
    False -> []
  }
  let all_values = list.append(raw_vals, stacked_vals)

  let has_negative = list.any(all_values, fn(v) { v <. 0.0 })
  let y_domain = case offset_type {
    StackOffsetSign | StackOffsetSilhouette | StackOffsetWiggle ->
      scale.auto_domain(all_values)
    _ ->
      case has_negative {
        True -> scale.auto_domain(all_values)
        False -> scale.auto_domain_from_zero(all_values)
      }
  }

  // Extend domain for reference elements with ExtendDomain overflow
  let y_domain = extend_domain_for_references(y_domain, children, axis_id, "y")

  // Apply custom domain if configured
  let y_domain_final = case config.has_custom_domain {
    True ->
      case config.allow_data_overflow {
        True -> #(config.domain_min, config.domain_max)
        False -> #(
          math.list_min([config.domain_min, y_domain.0]),
          math.list_max([config.domain_max, y_domain.1]),
        )
      }
    False -> y_domain
  }

  // Range with reversed support
  let #(y_range_start, y_range_end) = case config.reversed {
    True -> #(plot_y, plot_y +. plot_height)
    False -> #(plot_y +. plot_height, plot_y)
  }

  case config.scale_type {
    axis.LinearScaleType ->
      scale.linear(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
      )
    axis.LogScaleType(base:) ->
      scale.log(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
        base: base,
      )
    axis.SqrtScaleType ->
      scale.sqrt_scale(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
      )
    axis.PowerScaleType(exponent:) ->
      scale.power(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
        exponent: exponent,
      )
    axis.TimeScaleType ->
      scale.time(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
      )
    axis.OrdinalScaleType
    | axis.AutoScaleType
    | axis.IdentityScaleType
    | axis.BandScaleType
    | axis.PointScaleType ->
      scale.linear(
        domain_min: y_domain_final.0,
        domain_max: y_domain_final.1,
        range_start: y_range_start,
        range_end: y_range_end,
      )
  }
}

/// Extend a numeric domain to include reference element values
/// when they use `ExtendDomain` overflow behavior.
fn extend_domain_for_references(
  domain: #(Float, Float),
  children: List(ChartChild(msg)),
  axis_id: String,
  axis_type: String,
) -> #(Float, Float) {
  list.fold(children, domain, fn(acc, child) {
    case child {
      ReferenceLineChild(config:) ->
        case config.if_overflow == reference.ExtendDomain {
          True -> {
            let matches = case axis_type {
              "y" -> config.y_axis_id == axis_id
              _ -> config.x_axis_id == axis_id
            }
            case matches {
              True -> #(
                math.list_min([acc.0, config.value]),
                math.list_max([acc.1, config.value]),
              )
              False -> acc
            }
          }
          False -> acc
        }
      ReferenceAreaChild(config:) ->
        case config.if_overflow == reference.ExtendDomain {
          True -> {
            let matches = case axis_type {
              "y" -> config.y_axis_id == axis_id
              _ -> config.x_axis_id == axis_id
            }
            case matches {
              True -> #(
                math.list_min([acc.0, config.value1, config.value2]),
                math.list_max([acc.1, config.value1, config.value2]),
              )
              False -> acc
            }
          }
          False -> acc
        }
      ReferenceDotChild(config:) ->
        case config.if_overflow == reference.ExtendDomain {
          True ->
            case axis_type {
              "y" ->
                case config.y_axis_id == axis_id {
                  True -> #(
                    math.list_min([acc.0, config.y]),
                    math.list_max([acc.1, config.y]),
                  )
                  False -> acc
                }
              _ ->
                case config.x_axis_id == axis_id {
                  True -> #(
                    math.list_min([acc.0, config.x]),
                    math.list_max([acc.1, config.x]),
                  )
                  False -> acc
                }
            }
          False -> acc
        }
      _ -> acc
    }
  })
}

/// Build all Y-axis scales as a Dict keyed by axis_id.
fn build_y_scales(
  y_configs: Dict(String, axis.YAxisConfig(msg)),
  data_keys_by_axis: Dict(String, List(String)),
  all_data_keys: List(String),
  values_list: List(Dict(String, Float)),
  stacked_data: Dict(String, Dict(String, List(#(Float, Float)))),
  offset_type: StackOffsetType,
  plot_y: Float,
  plot_height: Float,
  children: List(ChartChild(msg)),
) -> Dict(String, scale.Scale) {
  dict.fold(y_configs, dict.new(), fn(acc, axis_id, config) {
    // Keys bound to this axis; fallback to all keys if none explicitly bound
    let bound_keys = case dict.get(data_keys_by_axis, axis_id) {
      Ok(keys) -> keys
      Error(_) ->
        case axis_id == "0" {
          True -> all_data_keys
          False -> []
        }
    }
    let y_scale =
      build_y_scale_for_axis(
        config,
        bound_keys,
        values_list,
        stacked_data,
        offset_type,
        plot_y,
        plot_height,
        children,
        axis_id,
      )
    dict.insert(acc, axis_id, y_scale)
  })
}

/// Look up a scale by axis_id, falling back to the "0" default.
fn get_scale(scales: Dict(String, scale.Scale), axis_id: String) -> scale.Scale {
  case dict.get(scales, axis_id) {
    Ok(s) -> s
    Error(_) ->
      case dict.get(scales, "0") {
        Ok(s) -> s
        Error(_) ->
          // Last resort: linear scale
          scale.linear(
            domain_min: 0.0,
            domain_max: 1.0,
            range_start: 0.0,
            range_end: 1.0,
          )
      }
  }
}

/// Compute the y-position offset for a secondary Y-axis on the same side.
/// When multiple Y-axes share the same orientation (Left or Right), each
/// additional axis is offset by the previous axes' widths.
fn compute_y_axis_offset(
  axis_id: String,
  orientation: axis.AxisOrientation,
  y_configs: Dict(String, axis.YAxisConfig(msg)),
) -> Float {
  let sorted_ids = dict.keys(y_configs) |> list.sort(by: string_compare)
  let same_side =
    list.filter(sorted_ids, fn(id) {
      case dict.get(y_configs, id) {
        Ok(c) -> c.orientation == orientation
        Error(_) -> False
      }
    })
  // Sum widths of all same-side axes that come before this one
  list.fold(same_side, 0.0, fn(acc, id) {
    case id == axis_id {
      True -> acc
      False ->
        case string_compare(id, axis_id) {
          order.Lt ->
            case dict.get(y_configs, id) {
              Ok(c) ->
                case c.width > 0 {
                  True -> acc +. int.to_float(c.width)
                  False -> acc +. 60.0
                }
              Error(_) -> acc
            }
          _ -> acc
        }
    }
  })
}

/// Simple string comparison for sorting.
fn string_compare(a: String, b: String) -> order.Order {
  string.compare(a, b)
}

/// Extract the z-axis configuration from children, if present.
fn find_z_axis_config(
  children: List(ChartChild(msg)),
) -> Result(axis.ZAxisConfig, Nil) {
  list.find_map(children, fn(child) {
    case child {
      ZAxisChild(config:) -> Ok(config)
      _ -> Error(Nil)
    }
  })
}

fn find_y_allow_data_overflow(children: List(ChartChild(msg))) -> Bool {
  list.fold(children, False, fn(acc, child) {
    case child {
      YAxisChild(config:) -> config.allow_data_overflow
      _ -> acc
    }
  })
}

/// Extract x-axis domain config.
/// Used when x-axis type is NumberAxis for numeric x-scales.
fn find_x_domain_config(
  children: List(ChartChild(msg)),
) -> #(Bool, Float, Float, Bool) {
  list.fold(children, #(False, 0.0, 0.0, False), fn(acc, child) {
    case child {
      XAxisChild(config:) ->
        case config.type_ {
          axis.NumberAxis -> #(
            config.has_custom_domain,
            config.domain_min,
            config.domain_max,
            config.allow_data_overflow,
          )
          axis.CategoryAxis -> acc
        }
      _ -> acc
    }
  })
}

/// Check if x-axis is configured as numeric type.
fn find_x_is_numeric(children: List(ChartChild(msg))) -> Bool {
  list.fold(children, False, fn(acc, child) {
    case child {
      XAxisChild(config:) ->
        case config.type_ {
          axis.NumberAxis -> True
          axis.CategoryAxis -> acc
        }
      _ -> acc
    }
  })
}

/// Extract the x-axis padding mode from children.
fn find_x_padding_mode(children: List(ChartChild(msg))) -> axis.PaddingMode {
  list.fold(children, axis.ExplicitPadding(left: 0, right: 0), fn(acc, child) {
    case child {
      XAxisChild(config:) -> config.padding
      _ -> acc
    }
  })
}

/// Resolve padding mode to adjusted range endpoints.
/// GapPadding adds half-bandwidth inward on each side.
/// NoGapPadding uses the raw range as-is (zero padding).
/// ExplicitPadding adjusts by the given pixel amounts.
fn resolve_x_padding(
  mode: axis.PaddingMode,
  range_start: Float,
  range_end: Float,
  n_categories: Int,
) -> #(Float, Float) {
  case mode {
    axis.ExplicitPadding(left:, right:) -> {
      let l = int.to_float(left)
      let r = int.to_float(right)
      case range_start <. range_end {
        True -> #(range_start +. l, range_end -. r)
        False -> #(range_start -. l, range_end +. r)
      }
    }
    axis.GapPadding -> {
      // Half-bandwidth padding: bandwidth = total_range / n_categories
      case n_categories <= 0 {
        True -> #(range_start, range_end)
        False -> {
          let total = math.abs(range_end -. range_start)
          let half_bw = total /. int.to_float(n_categories) /. 2.0
          case range_start <. range_end {
            True -> #(range_start +. half_bw, range_end -. half_bw)
            False -> #(range_start -. half_bw, range_end +. half_bw)
          }
        }
      }
    }
    axis.NoGapPadding -> #(range_start, range_end)
  }
}

/// Check if children include any Bar series.
fn has_bar_children(children: List(ChartChild(msg))) -> Bool {
  list.any(children, fn(child) {
    case child {
      BarChild(..) -> True
      _ -> False
    }
  })
}

fn collect_data_keys(children: List(ChartChild(msg))) -> List(String) {
  list.filter_map(children, fn(child) {
    case child {
      AreaChild(config:) -> Ok(config.data_key)
      BarChild(config:) -> Ok(config.data_key)
      LineChild(config:) -> Ok(config.data_key)
      PieChild(config:) -> Ok(config.data_key)
      RadarChild(config:) -> Ok(config.data_key)
      RadialBarChild(config:) -> Ok(config.data_key)
      ScatterChild(config:) -> Ok(config.y_data_key)
      FunnelChild(config:) -> Ok(config.data_key)
      _ -> Error(Nil)
    }
  })
}

/// Collect series info tuples: #(data_key, display_name, color, hidden, no_tooltip).
/// When a series has a non-empty `name`, it is used as the display name
/// for tooltip and legend.  Otherwise `data_key` is used.
/// Color matches the series' stroke/fill for tooltip indicator display.
/// The `no_tooltip` flag is True when the series has `NoTooltip` tooltip_type,
/// meaning it should be excluded from tooltip payloads regardless of visibility.
/// The `unit` string is the per-series unit; when non-empty it overrides the
/// y-axis unit in tooltip entries.
/// Matches recharts series `name` prop fallback behavior.
fn collect_series_display_info(
  children: List(ChartChild(msg)),
) -> List(#(String, String, String, Bool, Bool, String)) {
  list.filter_map(children, fn(child) {
    case child {
      AreaChild(config:) ->
        Ok(#(
          config.data_key,
          series_display_name(config.name, config.data_key),
          config.stroke,
          config.hide,
          is_no_tooltip(config.tooltip_type),
          config.unit,
        ))
      BarChild(config:) ->
        Ok(#(
          config.data_key,
          series_display_name(config.name, config.data_key),
          config.fill,
          config.hide,
          is_no_tooltip(config.tooltip_type),
          config.unit,
        ))
      LineChild(config:) ->
        Ok(#(
          config.data_key,
          series_display_name(config.name, config.data_key),
          config.stroke,
          config.hide,
          is_no_tooltip(config.tooltip_type),
          config.unit,
        ))
      PieChild(config:) ->
        Ok(#(
          config.data_key,
          series_display_name("", config.data_key),
          "var(--color-" <> config.data_key <> ", currentColor)",
          config.hide,
          is_no_tooltip(config.tooltip_type),
          "",
        ))
      RadarChild(config:) ->
        Ok(#(
          config.data_key,
          series_display_name(config.name, config.data_key),
          config.stroke,
          config.hide,
          is_no_tooltip(config.tooltip_type),
          "",
        ))
      RadialBarChild(config:) ->
        Ok(#(
          config.data_key,
          series_display_name("", config.data_key),
          "var(--color-" <> config.data_key <> ", currentColor)",
          config.hide,
          is_no_tooltip(config.tooltip_type),
          "",
        ))
      ScatterChild(config:) ->
        Ok(#(
          config.y_data_key,
          series_display_name(config.name, config.y_data_key),
          config.fill,
          config.hide,
          is_no_tooltip(config.tooltip_type),
          "",
        ))
      _ -> Error(Nil)
    }
  })
}

/// Check if a tooltip type is NoTooltip.
fn is_no_tooltip(tooltip_type: shape.TooltipType) -> Bool {
  case tooltip_type {
    shape.NoTooltip -> True
    shape.DefaultTooltip -> False
  }
}

/// Resolve display name: use name when non-empty, otherwise data_key.
fn series_display_name(name: String, data_key: String) -> String {
  case name {
    "" -> data_key
    n -> n
  }
}

fn build_tooltip_payloads(
  data: List(DataPoint),
  series_info: List(#(String, String, String, Bool, Bool, String)),
  x_scale: scale.Scale,
  y_scale: scale.Scale,
  categories: List(String),
  include_hidden: Bool,
  y_unit: String,
) -> List(tooltip.TooltipPayload) {
  list.zip(categories, data)
  |> list.map(fn(pair) {
    let #(cat, dp) = pair
    let x = scale.point_apply(x_scale, cat)

    let entries =
      list.filter_map(series_info, fn(info) {
        let #(data_key, display_name, color, hidden, no_tooltip, series_unit) =
          info
        // Per-series unit overrides y-axis unit when non-empty
        let effective_unit = case series_unit {
          "" -> y_unit
          u -> u
        }
        // Skip NoTooltip series unconditionally
        // Skip hidden series unless include_hidden is set
        case no_tooltip {
          True -> Error(Nil)
          False ->
            case hidden && !include_hidden {
              True -> Error(Nil)
              False ->
                case dict.get(dp.values, data_key) {
                  Ok(value) ->
                    Ok(tooltip.TooltipEntry(
                      name: display_name,
                      value: value,
                      color: color,
                      unit: effective_unit,
                      hidden: hidden,
                      entry_type: tooltip.VisibleEntry,
                    ))
                  Error(_) -> Error(Nil)
                }
            }
        }
      })

    // Compute per-entry SVG y coordinates for active dots
    let entry_ys = list.map(entries, fn(e) { scale.apply(y_scale, e.value) })

    // Y position for tooltip popup: average of all entry y values.
    // This centers the popup vertically among all active series rather
    // than anchoring to the first series only.
    let y = case entry_ys {
      [] -> 0.0
      ys -> {
        let sum = list.fold(ys, 0.0, fn(acc, v) { acc +. v })
        sum /. int.to_float(list.length(ys))
      }
    }

    tooltip.TooltipPayload(
      label: cat,
      entries: entries,
      x: x,
      y: y,
      active_dots: entry_ys,
      zone_width: 0.0,
      zone_height: 0.0,
    )
  })
}

/// Build legend payload entries from series children.
/// Uses series `name` when non-empty, falls back to `data_key`.
fn build_legend_payload(
  children: List(ChartChild(msg)),
) -> List(legend.LegendPayload) {
  list.flat_map(children, fn(child) {
    case child {
      AreaChild(config:) -> [
        legend.LegendPayload(
          value: series_display_name(config.name, config.data_key),
          color: config.stroke,
          icon_type: config.legend_type,
          inactive: False,
        ),
      ]
      BarChild(config:) -> [
        legend.LegendPayload(
          value: series_display_name(config.name, config.data_key),
          color: config.fill,
          icon_type: config.legend_type,
          inactive: False,
        ),
      ]
      LineChild(config:) -> [
        legend.LegendPayload(
          value: series_display_name(config.name, config.data_key),
          color: config.stroke,
          icon_type: config.legend_type,
          inactive: False,
        ),
      ]
      PieChild(config:) ->
        // When sector_names is set, produce one legend entry per sector with
        // the sector's fill color — matches recharts per-slice legend behavior.
        case config.sector_names {
          [] -> [
            legend.LegendPayload(
              value: config.data_key,
              color: "var(--color-" <> config.data_key <> ", currentColor)",
              icon_type: config.legend_type,
              inactive: False,
            ),
          ]
          names ->
            list.index_map(names, fn(name, i) {
              let n = list.length(config.fills)
              let fill = case n == 0 {
                True -> "currentColor"
                False ->
                  case list.drop(config.fills, i % n) {
                    [] -> "currentColor"
                    [c, ..] -> c
                  }
              }
              legend.LegendPayload(
                value: name,
                color: fill,
                icon_type: config.legend_type,
                inactive: False,
              )
            })
        }
      RadarChild(config:) -> [
        legend.LegendPayload(
          value: series_display_name(config.name, config.data_key),
          color: config.stroke,
          icon_type: config.legend_type,
          inactive: False,
        ),
      ]
      RadialBarChild(config:) -> [
        legend.LegendPayload(
          value: config.data_key,
          color: "var(--color-" <> config.data_key <> ", currentColor)",
          icon_type: config.legend_type,
          inactive: False,
        ),
      ]
      ScatterChild(config:) -> [
        legend.LegendPayload(
          value: series_display_name(config.name, config.y_data_key),
          color: config.fill,
          icon_type: config.legend_type,
          inactive: False,
        ),
      ]
      FunnelChild(config:) -> [
        legend.LegendPayload(
          value: config.data_key,
          color: "var(--color-" <> config.data_key <> ", currentColor)",
          icon_type: config.legend_type,
          inactive: False,
        ),
      ]
      TreemapChild(config:) -> [
        legend.LegendPayload(
          value: config.data_key,
          color: config.fill,
          icon_type: config.legend_type,
          inactive: False,
        ),
      ]
      SunburstChild(config:) -> [
        legend.LegendPayload(
          value: "sunburst",
          color: config.fill,
          icon_type: config.legend_type,
          inactive: False,
        ),
      ]
      SankeyChild(..) -> [
        legend.LegendPayload(
          value: "sankey",
          color: "#2563eb",
          icon_type: shape.RectIcon,
          inactive: False,
        ),
      ]
      _ -> []
    }
  })
}

/// Resolve an AreaBaseValue to a pixel y-coordinate.
/// Direct port of recharts Area.getBaseValue logic:
/// - Auto: 0 when domain crosses zero, domain_max when all negative,
///   domain_min when all positive
/// - FixedBase(n): use scale(n)
/// - DataMin: use scale(domain_min)
/// - DataMax: use scale(domain_max)
fn resolve_area_base_value(
  base_value: area.AreaBaseValue,
  y_scale: scale.Scale,
  default_baseline_y: Float,
) -> Float {
  case base_value {
    area.Auto -> {
      case extract_domain(y_scale) {
        Ok(#(domain_min, domain_max)) -> {
          case domain_min >=. 0.0 {
            // All positive: baseline at domain min (bottom)
            True -> scale.apply(y_scale, domain_min)
            False ->
              case domain_max <=. 0.0 {
                // All negative: baseline at domain max (closest to zero)
                True -> scale.apply(y_scale, domain_max)
                // Crosses zero: baseline at 0
                False -> scale.apply(y_scale, 0.0)
              }
          }
        }
        Error(_) -> default_baseline_y
      }
    }
    area.FixedBase(value:) -> scale.apply(y_scale, value)
    area.DataMin -> {
      // Use domain minimum — typically the bottom of the chart
      case y_scale {
        scale.LinearScale(domain_min:, ..) -> scale.apply(y_scale, domain_min)
        scale.LogScale(domain_min:, ..) -> scale.apply(y_scale, domain_min)
        scale.SqrtScale(domain_min:, ..) -> scale.apply(y_scale, domain_min)
        scale.PowerScale(domain_min:, ..) -> scale.apply(y_scale, domain_min)
        scale.TimeScale(domain_min:, ..) -> scale.apply(y_scale, domain_min)
        _ -> default_baseline_y
      }
    }
    area.DataMax -> {
      // Use domain maximum — the top of the chart
      case y_scale {
        scale.LinearScale(domain_max:, ..) -> scale.apply(y_scale, domain_max)
        scale.LogScale(domain_max:, ..) -> scale.apply(y_scale, domain_max)
        scale.SqrtScale(domain_max:, ..) -> scale.apply(y_scale, domain_max)
        scale.PowerScale(domain_max:, ..) -> scale.apply(y_scale, domain_max)
        scale.TimeScale(domain_max:, ..) -> scale.apply(y_scale, domain_max)
        _ -> default_baseline_y
      }
    }
  }
}

/// Extract domain min and max from a scale, if available.
fn extract_domain(s: scale.Scale) -> Result(#(Float, Float), Nil) {
  case s {
    scale.LinearScale(domain_min:, domain_max:, ..) ->
      Ok(#(domain_min, domain_max))
    scale.LogScale(domain_min:, domain_max:, ..) ->
      Ok(#(domain_min, domain_max))
    scale.SqrtScale(domain_min:, domain_max:, ..) ->
      Ok(#(domain_min, domain_max))
    scale.PowerScale(domain_min:, domain_max:, ..) ->
      Ok(#(domain_min, domain_max))
    scale.TimeScale(domain_min:, domain_max:, ..) ->
      Ok(#(domain_min, domain_max))
    _ -> Error(Nil)
  }
}

fn tooltip_css() -> String {
  ".chart-hotspot .chart-tooltip-cursor { display: none; }"
  <> ".chart-hotspot .chart-tooltip-dot { display: none; }"
  <> ".chart-hotspot .chart-tooltip-popup { display: none; }"
  <> ".chart-hotspot:hover .chart-tooltip-cursor { display: block; }"
  <> ".chart-hotspot:hover .chart-tooltip-dot { display: block; }"
  <> ".chart-hotspot:hover .chart-tooltip-popup { display: block; }"
}

/// Extract values for valid (non-missing) area points, preserving order.
fn extract_area_valid_values(
  maybe_points: List(MaybeAreaPoint),
  data: List(Dict(String, Float)),
  data_key: String,
) -> List(Float) {
  list.zip(maybe_points, data)
  |> list.filter_map(fn(pair) {
    let #(mp, values) = pair
    case mp {
      AreaValid(..) -> dict.get(values, data_key)
      AreaMissing -> Error(Nil)
    }
  })
}

/// Format a numeric value as a label string.
fn format_chart_value(value: Float) -> String {
  let rounded = float.round(value)
  case value == int.to_float(rounded) {
    True -> int.to_string(rounded)
    False -> math.fmt(value)
  }
}

/// Get element at index from a list.
fn list_at(items: List(a), index: Int) -> Result(a, Nil) {
  case items, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], n -> list_at(rest, n - 1)
  }
}

/// Convert a float to a category string.
fn float_to_cat(value: Float) -> String {
  float.to_string(value)
}
