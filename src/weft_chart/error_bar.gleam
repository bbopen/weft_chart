//// Error bar component for charts.
////
//// Renders error bar indicators on data points showing measurement
//// uncertainty.  Supports both symmetric (equal +/- range) and
//// asymmetric (different low/high) error values.  Each error bar
//// consists of a main line spanning the error range and two serif
//// lines at the endpoints.  Matches the recharts ErrorBar component
//// for direction, width, and stroke styling.

import gleam/dict.{type Dict}
import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import weft_chart/internal/math
import weft_chart/internal/svg
import weft_chart/scale.{type Scale}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Direction of the error bar indicator.
pub type ErrorBarDirection {
  /// Vertical error bars (default for most charts).
  ErrorBarY
  /// Horizontal error bars (for scatter charts or horizontal layouts).
  ErrorBarX
}

/// Represents the error magnitude for an error bar.
pub type ErrorBarValue {
  /// Symmetric error: same magnitude above and below.
  Symmetric(value: Float)
  /// Asymmetric error: different magnitude below and above.
  Asymmetric(low: Float, high: Float)
}

/// Configuration for an error bar component.
pub type ErrorBarConfig {
  ErrorBarConfig(
    data_key: String,
    high_data_key: Option(String),
    direction: ErrorBarDirection,
    width: Float,
    stroke: String,
    stroke_width: Float,
    /// SVG stroke-dasharray for dashed error bar lines. Empty string = solid.
    stroke_dasharray: String,
    offset: Float,
    x_axis_id: String,
    y_axis_id: String,
    css_class: String,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create an error bar configuration with default settings.
/// Matches recharts ErrorBar defaults: direction=y, width=5, stroke=#000.
/// The `data_key` identifies the error value in the data dictionary.
/// For symmetric errors, this single key provides the +/- magnitude.
/// For asymmetric errors, this key provides the low magnitude and a
/// separate `high_data_key` provides the high magnitude.
pub fn error_bar_config(data_key data_key: String) -> ErrorBarConfig {
  ErrorBarConfig(
    data_key: data_key,
    high_data_key: None,
    direction: ErrorBarY,
    width: 5.0,
    stroke: "var(--weft-chart-error-bar, #000)",
    stroke_width: 1.5,
    stroke_dasharray: "",
    offset: 0.0,
    x_axis_id: "0",
    y_axis_id: "0",
    css_class: "",
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the error bar direction.
pub fn error_bar_direction(
  config config: ErrorBarConfig,
  direction direction: ErrorBarDirection,
) -> ErrorBarConfig {
  ErrorBarConfig(..config, direction: direction)
}

/// Set the serif width (half-width of the cap lines).
pub fn error_bar_width(
  config config: ErrorBarConfig,
  width width: Float,
) -> ErrorBarConfig {
  ErrorBarConfig(..config, width: width)
}

/// Set the stroke color.
pub fn error_bar_stroke(
  config config: ErrorBarConfig,
  stroke stroke: String,
) -> ErrorBarConfig {
  ErrorBarConfig(..config, stroke: stroke)
}

/// Set the stroke width.
pub fn error_bar_stroke_width(
  config config: ErrorBarConfig,
  width width: Float,
) -> ErrorBarConfig {
  ErrorBarConfig(..config, stroke_width: width)
}

/// Set the SVG stroke-dasharray for dashed error bar lines.
/// An empty string produces solid lines (the default).
/// Matches the SVG `stroke-dasharray` attribute (e.g. "5 3" for dashes).
pub fn error_bar_stroke_dasharray(
  config config: ErrorBarConfig,
  dasharray dasharray: String,
) -> ErrorBarConfig {
  ErrorBarConfig(..config, stroke_dasharray: dasharray)
}

/// Set the pixel offset from the center position.
/// Positive values shift the error bar right (for vertical) or down
/// (for horizontal).  Matches recharts ErrorBar `offset` prop.
pub fn error_bar_offset(
  config config: ErrorBarConfig,
  offset_value offset_value: Float,
) -> ErrorBarConfig {
  ErrorBarConfig(..config, offset: offset_value)
}

/// Set the x-axis ID this error bar binds to.
/// Matches recharts ErrorBar `xAxisId` prop (default: "0").
pub fn error_bar_x_axis_id(
  config config: ErrorBarConfig,
  id id: String,
) -> ErrorBarConfig {
  ErrorBarConfig(..config, x_axis_id: id)
}

/// Set the y-axis ID this error bar binds to.
/// Matches recharts ErrorBar `yAxisId` prop (default: "0").
pub fn error_bar_y_axis_id(
  config config: ErrorBarConfig,
  id id: String,
) -> ErrorBarConfig {
  ErrorBarConfig(..config, y_axis_id: id)
}

/// Set the CSS class name for the error bar group.
/// Matches recharts ErrorBar `className` prop (default: "").
pub fn error_bar_css_class(
  config config: ErrorBarConfig,
  css_class css_class: String,
) -> ErrorBarConfig {
  ErrorBarConfig(..config, css_class: css_class)
}

/// Set the high data key for asymmetric error bars.
/// When set, `data_key` provides the low error magnitude and
/// `high_data_key` provides the high error magnitude.
pub fn error_bar_high_data_key(
  config config: ErrorBarConfig,
  key key: String,
) -> ErrorBarConfig {
  ErrorBarConfig(..config, high_data_key: Some(key))
}

/// Create a symmetric error bar value (same magnitude above and below).
pub fn error_bar_symmetric(value v: Float) -> ErrorBarValue {
  Symmetric(value: v)
}

/// Create an asymmetric error bar value (different magnitude below and above).
pub fn error_bar_asymmetric(low l: Float, high h: Float) -> ErrorBarValue {
  Asymmetric(low: l, high: h)
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render error bars for all data points that have error values.
/// Supports both symmetric and asymmetric errors.  When `high_data_key`
/// is set on the config, uses separate low/high magnitudes from data.
/// For each point with an error value, renders:
/// - A main line spanning the error range
/// - Two serif (cap) lines at the endpoints
pub fn render_error_bars(
  config config: ErrorBarConfig,
  data data: List(Dict(String, Float)),
  categories categories: List(String),
  x_scale x_scale: Scale,
  y_scale y_scale: Scale,
  series_data_key series_data_key: String,
) -> Element(msg) {
  let base_stroke_attrs = [
    svg.attr("stroke", config.stroke),
    svg.attr("stroke-width", float.to_string(config.stroke_width)),
    svg.attr("fill", "none"),
  ]
  let stroke_attrs = case config.stroke_dasharray {
    "" -> base_stroke_attrs
    d -> list.append(base_stroke_attrs, [svg.attr("stroke-dasharray", d)])
  }

  let error_els =
    list.zip(categories, data)
    |> list.filter_map(fn(pair) {
      let #(cat, values) = pair
      // Need the data value and the error value(s)
      case dict.get(values, series_data_key) {
        Error(Nil) -> Error(Nil)
        Ok(value) -> {
          case resolve_error_value(config, values) {
            Error(Nil) -> Error(Nil)
            Ok(error_value) -> {
              let x = scale.point_apply(x_scale, cat)
              let y = scale.linear_apply(y_scale, value)
              Ok(render_single_error_bar(
                config,
                x,
                y,
                value,
                error_value,
                x_scale,
                y_scale,
                stroke_attrs,
              ))
            }
          }
        }
      }
    })

  let class_value = case config.css_class {
    "" -> "recharts-errorBar"
    c -> "recharts-errorBar " <> c
  }
  svg.g(attrs: [svg.attr("class", class_value)], children: error_els)
}

/// Resolve the error value from data, returning Symmetric or Asymmetric.
fn resolve_error_value(
  config: ErrorBarConfig,
  values: Dict(String, Float),
) -> Result(ErrorBarValue, Nil) {
  case config.high_data_key {
    None ->
      case dict.get(values, config.data_key) {
        Ok(err) if err >. 0.0 -> Ok(Symmetric(value: err))
        _ -> Error(Nil)
      }
    Some(high_key) ->
      case dict.get(values, config.data_key), dict.get(values, high_key) {
        Ok(low), Ok(high) if low >. 0.0 || high >. 0.0 ->
          Ok(Asymmetric(low: low, high: high))
        _, _ -> Error(Nil)
      }
  }
}

/// Render a single error bar (main line + two serifs).
fn render_single_error_bar(
  config: ErrorBarConfig,
  x: Float,
  y: Float,
  value: Float,
  error_value: ErrorBarValue,
  x_scale: Scale,
  y_scale: Scale,
  stroke_attrs: List(Attribute(msg)),
) -> Element(msg) {
  let half_w = config.width /. 2.0

  let #(low_bound, high_bound) = case error_value {
    Symmetric(value: v) -> #(v, v)
    Asymmetric(low:, high:) -> #(low, high)
  }

  case config.direction {
    ErrorBarY -> {
      // Vertical error bar: map (value +/- error) through y-scale
      // Apply offset: shift x position
      let ox = x +. config.offset
      let y_top = scale.linear_apply(y_scale, value +. high_bound)
      let y_bottom = scale.linear_apply(y_scale, value -. low_bound)

      let main_line =
        svg.line(
          x1: math.fmt(ox),
          y1: math.fmt(y_top),
          x2: math.fmt(ox),
          y2: math.fmt(y_bottom),
          attrs: stroke_attrs,
        )
      let top_serif =
        svg.line(
          x1: math.fmt(ox -. half_w),
          y1: math.fmt(y_top),
          x2: math.fmt(ox +. half_w),
          y2: math.fmt(y_top),
          attrs: stroke_attrs,
        )
      let bottom_serif =
        svg.line(
          x1: math.fmt(ox -. half_w),
          y1: math.fmt(y_bottom),
          x2: math.fmt(ox +. half_w),
          y2: math.fmt(y_bottom),
          attrs: stroke_attrs,
        )
      svg.g(attrs: [], children: [main_line, top_serif, bottom_serif])
    }
    ErrorBarX -> {
      // Horizontal error bar: map (value +/- error) through x-scale
      // Apply offset: shift y position
      let oy = y +. config.offset
      let x_left = scale.linear_apply(x_scale, value -. low_bound)
      let x_right = scale.linear_apply(x_scale, value +. high_bound)

      let main_line =
        svg.line(
          x1: math.fmt(x_left),
          y1: math.fmt(oy),
          x2: math.fmt(x_right),
          y2: math.fmt(oy),
          attrs: stroke_attrs,
        )
      let left_serif =
        svg.line(
          x1: math.fmt(x_left),
          y1: math.fmt(oy -. half_w),
          x2: math.fmt(x_left),
          y2: math.fmt(oy +. half_w),
          attrs: stroke_attrs,
        )
      let right_serif =
        svg.line(
          x1: math.fmt(x_right),
          y1: math.fmt(oy -. half_w),
          x2: math.fmt(x_right),
          y2: math.fmt(oy +. half_w),
          attrs: stroke_attrs,
        )
      svg.g(attrs: [], children: [main_line, left_serif, right_serif])
    }
  }
}
