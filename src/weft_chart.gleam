//// SVG chart rendering for Lustre — a pure-Gleam port of Recharts.
////
//// This library provides compositional chart components that render
//// deterministic SVG output.  Supports area, bar, line, pie, radar,
//// and radial bar charts with configurable scales, curves, axes,
//// grids, tooltips, and legends.
////
//// ## Quick start
////
//// ```gleam
//// import weft_chart.{data_point}
//// import weft_chart/chart
//// import weft_chart/series/area
//// import weft_chart/series/common
//// import weft_chart/curve
////
//// let data = [
////   data_point("Jan", [#("revenue", 186.0)]),
////   data_point("Feb", [#("revenue", 305.0)]),
//// ]
////
//// chart.area_chart(data: data, width: 500, height: 300, children: [
////   chart.area(
////     area.area_config(data_key: "revenue", meta: common.series_meta())
////     |> area.area_curve_type(curve.Natural),
////   ),
//// ])
//// ```

import gleam/dict

/// A data point with a category label and named numeric values.
///
/// This is the primary data type consumed by all chart containers.
/// The `category` field maps to the x-axis (cartesian) or label (polar).
/// The `values` dict holds one entry per series, keyed by the series
/// `data_key`.
pub type DataPoint =
  dict.Dict(String, Float)

/// Construct a data point from a category label and key-value pairs.
///
/// ```gleam
/// data_point("January", [#("desktop", 186.0), #("mobile", 80.0)])
/// ```
pub fn data_point(
  category category: String,
  values values: List(#(String, Float)),
) -> #(String, DataPoint) {
  #(category, dict.from_list(values))
}
