//// Curve interpolation algorithms for SVG path generation.
////
//// Ports the d3-shape curve factories to pure Gleam.  Given a list
//// of `#(x, y)` points, each curve type produces an SVG path `d`
//// attribute string.  All 13 recharts/d3-shape curve types plus a
//// `Custom` variant for user-defined curve functions are supported.

import gleam/list
import weft_chart/internal/math

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Supported curve interpolation types, matching Recharts / d3-shape.
pub type CurveType {
  /// Straight line segments between points.
  Linear
  /// Straight line segments with a closing line back to the first point.
  LinearClosed
  /// Natural cubic spline — smooth curves passing through all points.
  Natural
  /// Monotone cubic interpolation preserving monotonicity in x.
  MonotoneX
  /// Monotone cubic interpolation preserving monotonicity in y.
  MonotoneY
  /// Step function with transition at the midpoint.
  Step
  /// Step function with transition before the data point.
  StepBefore
  /// Step function with transition after the data point.
  StepAfter
  /// Basis spline (B-spline) — smooth but may not pass through points.
  Basis
  /// Closed basis spline — wraps back to the first point.
  BasisClosed
  /// Open basis spline — excludes first and last points from the curve.
  BasisOpen
  /// Smooth S-shaped curves with horizontal tangents at endpoints.
  BumpX
  /// Smooth S-shaped curves with vertical tangents at endpoints.
  BumpY
  /// Alias for MonotoneX — monotone interpolation in the horizontal direction.
  Monotone
  /// Alias for BumpX — bump interpolation in the horizontal direction.
  Bump
  /// User-defined curve generation function.
  Custom(generator: fn(List(#(Float, Float))) -> String)
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Generate an SVG path `d` attribute for a curve through the given points.
pub fn path(
  curve_type curve_type: CurveType,
  points points: List(#(Float, Float)),
) -> String {
  case curve_type {
    Custom(generator:) -> generator(points)
    _ ->
      case list.length(points) {
        0 -> ""
        1 ->
          case points {
            [#(x, y)] -> "M" <> math.fmt(x) <> "," <> math.fmt(y)
            _ -> ""
          }
        _ ->
          case curve_type {
            Linear -> linear_path(points)
            LinearClosed -> linear_closed_path(points)
            Natural -> natural_path(points)
            MonotoneX -> monotone_x_path(points)
            MonotoneY -> monotone_y_path(points)
            Step -> step_path(points, 0.5)
            StepBefore -> step_path(points, 0.0)
            StepAfter -> step_path(points, 1.0)
            Basis -> basis_path(points)
            BasisClosed -> basis_closed_path(points)
            BasisOpen -> basis_open_path(points)
            BumpX -> bump_x_path(points)
            BumpY -> bump_y_path(points)
            Monotone -> monotone_x_path(points)
            Bump -> bump_x_path(points)
            Custom(_) -> ""
          }
      }
  }
}

/// Generate a closed area path: curve on top, baseline closure on bottom.
pub fn area_path(
  curve_type curve_type: CurveType,
  points points: List(#(Float, Float)),
  baseline baseline: Baseline,
) -> String {
  case points {
    [] -> ""
    _ -> {
      let curve = path(curve_type: curve_type, points: points)
      case curve {
        "" -> ""
        _ -> close_area(curve, points, baseline)
      }
    }
  }
}

/// How the area beneath a curve closes to form a filled region.
pub type Baseline {
  /// Flat baseline at a fixed y-coordinate.
  FlatBaseline(y: Float)
  /// Per-point baseline (for stacked areas).  Points should be in the
  /// same x-order as the curve points, reversed for correct winding.
  PointBaseline(points: List(#(Float, Float)))
}

// ---------------------------------------------------------------------------
// Linear
// ---------------------------------------------------------------------------

fn linear_path(points: List(#(Float, Float))) -> String {
  case points {
    [] -> ""
    [#(x, y), ..rest] ->
      list.fold(rest, "M" <> f2(x, y), fn(acc, pt) {
        acc <> "L" <> f2(pt.0, pt.1)
      })
  }
}

// ---------------------------------------------------------------------------
// Linear closed (d3 curveLinearClosed)
// ---------------------------------------------------------------------------

fn linear_closed_path(points: List(#(Float, Float))) -> String {
  case points {
    [] -> ""
    [#(x, y)] -> "M" <> f2(x, y) <> "Z"
    [#(x, y), ..rest] -> {
      let segments =
        list.fold(rest, "M" <> f2(x, y), fn(acc, pt) {
          acc <> "L" <> f2(pt.0, pt.1)
        })
      segments <> "Z"
    }
  }
}

// ---------------------------------------------------------------------------
// Natural cubic spline (d3 curveNatural)
// ---------------------------------------------------------------------------

fn natural_path(points: List(#(Float, Float))) -> String {
  let count = list.length(points)
  case count < 3 {
    True -> linear_path(points)
    False -> {
      let xs = list.map(points, fn(p) { p.0 })
      let ys = list.map(points, fn(p) { p.1 })
      let #(cpx1, cpx2) = natural_control_points(xs)
      let #(cpy1, cpy2) = natural_control_points(ys)

      let cps = list.zip(list.zip(cpx1, cpy1), list.zip(cpx2, cpy2))
      let rest_points = list.drop(points, 1)
      let segments = list.zip(cps, rest_points)

      case points {
        [#(x0, y0), ..] ->
          list.fold(segments, "M" <> f2(x0, y0), fn(acc, seg) {
            let #(#(#(cx1, cy1), #(cx2, cy2)), #(x, y)) = seg
            acc <> "C" <> f2(cx1, cy1) <> "," <> f2(cx2, cy2) <> "," <> f2(x, y)
          })
        _ -> ""
      }
    }
  }
}

/// Compute natural cubic spline control points for a 1-D coordinate
/// sequence.  Returns (cp1, cp2) each of length n-1.
fn natural_control_points(values: List(Float)) -> #(List(Float), List(Float)) {
  let n = list.length(values) - 1
  case n < 2 {
    True -> #([], [])
    False -> {
      let pairs = list.zip(values, list.drop(values, 1))

      // Build tridiagonal system matching d3-shape curveNatural
      let rows =
        list.index_map(pairs, fn(pair, i) {
          let #(xi, xi1) = pair
          case i == 0 {
            True -> #(0.0, 2.0, xi +. 2.0 *. xi1)
            False ->
              case i == n - 1 {
                True -> #(2.0, 7.0, 8.0 *. xi +. xi1)
                False -> #(1.0, 4.0, 4.0 *. xi +. 2.0 *. xi1)
              }
          }
        })

      // Forward elimination
      let eliminated = case rows {
        [] -> []
        [#(_, d0, r0), ..rest] -> {
          let #(acc_rev, _, _) =
            list.fold(rest, #([#(d0, r0)], d0, r0), fn(state, row) {
              let #(acc, prev_d, prev_r) = state
              let #(lower, d, r) = row
              let m = lower /. prev_d
              let new_d = d -. m
              let new_r = r -. m *. prev_r
              #([#(new_d, new_r), ..acc], new_d, new_r)
            })
          list.reverse(acc_rev)
        }
      }

      // Back substitution
      let cp1 = case list.reverse(eliminated) {
        [] -> []
        [#(d_last, r_last), ..rest] -> {
          let cp_last = r_last /. d_last
          let #(result, _) =
            list.fold(rest, #([cp_last], cp_last), fn(state, row) {
              let #(acc, next_cp) = state
              let #(d, r) = row
              let cp = { r -. next_cp } /. d
              #([cp, ..acc], cp)
            })
          result
        }
      }

      // Second control points
      let cp1_tail = list.drop(cp1, 1)
      let values_tail = list.drop(values, 1)
      let cp2_init =
        list.map(list.zip(values_tail, cp1_tail), fn(pair) {
          let #(xi1, cpi1) = pair
          2.0 *. xi1 -. cpi1
        })

      let last_val = list_last(values, 0.0)
      let last_cp1 = list_last(cp1, 0.0)
      let cp2 = list.append(cp2_init, [{ last_val +. last_cp1 } /. 2.0])
      #(cp1, cp2)
    }
  }
}

// ---------------------------------------------------------------------------
// Monotone X (d3 curveMonotoneX)
// ---------------------------------------------------------------------------

fn monotone_x_path(points: List(#(Float, Float))) -> String {
  let count = list.length(points)
  case count < 3 {
    True -> linear_path(points)
    False -> {
      let slopes = monotone_x_slopes(points)
      let rest_points = list.drop(points, 1)
      let slope_pairs = list.zip(slopes, list.drop(slopes, 1))

      case points {
        [#(x0, y0), ..] -> {
          let #(result, _) =
            list.fold(
              list.zip(rest_points, slope_pairs),
              #("M" <> f2(x0, y0), #(x0, y0)),
              fn(state, seg) {
                let #(acc, #(prev_x, prev_y)) = state
                let #(#(x1, y1), #(m0, m1)) = seg
                // Hermite to bezier: dx = (x1 - x0) / 3
                let dx = { x1 -. prev_x } /. 3.0
                let cx1 = prev_x +. dx
                let cy1 = prev_y +. dx *. m0
                let cx2 = x1 -. dx
                let cy2 = y1 -. dx *. m1
                let new_acc =
                  acc
                  <> "C"
                  <> f2(cx1, cy1)
                  <> ","
                  <> f2(cx2, cy2)
                  <> ","
                  <> f2(x1, y1)
                #(new_acc, #(x1, y1))
              },
            )
          result
        }
        _ -> ""
      }
    }
  }
}

/// Compute monotone slopes matching d3-shape curveMonotoneX.
/// Uses the Steffen (1990) method to preserve monotonicity.
fn monotone_x_slopes(points: List(#(Float, Float))) -> List(Float) {
  let deltas = list.zip(points, list.drop(points, 1))
  let dxs =
    list.map(deltas, fn(pair) {
      let #(#(x0, _), #(x1, _)) = pair
      x1 -. x0
    })
  let dys =
    list.map(deltas, fn(pair) {
      let #(#(_, y0), #(_, y1)) = pair
      y1 -. y0
    })
  let ms =
    list.map(list.zip(dys, dxs), fn(pair) {
      let #(dy, dx) = pair
      case dx == 0.0 {
        True -> 0.0
        False -> dy /. dx
      }
    })

  case ms {
    [] -> [0.0]
    [single] -> [single, single]
    [first, ..rest_ms] -> {
      // d3 slope3: computes slope at interior points
      // slope3(t) = (s0*h1 + s1*h0) / (h0 + h1), clamped for monotonicity
      let dx_pairs = list.zip(dxs, list.drop(dxs, 1))
      let m_pairs = list.zip([first, ..rest_ms], rest_ms)
      let interior =
        list.map(list.zip(m_pairs, dx_pairs), fn(pair) {
          let #(#(s0, s1), #(h0, h1)) = pair
          case s0 *. s1 <=. 0.0 {
            True -> 0.0
            False -> {
              let p = { s0 *. h1 +. s1 *. h0 } /. { h0 +. h1 }
              let abs_s0 = math.abs(s0)
              let abs_s1 = math.abs(s1)
              let half_abs_p = 0.5 *. math.abs(p)
              let min_val = math.list_min([abs_s0, abs_s1, half_abs_p])
              math.sign(s0) *. math.sign(s1) *. min_val
            }
          }
        })
      // d3 slope2 for endpoints
      let first_slope = case dxs {
        [h, ..] ->
          case h == 0.0 {
            True -> first
            False -> {
              let s = { 3.0 *. list_head_f(dys, 0.0) /. h -. first } /. 2.0
              case math.sign(s) != math.sign(first) {
                True -> 0.0
                False ->
                  case math.abs(s) >. math.abs(3.0 *. first) {
                    True -> 3.0 *. first
                    False -> s
                  }
              }
            }
          }
        _ -> first
      }
      let last_m = list_last(ms, 0.0)
      let last_dx = list_last(list.map(dxs, fn(v) { v }), 0.0)
      let last_dy = list_last(list.map(dys, fn(v) { v }), 0.0)
      let last_slope = case last_dx == 0.0 {
        True -> last_m
        False -> {
          let s = { 3.0 *. last_dy /. last_dx -. last_m } /. 2.0
          case math.sign(s) != math.sign(last_m) {
            True -> 0.0
            False ->
              case math.abs(s) >. math.abs(3.0 *. last_m) {
                True -> 3.0 *. last_m
                False -> s
              }
          }
        }
      }
      [first_slope, ..list.append(interior, [last_slope])]
    }
  }
}

// ---------------------------------------------------------------------------
// Monotone Y (d3 curveMonotoneY) — coordinate reflection
// ---------------------------------------------------------------------------

fn monotone_y_path(points: List(#(Float, Float))) -> String {
  // MonotoneY swaps x,y before applying MonotoneX, then swaps back
  let reflected = list.map(points, fn(p) { #(p.1, p.0) })
  let count = list.length(reflected)
  case count < 3 {
    True -> linear_path(points)
    False -> {
      let slopes = monotone_x_slopes(reflected)
      let rest_points = list.drop(points, 1)
      let slope_pairs = list.zip(slopes, list.drop(slopes, 1))

      case points {
        [#(x0, y0), ..] -> {
          let #(result, _) =
            list.fold(
              list.zip(rest_points, slope_pairs),
              #("M" <> f2(x0, y0), #(x0, y0)),
              fn(state, seg) {
                let #(acc, #(prev_x, prev_y)) = state
                let #(#(x1, y1), #(m0, m1)) = seg
                // Reflected hermite: dy = (y1 - y0) / 3
                let dy = { y1 -. prev_y } /. 3.0
                let cy1 = prev_y +. dy
                let cx1 = prev_x +. dy *. m0
                let cy2 = y1 -. dy
                let cx2 = x1 -. dy *. m1
                let new_acc =
                  acc
                  <> "C"
                  <> f2(cx1, cy1)
                  <> ","
                  <> f2(cx2, cy2)
                  <> ","
                  <> f2(x1, y1)
                #(new_acc, #(x1, y1))
              },
            )
          result
        }
        _ -> ""
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Step functions (d3 curveStep, curveStepBefore, curveStepAfter)
// ---------------------------------------------------------------------------

fn step_path(points: List(#(Float, Float)), t: Float) -> String {
  case points {
    [] -> ""
    [#(x0, y0), ..rest] ->
      list.fold(rest, #("M" <> f2(x0, y0), x0, y0), fn(state, pt) {
        let #(acc, prev_x, prev_y) = state
        let #(x1, y1) = pt
        case t <=. 0.0 {
          // StepBefore: vertical first, then horizontal
          True -> {
            let new_acc = acc <> "V" <> math.fmt(y1) <> "H" <> math.fmt(x1)
            let _ = prev_y
            #(new_acc, x1, y1)
          }
          False ->
            case t >=. 1.0 {
              // StepAfter: horizontal first, then vertical
              True -> {
                let new_acc = acc <> "H" <> math.fmt(x1) <> "V" <> math.fmt(y1)
                let _ = prev_y
                #(new_acc, x1, y1)
              }
              // Step (t=0.5): interpolate horizontal position
              False -> {
                let mid_x = prev_x +. { x1 -. prev_x } *. t
                let new_acc =
                  acc
                  <> "H"
                  <> math.fmt(mid_x)
                  <> "V"
                  <> math.fmt(y1)
                  <> "H"
                  <> math.fmt(x1)
                let _ = prev_y
                #(new_acc, x1, y1)
              }
            }
        }
      }).0
  }
}

// ---------------------------------------------------------------------------
// Basis spline (d3 curveBasis)
// ---------------------------------------------------------------------------

fn basis_path(points: List(#(Float, Float))) -> String {
  let count = list.length(points)
  case count < 3 {
    True -> linear_path(points)
    False ->
      case points {
        [#(x0, y0), #(x1, y1), ..rest] -> {
          let start_x = { x0 +. 2.0 *. x1 } /. 3.0
          let start_y = { y0 +. 2.0 *. y1 } /. 3.0
          let init = "M" <> f2(x0, y0) <> "L" <> f2(start_x, start_y)

          let #(result, prev_x, prev_y) =
            list.fold(rest, #(init, x1, y1), fn(state, pt) {
              let #(acc, px, py) = state
              let #(nx, ny) = pt
              basis_segment(acc, px, py, nx, ny)
            })

          result <> "L" <> f2(prev_x, prev_y)
        }
        _ -> ""
      }
  }
}

// ---------------------------------------------------------------------------
// Basis closed (d3 curveBasisClosed) — wraps back to first point
// ---------------------------------------------------------------------------

fn basis_closed_path(points: List(#(Float, Float))) -> String {
  let count = list.length(points)
  case count {
    0 -> ""
    1 ->
      case points {
        [#(x, y)] -> "M" <> f2(x, y) <> "Z"
        _ -> ""
      }
    2 ->
      case points {
        [#(x0, y0), #(x1, y1)] -> "M" <> f2(x0, y0) <> "L" <> f2(x1, y1) <> "Z"
        _ -> ""
      }
    _ -> {
      // For closed B-spline, we need to wrap using the last two and
      // first two points to close smoothly
      case points {
        [#(x0, y0), #(x1, y1), ..rest] -> {
          // Get the last point for wrapping
          let last_pt = list_last_point(points, #(x0, y0))
          let second_last_pt =
            list_last_point(list.take(points, count - 1), #(x0, y0))

          // Starting point uses wrapped values
          let start_x = { last_pt.0 +. 4.0 *. x0 +. x1 } /. 6.0
          let start_y = { last_pt.1 +. 4.0 *. y0 +. y1 } /. 6.0
          let init = "M" <> f2(start_x, start_y)

          // Process all interior segments
          let #(result, prev_x, prev_y) =
            list.fold(rest, #(init, x0, y0), fn(state, pt) {
              let #(acc, px, py) = state
              let #(nx, ny) = pt
              basis_segment(acc, px, py, nx, ny)
            })

          // Wrap segments: process p[n-2]->p[n-1], p[n-1]->p[0], p[0]->p[1]
          let #(result2, px2, py2) =
            basis_segment(result, prev_x, prev_y, last_pt.0, last_pt.1)
          let _ = second_last_pt
          let #(result3, px3, py3) = basis_segment(result2, px2, py2, x0, y0)
          let #(result4, _, _) = basis_segment(result3, px3, py3, x1, y1)

          result4 <> "Z"
        }
        _ -> ""
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Basis open (d3 curveBasisOpen) — excludes first and last points
// ---------------------------------------------------------------------------

fn basis_open_path(points: List(#(Float, Float))) -> String {
  let count = list.length(points)
  case count < 4 {
    True -> linear_path(points)
    False ->
      case points {
        [#(x0, y0), #(x1, y1), #(x2, y2), ..rest] -> {
          // First visible point is the basis formula applied at the third input
          let start_x = { x0 +. 4.0 *. x1 +. x2 } /. 6.0
          let start_y = { y0 +. 4.0 *. y1 +. y2 } /. 6.0
          let init = "M" <> f2(start_x, start_y)

          // Process remaining points using the basis formula
          let #(result, _, _) =
            list.fold(rest, #(init, x1, y1), fn(state, pt) {
              let #(acc, px, py) = state
              let #(nx, ny) = pt
              basis_segment(acc, px, py, nx, ny)
            })
          result
        }
        _ -> ""
      }
  }
}

/// Shared basis spline segment formula matching d3-shape.
fn basis_segment(
  acc: String,
  px: Float,
  py: Float,
  nx: Float,
  ny: Float,
) -> #(String, Float, Float) {
  let cx1 = { 2.0 *. px +. nx } /. 3.0
  let cy1 = { 2.0 *. py +. ny } /. 3.0
  let cx2 = { px +. 2.0 *. nx } /. 3.0
  let cy2 = { py +. 2.0 *. ny } /. 3.0
  let ex = { px +. 4.0 *. nx } /. 6.0
  let ey = { py +. 4.0 *. ny } /. 6.0
  let seg = "C" <> f2(cx1, cy1) <> "," <> f2(cx2, cy2) <> "," <> f2(ex, ey)
  #(acc <> seg, nx, ny)
}

// ---------------------------------------------------------------------------
// BumpX (d3 curveBumpX) — horizontal S-curves
// ---------------------------------------------------------------------------

fn bump_x_path(points: List(#(Float, Float))) -> String {
  case points {
    [] -> ""
    [#(x0, y0), ..rest] ->
      list.fold(rest, #("M" <> f2(x0, y0), x0, y0), fn(state, pt) {
        let #(acc, prev_x, prev_y) = state
        let #(x1, y1) = pt
        let mid_x = { prev_x +. x1 } /. 2.0
        let new_acc =
          acc
          <> "C"
          <> f2(mid_x, prev_y)
          <> ","
          <> f2(mid_x, y1)
          <> ","
          <> f2(x1, y1)
        #(new_acc, x1, y1)
      }).0
  }
}

// ---------------------------------------------------------------------------
// BumpY (d3 curveBumpY) — vertical S-curves
// ---------------------------------------------------------------------------

fn bump_y_path(points: List(#(Float, Float))) -> String {
  case points {
    [] -> ""
    [#(x0, y0), ..rest] ->
      list.fold(rest, #("M" <> f2(x0, y0), x0, y0), fn(state, pt) {
        let #(acc, prev_x, prev_y) = state
        let #(x1, y1) = pt
        let mid_y = { prev_y +. y1 } /. 2.0
        let new_acc =
          acc
          <> "C"
          <> f2(prev_x, mid_y)
          <> ","
          <> f2(x1, mid_y)
          <> ","
          <> f2(x1, y1)
        #(new_acc, x1, y1)
      }).0
  }
}

// ---------------------------------------------------------------------------
// Area closure
// ---------------------------------------------------------------------------

fn close_area(
  curve: String,
  points: List(#(Float, Float)),
  baseline: Baseline,
) -> String {
  case baseline {
    FlatBaseline(y:) ->
      case points {
        [] -> curve
        _ -> {
          let first_x = case points {
            [#(x, _), ..] -> x
            _ -> 0.0
          }
          let last_x = list_last_point_x(points, 0.0)
          curve <> "L" <> f2(last_x, y) <> "L" <> f2(first_x, y) <> "Z"
        }
      }

    PointBaseline(points: base_points) -> {
      // Trace baseline in reverse (matching d3 area path winding)
      let base_path =
        list.fold(list.reverse(base_points), "", fn(acc, pt) {
          acc <> "L" <> f2(pt.0, pt.1)
        })
      curve <> base_path <> "Z"
    }
  }
}

// ---------------------------------------------------------------------------
// Path length estimation
// ---------------------------------------------------------------------------

/// Estimate the path length for a list of points.
///
/// Computes the sum of Euclidean distances between consecutive points
/// with a 1.2 correction factor to account for curvature.
/// Returns a conservative overestimate suitable for stroke-dasharray.
pub fn approximate_path_length(points points: List(#(Float, Float))) -> Float {
  let chord_sum = compute_chord_sum(points, 0.0)
  chord_sum *. 1.2
}

fn compute_chord_sum(points: List(#(Float, Float)), acc: Float) -> Float {
  case points {
    [] -> acc
    [_] -> acc
    [#(x1, y1), #(x2, y2), ..rest] -> {
      let dx = x2 -. x1
      let dy = y2 -. y1
      let dist = math.sqrt(dx *. dx +. dy *. dy)
      compute_chord_sum([#(x2, y2), ..rest], acc +. dist)
    }
  }
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

fn f2(x: Float, y: Float) -> String {
  math.fmt(x) <> "," <> math.fmt(y)
}

fn list_last(items: List(Float), default: Float) -> Float {
  case list.last(items) {
    Ok(v) -> v
    Error(_) -> default
  }
}

fn list_head_f(items: List(Float), default: Float) -> Float {
  case items {
    [first, ..] -> first
    [] -> default
  }
}

fn list_last_point_x(points: List(#(Float, Float)), default: Float) -> Float {
  case list.last(points) {
    Ok(#(x, _)) -> x
    Error(_) -> default
  }
}

fn list_last_point(
  points: List(#(Float, Float)),
  default: #(Float, Float),
) -> #(Float, Float) {
  case list.last(points) {
    Ok(pt) -> pt
    Error(_) -> default
  }
}
