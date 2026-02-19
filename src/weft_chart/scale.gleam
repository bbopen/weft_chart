//// Scale functions that map data values to pixel coordinates.
////
//// Scale types cover all Recharts usage patterns:
//// - `LinearScale` for continuous numeric axes
//// - `LogScale` for logarithmic axes
//// - `SqrtScale` for square root axes
//// - `PowerScale` for power (exponent) axes
//// - `TimeScale` for temporal axes (epoch milliseconds)
//// - `BandScale` for categorical axes with width (bar charts)
//// - `PointScale` for categorical axes at single points (line/area charts)
//// - `OrdinalScale` for discrete category-to-value mappings
////
//// The `nice_ticks` function implements the recharts-scale
//// `getNiceTickValues` algorithm for human-friendly tick values.

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import weft_chart/internal/math

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A scale mapping data domain values to pixel range values.
pub type Scale {
  /// Maps a continuous numeric domain [min, max] to a continuous pixel
  /// range [start, end].
  LinearScale(
    domain_min: Float,
    domain_max: Float,
    range_start: Float,
    range_end: Float,
  )

  /// Maps a continuous numeric domain through a logarithmic transform.
  /// Values are mapped as log_base(value) within the domain.
  LogScale(
    domain_min: Float,
    domain_max: Float,
    range_start: Float,
    range_end: Float,
    base: Float,
  )

  /// Maps a continuous numeric domain through a square root transform.
  /// Values are mapped as sqrt(value) within the domain.
  SqrtScale(
    domain_min: Float,
    domain_max: Float,
    range_start: Float,
    range_end: Float,
  )

  /// Maps a continuous numeric domain through a power transform.
  /// Values are raised to the given exponent, then linearly mapped.
  /// Matches D3 scalePow behavior.
  PowerScale(
    domain_min: Float,
    domain_max: Float,
    range_start: Float,
    range_end: Float,
    exponent: Float,
  )

  /// Maps epoch-millisecond Float domain values with linear interpolation.
  /// Tick generation produces nice time boundaries (seconds, minutes,
  /// hours, days, months, years) based on the range.
  TimeScale(
    domain_min: Float,
    domain_max: Float,
    range_start: Float,
    range_end: Float,
  )

  /// Maps discrete categories to equal-width bands.  Each band has a
  /// start coordinate and a bandwidth.
  BandScale(
    categories: List(String),
    range_start: Float,
    range_end: Float,
    padding_inner: Float,
    padding_outer: Float,
  )

  /// Maps discrete categories to evenly spaced points within a range.
  PointScale(
    categories: List(String),
    range_start: Float,
    range_end: Float,
    padding: Float,
  )

  /// Maps discrete categories to specific output values via a dictionary.
  /// Unlike PointScale which maps to evenly-spaced points, OrdinalScale
  /// maps each category to an explicitly defined value.
  OrdinalScale(mapping: Dict(String, Float), default_value: Float)
}

/// A computed tick mark with its display value and pixel coordinate.
pub type ScaleTick {
  ScaleTick(value: String, coordinate: Float)
}

/// Errors that can occur during scale operations.
pub type ScaleError {
  /// Input string is not a valid percentage (e.g. missing '%' suffix).
  InvalidPercentage(input: String)
  /// The percentage value could not be parsed as a number.
  PercentageParseError(input: String)
}

/// A data key that can be either a string key or a function extractor.
/// Matches recharts DataKey type: `string | ((obj: T) => any)`.
pub type DataKey {
  /// A string key used to look up a value in a data dictionary.
  StringKey(key: String)
  /// A function that extracts a value from a data dictionary.
  FnKey(extractor: fn(Dict(String, Float)) -> Float)
}

/// A domain bound specification for axis domain configuration.
/// Matches recharts AxisDomainItem patterns: 'dataMin', 'dataMax',
/// fixed values, offsets, and transform functions.
pub type DomainBound {
  /// A fixed numeric value.
  Fixed(value: Float)
  /// Use the minimum value from the data.
  DataMin
  /// Use the maximum value from the data.
  DataMax
  /// Use the minimum data value minus an offset.
  DataMinOffset(offset: Float)
  /// Use the maximum data value plus an offset.
  DataMaxOffset(offset: Float)
  /// Apply a transform function to the computed bound.
  /// The function receives both data_min and data_max to allow
  /// computing bounds relative to the full data range.
  DomainFn(transform: fn(Float, Float) -> Float)
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a linear scale from a numeric domain to a pixel range.
pub fn linear(
  domain_min domain_min: Float,
  domain_max domain_max: Float,
  range_start range_start: Float,
  range_end range_end: Float,
) -> Scale {
  LinearScale(
    domain_min: domain_min,
    domain_max: domain_max,
    range_start: range_start,
    range_end: range_end,
  )
}

/// Create a logarithmic scale.
/// Matches D3 scaleLog: maps through log_base(value).
/// Domain values must be positive for logarithmic mapping.
pub fn log(
  domain_min domain_min: Float,
  domain_max domain_max: Float,
  range_start range_start: Float,
  range_end range_end: Float,
  base base: Float,
) -> Scale {
  LogScale(
    domain_min: domain_min,
    domain_max: domain_max,
    range_start: range_start,
    range_end: range_end,
    base: base,
  )
}

/// Create a square root scale.
/// Matches D3 scaleSqrt (= scalePow with exponent 0.5).
pub fn sqrt_scale(
  domain_min domain_min: Float,
  domain_max domain_max: Float,
  range_start range_start: Float,
  range_end range_end: Float,
) -> Scale {
  SqrtScale(
    domain_min: domain_min,
    domain_max: domain_max,
    range_start: range_start,
    range_end: range_end,
  )
}

/// Create a power scale with a configurable exponent.
/// Matches D3 scalePow: domain values are raised to the exponent,
/// then linearly mapped to the output range.
pub fn power(
  domain_min domain_min: Float,
  domain_max domain_max: Float,
  range_start range_start: Float,
  range_end range_end: Float,
  exponent exponent: Float,
) -> Scale {
  PowerScale(
    domain_min: domain_min,
    domain_max: domain_max,
    range_start: range_start,
    range_end: range_end,
    exponent: exponent,
  )
}

/// Create a time scale for epoch-millisecond domains.
/// Uses linear interpolation over temporal range.
/// Tick generation produces nice time boundaries.
pub fn time(
  domain_min domain_min: Float,
  domain_max domain_max: Float,
  range_start range_start: Float,
  range_end range_end: Float,
) -> Scale {
  TimeScale(
    domain_min: domain_min,
    domain_max: domain_max,
    range_start: range_start,
    range_end: range_end,
  )
}

/// Create a band scale from category names to a pixel range.
pub fn band(
  categories categories: List(String),
  range_start range_start: Float,
  range_end range_end: Float,
  padding_inner padding_inner: Float,
  padding_outer padding_outer: Float,
) -> Scale {
  BandScale(
    categories: categories,
    range_start: range_start,
    range_end: range_end,
    padding_inner: padding_inner,
    padding_outer: padding_outer,
  )
}

/// Create a point scale from category names to a pixel range.
pub fn point(
  categories categories: List(String),
  range_start range_start: Float,
  range_end range_end: Float,
  padding padding: Float,
) -> Scale {
  PointScale(
    categories: categories,
    range_start: range_start,
    range_end: range_end,
    padding: padding,
  )
}

/// Create an ordinal scale from a category-to-value mapping.
/// Categories not in the mapping will use the default value.
pub fn ordinal(
  mapping mapping: Dict(String, Float),
  default_value default_value: Float,
) -> Scale {
  OrdinalScale(mapping: mapping, default_value: default_value)
}

// ---------------------------------------------------------------------------
// Application
// ---------------------------------------------------------------------------

/// Apply a linear scale to a numeric value.  Returns the corresponding
/// pixel coordinate.
pub fn linear_apply(scale: Scale, value: Float) -> Float {
  case scale {
    LinearScale(domain_min:, domain_max:, range_start:, range_end:) -> {
      let domain_span = domain_max -. domain_min
      case domain_span == 0.0 {
        True -> { range_start +. range_end } /. 2.0
        False -> {
          let ratio = { value -. domain_min } /. domain_span
          range_start +. ratio *. { range_end -. range_start }
        }
      }
    }
    _ -> 0.0
  }
}

/// Apply a logarithmic scale to a numeric value.
/// Maps through log_base(value) for the interpolation.
pub fn log_apply(scale: Scale, value: Float) -> Float {
  case scale {
    LogScale(domain_min:, domain_max:, range_start:, range_end:, base:) -> {
      let log_min = math.log_base(domain_min, base)
      let log_max = math.log_base(domain_max, base)
      let log_val = math.log_base(value, base)
      let domain_span = log_max -. log_min
      case domain_span == 0.0 {
        True -> { range_start +. range_end } /. 2.0
        False -> {
          let ratio = { log_val -. log_min } /. domain_span
          range_start +. ratio *. { range_end -. range_start }
        }
      }
    }
    _ -> 0.0
  }
}

/// Apply a square root scale to a numeric value.
/// Maps through sqrt(value) for the interpolation.
pub fn sqrt_apply(scale: Scale, value: Float) -> Float {
  case scale {
    SqrtScale(domain_min:, domain_max:, range_start:, range_end:) -> {
      let sqrt_min = math.sqrt(math.abs(domain_min))
      let sqrt_max = math.sqrt(math.abs(domain_max))
      let sqrt_val = math.sqrt(math.abs(value))
      let domain_span = sqrt_max -. sqrt_min
      case domain_span == 0.0 {
        True -> { range_start +. range_end } /. 2.0
        False -> {
          let ratio = { sqrt_val -. sqrt_min } /. domain_span
          range_start +. ratio *. { range_end -. range_start }
        }
      }
    }
    _ -> 0.0
  }
}

/// Apply a power scale to a numeric value.
/// Raises domain values to the exponent, then linearly maps.
pub fn power_apply(scale: Scale, value: Float) -> Float {
  case scale {
    PowerScale(domain_min:, domain_max:, range_start:, range_end:, exponent:) -> {
      let pow_min = signed_pow(domain_min, exponent)
      let pow_max = signed_pow(domain_max, exponent)
      let pow_val = signed_pow(value, exponent)
      let domain_span = pow_max -. pow_min
      case domain_span == 0.0 {
        True -> { range_start +. range_end } /. 2.0
        False -> {
          let ratio = { pow_val -. pow_min } /. domain_span
          range_start +. ratio *. { range_end -. range_start }
        }
      }
    }
    _ -> 0.0
  }
}

/// Apply a time scale to an epoch-millisecond value.
/// Internally uses linear interpolation.
pub fn time_apply(scale: Scale, value: Float) -> Float {
  case scale {
    TimeScale(domain_min:, domain_max:, range_start:, range_end:) -> {
      let domain_span = domain_max -. domain_min
      case domain_span == 0.0 {
        True -> { range_start +. range_end } /. 2.0
        False -> {
          let ratio = { value -. domain_min } /. domain_span
          range_start +. ratio *. { range_end -. range_start }
        }
      }
    }
    _ -> 0.0
  }
}

/// Apply an ordinal scale to a category name.
/// Returns the mapped value, or the default value if the category
/// is not in the mapping.
pub fn ordinal_apply(scale: Scale, category: String) -> Float {
  case scale {
    OrdinalScale(mapping:, default_value:) ->
      case dict.get(mapping, category) {
        Ok(v) -> v
        Error(_) -> default_value
      }
    _ -> 0.0
  }
}

/// Unified scale application: dispatches to the correct apply function
/// based on the scale type.
pub fn apply(scale: Scale, value: Float) -> Float {
  case scale {
    LinearScale(..) -> linear_apply(scale, value)
    LogScale(..) -> log_apply(scale, value)
    SqrtScale(..) -> sqrt_apply(scale, value)
    PowerScale(..) -> power_apply(scale, value)
    TimeScale(..) -> time_apply(scale, value)
    BandScale(..) -> {
      let #(start, bw) = band_apply(scale, "")
      start +. bw /. 2.0
    }
    PointScale(..) -> point_apply(scale, "")
    OrdinalScale(default_value:, ..) -> default_value
  }
}

/// Apply a band scale to a category.  Returns `#(band_start, bandwidth)`.
pub fn band_apply(scale: Scale, category: String) -> #(Float, Float) {
  case scale {
    BandScale(
      categories:,
      range_start:,
      range_end:,
      padding_inner:,
      padding_outer:,
    ) -> {
      let n = list.length(categories)
      case n == 0 {
        True -> #(range_start, 0.0)
        False -> {
          let total = math.abs(range_end -. range_start)
          let outer_total = 2.0 *. padding_outer
          let inner_total = int.to_float(n - 1) *. padding_inner
          let band_total = int.to_float(n)
          let unit = total /. { outer_total +. inner_total +. band_total }
          let bw = unit
          let offset = unit *. padding_outer

          let index = find_index(categories, category, 0)
          let x =
            range_start
            +. offset
            +. int.to_float(index)
            *. { bw +. unit *. padding_inner }
          #(x, bw)
        }
      }
    }
    _ -> #(0.0, 0.0)
  }
}

/// Apply a point scale to a category.  Returns the center coordinate.
/// When given a BandScale (e.g. in a composed chart with bars), returns
/// the band center so that line/area series align with bar midpoints.
pub fn point_apply(scale: Scale, category: String) -> Float {
  case scale {
    PointScale(categories:, range_start:, range_end:, padding:) -> {
      let n = list.length(categories)
      case n <= 1 {
        True -> { range_start +. range_end } /. 2.0
        False -> {
          let total = math.abs(range_end -. range_start)
          let pad_px = total *. padding /. 2.0
          let usable = total -. 2.0 *. pad_px
          let step = usable /. int.to_float(n - 1)
          let index = find_index(categories, category, 0)
          range_start +. pad_px +. int.to_float(index) *. step
        }
      }
    }
    BandScale(..) -> {
      let #(start, bw) = band_apply(scale, category)
      start +. bw /. 2.0
    }
    _ -> 0.0
  }
}

/// Get the bandwidth of a band scale.
pub fn bandwidth(scale: Scale) -> Float {
  case scale {
    BandScale(
      categories:,
      range_start:,
      range_end:,
      padding_inner:,
      padding_outer:,
    ) -> {
      let n = list.length(categories)
      case n == 0 {
        True -> 0.0
        False -> {
          let total = math.abs(range_end -. range_start)
          let outer_total = 2.0 *. padding_outer
          let inner_total = int.to_float(n - 1) *. padding_inner
          let band_total = int.to_float(n)
          total /. { outer_total +. inner_total +. band_total }
        }
      }
    }
    _ -> 0.0
  }
}

// ---------------------------------------------------------------------------
// Inversion
// ---------------------------------------------------------------------------

/// Invert a linear scale: map a pixel coordinate back to a data value.
pub fn linear_invert(scale: Scale, pixel: Float) -> Float {
  case scale {
    LinearScale(domain_min:, domain_max:, range_start:, range_end:) -> {
      let range_span = range_end -. range_start
      case range_span == 0.0 {
        True -> domain_min
        False -> {
          let ratio = { pixel -. range_start } /. range_span
          domain_min +. ratio *. { domain_max -. domain_min }
        }
      }
    }
    _ -> 0.0
  }
}

/// Invert a power scale: map a pixel coordinate back to a data value.
pub fn power_invert(scale: Scale, pixel: Float) -> Float {
  case scale {
    PowerScale(domain_min:, domain_max:, range_start:, range_end:, exponent:) -> {
      let range_span = range_end -. range_start
      case range_span == 0.0 || exponent == 0.0 {
        True -> domain_min
        False -> {
          let pow_min = signed_pow(domain_min, exponent)
          let pow_max = signed_pow(domain_max, exponent)
          let ratio = { pixel -. range_start } /. range_span
          let pow_value = pow_min +. ratio *. { pow_max -. pow_min }
          signed_pow(pow_value, 1.0 /. exponent)
        }
      }
    }
    _ -> 0.0
  }
}

/// Invert a time scale: map a pixel coordinate back to an epoch-millisecond
/// value.
pub fn time_invert(scale: Scale, pixel: Float) -> Float {
  case scale {
    TimeScale(domain_min:, domain_max:, range_start:, range_end:) -> {
      let range_span = range_end -. range_start
      case range_span == 0.0 {
        True -> domain_min
        False -> {
          let ratio = { pixel -. range_start } /. range_span
          domain_min +. ratio *. { domain_max -. domain_min }
        }
      }
    }
    _ -> 0.0
  }
}

// ---------------------------------------------------------------------------
// Ticks
// ---------------------------------------------------------------------------

/// Compute tick marks for a scale.
///
/// For linear scales, generates `count` nice ticks using the recharts-scale
/// algorithm.  For log scales, generates ticks at powers of the base.
/// For sqrt scales, generates nice ticks in the transformed domain.
/// For power scales, generates nice ticks in the original domain.
/// For time scales, generates ticks at nice time boundaries.
/// For band/point scales, returns one tick per category.
/// For ordinal scales, returns one tick per mapped category.
/// The `allow_decimals` parameter controls whether tick values can have
/// fractional parts (matches recharts allowDecimals axis prop).
pub fn ticks(scale: Scale, count: Int, allow_decimals: Bool) -> List(ScaleTick) {
  case scale {
    LinearScale(domain_min:, domain_max:, ..) -> {
      let safe_count = case count < 2 {
        True -> 2
        False -> count
      }
      let tick_values =
        nice_ticks(domain_min, domain_max, safe_count, allow_decimals)
      list.map(tick_values, fn(value) {
        let coord = linear_apply(scale, value)
        ScaleTick(value: format_tick_value(value), coordinate: coord)
      })
    }

    LogScale(domain_min:, domain_max:, base:, ..) -> {
      let tick_values = log_ticks(domain_min, domain_max, base)
      list.map(tick_values, fn(value) {
        let coord = log_apply(scale, value)
        ScaleTick(value: format_tick_value(value), coordinate: coord)
      })
    }

    SqrtScale(domain_min:, domain_max:, ..) -> {
      let safe_count = case count < 2 {
        True -> 2
        False -> count
      }
      let tick_values =
        nice_ticks(domain_min, domain_max, safe_count, allow_decimals)
      list.map(tick_values, fn(value) {
        let coord = sqrt_apply(scale, value)
        ScaleTick(value: format_tick_value(value), coordinate: coord)
      })
    }

    PowerScale(domain_min:, domain_max:, ..) -> {
      let safe_count = case count < 2 {
        True -> 2
        False -> count
      }
      let tick_values =
        nice_ticks(domain_min, domain_max, safe_count, allow_decimals)
      list.map(tick_values, fn(value) {
        let coord = power_apply(scale, value)
        ScaleTick(value: format_tick_value(value), coordinate: coord)
      })
    }

    TimeScale(domain_min:, domain_max:, ..) -> {
      let tick_values = time_ticks(domain_min, domain_max, count)
      list.map(tick_values, fn(value) {
        let coord = time_apply(scale, value)
        ScaleTick(value: format_tick_value(value), coordinate: coord)
      })
    }

    BandScale(categories:, ..) ->
      list.map(categories, fn(cat) {
        let #(start, bw) = band_apply(scale, cat)
        ScaleTick(value: cat, coordinate: start +. bw /. 2.0)
      })

    PointScale(categories:, ..) ->
      list.map(categories, fn(cat) {
        let coord = point_apply(scale, cat)
        ScaleTick(value: cat, coordinate: coord)
      })

    OrdinalScale(mapping:, ..) ->
      dict.to_list(mapping)
      |> list.map(fn(pair) {
        let #(cat, value) = pair
        ScaleTick(value: cat, coordinate: value)
      })
  }
}

// ---------------------------------------------------------------------------
// Nice tick computation (matching recharts-scale getNiceTickValues)
// ---------------------------------------------------------------------------

/// Compute nice tick values for a numeric domain.
///
/// Implements the recharts-scale `getNiceTickValues` algorithm:
/// 1. Compute a rough step = (max - min) / (count - 1)
/// 2. Round the step to a "nice" number (1, 2, 2.5, 5, 10, etc.)
/// 3. Extend the domain to align with nice boundaries
/// 4. Generate ticks at exact intervals
///
/// If `allow_decimals` is False, the step is rounded up to the
/// nearest integer.
pub fn nice_ticks(
  min: Float,
  max: Float,
  count: Int,
  allow_decimals: Bool,
) -> List(Float) {
  let safe_count = case count < 2 {
    True -> 2
    False -> count
  }
  case min == max {
    True -> nice_ticks_single(min, safe_count, allow_decimals)
    False -> {
      let #(actual_min, actual_max, reversed) = case min >. max {
        True -> #(max, min, True)
        False -> #(min, max, False)
      }
      let result =
        nice_ticks_range(actual_min, actual_max, safe_count, allow_decimals)
      case reversed {
        True -> list.reverse(result)
        False -> result
      }
    }
  }
}

/// Generate ticks within a fixed domain (no domain extension).
/// Matches recharts-scale `getTickValuesFixedDomain`.
pub fn nice_ticks_fixed(
  min: Float,
  max: Float,
  count: Int,
  allow_decimals: Bool,
) -> List(Float) {
  let safe_count = case count < 2 {
    True -> 2
    False -> count
  }
  case min == max {
    True -> [min]
    False -> {
      let #(actual_min, actual_max, reversed) = case min >. max {
        True -> #(max, min, True)
        False -> #(min, max, False)
      }
      let step =
        nice_step(
          { actual_max -. actual_min } /. int.to_float(safe_count - 1),
          allow_decimals,
          0,
        )
      // Generate ticks from min up to (max - 0.99*step), then append max
      let inner = range_step(actual_min, actual_max -. 0.99 *. step, step)
      let result = list.append(inner, [actual_max])
      case reversed {
        True -> list.reverse(result)
        False -> result
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Domain helpers
// ---------------------------------------------------------------------------

/// Compute the numeric domain [min, max] from a list of data values.
/// Uses nice tick boundaries for clean axis limits.
pub fn auto_domain(values: List(Float)) -> #(Float, Float) {
  case values {
    [] -> #(0.0, 1.0)
    _ -> {
      let min = math.list_min(values)
      let max = math.list_max(values)
      case min == max {
        True ->
          case min == 0.0 {
            True -> #(0.0, 1.0)
            // Return degenerate domain as-is; tick generation handles nice
            // boundaries.  Matches recharts getNiceTickValues behavior for
            // single-value datasets.
            False -> #(min, max)
          }
        False -> #(min, max)
      }
    }
  }
}

/// Compute the numeric domain [0, max] for non-negative data (bar charts,
/// area charts).  Uses nice boundaries for the maximum.
pub fn auto_domain_from_zero(values: List(Float)) -> #(Float, Float) {
  case values {
    [] -> #(0.0, 1.0)
    _ -> {
      let max = math.list_max(values)
      case max <=. 0.0 {
        True -> #(0.0, 1.0)
        False -> {
          // Use nice tick to find a clean upper bound
          let ticks_list = nice_ticks(0.0, max, 5, True)
          let nice_max = case list.last(ticks_list) {
            Ok(v) -> v
            Error(_) -> max
          }
          #(0.0, nice_max)
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// DataKey resolution
// ---------------------------------------------------------------------------

/// Resolve a DataKey against a data dictionary, returning the extracted
/// Float value.
/// For StringKey, looks up the key in the dictionary.
/// For FnKey, calls the extractor function with the dictionary.
pub fn resolve_data_key(
  key key: DataKey,
  data data: Dict(String, Float),
) -> Result(Float, Nil) {
  case key {
    StringKey(k) -> dict.get(data, k)
    FnKey(extractor:) -> Ok(extractor(data))
  }
}

// ---------------------------------------------------------------------------
// DomainBound resolution
// ---------------------------------------------------------------------------

/// Resolve a domain bound to a concrete Float value, given the data
/// extremes.
pub fn resolve_domain_bound(
  bound bound: DomainBound,
  data_min data_min: Float,
  data_max data_max: Float,
) -> Float {
  case bound {
    Fixed(value:) -> value
    DataMin -> data_min
    DataMax -> data_max
    DataMinOffset(offset:) -> data_min -. offset
    DataMaxOffset(offset:) -> data_max +. offset
    DomainFn(transform:) -> transform(data_min, data_max)
  }
}

// ---------------------------------------------------------------------------
// Percentage parsing
// ---------------------------------------------------------------------------

/// Parse a percentage string like "50%" and multiply by the given total.
/// Returns Error for strings that do not end with '%' or cannot be parsed.
pub fn resolve_percent(
  value value: String,
  total total: Float,
) -> Result(Float, ScaleError) {
  case string.ends_with(value, "%") {
    False -> Error(InvalidPercentage(input: value))
    True -> {
      let numeric_part = string.drop_end(value, 1)
      case float.parse(numeric_part) {
        Ok(pct) -> Ok(pct /. 100.0 *. total)
        Error(_) ->
          case int.parse(numeric_part) {
            Ok(pct_int) -> Ok(int.to_float(pct_int) /. 100.0 *. total)
            Error(_) -> Error(PercentageParseError(input: value))
          }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Nice step computation (matches recharts-scale getFormatStep)
// ---------------------------------------------------------------------------

/// Natural log of 10, precomputed for digit count calculations.
const ln10 = 2.302585092994046

/// Compute the digit count of a number: floor(log10(abs(x))) + 1.
/// Returns 1 for zero. Matches recharts-scale Arithmetic.getDigitCount.
fn get_digit_count(value: Float) -> Int {
  case value == 0.0 {
    True -> 1
    False -> {
      let abs_val = math.abs(value)
      floor_int(math.ln(abs_val) /. ln10) + 1
    }
  }
}

/// Round a rough step size to a human-friendly number.
/// Matches recharts-scale getFormatStep exactly, including the
/// correction_factor parameter used by calculate_step for recursion.
fn nice_step(
  rough_step: Float,
  allow_decimals: Bool,
  correction_factor: Int,
) -> Float {
  case rough_step <=. 0.0 {
    True -> 0.0
    False -> {
      let digit_count = get_digit_count(rough_step)
      let digit_count_value = math.pow(10.0, int.to_float(digit_count))
      let step_ratio = rough_step /. digit_count_value
      let step_ratio_scale = case digit_count == 1 {
        True -> 0.1
        False -> 0.05
      }
      // Multiply the ceil result by (step_ratio_scale * digit_count_value) as a
      // single unit rather than (steps * srs) * dcv.  For common nice steps the
      // unit is an exact integer (e.g. 0.05 * 100 = 5, 0.1 * 10 = 1), so the
      // final product is exact and avoids floating-point drift such as
      // (12 * 0.05) * 100 = 0.6000000000000001 * 100 = 60.00000000000001.
      let ceil_steps =
        ceil_int(step_ratio /. step_ratio_scale) + correction_factor
      let unit = step_ratio_scale *. digit_count_value
      let format_step = int.to_float(ceil_steps) *. unit
      case allow_decimals {
        True -> format_step
        False -> int.to_float(ceil_int(format_step))
      }
    }
  }
}

/// Truncation-based modulo for floats, matching Decimal.js mod semantics.
fn float_mod(a: Float, b: Float) -> Float {
  a -. int.to_float(float.truncate(a /. b)) *. b
}

/// Check if a float value is an integer (has no fractional part).
fn is_float_integer(value: Float) -> Bool {
  int.to_float(float.truncate(value)) == value
}

// ---------------------------------------------------------------------------
// Nice ticks implementation
// ---------------------------------------------------------------------------

/// Generate nice ticks for a single value.
/// Matches recharts-scale getTickOfSingleValue exactly.
fn nice_ticks_single(
  value: Float,
  count: Int,
  allow_decimals: Bool,
) -> List(Float) {
  let #(step, middle) = case !is_float_integer(value) && allow_decimals {
    True -> {
      let abs_val = math.abs(value)
      case abs_val <. 1.0 {
        True -> {
          let s = math.pow(10.0, int.to_float(get_digit_count(value) - 1))
          let m = int.to_float(floor_int(value /. s)) *. s
          #(s, m)
        }
        False -> #(1.0, int.to_float(floor_int(value)))
      }
    }
    False ->
      case value == 0.0 {
        True -> {
          let m = int.to_float({ count - 1 } / 2)
          #(1.0, m)
        }
        False ->
          case !allow_decimals {
            True -> #(1.0, int.to_float(floor_int(value)))
            False -> #(1.0, value)
          }
      }
  }

  let middle_index = { count - 1 } / 2
  generate_single_ticks(0, count, middle, middle_index, step, [])
}

fn generate_single_ticks(
  i: Int,
  count: Int,
  middle: Float,
  middle_index: Int,
  step: Float,
  acc: List(Float),
) -> List(Float) {
  case i >= count {
    True -> list.reverse(acc)
    False -> {
      let tick = middle +. int.to_float(i - middle_index) *. step
      generate_single_ticks(i + 1, count, middle, middle_index, step, [
        tick,
        ..acc
      ])
    }
  }
}

/// Generate nice ticks for a range.
/// Matches recharts-scale calculateStep + rangeStep call exactly.
fn nice_ticks_range(
  min: Float,
  max: Float,
  count: Int,
  allow_decimals: Bool,
) -> List(Float) {
  let #(step, tick_min, tick_max) =
    calculate_step(min, max, count, allow_decimals, 0)
  range_step(tick_min, tick_max, step)
}

/// Compute the step, tick_min, and tick_max for a range.
/// Matches recharts-scale calculateStep with recursive correction.
fn calculate_step(
  min: Float,
  max: Float,
  count: Int,
  allow_decimals: Bool,
  correction_factor: Int,
) -> #(Float, Float, Float) {
  let step =
    nice_step(
      { max -. min } /. int.to_float(count - 1),
      allow_decimals,
      correction_factor,
    )

  // When 0 is inside the interval, force 0 as the middle tick
  let middle = case min <=. 0.0 && max >=. 0.0 {
    True -> 0.0
    False -> {
      let m = { min +. max } /. 2.0
      m -. float_mod(m, step)
    }
  }

  let below_count = ceil_int({ middle -. min } /. step)
  let up_count = ceil_int({ max -. middle } /. step)
  let scale_count = below_count + up_count + 1

  case scale_count > count {
    True ->
      calculate_step(min, max, count, allow_decimals, correction_factor + 1)
    False -> {
      // Distribute extra ticks when scale_count < count
      let #(final_below, final_up) = case scale_count < count {
        True ->
          case max >. 0.0 {
            True -> #(below_count, up_count + count - scale_count)
            False -> #(below_count + count - scale_count, up_count)
          }
        False -> #(below_count, up_count)
      }
      let tick_min = middle -. int.to_float(final_below) *. step
      let tick_max = middle +. int.to_float(final_up) *. step
      #(step, tick_min, tick_max)
    }
  }
}

/// Generate a list of values from start to end (inclusive) by step.
fn range_step(start: Float, end: Float, step: Float) -> List(Float) {
  case step <=. 0.0 {
    True -> [start]
    False -> range_step_loop(start, end, step, [])
  }
}

fn range_step_loop(
  current: Float,
  end: Float,
  step: Float,
  acc: List(Float),
) -> List(Float) {
  case current >. end +. step *. 0.1 {
    True -> list.reverse(acc)
    False -> range_step_loop(current +. step, end, step, [current, ..acc])
  }
}

/// Floor for floats to int.
fn floor_int(x: Float) -> Int {
  let truncated = float.truncate(x)
  case int.to_float(truncated) >. x {
    True -> truncated - 1
    False -> truncated
  }
}

/// Ceiling for floats to int.
fn ceil_int(x: Float) -> Int {
  let truncated = float.truncate(x)
  case int.to_float(truncated) <. x {
    True -> truncated + 1
    False -> truncated
  }
}

/// Format a tick value as a string, removing unnecessary trailing zeros.
fn format_tick_value(value: Float) -> String {
  let rounded = float.round(value)
  case math.abs(value -. int.to_float(rounded)) <. 0.0001 {
    True -> int.to_string(rounded)
    False -> math.fmt(value)
  }
}

// ---------------------------------------------------------------------------
// Log tick generation
// ---------------------------------------------------------------------------

/// Generate tick values at powers of the base within [min, max].
/// For base=10 and domain [1, 10000]: produces [1, 10, 100, 1000, 10000].
pub fn log_ticks(min: Float, max: Float, base: Float) -> List(Float) {
  case min <=. 0.0 || max <=. 0.0 || base <=. 1.0 {
    True -> [min, max]
    False -> {
      let log_min = math.log_base(min, base)
      let log_max = math.log_base(max, base)
      let start_exp = floor_int(log_min)
      let end_exp = ceil_int(log_max)
      log_ticks_loop(start_exp, end_exp, base, [])
    }
  }
}

fn log_ticks_loop(
  current: Int,
  end: Int,
  base: Float,
  acc: List(Float),
) -> List(Float) {
  case current > end {
    True -> list.reverse(acc)
    False -> {
      let value = math.pow(base, int.to_float(current))
      log_ticks_loop(current + 1, end, base, [value, ..acc])
    }
  }
}

// ---------------------------------------------------------------------------
// Time tick generation
// ---------------------------------------------------------------------------

/// Milliseconds per second.
const ms_second = 1000.0

/// Milliseconds per minute.
const ms_minute = 60_000.0

/// Milliseconds per hour.
const ms_hour = 3_600_000.0

/// Milliseconds per day.
const ms_day = 86_400_000.0

/// Approximate milliseconds per month (30 days).
const ms_month = 2_592_000_000.0

/// Approximate milliseconds per year (365 days).
const ms_year = 31_536_000_000.0

/// Generate nice time tick values for an epoch-millisecond domain.
/// Selects an appropriate time interval based on the range span,
/// then rounds to nice boundaries.
pub fn time_ticks(min: Float, max: Float, count: Int) -> List(Float) {
  let safe_count = case count < 2 {
    True -> 2
    False -> count
  }
  let span = math.abs(max -. min)
  case span == 0.0 {
    True -> [min]
    False -> {
      let step = pick_time_step(span, safe_count)
      let nice_min = float_floor_to(min, step)
      time_ticks_loop(nice_min, max, step, [])
    }
  }
}

/// Pick an appropriate time step based on the domain span and desired count.
fn pick_time_step(span: Float, count: Int) -> Float {
  let rough = span /. int.to_float(count - 1)
  // Pick the largest "nice" time interval that fits
  case rough >=. ms_year {
    True -> round_up_to_nice(rough /. ms_year) *. ms_year
    False ->
      case rough >=. ms_month {
        True -> round_up_to_nice(rough /. ms_month) *. ms_month
        False ->
          case rough >=. ms_day {
            True -> round_up_to_nice(rough /. ms_day) *. ms_day
            False ->
              case rough >=. ms_hour {
                True -> round_up_to_nice(rough /. ms_hour) *. ms_hour
                False ->
                  case rough >=. ms_minute {
                    True -> round_up_to_nice(rough /. ms_minute) *. ms_minute
                    False ->
                      case rough >=. ms_second {
                        True ->
                          round_up_to_nice(rough /. ms_second) *. ms_second
                        False -> {
                          // Sub-second: use raw nice step in milliseconds
                          let nice_values = nice_ticks(0.0, span, count, True)
                          case nice_values {
                            [_, second, ..] -> second
                            _ -> rough
                          }
                        }
                      }
                  }
              }
          }
      }
  }
}

/// Round up a multiplier to a nice number (1, 2, 3, 5, 6, 10, 12, ...).
fn round_up_to_nice(x: Float) -> Float {
  let nice_multiples = [1.0, 2.0, 3.0, 5.0, 6.0, 10.0, 12.0, 15.0, 20.0, 30.0]
  find_nice_multiple(nice_multiples, x)
}

fn find_nice_multiple(multiples: List(Float), target: Float) -> Float {
  case multiples {
    [] -> target
    [m, ..rest] ->
      case m >=. target {
        True -> m
        False -> find_nice_multiple(rest, target)
      }
  }
}

/// Floor a value to the nearest multiple of step.
fn float_floor_to(value: Float, step: Float) -> Float {
  case step <=. 0.0 {
    True -> value
    False -> int.to_float(floor_int(value /. step)) *. step
  }
}

fn time_ticks_loop(
  current: Float,
  max: Float,
  step: Float,
  acc: List(Float),
) -> List(Float) {
  case current >. max +. step *. 0.01 {
    True -> list.reverse(acc)
    False -> time_ticks_loop(current +. step, max, step, [current, ..acc])
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn find_index(items: List(String), target: String, current: Int) -> Int {
  case items {
    [] -> 0
    [first, ..rest] ->
      case first == target {
        True -> current
        False -> find_index(rest, target, current + 1)
      }
  }
}

/// Apply power with sign preservation for negative base values.
/// This matches D3's behavior where negative values are raised to the
/// exponent with sign preserved: sign(x) * |x|^exp.
fn signed_pow(value: Float, exp: Float) -> Float {
  case value <. 0.0 {
    True -> -1.0 *. math.pow(math.abs(value), exp)
    False -> math.pow(value, exp)
  }
}
