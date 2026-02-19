//// Polar axis components for radar and radial bar charts.
////
//// PolarAngleAxis renders category labels and tick marks around the
//// perimeter of a polar chart.  PolarRadiusAxis renders value ticks
//// along a radial line from center to edge.  Matches the recharts
//// PolarAngleAxis and PolarRadiusAxis components.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import weft_chart/internal/math
import weft_chart/internal/polar
import weft_chart/internal/svg
import weft_chart/scale

// ---------------------------------------------------------------------------
// Types — PolarAngleAxis
// ---------------------------------------------------------------------------

/// Axis line shape for polar angle axis.
pub type AngleAxisLineType {
  /// Polygon connecting tick points (default for radar charts).
  PolygonAxisLine
  /// Circle at the outer radius.
  CircleAxisLine
}

/// Label orientation for polar angle axis.
pub type AngleAxisOrientation {
  /// Labels face outward from center (default).
  OuterOrientation
  /// Labels face inward toward center.
  InnerOrientation
}

/// Scale type for polar angle axis.
/// Local enum to avoid circular dependency with axis module.
pub type AngleAxisScaleType {
  /// Auto-detect scale type (default).
  AutoScale
  /// Linear numeric scale.
  LinearScale
  /// Band/category scale.
  BandScale
}

/// Axis type: category or number.
pub type PolarAxisType {
  /// Categorical axis (default for angle axis).
  CategoryAxisType
  /// Numeric axis.
  NumberAxisType
}

/// Configuration for a polar angle axis.
pub type PolarAngleAxisConfig {
  PolarAngleAxisConfig(
    show_axis_line: Bool,
    axis_line_type: AngleAxisLineType,
    show_tick_line: Bool,
    tick_size: Int,
    show_tick: Bool,
    orientation: AngleAxisOrientation,
    stroke: String,
    tick_formatter: fn(String, Int) -> String,
    label_angle: Option(Float),
    scale_type: Option(AngleAxisScaleType),
    axis_type: PolarAxisType,
    allow_duplicated_category: Bool,
    hide: Bool,
  )
}

// ---------------------------------------------------------------------------
// Types — PolarRadiusAxis
// ---------------------------------------------------------------------------

/// Text anchor orientation for polar radius axis labels.
pub type RadiusAxisOrientation {
  /// Labels anchored to the left of the tick.
  LeftOrientation
  /// Labels anchored to the right of the tick (default).
  RightOrientation
  /// Labels centered on the tick.
  MiddleOrientation
}

/// Configuration for a polar radius axis.
pub type PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(
    angle: Float,
    show_axis_line: Bool,
    show_tick: Bool,
    tick_count: Int,
    orientation: RadiusAxisOrientation,
    stroke: String,
    tick_formatter: fn(String, Int) -> String,
    domain_min: Float,
    domain_max: Float,
    has_custom_domain: Bool,
    reversed: Bool,
    axis_type: PolarAxisType,
    allow_duplicated_category: Bool,
    allow_data_overflow: Bool,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a default polar angle axis configuration.
/// Matches recharts PolarAngleAxis defaults.
pub fn angle_axis_config() -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(
    show_axis_line: True,
    axis_line_type: PolygonAxisLine,
    show_tick_line: True,
    tick_size: 8,
    show_tick: True,
    orientation: OuterOrientation,
    stroke: "var(--weft-chart-axis, currentColor)",
    tick_formatter: fn(v, _i) { v },
    label_angle: None,
    scale_type: None,
    axis_type: CategoryAxisType,
    allow_duplicated_category: True,
    hide: False,
  )
}

/// Create a default polar radius axis configuration.
/// Matches recharts PolarRadiusAxis defaults.
pub fn radius_axis_config() -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(
    angle: 0.0,
    show_axis_line: True,
    show_tick: True,
    tick_count: 5,
    orientation: RightOrientation,
    stroke: "var(--weft-chart-axis, currentColor)",
    tick_formatter: fn(v, _i) { v },
    domain_min: 0.0,
    domain_max: 0.0,
    has_custom_domain: False,
    reversed: False,
    axis_type: NumberAxisType,
    allow_duplicated_category: True,
    allow_data_overflow: False,
  )
}

// ---------------------------------------------------------------------------
// PolarAngleAxis builders
// ---------------------------------------------------------------------------

/// Show or hide the axis line.
pub fn angle_axis_line(
  config config: PolarAngleAxisConfig,
  show show: Bool,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, show_axis_line: show)
}

/// Set the axis line type (polygon or circle).
pub fn angle_axis_line_type(
  config config: PolarAngleAxisConfig,
  type_ type_: AngleAxisLineType,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, axis_line_type: type_)
}

/// Show or hide tick lines.
pub fn angle_tick_line(
  config config: PolarAngleAxisConfig,
  show show: Bool,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, show_tick_line: show)
}

/// Set the tick line size in pixels.
pub fn angle_tick_size(
  config config: PolarAngleAxisConfig,
  size size: Int,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, tick_size: size)
}

/// Show or hide tick labels.
pub fn angle_show_tick(
  config config: PolarAngleAxisConfig,
  show show: Bool,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, show_tick: show)
}

/// Set the label orientation.
pub fn angle_orientation(
  config config: PolarAngleAxisConfig,
  orientation orientation: AngleAxisOrientation,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, orientation: orientation)
}

/// Set the stroke color.
pub fn angle_stroke(
  config config: PolarAngleAxisConfig,
  color color: String,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, stroke: color)
}

/// Set the tick label formatter.
/// The formatter receives the tick value and its zero-based index.
pub fn angle_tick_formatter(
  config config: PolarAngleAxisConfig,
  formatter formatter: fn(String, Int) -> String,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, tick_formatter: formatter)
}

/// Set the rotation angle for tick labels (in degrees).
/// Applied as an SVG transform="rotate(angle)" on each tick label.
/// Matches recharts PolarAngleAxis tick label rotation.
pub fn angle_label_angle(
  config config: PolarAngleAxisConfig,
  angle angle: Float,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, label_angle: Some(angle))
}

/// Set the scale type for the angle axis.
/// Allows overriding the default auto-detected scale.
/// Matches recharts PolarAngleAxis `scale` prop.
pub fn angle_scale_type(
  config config: PolarAngleAxisConfig,
  scale_type scale_type: AngleAxisScaleType,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, scale_type: Some(scale_type))
}

/// Set the axis type (category or number).
/// Matches recharts PolarAngleAxis `type` prop (default: category).
pub fn angle_axis_type(
  config config: PolarAngleAxisConfig,
  axis_type axis_type: PolarAxisType,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, axis_type: axis_type)
}

/// Allow or disallow duplicated categories.
/// Matches recharts PolarAngleAxis `allowDuplicatedCategory` prop (default: True).
pub fn angle_allow_duplicated_category(
  config config: PolarAngleAxisConfig,
  allow allow: Bool,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, allow_duplicated_category: allow)
}

/// Show or hide the entire angle axis.
/// When True, the axis renders nothing.
/// Matches recharts PolarAngleAxis `hide` prop (default: False).
pub fn angle_hide(
  config config: PolarAngleAxisConfig,
  hide hide: Bool,
) -> PolarAngleAxisConfig {
  PolarAngleAxisConfig(..config, hide: hide)
}

// ---------------------------------------------------------------------------
// PolarRadiusAxis builders
// ---------------------------------------------------------------------------

/// Set the angle of the radius axis line (degrees from 3 o'clock).
pub fn radius_angle(
  config config: PolarRadiusAxisConfig,
  angle angle: Float,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, angle: angle)
}

/// Show or hide the axis line.
pub fn radius_axis_line(
  config config: PolarRadiusAxisConfig,
  show show: Bool,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, show_axis_line: show)
}

/// Show or hide tick labels.
pub fn radius_show_tick(
  config config: PolarRadiusAxisConfig,
  show show: Bool,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, show_tick: show)
}

/// Set the number of ticks.
pub fn radius_tick_count(
  config config: PolarRadiusAxisConfig,
  count count: Int,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, tick_count: count)
}

/// Set the text anchor orientation for labels.
pub fn radius_orientation(
  config config: PolarRadiusAxisConfig,
  orientation orientation: RadiusAxisOrientation,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, orientation: orientation)
}

/// Set the stroke color.
pub fn radius_stroke(
  config config: PolarRadiusAxisConfig,
  color color: String,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, stroke: color)
}

/// Set the tick label formatter.
/// The formatter receives the tick value and its zero-based index.
pub fn radius_tick_formatter(
  config config: PolarRadiusAxisConfig,
  formatter formatter: fn(String, Int) -> String,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, tick_formatter: formatter)
}

/// Reverse the radius axis direction.
/// When True, the scale range maps inner_radius to domain_max and
/// outer_radius to domain_min, inverting the radial layout.
/// Matches recharts PolarRadiusAxis `reversed` prop (default: False).
pub fn radius_reversed(
  config config: PolarRadiusAxisConfig,
  reversed reversed: Bool,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, reversed: reversed)
}

/// Set a custom domain for the radius axis.
pub fn radius_domain(
  config config: PolarRadiusAxisConfig,
  min min: Float,
  max max: Float,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(
    ..config,
    domain_min: min,
    domain_max: max,
    has_custom_domain: True,
  )
}

/// Set the axis type (category or number).
/// Matches recharts PolarRadiusAxis `type` prop (default: number).
pub fn radius_axis_type(
  config config: PolarRadiusAxisConfig,
  axis_type axis_type: PolarAxisType,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, axis_type: axis_type)
}

/// Allow or disallow duplicated categories.
/// Matches recharts PolarRadiusAxis `allowDuplicatedCategory` prop (default: True).
pub fn radius_allow_duplicated_category(
  config config: PolarRadiusAxisConfig,
  allow allow: Bool,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, allow_duplicated_category: allow)
}

/// Allow or disallow data overflow beyond the domain.
/// Matches recharts PolarRadiusAxis `allowDataOverflow` prop (default: False).
pub fn radius_allow_data_overflow(
  config config: PolarRadiusAxisConfig,
  allow allow: Bool,
) -> PolarRadiusAxisConfig {
  PolarRadiusAxisConfig(..config, allow_data_overflow: allow)
}

// ---------------------------------------------------------------------------
// Rendering — PolarAngleAxis
// ---------------------------------------------------------------------------

/// Render a polar angle axis with tick labels around the perimeter.
/// Matches the recharts PolarAngleAxis rendering structure.
pub fn render_angle_axis(
  config config: PolarAngleAxisConfig,
  cx cx: Float,
  cy cy: Float,
  radius radius: Float,
  categories categories: List(String),
  angles angles: List(Float),
) -> Element(msg) {
  case config.hide {
    True -> element.none()
    False ->
      render_angle_axis_visible(config, cx, cy, radius, categories, angles)
  }
}

/// Render a visible polar angle axis (not hidden).
fn render_angle_axis_visible(
  config: PolarAngleAxisConfig,
  cx: Float,
  cy: Float,
  radius: Float,
  categories: List(String),
  angles: List(Float),
) -> Element(msg) {
  let base_attrs = [
    svg.attr("stroke", config.stroke),
    svg.attr("stroke-width", "1"),
    svg.attr("fill", "none"),
  ]

  // Axis line
  let axis_line_el = case config.show_axis_line {
    False -> element.none()
    True ->
      case config.axis_line_type {
        CircleAxisLine ->
          svg.circle(
            cx: math.fmt(cx),
            cy: math.fmt(cy),
            r: math.fmt(radius),
            attrs: base_attrs,
          )
        PolygonAxisLine -> {
          let d = polygon_path(cx, cy, radius, angles)
          svg.path(d: d, attrs: base_attrs)
        }
      }
  }

  // Tick lines and labels
  let tick_els =
    list.zip(categories, angles)
    |> list.index_map(fn(pair, index) {
      let #(cat, angle) = pair
      render_angle_tick(config, cx, cy, radius, cat, angle, index)
    })

  svg.g(attrs: [svg.attr("class", "recharts-polar-angle-axis")], children: [
    axis_line_el,
    ..tick_els
  ])
}

/// Render a single angle axis tick (line + label).
fn render_angle_tick(
  config: PolarAngleAxisConfig,
  cx: Float,
  cy: Float,
  radius: Float,
  category: String,
  angle: Float,
  tick_index: Int,
) -> Element(msg) {
  let label = config.tick_formatter(category, tick_index)

  // Point on the circle at this angle
  let #(px, py) =
    polar.to_cartesian(cx: cx, cy: cy, radius: radius, angle_degrees: angle)

  // Tick line extends outward (or inward) from the circle edge
  let tick_offset = case config.orientation {
    OuterOrientation -> int.to_float(config.tick_size)
    InnerOrientation -> 0.0 -. int.to_float(config.tick_size)
  }
  let #(tx, ty) =
    polar.to_cartesian(
      cx: cx,
      cy: cy,
      radius: radius +. tick_offset,
      angle_degrees: angle,
    )

  let tick_line_el = case config.show_tick_line {
    False -> element.none()
    True ->
      svg.line(
        x1: math.fmt(px),
        y1: math.fmt(py),
        x2: math.fmt(tx),
        y2: math.fmt(ty),
        attrs: [
          svg.attr("stroke", config.stroke),
          svg.attr("stroke-width", "1"),
        ],
      )
  }

  // Label position: at the tick line endpoint
  let label_offset = case config.orientation {
    OuterOrientation -> int.to_float(config.tick_size)
    InnerOrientation -> 0.0 -. int.to_float(config.tick_size)
  }
  let #(lx, ly) =
    polar.to_cartesian(
      cx: cx,
      cy: cy,
      radius: radius +. label_offset,
      angle_degrees: angle,
    )

  // Text anchor based on angle position (matching recharts getTickTextAnchor)
  let anchor = get_tick_text_anchor(angle, config.orientation)
  let baseline = get_tick_vertical_anchor(angle, config.orientation)

  let rotation_attrs = case config.label_angle {
    Some(la) -> [
      svg.attr(
        "transform",
        "rotate("
          <> float.to_string(la)
          <> ","
          <> math.fmt(lx)
          <> ","
          <> math.fmt(ly)
          <> ")",
      ),
    ]
    None -> []
  }

  let label_el = case config.show_tick {
    False -> element.none()
    True ->
      svg.text(
        x: math.fmt(lx),
        y: math.fmt(ly),
        content: label,
        attrs: list.append(
          [
            svg.attr("text-anchor", anchor),
            svg.attr("dominant-baseline", baseline),
            svg.attr("font-size", "12"),
            svg.attr("fill", "var(--weft-chart-tick-text, currentColor)"),
          ],
          rotation_attrs,
        ),
      )
  }

  svg.g(attrs: [], children: [tick_line_el, label_el])
}

/// Compute text-anchor for angle axis ticks.
/// Uses sin(angle) to determine horizontal position: positive sin means
/// the tick is to the right of center (start anchor for outer orientation).
/// Matches recharts getTickTextAnchor logic with eps = 1e-5.
fn get_tick_text_anchor(
  angle: Float,
  orientation: AngleAxisOrientation,
) -> String {
  let angle_rad = math.to_radians(angle)
  let sin_val = math.sin(angle_rad)

  // Threshold for "near zero" (label at top/bottom → middle anchor)
  let eps = 1.0e-5
  case math.abs(sin_val) <. eps {
    True -> "middle"
    False ->
      case orientation {
        OuterOrientation ->
          case sin_val >. 0.0 {
            True -> "start"
            False -> "end"
          }
        InnerOrientation ->
          case sin_val >. 0.0 {
            True -> "end"
            False -> "start"
          }
      }
  }
}

/// Compute dominant-baseline for angle axis ticks.
/// Uses -cos(angle) to determine vertical position: positive means
/// the tick is below center (hanging baseline for outer orientation).
/// Matches recharts getTickTextVerticalAnchor logic with eps = 1e-5.
fn get_tick_vertical_anchor(
  angle: Float,
  orientation: AngleAxisOrientation,
) -> String {
  let angle_rad = math.to_radians(angle)
  let neg_cos_val = 0.0 -. math.cos(angle_rad)
  let eps = 1.0e-5
  case math.abs(neg_cos_val) <. eps {
    True -> "central"
    False ->
      case orientation {
        OuterOrientation ->
          case neg_cos_val >. 0.0 {
            True -> "hanging"
            False -> "auto"
          }
        InnerOrientation ->
          case neg_cos_val >. 0.0 {
            True -> "auto"
            False -> "hanging"
          }
      }
  }
}

/// Generate a closed polygon path through points at given angles.
fn polygon_path(
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
        list.fold(rest_angles, start, fn(acc, a) {
          let #(x, y) =
            polar.to_cartesian(cx: cx, cy: cy, radius: radius, angle_degrees: a)
          acc <> "L" <> math.fmt(x) <> "," <> math.fmt(y)
        })
      segments <> "Z"
    }
  }
}

// ---------------------------------------------------------------------------
// Rendering — PolarRadiusAxis
// ---------------------------------------------------------------------------

/// Render a polar radius axis with tick labels along a radial line.
/// Matches the recharts PolarRadiusAxis rendering structure.
pub fn render_radius_axis(
  config config: PolarRadiusAxisConfig,
  cx cx: Float,
  cy cy: Float,
  inner_radius inner_radius: Float,
  outer_radius outer_radius: Float,
  domain_max domain_max: Float,
) -> Element(msg) {
  // Compute the actual domain
  let #(d_min, d_max) = case config.has_custom_domain {
    True -> #(config.domain_min, config.domain_max)
    False -> #(0.0, domain_max)
  }

  // Build a linear scale from data domain to radius range.
  // When reversed, swap range so larger values map to inner radius.
  let #(r_start, r_end) = case config.reversed {
    False -> #(inner_radius, outer_radius)
    True -> #(outer_radius, inner_radius)
  }
  let r_scale =
    scale.linear(
      domain_min: d_min,
      domain_max: d_max,
      range_start: r_start,
      range_end: r_end,
    )

  // Generate nice tick values
  let tick_values = scale.nice_ticks(d_min, d_max, config.tick_count, True)

  // Convert recharts angle convention (0=east) to weft_chart convention (0=north).
  // recharts polarToCartesian: x = cx + cos(-angle*π/180)*r → angle=0 → east.
  // weft_chart to_cartesian: angle=0 → north.  Formula: weft_angle = 90 - recharts_angle.
  let weft_angle = 90.0 -. config.angle

  // Axis line from inner to outer radius along the configured angle
  let axis_line_el = case config.show_axis_line {
    False -> element.none()
    True -> {
      let #(x1, y1) =
        polar.to_cartesian(
          cx: cx,
          cy: cy,
          radius: inner_radius,
          angle_degrees: weft_angle,
        )
      let #(x2, y2) =
        polar.to_cartesian(
          cx: cx,
          cy: cy,
          radius: outer_radius,
          angle_degrees: weft_angle,
        )
      svg.line(
        x1: math.fmt(x1),
        y1: math.fmt(y1),
        x2: math.fmt(x2),
        y2: math.fmt(y2),
        attrs: [
          svg.attr("stroke", config.stroke),
          svg.attr("stroke-width", "1"),
        ],
      )
    }
  }

  // Tick labels along the radius.
  // Recharts applies rotate(90 - angle) to each tick so labels read perpendicular
  // to the axis.  Ticks at or below inner_radius (the origin) are suppressed —
  // recharts does not render the "0" label at the center point.
  let tick_els = case config.show_tick {
    False -> []
    True ->
      list.filter_map(
        list.index_map(tick_values, fn(tick_val, tick_index) {
          #(tick_val, tick_index)
        }),
        fn(pair) {
          let #(tick_val, tick_index) = pair
          let r = scale.linear_apply(r_scale, tick_val)
          case r <=. inner_radius +. 0.001 {
            True -> Error(Nil)
            False -> {
              let #(tx, ty) =
                polar.to_cartesian(
                  cx: cx,
                  cy: cy,
                  radius: r,
                  angle_degrees: weft_angle,
                )
              let formatted =
                config.tick_formatter(format_tick(tick_val), tick_index)
              let anchor = case config.orientation {
                LeftOrientation -> "end"
                RightOrientation -> "start"
                MiddleOrientation -> "middle"
              }
              let rotation = 90.0 -. config.angle
              Ok(
                svg.text(
                  x: math.fmt(tx),
                  y: math.fmt(ty),
                  content: formatted,
                  attrs: [
                    svg.attr("text-anchor", anchor),
                    svg.attr("dominant-baseline", "central"),
                    svg.attr("font-size", "12"),
                    svg.attr(
                      "fill",
                      "var(--weft-chart-tick-text, currentColor)",
                    ),
                    svg.attr(
                      "transform",
                      "rotate("
                        <> math.fmt(rotation)
                        <> ","
                        <> math.fmt(tx)
                        <> ","
                        <> math.fmt(ty)
                        <> ")",
                    ),
                  ],
                ),
              )
            }
          }
        },
      )
  }

  svg.g(attrs: [svg.attr("class", "recharts-polar-radius-axis")], children: [
    axis_line_el,
    ..tick_els
  ])
}

/// Format a tick value, removing unnecessary trailing zeros.
fn format_tick(value: Float) -> String {
  let rounded = float.round(value)
  case math.abs(value -. int.to_float(rounded)) <. 0.0001 {
    True -> int.to_string(rounded)
    False -> math.fmt(value)
  }
}
