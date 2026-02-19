//// Mathematical utilities for chart computation.
////
//// Clamping, interpolation, and trigonometry helpers used across the
//// chart library.

import gleam/float
import gleam/int
import gleam/list

/// The mathematical constant pi.
pub const pi = 3.14159265358979323846

/// Convert degrees to radians.
pub fn to_radians(degrees: Float) -> Float {
  degrees *. pi /. 180.0
}

/// Convert radians to degrees.
pub fn to_degrees(radians: Float) -> Float {
  radians *. 180.0 /. pi
}

/// Clamp a float value to [min, max].
pub fn clamp(value: Float, min: Float, max: Float) -> Float {
  case value <. min {
    True -> min
    False ->
      case value >. max {
        True -> max
        False -> value
      }
  }
}

/// Clamp an integer to be non-negative.
pub fn clamp_non_negative(value: Int) -> Int {
  case value < 0 {
    True -> 0
    False -> value
  }
}

/// Linear interpolation between two values.
pub fn lerp(a: Float, b: Float, t: Float) -> Float {
  a +. { b -. a } *. t
}

/// Find the minimum value in a list of floats.
pub fn list_min(values: List(Float)) -> Float {
  case values {
    [] -> 0.0
    [first, ..rest] ->
      list.fold(rest, first, fn(acc, v) {
        case v <. acc {
          True -> v
          False -> acc
        }
      })
  }
}

/// Find the maximum value in a list of floats.
pub fn list_max(values: List(Float)) -> Float {
  case values {
    [] -> 0.0
    [first, ..rest] ->
      list.fold(rest, first, fn(acc, v) {
        case v >. acc {
          True -> v
          False -> acc
        }
      })
  }
}

/// Format a float as a compact string for SVG attributes.
/// Rounds to 2 decimal places to keep path data readable.
pub fn fmt(value: Float) -> String {
  // Round to 2 decimal places
  let rounded = float.round(value *. 100.0)
  let whole = rounded / 100
  let frac = case rounded < 0 {
    True -> { 0 - rounded } % 100
    False -> rounded % 100
  }
  case frac == 0 {
    True -> int.to_string(whole)
    False -> {
      let frac_str = case frac < 10 {
        True -> "0" <> int.to_string(frac)
        False -> int.to_string(frac)
      }
      int.to_string(whole) <> "." <> frac_str
    }
  }
}

/// Compute the sign of a float: -1.0, 0.0, or 1.0.
pub fn sign(value: Float) -> Float {
  case value >. 0.0 {
    True -> 1.0
    False ->
      case value <. 0.0 {
        True -> -1.0
        False -> 0.0
      }
  }
}

/// Sine function via the standard library.
pub fn sin(x: Float) -> Float {
  do_sin(x)
}

/// Cosine function via the standard library.
pub fn cos(x: Float) -> Float {
  do_cos(x)
}

/// Arc sine function.
pub fn asin(x: Float) -> Float {
  do_asin(x)
}

/// Square root function.
pub fn sqrt(x: Float) -> Float {
  float.square_root(x)
  |> unwrap_or(0.0)
}

/// Natural logarithm (ln).
/// Returns 0.0 for non-positive input.
pub fn ln(x: Float) -> Float {
  case x <=. 0.0 {
    True -> 0.0
    False ->
      case float.logarithm(x) {
        Ok(v) -> v
        Error(_) -> 0.0
      }
  }
}

/// Power function: base^exp.
/// Returns 0.0 when the result is not real.
pub fn pow(base: Float, exp: Float) -> Float {
  case float.power(base, exp) {
    Ok(v) -> v
    Error(_) -> 0.0
  }
}

/// Logarithm with arbitrary base: log_base(value, base).
/// Returns 0.0 for non-positive input or base.
pub fn log_base(value: Float, base: Float) -> Float {
  case value <=. 0.0 || base <=. 0.0 || base == 1.0 {
    True -> 0.0
    False -> ln(value) /. ln(base)
  }
}

/// Absolute value for floats.
pub fn abs(x: Float) -> Float {
  float.absolute_value(x)
}

// -- Private helpers ----------------------------------------------------------

fn unwrap_or(result: Result(a, b), default: a) -> a {
  case result {
    Ok(v) -> v
    Error(_) -> default
  }
}

// Pure Gleam trig via Taylor series for cross-target compatibility.

fn do_sin(x: Float) -> Float {
  // Normalize to [-pi, pi]
  let normalized = normalize_angle(x)
  // Taylor series: sin(x) = x - x^3/3! + x^5/5! - x^7/7! + ...
  let x2 = normalized *. normalized
  let x3 = normalized *. x2
  let x5 = x3 *. x2
  let x7 = x5 *. x2
  let x9 = x7 *. x2
  let x11 = x9 *. x2
  normalized
  -. x3
  /. 6.0
  +. x5
  /. 120.0
  -. x7
  /. 5040.0
  +. x9
  /. 362_880.0
  -. x11
  /. 39_916_800.0
}

fn do_cos(x: Float) -> Float {
  do_sin(x +. pi /. 2.0)
}

fn do_asin(x: Float) -> Float {
  // Clamp to [-1, 1]
  let clamped = clamp(x, -1.0, 1.0)
  // Taylor series approximation for asin
  // asin(x) = x + x^3/6 + 3x^5/40 + 15x^7/336 + ...
  let x2 = clamped *. clamped
  let x3 = clamped *. x2
  let x5 = x3 *. x2
  let x7 = x5 *. x2
  let x9 = x7 *. x2
  clamped
  +. x3
  /. 6.0
  +. x5
  *. 3.0
  /. 40.0
  +. x7
  *. 15.0
  /. 336.0
  +. x9
  *. 105.0
  /. 3456.0
}

fn normalize_angle(x: Float) -> Float {
  // Reduce to [-pi, pi] range
  let two_pi = 2.0 *. pi
  let shifted = x +. pi
  let periods = float.truncate(shifted /. two_pi)
  let remainder = shifted -. int.to_float(periods) *. two_pi
  let adjusted = case remainder <. 0.0 {
    True -> remainder +. two_pi
    False -> remainder
  }
  adjusted -. pi
}
