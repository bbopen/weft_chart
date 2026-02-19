//// Easing functions for SVG animation.
////
//// Pure mathematical ports of d3-ease functions.  Each takes normalized
//// time `t ∈ [0,1]` and returns progress, typically in `[0,1]` but
//// potentially beyond for overshoot/elastic effects.

import gleam/float
import gleam/int
import gleam/list
import weft_chart/internal/math

/// Easing function identifier.
pub type Easing {
  /// Linear interpolation (no easing).
  Linear
  /// CSS ease curve: cubic-bezier(0.25, 0.1, 0.25, 1.0).
  Ease
  /// CSS ease-in curve: cubic-bezier(0.42, 0.0, 1.0, 1.0).
  EaseIn
  /// CSS ease-out curve: cubic-bezier(0.0, 0.0, 0.58, 1.0).
  ///
  /// Note: weft_chart uses the correct CSS specification values.
  /// react-smooth (used by recharts) has ease-out and ease-in-out
  /// swapped, which is a known bug. The correct ease-out curve is
  /// cubic-bezier(0.0, 0.0, 0.58, 1.0).
  EaseOut
  /// CSS ease-in-out curve: cubic-bezier(0.42, 0.0, 0.58, 1.0).
  ///
  /// Note: weft_chart uses the correct CSS specification values.
  /// react-smooth (used by recharts) has ease-out and ease-in-out
  /// swapped, which is a known bug. The correct ease-in-out curve is
  /// cubic-bezier(0.42, 0.0, 0.58, 1.0).
  EaseInOut
  /// Quadratic ease-in: t squared.
  QuadIn
  /// Quadratic ease-out: t(2-t).
  QuadOut
  /// Quadratic ease-in-out.
  QuadInOut
  /// Cubic ease-in: t cubed.
  CubicIn
  /// Cubic ease-out: (t-1) cubed + 1.
  CubicOut
  /// Cubic ease-in-out.
  CubicInOut
  /// Sinusoidal ease-in.
  SinIn
  /// Sinusoidal ease-out.
  SinOut
  /// Sinusoidal ease-in-out.
  SinInOut
  /// Exponential ease-in.
  ExpIn
  /// Exponential ease-out.
  ExpOut
  /// Exponential ease-in-out.
  ExpInOut
  /// Circular ease-in.
  CircleIn
  /// Circular ease-out.
  CircleOut
  /// Circular ease-in-out.
  CircleInOut
  /// Bounce ease-in.
  BounceIn
  /// Bounce ease-out (4-bounce pattern).
  BounceOut
  /// Bounce ease-in-out.
  BounceInOut
  /// Back ease-in with overshoot (s=1.70158).
  BackIn
  /// Back ease-out with overshoot.
  BackOut
  /// Back ease-in-out with overshoot.
  BackInOut
  /// Elastic ease-in (spring oscillation).
  ElasticIn
  /// Elastic ease-out.
  ElasticOut
  /// Elastic ease-in-out.
  ElasticInOut
  /// Physics-based spring simulation.
  Spring(stiffness: Float, damping: Float)
  /// Arbitrary cubic-bezier curve.
  CubicBezier(x1: Float, y1: Float, x2: Float, y2: Float)
  /// User-provided easing function.
  CustomEasing(apply: fn(Float) -> Float)
}

/// Evaluate an easing function at normalized time t.
pub fn apply(easing easing: Easing, t t: Float) -> Float {
  case easing {
    Linear -> t
    Ease -> apply_cubic_bezier(0.25, 0.1, 0.25, 1.0, t)
    EaseIn -> apply_cubic_bezier(0.42, 0.0, 1.0, 1.0, t)
    EaseOut -> apply_cubic_bezier(0.0, 0.0, 0.58, 1.0, t)
    EaseInOut -> apply_cubic_bezier(0.42, 0.0, 0.58, 1.0, t)
    QuadIn -> quad_in(t)
    QuadOut -> quad_out(t)
    QuadInOut -> quad_in_out(t)
    CubicIn -> cubic_in(t)
    CubicOut -> cubic_out(t)
    CubicInOut -> cubic_in_out(t)
    SinIn -> sin_in(t)
    SinOut -> sin_out(t)
    SinInOut -> sin_in_out(t)
    ExpIn -> exp_in(t)
    ExpOut -> exp_out(t)
    ExpInOut -> exp_in_out(t)
    CircleIn -> circle_in(t)
    CircleOut -> circle_out(t)
    CircleInOut -> circle_in_out(t)
    BounceIn -> bounce_in(t)
    BounceOut -> bounce_out(t)
    BounceInOut -> bounce_in_out(t)
    BackIn -> back_in(t)
    BackOut -> back_out(t)
    BackInOut -> back_in_out(t)
    ElasticIn -> elastic_in(t)
    ElasticOut -> elastic_out(t)
    ElasticInOut -> elastic_in_out(t)
    Spring(stiffness:, damping:) -> apply_spring(stiffness, damping, t)
    CubicBezier(x1:, y1:, x2:, y2:) -> apply_cubic_bezier(x1, y1, x2, y2, t)
    CustomEasing(apply: f) -> f(t)
  }
}

/// Whether this easing can be expressed as a single CSS cubic-bezier.
pub fn is_css_native(easing easing: Easing) -> Bool {
  case easing {
    Linear -> True
    Ease -> True
    EaseIn -> True
    EaseOut -> True
    EaseInOut -> True
    _ -> False
  }
}

/// Return the CSS cubic-bezier control points for native easings.
pub fn to_cubic_bezier(
  easing easing: Easing,
) -> Result(#(Float, Float, Float, Float), Nil) {
  case easing {
    Linear -> Ok(#(0.0, 0.0, 1.0, 1.0))
    Ease -> Ok(#(0.25, 0.1, 0.25, 1.0))
    EaseIn -> Ok(#(0.42, 0.0, 1.0, 1.0))
    EaseOut -> Ok(#(0.0, 0.0, 0.58, 1.0))
    EaseInOut -> Ok(#(0.42, 0.0, 0.58, 1.0))
    _ -> Error(Nil)
  }
}

/// Create a spring easing with default parameters.
///
/// Defaults: stiffness 170.0, damping 26.0 (matching common physics-based
/// spring presets).
pub fn spring_default() -> Easing {
  Spring(stiffness: 170.0, damping: 26.0)
}

/// Set the stiffness on a Spring easing.
///
/// Higher stiffness makes the spring snap faster. Has no effect on
/// non-Spring easings, which are returned unchanged.
pub fn with_stiffness(
  easing easing: Easing,
  stiffness stiffness: Float,
) -> Easing {
  case easing {
    Spring(damping:, ..) -> Spring(stiffness: stiffness, damping: damping)
    other -> other
  }
}

/// Set the damping on a Spring easing.
///
/// Higher damping reduces oscillation. Has no effect on non-Spring
/// easings, which are returned unchanged.
pub fn with_damping(easing easing: Easing, damping damping: Float) -> Easing {
  case easing {
    Spring(stiffness:, ..) -> Spring(stiffness: stiffness, damping: damping)
    other -> other
  }
}

// -- Quad ---------------------------------------------------------------------

fn quad_in(t: Float) -> Float {
  t *. t
}

fn quad_out(t: Float) -> Float {
  t *. { 2.0 -. t }
}

fn quad_in_out(t: Float) -> Float {
  case t <. 0.5 {
    True -> {
      let t2 = t *. 2.0
      t2 *. t2 /. 2.0
    }
    False -> {
      let t2 = t *. 2.0 -. 1.0
      { t2 *. { 2.0 -. t2 } +. 1.0 } /. 2.0
    }
  }
}

// -- Cubic --------------------------------------------------------------------

fn cubic_in(t: Float) -> Float {
  t *. t *. t
}

fn cubic_out(t: Float) -> Float {
  let t1 = t -. 1.0
  t1 *. t1 *. t1 +. 1.0
}

fn cubic_in_out(t: Float) -> Float {
  case t <. 0.5 {
    True -> {
      let t2 = t *. 2.0
      t2 *. t2 *. t2 /. 2.0
    }
    False -> {
      let t2 = t *. 2.0 -. 2.0
      { t2 *. t2 *. t2 +. 2.0 } /. 2.0
    }
  }
}

// -- Sin ----------------------------------------------------------------------

fn sin_in(t: Float) -> Float {
  1.0 -. math.cos(t *. math.pi /. 2.0)
}

fn sin_out(t: Float) -> Float {
  math.sin(t *. math.pi /. 2.0)
}

fn sin_in_out(t: Float) -> Float {
  { 1.0 -. math.cos(math.pi *. t) } /. 2.0
}

// -- Exp (tpmt-based) ---------------------------------------------------------

fn tpmt(x: Float) -> Float {
  { math.pow(2.0, -10.0 *. x) -. 0.0009765625 } *. 1.0009775171065494
}

fn exp_in(t: Float) -> Float {
  tpmt(1.0 -. t)
}

fn exp_out(t: Float) -> Float {
  1.0 -. tpmt(t)
}

fn exp_in_out(t: Float) -> Float {
  case t <. 0.5 {
    True -> tpmt(1.0 -. 2.0 *. t) /. 2.0
    False -> { 2.0 -. tpmt(2.0 *. t -. 1.0) } /. 2.0
  }
}

// -- Circle -------------------------------------------------------------------

fn circle_in(t: Float) -> Float {
  1.0 -. math.sqrt(1.0 -. t *. t)
}

fn circle_out(t: Float) -> Float {
  let t1 = t -. 1.0
  math.sqrt(1.0 -. t1 *. t1)
}

fn circle_in_out(t: Float) -> Float {
  case t <. 0.5 {
    True -> {
      let t2 = t *. 2.0
      { 1.0 -. math.sqrt(1.0 -. t2 *. t2) } /. 2.0
    }
    False -> {
      let t2 = t *. 2.0 -. 2.0
      { math.sqrt(1.0 -. t2 *. t2) +. 1.0 } /. 2.0
    }
  }
}

// -- Bounce -------------------------------------------------------------------

fn bounce_out(t: Float) -> Float {
  let b1 = 4.0 /. 11.0
  let b2 = 6.0 /. 11.0
  let b3 = 8.0 /. 11.0
  let b4 = 3.0 /. 4.0
  let b5 = 9.0 /. 11.0
  let b6 = 10.0 /. 11.0
  let b7 = 15.0 /. 16.0
  let b8 = 21.0 /. 22.0
  let b9 = 63.0 /. 64.0
  let b0 = 1.0 /. { b1 *. b1 }
  case t <. b1 {
    True -> b0 *. t *. t
    False ->
      case t <. b3 {
        True -> {
          let t2 = t -. b2
          b0 *. t2 *. t2 +. b4
        }
        False ->
          case t <. b6 {
            True -> {
              let t2 = t -. b5
              b0 *. t2 *. t2 +. b7
            }
            False -> {
              let t2 = t -. b8
              b0 *. t2 *. t2 +. b9
            }
          }
      }
  }
}

fn bounce_in(t: Float) -> Float {
  1.0 -. bounce_out(1.0 -. t)
}

fn bounce_in_out(t: Float) -> Float {
  case t <. 0.5 {
    True -> { 1.0 -. bounce_out(1.0 -. 2.0 *. t) } /. 2.0
    False -> { bounce_out(2.0 *. t -. 1.0) +. 1.0 } /. 2.0
  }
}

// -- Back ---------------------------------------------------------------------

const back_s = 1.70158

fn back_in(t: Float) -> Float {
  t *. t *. { { back_s +. 1.0 } *. t -. back_s }
}

fn back_out(t: Float) -> Float {
  let t1 = t -. 1.0
  t1 *. t1 *. { { back_s +. 1.0 } *. t1 +. back_s } +. 1.0
}

fn back_in_out(t: Float) -> Float {
  let s = back_s *. 1.525
  case t <. 0.5 {
    True -> {
      let t2 = t *. 2.0
      t2 *. t2 *. { { s +. 1.0 } *. t2 -. s } /. 2.0
    }
    False -> {
      let t2 = t *. 2.0 -. 2.0
      { t2 *. t2 *. { { s +. 1.0 } *. t2 +. s } +. 2.0 } /. 2.0
    }
  }
}

// -- Elastic ------------------------------------------------------------------

// tau = 2 * pi (computed as literal since const can't use float ops)
const tau = 6.28318530717958647692

const elastic_amplitude = 1.0

const elastic_period = 0.3

fn elastic_in(t: Float) -> Float {
  case t <=. 0.0 {
    True -> 0.0
    False ->
      case t >=. 1.0 {
        True -> 1.0
        False -> {
          let a = elastic_amplitude
          let p = elastic_period
          let s = math.asin(1.0 /. a) *. p /. tau
          let t1 = t -. 1.0
          0.0 -. a *. tpmt(0.0 -. t1) *. math.sin({ t1 -. s } *. tau /. p)
        }
      }
  }
}

fn elastic_out(t: Float) -> Float {
  case t <=. 0.0 {
    True -> 0.0
    False ->
      case t >=. 1.0 {
        True -> 1.0
        False -> {
          let a = elastic_amplitude
          let p = elastic_period
          let s = math.asin(1.0 /. a) *. p /. tau
          1.0 -. a *. tpmt(t) *. math.sin({ t +. s } *. tau /. p)
        }
      }
  }
}

fn elastic_in_out(t: Float) -> Float {
  case t <=. 0.0 {
    True -> 0.0
    False ->
      case t >=. 1.0 {
        True -> 1.0
        False -> {
          let a = elastic_amplitude
          let p = elastic_period *. 1.5
          let s = math.asin(1.0 /. a) *. p /. tau
          case t <. 0.5 {
            True -> {
              let t1 = 2.0 *. t -. 1.0
              0.0
              -. a
              /. 2.0
              *. tpmt(0.0 -. t1)
              *. math.sin({ t1 -. s } *. tau /. p)
            }
            False -> {
              let t1 = 2.0 *. t -. 1.0
              { a *. tpmt(t1) *. math.sin({ t1 +. s } *. tau /. p) +. 2.0 }
              /. 2.0
            }
          }
        }
      }
  }
}

// -- Spring -------------------------------------------------------------------

fn apply_spring(stiffness: Float, damping: Float, t: Float) -> Float {
  let samples = compute_spring_samples(stiffness, damping)
  let count = list.length(samples)
  case count {
    0 -> t
    _ -> {
      let max_idx = int.to_float(count - 1)
      let raw_idx = t *. max_idx
      let idx_low = float.truncate(raw_idx)
      let idx_low_clamped = clamp_int(idx_low, 0, count - 1)
      let idx_high_clamped = clamp_int(idx_low + 1, 0, count - 1)
      let frac = raw_idx -. int.to_float(idx_low)
      let low_val = list_at(samples, idx_low_clamped, 1.0)
      let high_val = list_at(samples, idx_high_clamped, 1.0)
      low_val +. { high_val -. low_val } *. frac
    }
  }
}

fn compute_spring_samples(stiffness: Float, damping: Float) -> List(Float) {
  let dt = 0.017
  compute_spring_loop(stiffness, damping, dt, 0.0, 0.0, [])
  |> list.reverse
}

fn compute_spring_loop(
  stiffness: Float,
  damping: Float,
  dt: Float,
  position: Float,
  velocity: Float,
  acc: List(Float),
) -> List(Float) {
  let new_velocity =
    velocity
    +. { { 0.0 -. stiffness } *. { position -. 1.0 } -. damping *. velocity }
    *. dt
  let new_position = position +. new_velocity *. dt
  let new_acc = [new_position, ..acc]
  let pos_settled = math.abs(new_position -. 1.0) <. 0.0001
  let vel_settled = math.abs(new_velocity) <. 0.0001
  case pos_settled && vel_settled {
    True -> new_acc
    False ->
      case list.length(new_acc) > 10_000 {
        True -> new_acc
        False ->
          compute_spring_loop(
            stiffness,
            damping,
            dt,
            new_position,
            new_velocity,
            new_acc,
          )
      }
  }
}

fn clamp_int(value: Int, min: Int, max: Int) -> Int {
  case value < min {
    True -> min
    False ->
      case value > max {
        True -> max
        False -> value
      }
  }
}

fn list_at(items: List(Float), index: Int, default: Float) -> Float {
  case index, items {
    _, [] -> default
    0, [first, ..] -> first
    n, [_, ..rest] -> list_at(rest, n - 1, default)
  }
}

// -- Cubic Bezier -------------------------------------------------------------

fn apply_cubic_bezier(
  x1: Float,
  y1: Float,
  x2: Float,
  y2: Float,
  t: Float,
) -> Float {
  // Find parameter u where bezier_x(u) = t using Newton's method
  let u = find_bezier_t(x1, x2, t, t, 0)
  bezier_component(y1, y2, u)
}

fn bezier_component(c1: Float, c2: Float, u: Float) -> Float {
  let one_minus_u = 1.0 -. u
  3.0
  *. c1
  *. one_minus_u
  *. one_minus_u
  *. u
  +. 3.0
  *. c2
  *. one_minus_u
  *. u
  *. u
  +. u
  *. u
  *. u
}

fn bezier_derivative(c1: Float, c2: Float, u: Float) -> Float {
  let one_minus_u = 1.0 -. u
  3.0
  *. c1
  *. one_minus_u
  *. { one_minus_u -. 2.0 *. u }
  +. 3.0
  *. c2
  *. u
  *. { 2.0 *. one_minus_u -. u }
  +. 3.0
  *. u
  *. u
}

fn find_bezier_t(
  x1: Float,
  x2: Float,
  target: Float,
  u: Float,
  iteration: Int,
) -> Float {
  case iteration >= 8 {
    True -> u
    False -> {
      let x_at_u = bezier_component(x1, x2, u)
      let error = x_at_u -. target
      case math.abs(error) <. 0.0000001 {
        True -> u
        False -> {
          let dx = bezier_derivative(x1, x2, u)
          case math.abs(dx) <. 0.0000001 {
            True -> u
            False ->
              find_bezier_t(x1, x2, target, u -. error /. dx, iteration + 1)
          }
        }
      }
    }
  }
}
