//// Grid components for charts.
////
//// CartesianGrid renders horizontal and/or vertical grid lines with
//// optional stripe fills.  PolarGrid renders concentric rings and
//// radial lines for radar/radial bar charts.  Matches the recharts
//// CartesianGrid and PolarGrid components.

import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import weft_chart/internal/math
import weft_chart/internal/polar
import weft_chart/internal/svg
import weft_chart/scale.{type Scale}

// ---------------------------------------------------------------------------
// Types — CartesianGrid
// ---------------------------------------------------------------------------

/// Configuration for a cartesian grid.
pub type CartesianGridConfig {
  CartesianGridConfig(
    show_horizontal: Bool,
    show_vertical: Bool,
    stroke_dasharray: String,
    stroke: String,
    horizontal_fill: List(String),
    vertical_fill: List(String),
    fill_opacity: Float,
    sync_with_ticks: Bool,
    sync_x_ticks: List(Float),
    sync_y_ticks: List(Float),
    horizontal_values: List(Float),
    vertical_values: List(Float),
    horizontal_generator: Option(fn(Float, Float, Int) -> List(Float)),
    vertical_generator: Option(fn(Float, Float, Int) -> List(Float)),
  )
}

// ---------------------------------------------------------------------------
// Types — PolarGrid
// ---------------------------------------------------------------------------

/// Configuration for a polar grid.
pub type PolarGridConfig {
  PolarGridConfig(
    grid_type: PolarGridType,
    show_radial_lines: Bool,
    stroke: String,
    stroke_dasharray: String,
    fill: String,
  )
}

/// Grid shape for concentric rings in polar charts.
pub type PolarGridType {
  /// Polygon connecting angle axis points (default for radar).
  PolygonGrid
  /// Circular concentric rings.
  CircleGrid
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create default cartesian grid configuration.
pub fn cartesian_grid_config() -> CartesianGridConfig {
  CartesianGridConfig(
    show_horizontal: True,
    show_vertical: True,
    stroke_dasharray: "",
    stroke: "var(--weft-chart-grid, #ccc)",
    horizontal_fill: [],
    vertical_fill: [],
    fill_opacity: 1.0,
    sync_with_ticks: False,
    sync_x_ticks: [],
    sync_y_ticks: [],
    horizontal_values: [],
    vertical_values: [],
    horizontal_generator: None,
    vertical_generator: None,
  )
}

/// Create default polar grid configuration.
pub fn polar_grid_config() -> PolarGridConfig {
  PolarGridConfig(
    grid_type: PolygonGrid,
    show_radial_lines: True,
    stroke: "var(--weft-chart-grid, #ccc)",
    stroke_dasharray: "",
    fill: "",
  )
}

// ---------------------------------------------------------------------------
// CartesianGrid builders
// ---------------------------------------------------------------------------

/// Show or hide horizontal grid lines.
pub fn grid_horizontal(
  config config: CartesianGridConfig,
  show show: Bool,
) -> CartesianGridConfig {
  CartesianGridConfig(..config, show_horizontal: show)
}

/// Show or hide vertical grid lines.
pub fn grid_vertical(
  config config: CartesianGridConfig,
  show show: Bool,
) -> CartesianGridConfig {
  CartesianGridConfig(..config, show_vertical: show)
}

/// Set the stroke dash pattern (e.g. "3 3" for dashed lines).
pub fn grid_stroke_dasharray(
  config config: CartesianGridConfig,
  pattern pattern: String,
) -> CartesianGridConfig {
  CartesianGridConfig(..config, stroke_dasharray: pattern)
}

/// Set the stroke color.
pub fn grid_stroke(
  config config: CartesianGridConfig,
  color color: String,
) -> CartesianGridConfig {
  CartesianGridConfig(..config, stroke: color)
}

/// Set alternating horizontal stripe fill colors.
/// Matches recharts CartesianGrid horizontalFill prop.
pub fn grid_horizontal_fill(
  config config: CartesianGridConfig,
  colors colors: List(String),
) -> CartesianGridConfig {
  CartesianGridConfig(..config, horizontal_fill: colors)
}

/// Set alternating vertical stripe fill colors.
/// Matches recharts CartesianGrid verticalFill prop.
pub fn grid_vertical_fill(
  config config: CartesianGridConfig,
  colors colors: List(String),
) -> CartesianGridConfig {
  CartesianGridConfig(..config, vertical_fill: colors)
}

/// Set the fill opacity for stripe backgrounds.
/// Matches recharts CartesianGrid fillOpacity prop (default: 1.0).
pub fn grid_fill_opacity(
  config config: CartesianGridConfig,
  opacity opacity: Float,
) -> CartesianGridConfig {
  CartesianGridConfig(..config, fill_opacity: opacity)
}

/// Synchronize grid lines with axis tick positions.
/// When True, grid lines are drawn at the exact tick coordinates from
/// the axes rather than being computed independently from the scale.
/// Matches recharts CartesianGrid `syncWithTicks` prop (default: False).
pub fn grid_sync_with_ticks(
  config config: CartesianGridConfig,
  sync sync: Bool,
) -> CartesianGridConfig {
  CartesianGridConfig(..config, sync_with_ticks: sync)
}

/// Set explicit tick coordinates for synchronized grid lines.
/// When these lists are non-empty, they override the scale-computed
/// tick positions for vertical (x) and horizontal (y) grid lines.
/// Typically populated by the chart container when `sync_with_ticks`
/// is True.
pub fn grid_sync_tick_coords(
  config config: CartesianGridConfig,
  x_coords x_coords: List(Float),
  y_coords y_coords: List(Float),
) -> CartesianGridConfig {
  CartesianGridConfig(..config, sync_x_ticks: x_coords, sync_y_ticks: y_coords)
}

/// Set explicit horizontal grid line positions as data-space values.
/// These values are mapped through the y-scale to pixel coordinates.
/// When non-empty, takes priority over sync_with_ticks and computed ticks.
/// Matches recharts CartesianGrid `horizontalValues` prop.
pub fn grid_horizontal_values(
  config config: CartesianGridConfig,
  values values: List(Float),
) -> CartesianGridConfig {
  CartesianGridConfig(..config, horizontal_values: values)
}

/// Set explicit vertical grid line positions as data-space values.
/// These values are mapped through the x-scale to pixel coordinates.
/// When non-empty, takes priority over sync_with_ticks and computed ticks.
/// Matches recharts CartesianGrid `verticalValues` prop.
pub fn grid_vertical_values(
  config config: CartesianGridConfig,
  values values: List(Float),
) -> CartesianGridConfig {
  CartesianGridConfig(..config, vertical_values: values)
}

/// Set a custom horizontal grid line position generator.
/// The function receives (range_start, range_end, tick_count) and returns
/// pixel coordinates for horizontal grid lines.
/// When provided, overrides computed tick positions.
/// Matches recharts CartesianGrid `horizontalCoordinatesGenerator` prop.
pub fn grid_horizontal_generator(
  config config: CartesianGridConfig,
  generator generator: fn(Float, Float, Int) -> List(Float),
) -> CartesianGridConfig {
  CartesianGridConfig(..config, horizontal_generator: Some(generator))
}

/// Set a custom vertical grid line position generator.
/// The function receives (range_start, range_end, tick_count) and returns
/// pixel coordinates for vertical grid lines.
/// When provided, overrides computed tick positions.
/// Matches recharts CartesianGrid `verticalCoordinatesGenerator` prop.
pub fn grid_vertical_generator(
  config config: CartesianGridConfig,
  generator generator: fn(Float, Float, Int) -> List(Float),
) -> CartesianGridConfig {
  CartesianGridConfig(..config, vertical_generator: Some(generator))
}

// ---------------------------------------------------------------------------
// PolarGrid builders
// ---------------------------------------------------------------------------

/// Set the polar grid type.
pub fn polar_grid_type(
  config config: PolarGridConfig,
  grid_type grid_type: PolarGridType,
) -> PolarGridConfig {
  PolarGridConfig(..config, grid_type: grid_type)
}

/// Show or hide radial lines.
pub fn polar_grid_radial_lines(
  config config: PolarGridConfig,
  show show: Bool,
) -> PolarGridConfig {
  PolarGridConfig(..config, show_radial_lines: show)
}

/// Set the polar grid stroke color.
pub fn polar_grid_stroke(
  config config: PolarGridConfig,
  color color: String,
) -> PolarGridConfig {
  PolarGridConfig(..config, stroke: color)
}

/// Set the polar grid dash pattern.
pub fn polar_grid_stroke_dasharray(
  config config: PolarGridConfig,
  pattern pattern: String,
) -> PolarGridConfig {
  PolarGridConfig(..config, stroke_dasharray: pattern)
}

/// Set the fill color for polar grid rings.
/// When non-empty, concentric rings are filled with this color.
/// Matches recharts PolarGrid `fill` prop (default: no fill).
pub fn polar_grid_fill(
  config config: PolarGridConfig,
  color color: String,
) -> PolarGridConfig {
  PolarGridConfig(..config, fill: color)
}

// ---------------------------------------------------------------------------
// Rendering — CartesianGrid
// ---------------------------------------------------------------------------

/// Render cartesian grid lines with optional stripe fills.
/// Matches the recharts CartesianGrid rendering structure:
/// background, horizontal stripes, vertical stripes, horizontal
/// lines, vertical lines.
pub fn render_cartesian_grid(
  config config: CartesianGridConfig,
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  plot_x plot_x: Float,
  plot_y plot_y: Float,
  plot_width plot_width: Float,
  plot_height plot_height: Float,
) -> Element(msg) {
  let dash_attrs = case config.stroke_dasharray {
    "" -> []
    pattern -> [svg.attr("stroke-dasharray", pattern)]
  }

  let base_attrs = [
    svg.attr("stroke", config.stroke),
    svg.attr("stroke-width", "1"),
    svg.attr("fill", "none"),
    ..dash_attrs
  ]

  // Compute tick coordinates.
  // Priority: explicit values > sync_with_ticks > generator > computed ticks.
  let y_coords = case config.horizontal_values {
    [_, ..] ->
      list.map(config.horizontal_values, fn(v) { scale.apply(y_scale, v) })
    [] ->
      case config.sync_y_ticks {
        [] ->
          case config.horizontal_generator {
            Some(gen) -> gen(plot_y, plot_y +. plot_height, 5)
            None -> {
              let y_ticks = scale.ticks(y_scale, 5, True)
              list.map(y_ticks, fn(t) { t.coordinate })
            }
          }
        coords -> coords
      }
  }
  let x_coords = case config.vertical_values {
    [_, ..] ->
      list.map(config.vertical_values, fn(v) { scale.apply(x_scale, v) })
    [] ->
      case config.sync_x_ticks {
        [] ->
          case config.vertical_generator {
            Some(gen) -> gen(plot_x, plot_x +. plot_width, 5)
            None -> {
              let x_ticks = scale.ticks(x_scale, 5, True)
              list.map(x_ticks, fn(t) { t.coordinate })
            }
          }
        coords -> coords
      }
  }

  // Horizontal stripe fills
  let h_stripe_els =
    render_stripes(
      config.horizontal_fill,
      y_coords,
      plot_x,
      plot_y,
      plot_width,
      plot_height,
      True,
      config.fill_opacity,
    )

  // Vertical stripe fills
  let v_stripe_els =
    render_stripes(
      config.vertical_fill,
      x_coords,
      plot_x,
      plot_y,
      plot_width,
      plot_height,
      False,
      config.fill_opacity,
    )

  // Horizontal grid lines
  let h_lines = case config.show_horizontal {
    False -> []
    True ->
      list.map(y_coords, fn(coord) {
        svg.line(
          x1: math.fmt(plot_x),
          y1: math.fmt(coord),
          x2: math.fmt(plot_x +. plot_width),
          y2: math.fmt(coord),
          attrs: base_attrs,
        )
      })
  }

  // Vertical grid lines
  let v_lines = case config.show_vertical {
    False -> []
    True ->
      list.map(x_coords, fn(coord) {
        svg.line(
          x1: math.fmt(coord),
          y1: math.fmt(plot_y),
          x2: math.fmt(coord),
          y2: math.fmt(plot_y +. plot_height),
          attrs: base_attrs,
        )
      })
  }

  let children = list.flatten([h_stripe_els, v_stripe_els, h_lines, v_lines])

  svg.g(
    attrs: [svg.attr("class", "recharts-cartesian-grid")],
    children: children,
  )
}

/// Render stripe fill rectangles between consecutive grid lines.
fn render_stripes(
  colors: List(String),
  coords: List(Float),
  plot_x: Float,
  plot_y: Float,
  plot_width: Float,
  plot_height: Float,
  horizontal: Bool,
  fill_opacity: Float,
) -> List(Element(msg)) {
  case colors {
    [] -> []
    _ -> {
      // Build pairs of consecutive coordinates
      let all_coords = case horizontal {
        True -> [plot_y, ..list.append(coords, [plot_y +. plot_height])]
        False -> [plot_x, ..list.append(coords, [plot_x +. plot_width])]
      }
      let opacity_attrs = case fill_opacity == 1.0 {
        True -> []
        False -> [svg.attr("fill-opacity", float.to_string(fill_opacity))]
      }
      let pairs = list.zip(all_coords, list.drop(all_coords, 1))
      list.index_map(pairs, fn(pair, i) {
        let #(start, end) = pair
        let color = cycle_list(colors, i)
        let dim = math.abs(end -. start)
        case horizontal {
          True ->
            svg.rect(
              x: math.fmt(plot_x),
              y: math.fmt(start),
              width: math.fmt(plot_width),
              height: math.fmt(dim),
              attrs: list.append(
                [svg.attr("fill", color), svg.attr("stroke", "none")],
                opacity_attrs,
              ),
            )
          False ->
            svg.rect(
              x: math.fmt(start),
              y: math.fmt(plot_y),
              width: math.fmt(dim),
              height: math.fmt(plot_height),
              attrs: list.append(
                [svg.attr("fill", color), svg.attr("stroke", "none")],
                opacity_attrs,
              ),
            )
        }
      })
    }
  }
}

// ---------------------------------------------------------------------------
// Rendering — PolarGrid
// ---------------------------------------------------------------------------

/// Render a polar grid with concentric rings and radial lines.
/// Matches the recharts PolarGrid component structure.
pub fn render_polar_grid(
  config config: PolarGridConfig,
  cx cx: Float,
  cy cy: Float,
  inner_radius inner_radius: Float,
  outer_radius outer_radius: Float,
  angles angles: List(Float),
  radii radii: List(Float),
) -> Element(msg) {
  let dash_attrs = case config.stroke_dasharray {
    "" -> []
    pattern -> [svg.attr("stroke-dasharray", pattern)]
  }

  let fill_value = case config.fill {
    "" -> "none"
    f -> f
  }

  let base_attrs = [
    svg.attr("stroke", config.stroke),
    svg.attr("stroke-width", "1"),
    svg.attr("fill", fill_value),
    ..dash_attrs
  ]

  // Radial lines from center to outer edge
  let radial_els = case config.show_radial_lines {
    False -> []
    True ->
      list.map(angles, fn(angle) {
        let #(x1, y1) =
          polar.to_cartesian(
            cx: cx,
            cy: cy,
            radius: inner_radius,
            angle_degrees: angle,
          )
        let #(x2, y2) =
          polar.to_cartesian(
            cx: cx,
            cy: cy,
            radius: outer_radius,
            angle_degrees: angle,
          )
        svg.line(
          x1: math.fmt(x1),
          y1: math.fmt(y1),
          x2: math.fmt(x2),
          y2: math.fmt(y2),
          attrs: base_attrs,
        )
      })
  }

  // Concentric rings — polygon or circle
  // Force fill: "none" on ring elements to match recharts ConcentricCircle
  // and ConcentricPolygon which always render with fill='none'.
  let ring_attrs = [svg.attr("fill", "none"), ..base_attrs]
  let ring_els = case config.grid_type {
    CircleGrid ->
      list.map(radii, fn(r) {
        svg.circle(
          cx: math.fmt(cx),
          cy: math.fmt(cy),
          r: math.fmt(r),
          attrs: ring_attrs,
        )
      })
    PolygonGrid ->
      list.map(radii, fn(r) {
        let d = polygon_ring_path(cx, cy, r, angles)
        svg.path(d: d, attrs: ring_attrs)
      })
  }

  let radial_group =
    svg.g(
      attrs: [svg.attr("class", "recharts-polar-grid-angle")],
      children: radial_els,
    )
  let ring_group =
    svg.g(
      attrs: [svg.attr("class", "recharts-polar-grid-concentric")],
      children: ring_els,
    )

  svg.g(attrs: [svg.attr("class", "recharts-polar-grid")], children: [
    radial_group,
    ring_group,
  ])
}

/// Generate a closed polygon path at a given radius through all angles.
fn polygon_ring_path(
  cx: Float,
  cy: Float,
  radius: Float,
  angles: List(Float),
) -> String {
  case angles {
    [] -> ""
    [first_angle, ..rest_angles] -> {
      let #(x0, y0) =
        polar.to_cartesian(
          cx: cx,
          cy: cy,
          radius: radius,
          angle_degrees: first_angle,
        )
      let start = "M" <> math.fmt(x0) <> "," <> math.fmt(y0)
      let segments =
        list.fold(rest_angles, start, fn(acc, angle) {
          let #(x, y) =
            polar.to_cartesian(
              cx: cx,
              cy: cy,
              radius: radius,
              angle_degrees: angle,
            )
          acc <> "L" <> math.fmt(x) <> "," <> math.fmt(y)
        })
      segments <> "Z"
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn cycle_list(items: List(String), index: Int) -> String {
  let len = list.length(items)
  case len == 0 {
    True -> ""
    False -> {
      let idx = index % len
      case list.drop(items, idx) {
        [first, ..] -> first
        [] -> ""
      }
    }
  }
}
