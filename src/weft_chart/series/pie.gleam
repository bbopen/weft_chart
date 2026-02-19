//// Pie chart series component.
////
//// Renders sectors (arc slices) for each data value.  Supports donut
//// charts via `inner_radius`, label lines connecting sectors to text,
//// configurable start/end angles, padding between slices, and minimum
//// angle for small slices.  Matches the recharts Pie component.

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

/// Per-item fill customization for individual pie sectors.
/// Matches recharts Cell component behavior on Pie.
pub type PieCellConfig {
  PieCellConfig(fill: String, stroke: String, fill_opacity: Float)
}

/// Configuration for a pie series.
pub type PieConfig(msg) {
  PieConfig(
    data_key: String,
    name_key: String,
    sector_names: List(String),
    inner_radius: Float,
    outer_radius: Float,
    start_angle: Float,
    end_angle: Float,
    padding_angle: Float,
    min_angle: Float,
    corner_radius: Float,
    show_label: Bool,
    show_label_line: Bool,
    label_offset: Float,
    cx: Float,
    cy: Float,
    fills: List(String),
    legend_type: shape.LegendIconType,
    blend_stroke: Bool,
    active_indices: List(Int),
    max_radius: Float,
    stroke: String,
    stroke_width: Float,
    name: String,
    data: List(Dict(String, Float)),
    cells: List(PieCellConfig),
    hide: Bool,
    tooltip_type: shape.TooltipType,
    custom_label: Option(fn(render.PieLabelProps) -> Element(msg)),
    custom_label_line: Option(fn(render.LabelLineProps) -> Element(msg)),
    active_shape: Option(fn(render.SectorProps) -> Element(msg)),
    inactive_shape: Option(fn(render.SectorProps) -> Element(msg)),
    value_key: String,
    css_class: String,
    animation: AnimationConfig,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a pie configuration with default settings.
/// Matches recharts Pie defaults: outerRadius=80%, paddingAngle=0,
/// startAngle=0, endAngle=360, nameKey="name".
pub fn pie_config(data_key data_key: String) -> PieConfig(msg) {
  PieConfig(
    data_key: data_key,
    name_key: "name",
    sector_names: [],
    inner_radius: 0.0,
    outer_radius: 0.8,
    start_angle: 0.0,
    end_angle: 360.0,
    padding_angle: 0.0,
    min_angle: 0.0,
    corner_radius: 0.0,
    show_label: False,
    show_label_line: True,
    label_offset: 20.0,
    cx: 0.0,
    cy: 0.0,
    fills: [
      "var(--weft-chart-1, #2563eb)",
      "var(--weft-chart-2, #60a5fa)",
      "var(--weft-chart-3, #93c5fd)",
      "var(--weft-chart-4, #bfdbfe)",
      "var(--weft-chart-5, #dbeafe)",
    ],
    legend_type: shape.RectIcon,
    blend_stroke: False,
    active_indices: [],
    max_radius: 0.0,
    stroke: "#fff",
    stroke_width: 1.0,
    name: "",
    data: [],
    cells: [],
    hide: False,
    tooltip_type: shape.DefaultTooltip,
    custom_label: None,
    custom_label_line: None,
    active_shape: None,
    inactive_shape: None,
    value_key: "value",
    css_class: "",
    animation: animation.pie_default(),
  )
}

/// Create a cell configuration for per-item pie sector customization.
/// Matches recharts Cell component on Pie.
pub fn pie_cell_config(fill fill: String) -> PieCellConfig {
  PieCellConfig(fill: fill, stroke: "", fill_opacity: 1.0)
}

/// Create a cell configuration with full customization for pie sectors.
/// Matches recharts Cell with stroke and fillOpacity props.
pub fn pie_cell_config_full(
  fill fill: String,
  stroke stroke: String,
  fill_opacity fill_opacity: Float,
) -> PieCellConfig {
  PieCellConfig(fill: fill, stroke: stroke, fill_opacity: fill_opacity)
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the inner radius (0 for full pie, >0 for donut).
pub fn pie_inner_radius(config: PieConfig(msg), radius: Float) -> PieConfig(msg) {
  PieConfig(..config, inner_radius: radius)
}

/// Set the outer radius.
pub fn pie_outer_radius(config: PieConfig(msg), radius: Float) -> PieConfig(msg) {
  PieConfig(..config, outer_radius: radius)
}

/// Set the start angle in degrees.
pub fn pie_start_angle(config: PieConfig(msg), angle: Float) -> PieConfig(msg) {
  PieConfig(..config, start_angle: angle)
}

/// Set the end angle in degrees.
pub fn pie_end_angle(config: PieConfig(msg), angle: Float) -> PieConfig(msg) {
  PieConfig(..config, end_angle: angle)
}

/// Set the padding angle between sectors.
/// Matches recharts Pie paddingAngle: applied to all sectors
/// except the first, creating visual gaps between slices.
pub fn pie_padding_angle(config: PieConfig(msg), angle: Float) -> PieConfig(msg) {
  PieConfig(..config, padding_angle: angle)
}

/// Set the minimum angle for small slices.
/// Matches recharts Pie minAngle prop: small slices are expanded to
/// the minimum, and remaining slices are proportionally shrunk to
/// compensate.
pub fn pie_min_angle(config: PieConfig(msg), angle: Float) -> PieConfig(msg) {
  PieConfig(..config, min_angle: angle)
}

/// Set the corner radius for rounded sector edges.
pub fn pie_corner_radius(
  config: PieConfig(msg),
  radius: Float,
) -> PieConfig(msg) {
  PieConfig(..config, corner_radius: radius)
}

/// Show or hide sector labels.
pub fn pie_label(config: PieConfig(msg), show: Bool) -> PieConfig(msg) {
  PieConfig(..config, show_label: show)
}

/// Show or hide label connector lines.
pub fn pie_label_line(config: PieConfig(msg), show: Bool) -> PieConfig(msg) {
  PieConfig(..config, show_label_line: show)
}

/// Set the label offset from the outer edge.
pub fn pie_label_offset(config: PieConfig(msg), offset: Float) -> PieConfig(msg) {
  PieConfig(..config, label_offset: offset)
}

/// Set the center x-coordinate (0 = auto-center).
pub fn pie_cx(config: PieConfig(msg), x: Float) -> PieConfig(msg) {
  PieConfig(..config, cx: x)
}

/// Set the center y-coordinate (0 = auto-center).
pub fn pie_cy(config: PieConfig(msg), y: Float) -> PieConfig(msg) {
  PieConfig(..config, cy: y)
}

/// Set the name key for label text.
/// Matches recharts Pie nameKey prop (default: "name").
pub fn pie_name_key(config: PieConfig(msg), key: String) -> PieConfig(msg) {
  PieConfig(..config, name_key: key)
}

/// Set explicit string names for each sector.
///
/// When set, these override the float-encoded names derived from `name_key`.
/// Matches recharts behavior where data objects contain string `name` fields.
/// Names are matched by index to data points.
pub fn pie_sector_names(
  config: PieConfig(msg),
  names: List(String),
) -> PieConfig(msg) {
  PieConfig(..config, sector_names: names)
}

/// Set the fill colors for sectors (cycled if fewer than data points).
pub fn pie_fills(config: PieConfig(msg), fills: List(String)) -> PieConfig(msg) {
  PieConfig(..config, fills: fills)
}

/// Set the legend icon type for this series.
/// Matches recharts Pie `legendType` prop (default: rect).
pub fn pie_legend_type(
  config: PieConfig(msg),
  icon_type: shape.LegendIconType,
) -> PieConfig(msg) {
  PieConfig(..config, legend_type: icon_type)
}

/// Enable blend stroke mode where each sector uses its fill color as stroke.
/// When True, sector edges blend seamlessly with the fill.
/// Matches recharts Pie blend-stroke behavior.
pub fn pie_blend_stroke(config: PieConfig(msg), blend: Bool) -> PieConfig(msg) {
  PieConfig(..config, blend_stroke: blend)
}

/// Set a single pre-selected active sector index for SSR.
/// That sector renders with a slightly larger outer radius (+4px).
/// Matches recharts Pie `activeIndex` prop.
pub fn pie_active_index(
  config: PieConfig(msg),
  index index: Int,
) -> PieConfig(msg) {
  PieConfig(..config, active_indices: [index])
}

/// Set multiple pre-selected active sector indices for SSR.
/// Each active sector renders with a slightly larger outer radius (+4px).
/// Matches recharts Pie `activeIndex` prop (array form).
pub fn pie_active_indices(
  config: PieConfig(msg),
  indices indices: List(Int),
) -> PieConfig(msg) {
  PieConfig(..config, active_indices: indices)
}

/// Set the maximum outer radius cap.
/// When > 0, the computed outer radius will not exceed this value.
pub fn pie_max_radius(config: PieConfig(msg), radius: Float) -> PieConfig(msg) {
  PieConfig(..config, max_radius: radius)
}

/// Set the sector stroke color.
/// Matches recharts Pie `stroke` prop (default: "#fff").
pub fn pie_stroke(
  config: PieConfig(msg),
  stroke_value: String,
) -> PieConfig(msg) {
  PieConfig(..config, stroke: stroke_value)
}

/// Set the sector stroke width.
/// Matches recharts Pie `strokeWidth` prop (default: 1.0).
pub fn pie_stroke_width(config: PieConfig(msg), width: Float) -> PieConfig(msg) {
  PieConfig(..config, stroke_width: width)
}

/// Set the display name for tooltip and legend.
/// Matches recharts Pie `name` prop.
pub fn pie_name(config: PieConfig(msg), name_value: String) -> PieConfig(msg) {
  PieConfig(..config, name: name_value)
}

/// Set per-pie data for this series.
///
/// When non-empty, this data is used instead of chart-level data,
/// enabling multiple pie rings with different datasets in the same
/// pie chart.  Matches the recharts Pie `data` prop.
pub fn pie_data(
  config: PieConfig(msg),
  data: List(Dict(String, Float)),
) -> PieConfig(msg) {
  PieConfig(..config, data: data)
}

/// Hide the pie from rendering while keeping it in legend calculation.
/// Matches recharts Pie `hide` prop.
pub fn pie_hide(
  config config: PieConfig(msg),
  hide hide: Bool,
) -> PieConfig(msg) {
  PieConfig(..config, hide: hide)
}

/// Set the tooltip type to control whether this series appears in tooltips.
/// Matches recharts Pie `tooltipType` prop (default: DefaultTooltip).
pub fn pie_tooltip_type(
  config config: PieConfig(msg),
  tooltip_type tooltip_type: shape.TooltipType,
) -> PieConfig(msg) {
  PieConfig(..config, tooltip_type: tooltip_type)
}

/// Set per-item cell configurations for individual sector customization.
/// When non-empty, each sector uses the corresponding cell's fill color.
/// Sectors beyond the cell list length fall back to the default fills cycle.
/// Matches recharts Cell component behavior on Pie.
pub fn pie_cells(
  config config: PieConfig(msg),
  cells cells: List(PieCellConfig),
) -> PieConfig(msg) {
  PieConfig(..config, cells: cells)
}

/// Set a custom label render function for pie sector labels.
/// When provided, replaces the default text label for each sector.
/// Receives pie-specific props including percent, mid_angle, and
/// middle_radius.  Matches recharts Pie `label` prop (element/function form).
pub fn pie_custom_label(
  config config: PieConfig(msg),
  renderer renderer: fn(render.PieLabelProps) -> Element(msg),
) -> PieConfig(msg) {
  PieConfig(..config, custom_label: Some(renderer))
}

/// Set a custom label line render function for pie label connectors.
/// When provided, replaces the default line from sector to label.
/// Matches recharts Pie `labelLine` prop (element/function form).
pub fn pie_custom_label_line(
  config config: PieConfig(msg),
  renderer renderer: fn(render.LabelLineProps) -> Element(msg),
) -> PieConfig(msg) {
  PieConfig(..config, custom_label_line: Some(renderer))
}

/// Set a custom renderer for the active (hovered/selected) sector.
/// When provided, the active sector is rendered using this function
/// instead of the default enlarged sector.
/// Matches recharts Pie `activeShape` prop.
pub fn pie_active_shape(
  config config: PieConfig(msg),
  renderer renderer: fn(render.SectorProps) -> Element(msg),
) -> PieConfig(msg) {
  PieConfig(..config, active_shape: Some(renderer))
}

/// Set a custom renderer for inactive (non-selected) sectors.
/// When provided, non-active sectors are rendered using this function.
/// Matches recharts Pie `inactiveShape` prop.
pub fn pie_inactive_shape(
  config config: PieConfig(msg),
  renderer renderer: fn(render.SectorProps) -> Element(msg),
) -> PieConfig(msg) {
  PieConfig(..config, inactive_shape: Some(renderer))
}

/// Set the data field key used for sector values.
/// Matches recharts Pie `valueKey` prop (default: "value").
pub fn pie_value_key(
  config config: PieConfig(msg),
  key key: String,
) -> PieConfig(msg) {
  PieConfig(..config, value_key: key)
}

/// Set the CSS class applied to the pie group element.
pub fn pie_css_class(
  config config: PieConfig(msg),
  class class: String,
) -> PieConfig(msg) {
  PieConfig(..config, css_class: class)
}

/// Set the animation configuration for pie entry effects.
pub fn pie_animation(
  config config: PieConfig(msg),
  anim anim: AnimationConfig,
) -> PieConfig(msg) {
  PieConfig(..config, animation: anim)
}

// ---------------------------------------------------------------------------
// Tooltip geometry
// ---------------------------------------------------------------------------

/// Centroid position and metadata for a single pie sector.
/// Used by the chart container to build CSS-hover tooltip zones.
pub type PieSectorInfo {
  PieSectorInfo(
    centroid_x: Float,
    centroid_y: Float,
    value: Float,
    fill: String,
    category: String,
    outer_radius: Float,
  )
}

/// Return centroid positions and values for each visible sector.
///
/// Matches recharts `tooltipPosition` calculation:
/// centroid = `polarToCartesian(cx, cy, middleRadius, midAngle)`
/// where `middleRadius = (innerRadius + outerRadius) / 2`.
pub fn pie_sector_infos(
  config config: PieConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  width width: Float,
  height height: Float,
) -> List(PieSectorInfo) {
  case config.hide {
    True -> []
    False -> {
      let cx = case config.cx <=. 0.0 {
        True -> width /. 2.0
        False -> config.cx
      }
      let cy = case config.cy <=. 0.0 {
        True -> height /. 2.0
        False -> config.cy
      }
      let values =
        list.map(data, fn(d) {
          case dict.get(d, config.data_key) {
            Ok(v) -> math.abs(v)
            Error(_) -> 0.0
          }
        })
      let angles = compute_angles_with_min(config, values)
      let max_r = float.min(width, height) /. 2.0
      let resolved_outer = case config.outer_radius <=. 1.0 {
        True -> config.outer_radius *. max_r
        False -> float.min(config.outer_radius, max_r)
      }
      let resolved_inner = case
        config.inner_radius <=. 1.0 && config.inner_radius >. 0.0
      {
        True -> config.inner_radius *. max_r
        False -> config.inner_radius
      }
      let effective_outer = case config.max_radius >. 0.0 {
        True -> float.min(resolved_outer, config.max_radius)
        False -> resolved_outer
      }
      let mid_radius = { resolved_inner +. effective_outer } /. 2.0
      // Prefer explicit sector_names (e.g. ["Group A", "Group B"]) over
      // float-encoded names derived from the data dict. Matches recharts
      // behavior where data objects carry string name fields.
      let resolved_cats = case config.sector_names {
        [] -> categories
        names -> names
      }
      list.index_map(
        list.zip(list.zip(angles, values), resolved_cats),
        fn(item, idx) {
          let #(#(#(sa, ea), value), cat) = item
          let mid = polar.mid_angle(sa, ea)
          let #(cx_pt, cy_pt) =
            polar.to_cartesian(
              cx: cx,
              cy: cy,
              radius: mid_radius,
              angle_degrees: mid,
            )
          PieSectorInfo(
            centroid_x: cx_pt,
            centroid_y: cy_pt,
            value: value,
            fill: cycle_fill(config.fills, idx),
            category: cat,
            outer_radius: effective_outer,
          )
        },
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a pie series given the data.
pub fn render_pie(
  config config: PieConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  width width: Float,
  height height: Float,
) -> Element(msg) {
  case config.hide {
    True -> element.none()
    False ->
      render_pie_visible(
        config: config,
        data: data,
        categories: categories,
        width: width,
        height: height,
      )
  }
}

/// Internal rendering for a visible pie series.
fn render_pie_visible(
  config config: PieConfig(msg),
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  width width: Float,
  height height: Float,
) -> Element(msg) {
  let cx = case config.cx <=. 0.0 {
    True -> width /. 2.0
    False -> config.cx
  }
  let cy = case config.cy <=. 0.0 {
    True -> height /. 2.0
    False -> config.cy
  }

  // Extract values
  let values =
    list.map(data, fn(d) {
      case dict.get(d, config.data_key) {
        Ok(v) -> math.abs(v)
        Error(_) -> 0.0
      }
    })

  // Compute sector angles with minAngle enforcement
  let angles = compute_angles_with_min(config, values)

  // Resolve percentage-based radii: values <= 1.0 are treated as
  // fractions of min(width, height) / 2, matching recharts behavior.
  let max_r = float.min(width, height) /. 2.0
  let resolved_outer = case config.outer_radius <=. 1.0 {
    True -> config.outer_radius *. max_r
    False -> float.min(config.outer_radius, max_r)
  }
  let resolved_inner = case
    config.inner_radius <=. 1.0 && config.inner_radius >. 0.0
  {
    True -> config.inner_radius *. max_r
    False -> config.inner_radius
  }

  // Apply max_radius cap to outer_radius
  let effective_outer = case config.max_radius >. 0.0 {
    True ->
      case resolved_outer >. config.max_radius {
        True -> config.max_radius
        False -> resolved_outer
      }
    False -> resolved_outer
  }

  // Render sectors
  let sector_els =
    list.index_map(list.zip(angles, categories), fn(pair, index) {
      let #(#(sa, ea), _cat) = pair
      let #(fill_color, cell_stroke_override, cell_opacity) = case
        get_pie_cell_at(config.cells, index)
      {
        Ok(cell) -> #(cell.fill, cell.stroke, cell.fill_opacity)
        Error(_) -> #(cycle_fill(config.fills, index), "", 1.0)
      }

      // Check if this sector is active
      let is_active = list.contains(config.active_indices, index)

      // Apply active_index: enlarge outer radius by 4px for active sector
      let sector_outer = case is_active {
        True -> effective_outer +. 4.0
        False -> effective_outer
      }

      // Apply blend_stroke: use fill as stroke, cell override, or config.stroke
      let sector_stroke = case cell_stroke_override {
        "" ->
          case config.blend_stroke {
            True -> fill_color
            False -> config.stroke
          }
        s -> s
      }

      let raw_sector =
        shape.sector_with_stroke(
          cx: cx,
          cy: cy,
          inner_radius: resolved_inner,
          outer_radius: sector_outer,
          start_angle: sa,
          end_angle: ea,
          corner_radius: config.corner_radius,
          fill: fill_color,
          stroke: sector_stroke,
          stroke_width: config.stroke_width,
        )
      let sector_el = case config.animation.active {
        False -> raw_sector
        True -> {
          let path_fn = fn(progress) {
            let animated_end = sa +. progress *. { ea -. sa }
            polar.sector_path(
              cx: cx,
              cy: cy,
              inner_radius: resolved_inner,
              outer_radius: sector_outer,
              start_angle: sa,
              end_angle: animated_end,
            )
          }
          let initial_d =
            polar.sector_path(
              cx: cx,
              cy: cy,
              inner_radius: resolved_inner,
              outer_radius: sector_outer,
              start_angle: sa,
              end_angle: sa +. 0.001,
            )
          let animate_el =
            animation.animate_path(
              path_at_progress: path_fn,
              config: config.animation,
              steps: 30,
            )
          let stroke_attrs = [
            svg.attr("fill", fill_color),
            svg.attr("stroke", sector_stroke),
            svg.attr("stroke-width", float.to_string(config.stroke_width)),
          ]
          svg.path_with_children(d: initial_d, attrs: stroke_attrs, children: [
            animate_el,
          ])
        }
      }
      // Dispatch to active_shape/inactive_shape renderers if provided
      let sector_props =
        render.SectorProps(
          cx: cx,
          cy: cy,
          inner_radius: resolved_inner,
          outer_radius: sector_outer,
          start_angle: sa,
          end_angle: ea,
          index: index,
          fill: fill_color,
          stroke: sector_stroke,
        )
      let final_sector_el = case is_active, config.active_shape {
        True, Some(renderer) -> renderer(sector_props)
        False, _ ->
          case config.inactive_shape {
            Some(renderer) ->
              case list.is_empty(config.active_indices) {
                True -> sector_el
                False -> renderer(sector_props)
              }
            None -> sector_el
          }
        _, _ -> sector_el
      }

      // Apply cell fill_opacity when not 1.0
      case cell_opacity == 1.0 {
        True -> final_sector_el
        False ->
          svg.g(
            attrs: [svg.attr("fill-opacity", float.to_string(cell_opacity))],
            children: [final_sector_el],
          )
      }
    })

  // Render label lines and labels.
  // Matches recharts: labelLine defaults to true, but lines only appear when
  // renderLabels is called (i.e. when label prop is truthy).
  let label_line_els = case config.show_label && config.show_label_line {
    False -> []
    True ->
      list.index_map(angles, fn(angle_pair, idx) {
        let #(sa, ea) = angle_pair
        let mid = polar.mid_angle(sa, ea)
        // Line from outer edge to label position
        let #(ox, oy) =
          polar.to_cartesian(
            cx: cx,
            cy: cy,
            radius: effective_outer,
            angle_degrees: mid,
          )
        let #(lx, ly) =
          polar.to_cartesian(
            cx: cx,
            cy: cy,
            radius: effective_outer +. config.label_offset,
            angle_degrees: mid,
          )
        let sector_fill = cycle_fill(config.fills, idx)
        case config.custom_label_line {
          Some(renderer) ->
            renderer(render.LabelLineProps(
              cx: cx,
              cy: cy,
              inner_radius: resolved_inner,
              outer_radius: effective_outer,
              mid_angle: mid,
              start_x: ox,
              start_y: oy,
              end_x: lx,
              end_y: ly,
              index: idx,
              fill: sector_fill,
              stroke: sector_fill,
            ))
          None ->
            svg.line(
              x1: math.fmt(ox),
              y1: math.fmt(oy),
              x2: math.fmt(lx),
              y2: math.fmt(ly),
              attrs: [
                // recharts: label line stroke = entry.fill (sector fill color)
                svg.attr("stroke", sector_fill),
                svg.attr("stroke-width", "1"),
                svg.attr("fill", "none"),
              ],
            )
        }
      })
  }

  // Total value for percent computation
  let total_value = list.fold(values, 0.0, fn(acc, v) { acc +. v })

  // Prefer explicit sector_names over float-encoded category names.
  let resolved_cats = case config.sector_names {
    [] -> categories
    names -> names
  }

  let label_els = case config.show_label {
    False -> []
    True ->
      list.index_map(
        list.zip(list.zip(angles, values), resolved_cats),
        fn(item, idx) {
          let #(#(#(sa, ea), value), cat) = item
          let mid = polar.mid_angle(sa, ea)
          let label_r = effective_outer +. config.label_offset
          let #(lx, ly) =
            polar.to_cartesian(
              cx: cx,
              cy: cy,
              radius: label_r,
              angle_degrees: mid,
            )

          // Pie-specific geometry for label renderer
          let percent = case total_value >. 0.0 {
            True -> value /. total_value
            False -> 0.0
          }
          let mid_angle = sa +. { ea -. sa } /. 2.0
          let middle_radius = { resolved_inner +. effective_outer } /. 2.0

          // Label content: matches recharts default label=true behavior —
          // shows just the raw value. Whole numbers omit the decimal, matching
          // how recharts renders JS numbers (400 not 400.0).
          let rounded = float.round(value)
          let label_text = case int.to_float(rounded) == value {
            True -> int.to_string(rounded)
            False -> float.to_string(value)
          }
          let _ = cat

          // Text anchor: recharts getTextAnchor(x, cx)
          let anchor = case lx >. cx {
            True -> "start"
            False ->
              case lx <. cx {
                True -> "end"
                False -> "middle"
              }
          }

          case config.custom_label {
            Some(renderer) ->
              renderer(render.PieLabelProps(
                x: lx,
                y: ly,
                width: 0.0,
                height: 0.0,
                index: idx,
                value: label_text,
                offset: config.label_offset,
                position: case lx >. cx {
                  True -> "right"
                  False -> "left"
                },
                fill: "var(--weft-chart-label, currentColor)",
                percent: percent,
                mid_angle: mid_angle,
                middle_radius: middle_radius,
              ))
            None -> {
              // recharts: label fill = entry.fill (sector fill color).
              // No dominant-baseline set: recharts uses alignment-baseline="middle"
              // on <text> which browsers ignore (only valid on tspan/textPath), so
              // the SVG default applies — text baseline sits at y, making the
              // connector line appear at the bottom of the text, not the middle.
              let label_fill = cycle_fill(config.fills, idx)
              svg.text(
                x: math.fmt(lx),
                y: math.fmt(ly),
                content: label_text,
                attrs: [
                  svg.attr("text-anchor", anchor),
                  svg.attr("fill", label_fill),
                ],
              )
            }
          }
        },
      )
  }

  let class_attr = case config.css_class {
    "" -> "recharts-pie"
    c -> "recharts-pie " <> c
  }
  svg.g(
    attrs: [svg.attr("class", class_attr)],
    children: list.flatten([sector_els, label_line_els, label_els]),
  )
}

// ---------------------------------------------------------------------------
// Internal: angle computation with minAngle and paddingAngle
// ---------------------------------------------------------------------------

/// Compute sector angles, enforcing minimum angle for small slices
/// and paddingAngle between sectors.
///
/// Matches recharts Pie sector computation:
/// - paddingAngle is applied to all sectors except the first
/// - small slices are expanded to minAngle
/// - remaining slices are proportionally shrunk to compensate
fn compute_angles_with_min(
  config: PieConfig(msg),
  values: List(Float),
) -> List(#(Float, Float)) {
  let total = list.fold(values, 0.0, fn(acc, v) { acc +. math.abs(v) })
  case total <=. 0.0 {
    True ->
      list.map(values, fn(_) { #(config.start_angle, config.start_angle) })
    False -> {
      let n = list.length(values)
      let dir = math.sign(config.end_angle -. config.start_angle)

      // Count non-zero entries for padding angle calculation
      // Recharts: paddingAngle applied to all sectors except the first
      let n_nonzero =
        list.fold(values, 0, fn(acc, v) {
          case v >. 0.0 {
            True -> acc + 1
            False -> acc
          }
        })

      // Force paddingAngle to 0 if only one or fewer data entries
      let effective_padding = case n_nonzero <= 1 {
        True -> 0.0
        False -> config.padding_angle
      }

      // Total padding: applied between sectors (n_nonzero - 1 gaps)
      let total_padding = case n_nonzero <= 1 {
        True -> 0.0
        False -> int.to_float(n_nonzero - 1) *. effective_padding
      }

      let abs_delta =
        math.abs(config.end_angle -. config.start_angle) -. total_padding

      case config.min_angle <=. 0.0 {
        // No minimum angle — distribute proportionally with padding
        True -> {
          let #(result, _) =
            list.index_fold(
              values,
              #([], config.start_angle),
              fn(state, value, index) {
                let #(acc, current_start) = state
                let sweep = math.abs(value) /. total *. abs_delta
                let current_end = current_start +. sweep *. dir
                // Add padding after non-zero entries (not the first)
                let next_start = case index < n - 1 && value >. 0.0 {
                  True -> current_end +. effective_padding *. dir
                  False -> current_end
                }
                #([#(current_start, current_end), ..acc], next_start)
              },
            )
          list.reverse(result)
        }
        // With minimum angle enforcement
        False -> {
          // Calculate available angle after subtracting minAngle reservations
          let real_total_angle =
            abs_delta -. int.to_float(n_nonzero) *. config.min_angle

          // Compute final sweep angles
          let final_sweeps =
            list.map(values, fn(v) {
              let abs_v = math.abs(v)
              case abs_v <=. 0.0 {
                True -> 0.0
                False -> {
                  let proportional =
                    abs_v /. total *. math.abs(real_total_angle)
                  case proportional <. config.min_angle {
                    True -> config.min_angle
                    False -> proportional +. config.min_angle
                  }
                }
              }
            })

          // Normalize if total exceeds available
          let sweep_total =
            list.fold(final_sweeps, 0.0, fn(acc, s) { acc +. s })
          let normalized = case sweep_total >. abs_delta && sweep_total >. 0.0 {
            True -> {
              let scale_factor = abs_delta /. sweep_total
              list.map(final_sweeps, fn(s) { s *. scale_factor })
            }
            False -> final_sweeps
          }

          // Convert to start/end pairs with padding
          let #(result, _) =
            list.index_fold(
              normalized,
              #([], config.start_angle),
              fn(state, sweep, index) {
                let #(acc, current_start) = state
                let current_end = current_start +. sweep *. dir
                let next_start = case index < n - 1 && sweep >. 0.0 {
                  True -> current_end +. effective_padding *. dir
                  False -> current_end
                }
                #([#(current_start, current_end), ..acc], next_start)
              },
            )
          list.reverse(result)
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

/// Get a pie cell configuration at a given index, or Error if out of range.
fn get_pie_cell_at(
  cells: List(PieCellConfig),
  index: Int,
) -> Result(PieCellConfig, Nil) {
  case cells, index {
    [], _ -> Error(Nil)
    [first, ..], 0 -> Ok(first)
    [_, ..rest], n -> get_pie_cell_at(rest, n - 1)
  }
}
