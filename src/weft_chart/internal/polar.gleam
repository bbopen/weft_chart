//// Polar coordinate helpers.
////
//// Conversion between polar and cartesian coordinates, angle
//// computation for pie sectors, and arc path generation.

import gleam/int
import gleam/list
import weft_chart/internal/math

// ---------------------------------------------------------------------------
// Coordinate conversion
// ---------------------------------------------------------------------------

/// Convert polar coordinates to cartesian.
/// Angle is in degrees, measured clockwise from 12 o'clock (north).
pub fn to_cartesian(
  cx cx: Float,
  cy cy: Float,
  radius radius: Float,
  angle_degrees angle_degrees: Float,
) -> #(Float, Float) {
  let rad = math.to_radians(angle_degrees -. 90.0)
  let x = cx +. radius *. math.cos(rad)
  let y = cy +. radius *. math.sin(rad)
  #(x, y)
}

// ---------------------------------------------------------------------------
// Arc path generation
// ---------------------------------------------------------------------------

/// Generate an SVG arc path for a pie sector.
///
/// Draws from `start_angle` to `end_angle` at the given radii.
/// Angles are in degrees, clockwise from 12 o'clock.
pub fn sector_path(
  cx cx: Float,
  cy cy: Float,
  inner_radius inner_radius: Float,
  outer_radius outer_radius: Float,
  start_angle start_angle: Float,
  end_angle end_angle: Float,
) -> String {
  let delta = math.abs(end_angle -. start_angle)
  let large_arc = case delta >. 180.0 {
    True -> "1"
    False -> "0"
  }
  let sweep = case end_angle >. start_angle {
    True -> "1"
    False -> "0"
  }

  let #(ox1, oy1) =
    to_cartesian(
      cx: cx,
      cy: cy,
      radius: outer_radius,
      angle_degrees: start_angle,
    )
  let #(ox2, oy2) =
    to_cartesian(cx: cx, cy: cy, radius: outer_radius, angle_degrees: end_angle)

  case inner_radius >. 0.0 {
    True -> {
      let #(ix1, iy1) =
        to_cartesian(
          cx: cx,
          cy: cy,
          radius: inner_radius,
          angle_degrees: end_angle,
        )
      let #(ix2, iy2) =
        to_cartesian(
          cx: cx,
          cy: cy,
          radius: inner_radius,
          angle_degrees: start_angle,
        )
      let inner_sweep = case end_angle >. start_angle {
        True -> "0"
        False -> "1"
      }

      "M"
      <> f(ox1)
      <> ","
      <> f(oy1)
      <> "A"
      <> f(outer_radius)
      <> ","
      <> f(outer_radius)
      <> " 0 "
      <> large_arc
      <> " "
      <> sweep
      <> " "
      <> f(ox2)
      <> ","
      <> f(oy2)
      <> "L"
      <> f(ix1)
      <> ","
      <> f(iy1)
      <> "A"
      <> f(inner_radius)
      <> ","
      <> f(inner_radius)
      <> " 0 "
      <> large_arc
      <> " "
      <> inner_sweep
      <> " "
      <> f(ix2)
      <> ","
      <> f(iy2)
      <> "Z"
    }
    False ->
      "M"
      <> f(ox1)
      <> ","
      <> f(oy1)
      <> "A"
      <> f(outer_radius)
      <> ","
      <> f(outer_radius)
      <> " 0 "
      <> large_arc
      <> " "
      <> sweep
      <> " "
      <> f(ox2)
      <> ","
      <> f(oy2)
      <> "L"
      <> f(cx)
      <> ","
      <> f(cy)
      <> "Z"
  }
}

/// Compute the signed delta angle, capped at 359.999 degrees.
///
/// Matches recharts `getDeltaAngle` — ensures a full 360 sector
/// never produces coincident start/end points.
pub fn get_delta_angle(start_angle: Float, end_angle: Float) -> Float {
  let s = math.sign(end_angle -. start_angle)
  let delta = math.list_min([math.abs(end_angle -. start_angle), 359.999])
  s *. delta
}

/// Compute tangent circle contact points for a corner radius arc.
///
/// Returns `#(#(circle_tangent_x, circle_tangent_y), #(line_tangent_x, line_tangent_y), theta)`
/// where theta is the angular offset in degrees.  Matches recharts
/// `getTangentCircle` from Sector.tsx.
pub fn get_tangent_circle(
  cx cx: Float,
  cy cy: Float,
  radius radius: Float,
  angle angle: Float,
  sign sign: Float,
  is_external is_external: Bool,
  corner_radius corner_radius: Float,
  corner_is_external corner_is_external: Bool,
) -> #(#(Float, Float), #(Float, Float), Float) {
  let ext_sign = case is_external {
    True -> 1.0
    False -> -1.0
  }
  let center_radius = corner_radius *. ext_sign +. radius
  // Guard against division by zero or invalid asin input
  let ratio = case math.abs(center_radius) <. 0.0001 {
    True -> 0.0
    False -> math.clamp(corner_radius /. center_radius, -1.0, 1.0)
  }
  let theta = math.to_degrees(math.asin(ratio))
  let center_angle = case corner_is_external {
    True -> angle
    False -> angle +. sign *. theta
  }

  // Circle tangency: point on the radius arc
  let circle_tangent =
    to_cartesian(cx: cx, cy: cy, radius: radius, angle_degrees: center_angle)

  // Line tangency: point on the radial line
  let line_tangent_angle = case corner_is_external {
    True -> angle -. sign *. theta
    False -> angle
  }
  let line_tangent =
    to_cartesian(
      cx: cx,
      cy: cy,
      radius: center_radius *. math.cos(math.to_radians(theta)),
      angle_degrees: line_tangent_angle,
    )

  #(circle_tangent, line_tangent, theta)
}

/// Generate an SVG arc path for a sector with rounded corners.
///
/// Direct port of recharts `getSectorWithCorner`.  Applies corner
/// radius arcs at each transition between the radial edges and the
/// outer/inner arcs.  `force_corner_radius` draws a pill shape when
/// the sector angle is too small for corners.
pub fn sector_path_with_corners(
  cx cx: Float,
  cy cy: Float,
  inner_radius inner_radius: Float,
  outer_radius outer_radius: Float,
  corner_radius corner_radius: Float,
  force_corner_radius force_corner_radius: Bool,
  corner_is_external corner_is_external: Bool,
  start_angle start_angle: Float,
  end_angle end_angle: Float,
) -> String {
  let sign = math.sign(end_angle -. start_angle)

  // Sweep flag for arcs curving in the main direction (CW when sign > 0)
  let sweep = case sign >. 0.0 {
    True -> "1"
    False -> "0"
  }
  // Opposite sweep for inner arc and force-corner pill
  let rev_sweep = case sign <. 0.0 {
    True -> "1"
    False -> "0"
  }

  // Start outer corner
  let #(soct, solt, sot) =
    get_tangent_circle(
      cx: cx,
      cy: cy,
      radius: outer_radius,
      angle: start_angle,
      sign: sign,
      is_external: False,
      corner_radius: corner_radius,
      corner_is_external: corner_is_external,
    )

  // End outer corner
  let #(eoct, eolt, eot) =
    get_tangent_circle(
      cx: cx,
      cy: cy,
      radius: outer_radius,
      angle: end_angle,
      sign: 0.0 -. sign,
      is_external: False,
      corner_radius: corner_radius,
      corner_is_external: corner_is_external,
    )

  let outer_arc_angle = case corner_is_external {
    True -> math.abs(start_angle -. end_angle)
    False -> math.abs(start_angle -. end_angle) -. sot -. eot
  }

  // If sector too small for corners
  case outer_arc_angle <. 0.0 {
    True ->
      case force_corner_radius {
        True ->
          // Pill shape
          "M"
          <> f(solt.0)
          <> ","
          <> f(solt.1)
          <> "a"
          <> f(corner_radius)
          <> ","
          <> f(corner_radius)
          <> ",0,0,"
          <> sweep
          <> ","
          <> f(corner_radius *. 2.0)
          <> ",0"
          <> "a"
          <> f(corner_radius)
          <> ","
          <> f(corner_radius)
          <> ",0,0,"
          <> sweep
          <> ","
          <> f(0.0 -. corner_radius *. 2.0)
          <> ",0"
        False ->
          sector_path(
            cx: cx,
            cy: cy,
            inner_radius: inner_radius,
            outer_radius: outer_radius,
            start_angle: start_angle,
            end_angle: end_angle,
          )
      }

    False -> {
      let outer_large = case outer_arc_angle >. 180.0 {
        True -> "1"
        False -> "0"
      }

      // Outer path: line tangent → corner arc → outer arc → corner arc → line tangent
      let path =
        "M"
        <> f(solt.0)
        <> ","
        <> f(solt.1)
        <> "A"
        <> f(corner_radius)
        <> ","
        <> f(corner_radius)
        <> ",0,0,"
        <> sweep
        <> ","
        <> f(soct.0)
        <> ","
        <> f(soct.1)
        <> "A"
        <> f(outer_radius)
        <> ","
        <> f(outer_radius)
        <> ",0,"
        <> outer_large
        <> ","
        <> sweep
        <> ","
        <> f(eoct.0)
        <> ","
        <> f(eoct.1)
        <> "A"
        <> f(corner_radius)
        <> ","
        <> f(corner_radius)
        <> ",0,0,"
        <> sweep
        <> ","
        <> f(eolt.0)
        <> ","
        <> f(eolt.1)

      case inner_radius >. 0.0 {
        True -> {
          // Start inner corner (external tangent)
          let #(sict, silt, sit) =
            get_tangent_circle(
              cx: cx,
              cy: cy,
              radius: inner_radius,
              angle: start_angle,
              sign: sign,
              is_external: True,
              corner_radius: corner_radius,
              corner_is_external: corner_is_external,
            )

          // End inner corner (external tangent)
          let #(eict, eilt, eit) =
            get_tangent_circle(
              cx: cx,
              cy: cy,
              radius: inner_radius,
              angle: end_angle,
              sign: 0.0 -. sign,
              is_external: True,
              corner_radius: corner_radius,
              corner_is_external: corner_is_external,
            )

          let inner_arc_angle = case corner_is_external {
            True -> math.abs(start_angle -. end_angle)
            False -> math.abs(start_angle -. end_angle) -. sit -. eit
          }

          case inner_arc_angle <. 0.0 && corner_radius == 0.0 {
            True -> path <> "L" <> f(cx) <> "," <> f(cy) <> "Z"
            False -> {
              let inner_large = case inner_arc_angle >. 180.0 {
                True -> "1"
                False -> "0"
              }
              path
              <> "L"
              <> f(eilt.0)
              <> ","
              <> f(eilt.1)
              <> "A"
              <> f(corner_radius)
              <> ","
              <> f(corner_radius)
              <> ",0,0,"
              <> sweep
              <> ","
              <> f(eict.0)
              <> ","
              <> f(eict.1)
              <> "A"
              <> f(inner_radius)
              <> ","
              <> f(inner_radius)
              <> ",0,"
              <> inner_large
              <> ","
              <> rev_sweep
              <> ","
              <> f(sict.0)
              <> ","
              <> f(sict.1)
              <> "A"
              <> f(corner_radius)
              <> ","
              <> f(corner_radius)
              <> ",0,0,"
              <> sweep
              <> ","
              <> f(silt.0)
              <> ","
              <> f(silt.1)
              <> "Z"
            }
          }
        }
        False -> path <> "L" <> f(cx) <> "," <> f(cy) <> "Z"
      }
    }
  }
}

/// Compute the midpoint angle between start and end.
pub fn mid_angle(start_angle: Float, end_angle: Float) -> Float {
  { start_angle +. end_angle } /. 2.0
}

/// Compute sector angles for a list of values.
///
/// Returns a list of `#(start_angle, end_angle)` pairs distributed
/// proportionally across the angular range.
pub fn distribute_angles(
  values values: List(Float),
  start_angle start_angle: Float,
  end_angle end_angle: Float,
  padding_angle padding_angle: Float,
) -> List(#(Float, Float)) {
  let total = list.fold(values, 0.0, fn(acc, v) { acc +. math.abs(v) })
  case total <=. 0.0 {
    True -> list.map(values, fn(_) { #(start_angle, start_angle) })
    False -> {
      let n = list.length(values)
      let total_padding = int.to_float(n) *. padding_angle
      let available = math.abs(end_angle -. start_angle) -. total_padding
      let dir = math.sign(end_angle -. start_angle)

      let #(result, _) =
        list.fold(values, #([], start_angle), fn(state, value) {
          let #(acc, current_start) = state
          let proportion = math.abs(value) /. total
          let sweep_val = proportion *. available *. dir
          let current_end = current_start +. sweep_val
          let next_start = current_end +. padding_angle *. dir
          #([#(current_start, current_end), ..acc], next_start)
        })
      list.reverse(result)
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn f(value: Float) -> String {
  math.fmt(value)
}
