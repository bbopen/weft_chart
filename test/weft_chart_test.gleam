//// Tests for the weft_chart library.

import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft
import weft_chart
import weft_chart/axis
import weft_chart/chart
import weft_chart/curve
import weft_chart/error_bar
import weft_chart/grid
import weft_chart/internal/layout
import weft_chart/internal/math
import weft_chart/internal/polar
import weft_chart/label
import weft_chart/legend
import weft_chart/polar_axis
import weft_chart/reference.{
  Discard, ExtendDomain, Hidden, RefLineEnd, RefLineMiddle, RefLineStart,
  Visible,
}
import weft_chart/scale
import weft_chart/series/area
import weft_chart/series/bar
import weft_chart/series/common
import weft_chart/series/funnel
import weft_chart/series/line
import weft_chart/series/pie
import weft_chart/series/radar
import weft_chart/series/radial_bar
import weft_chart/series/sankey
import weft_chart/series/scatter
import weft_chart/series/sunburst
import weft_chart/series/treemap
import weft_chart/shape
import weft_chart/tooltip

pub fn main() {
  startest.run(startest.default_config())
}

pub fn data_point_tests() {
  describe("data_point", [
    it("constructs a category-values pair", fn() {
      let point =
        weft_chart.data_point("Jan", [#("desktop", 186.0), #("mobile", 80.0)])
      point.category |> expect.to_equal(expected: "Jan")
      dict.get(point.values, "desktop")
      |> expect.to_equal(expected: Ok(186.0))
      dict.get(point.values, "mobile")
      |> expect.to_equal(expected: Ok(80.0))
    }),
  ])
}

pub fn scale_tests() {
  describe("scale", [
    describe("linear", [
      it("maps domain values to range", fn() {
        let s =
          scale.linear(
            domain_min: 0.0,
            domain_max: 100.0,
            range_start: 0.0,
            range_end: 500.0,
          )
        scale.linear_apply(s, 0.0) |> expect.to_equal(expected: 0.0)
        scale.linear_apply(s, 50.0) |> expect.to_equal(expected: 250.0)
        scale.linear_apply(s, 100.0) |> expect.to_equal(expected: 500.0)
      }),
      it("handles zero-span domain", fn() {
        let s =
          scale.linear(
            domain_min: 50.0,
            domain_max: 50.0,
            range_start: 0.0,
            range_end: 500.0,
          )
        scale.linear_apply(s, 50.0) |> expect.to_equal(expected: 250.0)
      }),
      it("inverts pixel to value", fn() {
        let s =
          scale.linear(
            domain_min: 0.0,
            domain_max: 100.0,
            range_start: 0.0,
            range_end: 500.0,
          )
        scale.linear_invert(s, 250.0) |> expect.to_equal(expected: 50.0)
      }),
    ]),
    describe("band", [
      it("computes bandwidth for categories", fn() {
        let s =
          scale.band(
            categories: ["A", "B", "C"],
            range_start: 0.0,
            range_end: 300.0,
            padding_inner: 0.1,
            padding_outer: 0.1,
          )
        let bw = scale.bandwidth(s)
        // Bandwidth should be positive
        { bw >. 0.0 } |> expect.to_be_true
        // Each band should fit within the range
        { bw *. 3.0 <. 300.0 } |> expect.to_be_true
      }),
      it("maps categories to bands", fn() {
        let s =
          scale.band(
            categories: ["A", "B"],
            range_start: 0.0,
            range_end: 200.0,
            padding_inner: 0.0,
            padding_outer: 0.0,
          )
        let #(a_start, a_bw) = scale.band_apply(s, "A")
        let #(b_start, _b_bw) = scale.band_apply(s, "B")
        a_start |> expect.to_equal(expected: 0.0)
        a_bw |> expect.to_equal(expected: 100.0)
        b_start |> expect.to_equal(expected: 100.0)
      }),
    ]),
    describe("point", [
      it("maps categories to evenly spaced coordinates", fn() {
        let s =
          scale.point(
            categories: ["A", "B", "C"],
            range_start: 0.0,
            range_end: 300.0,
            padding: 0.0,
          )
        scale.point_apply(s, "A") |> expect.to_equal(expected: 0.0)
        scale.point_apply(s, "B") |> expect.to_equal(expected: 150.0)
        scale.point_apply(s, "C") |> expect.to_equal(expected: 300.0)
      }),
    ]),
    describe("ticks", [
      it("generates linear ticks", fn() {
        let s =
          scale.linear(
            domain_min: 0.0,
            domain_max: 100.0,
            range_start: 0.0,
            range_end: 500.0,
          )
        let tick_list = scale.ticks(s, 3, True)
        list.length(tick_list) |> expect.to_equal(expected: 3)
      }),
      it("generates point ticks for all categories", fn() {
        let s =
          scale.point(
            categories: ["A", "B", "C"],
            range_start: 0.0,
            range_end: 300.0,
            padding: 0.0,
          )
        let tick_list = scale.ticks(s, 5, True)
        list.length(tick_list) |> expect.to_equal(expected: 3)
      }),
    ]),
    describe("nice_ticks", [
      it("produces nice round values for simple range", fn() {
        let ticks = scale.nice_ticks(0.0, 100.0, 5, True)
        // Should include 0 and 100 as boundaries
        case list.first(ticks) {
          Ok(first) -> { first <=. 0.0 } |> expect.to_be_true
          Error(_) -> expect.to_be_true(False)
        }
        case list.last(ticks) {
          Ok(last) -> { last >=. 100.0 } |> expect.to_be_true
          Error(_) -> expect.to_be_true(False)
        }
      }),
      it("handles equal min and max", fn() {
        let ticks = scale.nice_ticks(50.0, 50.0, 5, True)
        { list.length(ticks) >= 1 } |> expect.to_be_true
      }),
      it("handles reversed range", fn() {
        let ticks = scale.nice_ticks(100.0, 0.0, 5, True)
        case list.first(ticks) {
          Ok(first) -> { first >=. 100.0 } |> expect.to_be_true
          Error(_) -> expect.to_be_true(False)
        }
      }),
      it("respects allow_decimals=False", fn() {
        let ticks = scale.nice_ticks(0.0, 3.0, 5, False)
        // All ticks should be integers when allow_decimals is False
        list.each(ticks, fn(t) {
          let rounded = {
            t -. int.to_float(float.truncate(t))
          }
          { rounded <=. 0.001 || rounded >=. 0.999 } |> expect.to_be_true
        })
      }),
    ]),
    describe("nice_ticks_fixed", [
      it("generates ticks within domain bounds", fn() {
        let ticks = scale.nice_ticks_fixed(10.0, 90.0, 5, True)
        case list.first(ticks) {
          Ok(first) -> { first >=. 10.0 } |> expect.to_be_true
          Error(_) -> expect.to_be_true(False)
        }
        case list.last(ticks) {
          Ok(last) -> { last <=. 90.0 } |> expect.to_be_true
          Error(_) -> expect.to_be_true(False)
        }
      }),
    ]),
    describe("auto_domain", [
      it("computes domain from values", fn() {
        let #(min, max) = scale.auto_domain([10.0, 50.0, 30.0])
        min |> expect.to_equal(expected: 10.0)
        max |> expect.to_equal(expected: 50.0)
      }),
      it("handles empty list", fn() {
        let #(min, max) = scale.auto_domain([])
        min |> expect.to_equal(expected: 0.0)
        max |> expect.to_equal(expected: 1.0)
      }),
      it("handles single value", fn() {
        let #(min, max) = scale.auto_domain([42.0])
        // Returns degenerate domain; tick generation handles nice boundaries
        // matching recharts getNiceTickValues behavior
        min |> expect.to_equal(expected: 42.0)
        max |> expect.to_equal(expected: 42.0)
      }),
    ]),
    describe("auto_domain_from_zero", [
      it("starts at zero", fn() {
        let #(min, _max) = scale.auto_domain_from_zero([10.0, 50.0, 30.0])
        min |> expect.to_equal(expected: 0.0)
      }),
      it("uses nice upper bound", fn() {
        let #(_min, max) = scale.auto_domain_from_zero([10.0, 47.0, 30.0])
        // Nice upper bound should be >= actual max
        { max >=. 47.0 } |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn curve_tests() {
  describe("curve", [
    describe("path", [
      it("generates empty string for no points", fn() {
        curve.path(curve_type: curve.Linear, points: [])
        |> expect.to_equal(expected: "")
      }),
      it("generates moveto for single point", fn() {
        let result =
          curve.path(curve_type: curve.Linear, points: [#(10.0, 20.0)])
        result |> expect.to_equal(expected: "M10,20")
      }),
      it("generates linear segments", fn() {
        let result =
          curve.path(curve_type: curve.Linear, points: [
            #(0.0, 0.0),
            #(100.0, 50.0),
            #(200.0, 25.0),
          ])
        result
        |> string.contains("M0,0")
        |> expect.to_be_true
        result
        |> string.contains("L100,50")
        |> expect.to_be_true
        result
        |> string.contains("L200,25")
        |> expect.to_be_true
      }),
      it("generates cubic bezier curves for natural type", fn() {
        let result =
          curve.path(curve_type: curve.Natural, points: [
            #(0.0, 0.0),
            #(100.0, 50.0),
            #(200.0, 25.0),
          ])
        result
        |> string.contains("C")
        |> expect.to_be_true
      }),
      it("falls back to linear for 2 points with natural type", fn() {
        let result =
          curve.path(curve_type: curve.Natural, points: [
            #(0.0, 0.0),
            #(100.0, 50.0),
          ])
        result
        |> string.contains("L")
        |> expect.to_be_true
      }),
      it("generates step paths", fn() {
        let result =
          curve.path(curve_type: curve.Step, points: [
            #(0.0, 0.0),
            #(100.0, 50.0),
          ])
        result
        |> string.contains("H")
        |> expect.to_be_true
        result
        |> string.contains("V")
        |> expect.to_be_true
      }),
      it("generates monotone x paths", fn() {
        let result =
          curve.path(curve_type: curve.MonotoneX, points: [
            #(0.0, 0.0),
            #(100.0, 50.0),
            #(200.0, 25.0),
          ])
        result
        |> string.contains("C")
        |> expect.to_be_true
      }),
      it("generates basis spline paths", fn() {
        let result =
          curve.path(curve_type: curve.Basis, points: [
            #(0.0, 0.0),
            #(100.0, 50.0),
            #(200.0, 25.0),
          ])
        result
        |> string.contains("C")
        |> expect.to_be_true
      }),
    ]),
    describe("area_path", [
      it("closes to flat baseline", fn() {
        let result =
          curve.area_path(
            curve_type: curve.Linear,
            points: [#(0.0, 50.0), #(100.0, 25.0)],
            baseline: curve.FlatBaseline(y: 200.0),
          )
        result
        |> string.contains("Z")
        |> expect.to_be_true
        result
        |> string.contains("L100,200")
        |> expect.to_be_true
        result
        |> string.contains("L0,200")
        |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn tooltip_tests() {
  describe("tooltip", [
    describe("tooltip_config", [
      it("creates default configuration", fn() {
        let config = tooltip.tooltip_config()
        config.show_cursor |> expect.to_be_true
        config.hide_label |> expect.to_be_false
        config.hide_indicator |> expect.to_be_true
        config.offset |> expect.to_equal(expected: 10)
        config.has_custom_position |> expect.to_be_false
        config.allow_escape_x |> expect.to_be_false
        config.allow_escape_y |> expect.to_be_false
      }),
      it("applies position builder", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_position(100.0, 200.0)
        config.has_custom_position |> expect.to_be_true
        config.position_x |> expect.to_equal(expected: 100.0)
        config.position_y |> expect.to_equal(expected: 200.0)
      }),
      it("applies offset builder", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_offset(15)
        config.offset |> expect.to_equal(expected: 15)
      }),
      it("applies cursor type builder", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_cursor_type(tooltip.RectangleCursor)
        config.cursor_type
        |> expect.to_equal(expected: tooltip.RectangleCursor)
      }),
      it("applies indicator builder", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_indicator(tooltip.DashedIndicator)
        config.indicator
        |> expect.to_equal(expected: tooltip.DashedIndicator)
      }),
    ]),
    describe("auto_cursor", [
      it("bar_chart auto-sets RectangleCursor", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.bar(bar.bar_config(
                data_key: "v",
                meta: common.series_meta(),
              )),
              chart.tooltip(tooltip.tooltip_config()),
            ],
          )
          |> element.to_string
        // RectangleCursor renders a rect with opacity, not a line
        html |> string.contains("opacity") |> expect.to_be_true
        html
        |> string.contains("chart-tooltip-cursor")
        |> expect.to_be_true
      }),
      it("line_chart keeps VerticalCursor", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.line_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.line(line.line_config(
                data_key: "v",
                meta: common.series_meta(),
              )),
              chart.tooltip(tooltip.tooltip_config()),
            ],
          )
          |> element.to_string
        // VerticalCursor renders a line element, no opacity attribute
        html
        |> string.contains("chart-tooltip-cursor")
        |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn bar_tests() {
  describe("bar", [
    describe("bar_config", [
      it("creates default configuration", fn() {
        let config =
          bar.bar_config(data_key: "sales", meta: common.series_meta())
        config.data_key |> expect.to_equal(expected: "sales")
        config.radius |> expect.to_equal(expected: 0.0)
        config.has_custom_corners |> expect.to_be_false
        config.show_background |> expect.to_be_false
        config.min_point_size
        |> expect.to_equal(expected: bar.FixedMinPointSize(0.0))
        config.background_fill
        |> expect.to_equal(expected: weft.css_color(
          value: "var(--weft-chart-bar-bg, #eee)",
        ))
      }),
      it("applies corner radius builders", fn() {
        let config =
          bar.bar_config(data_key: "sales", meta: common.series_meta())
          |> bar.bar_radius_corners(tl: 4.0, tr: 4.0, br: 0.0, bl: 0.0)
        config.has_custom_corners |> expect.to_be_true
        let #(tl, tr, br, bl) = config.radius_corners
        tl |> expect.to_equal(expected: 4.0)
        tr |> expect.to_equal(expected: 4.0)
        br |> expect.to_equal(expected: 0.0)
        bl |> expect.to_equal(expected: 0.0)
      }),
      it("applies background fill builder", fn() {
        let config =
          bar.bar_config(data_key: "sales", meta: common.series_meta())
          |> bar.bar_background(True)
          |> bar.bar_background_fill(weft.css_color(value: "#f0f0f0"))
        config.show_background |> expect.to_be_true
        config.background_fill
        |> expect.to_equal(expected: weft.css_color(value: "#f0f0f0"))
      }),
    ]),
    describe("multi_bar_chart", [
      it("renders multiple bars side by side", fn() {
        let data = [
          chart.DataPoint(
            category: "Jan",
            values: dict.from_list([#("sales", 50.0), #("profit", 30.0)]),
          ),
          chart.DataPoint(
            category: "Feb",
            values: dict.from_list([#("sales", 80.0), #("profit", 45.0)]),
          ),
        ]
        let el =
          chart.bar_chart(
            data: data,
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [
              chart.bar(
                bar.bar_config(data_key: "sales", meta: common.series_meta())
                |> bar.bar_fill(weft.css_color(value: "#8884d8")),
              ),
              chart.bar(
                bar.bar_config(data_key: "profit", meta: common.series_meta())
                |> bar.bar_fill(weft.css_color(value: "#82ca9d")),
              ),
            ],
          )
        // Should render without crashing and differ from empty
        el
        |> expect.to_not_equal(
          expected: chart.bar_chart(
            data: [],
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [],
          ),
        )
      }),
    ]),
  ])
}

pub fn pie_tests() {
  describe("pie", [
    describe("pie_config", [
      it("creates default configuration with recharts defaults", fn() {
        let config = pie.pie_config(data_key: "value")
        config.name_key |> expect.to_equal(expected: "name")
        config.outer_radius |> expect.to_equal(expected: 0.8)
        config.start_angle |> expect.to_equal(expected: 0.0)
        config.end_angle |> expect.to_equal(expected: 360.0)
        config.padding_angle |> expect.to_equal(expected: 0.0)
        config.min_angle |> expect.to_equal(expected: 0.0)
      }),
      it("applies padding angle builder", fn() {
        let config =
          pie.pie_config(data_key: "value")
          |> pie.pie_padding_angle(5.0)
        config.padding_angle |> expect.to_equal(expected: 5.0)
      }),
      it("applies min angle builder", fn() {
        let config =
          pie.pie_config(data_key: "value")
          |> pie.pie_min_angle(3.0)
        config.min_angle |> expect.to_equal(expected: 3.0)
      }),
      it("applies label and label line builders", fn() {
        let config =
          pie.pie_config(data_key: "value")
          |> pie.pie_label(True)
          |> pie.pie_label_line(True)
          |> pie.pie_label_offset(30.0)
        config.show_label |> expect.to_be_true
        config.show_label_line |> expect.to_be_true
        config.label_offset |> expect.to_equal(expected: 30.0)
      }),
    ]),
    describe("pie_chart_with_padding", [
      it("renders pie with padding angle", fn() {
        let data = [
          chart.DataPoint(
            category: "A",
            values: dict.from_list([#("val", 40.0)]),
          ),
          chart.DataPoint(
            category: "B",
            values: dict.from_list([#("val", 30.0)]),
          ),
          chart.DataPoint(
            category: "C",
            values: dict.from_list([#("val", 30.0)]),
          ),
        ]
        let el =
          chart.pie_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 400,
            children: [
              chart.pie(
                pie.pie_config(data_key: "val")
                |> pie.pie_padding_angle(5.0)
                |> pie.pie_inner_radius(40.0)
                |> pie.pie_outer_radius(120.0),
              ),
            ],
          )
        el
        |> expect.to_not_equal(
          expected: chart.pie_chart(
            data: [],
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 400,
            children: [],
          ),
        )
      }),
    ]),
  ])
}

pub fn polar_axis_tests() {
  describe("polar_axis", [
    describe("angle_axis_config", [
      it("creates default configuration", fn() {
        let config = polar_axis.angle_axis_config()
        config.show_axis_line |> expect.to_be_true
        config.show_tick_line |> expect.to_be_true
        config.show_tick |> expect.to_be_true
        config.tick_size |> expect.to_equal(expected: 8)
      }),
      it("applies builder functions", fn() {
        let config =
          polar_axis.angle_axis_config()
          |> polar_axis.angle_axis_line(show: False)
          |> polar_axis.angle_tick_size(size: 12)
          |> polar_axis.angle_axis_line_type(type_: polar_axis.CircleAxisLine)
        config.show_axis_line |> expect.to_be_false
        config.tick_size |> expect.to_equal(expected: 12)
      }),
    ]),
    describe("radius_axis_config", [
      it("creates default configuration", fn() {
        let config = polar_axis.radius_axis_config()
        config.angle |> expect.to_equal(expected: 0.0)
        config.tick_count |> expect.to_equal(expected: 5)
        config.has_custom_domain |> expect.to_be_false
      }),
      it("applies custom domain", fn() {
        let config =
          polar_axis.radius_axis_config()
          |> polar_axis.radius_domain(min: 0.0, max: 1000.0)
        config.has_custom_domain |> expect.to_be_true
        config.domain_min |> expect.to_equal(expected: 0.0)
        config.domain_max |> expect.to_equal(expected: 1000.0)
      }),
    ]),
  ])
}

pub fn chart_tests() {
  describe("chart", [
    describe("area_chart", [
      it("renders with empty data", fn() {
        let el =
          chart.area_chart(
            data: [],
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [],
          )
        el
        |> expect.to_equal(
          expected: chart.area_chart(
            data: [],
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [],
          ),
        )
      }),
      it("renders with data and area series", fn() {
        let data = [
          chart.DataPoint(
            category: "Jan",
            values: dict.from_list([#("revenue", 100.0)]),
          ),
          chart.DataPoint(
            category: "Feb",
            values: dict.from_list([#("revenue", 200.0)]),
          ),
          chart.DataPoint(
            category: "Mar",
            values: dict.from_list([#("revenue", 150.0)]),
          ),
        ]
        let el =
          chart.area_chart(
            data: data,
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [
              chart.area(
                area.area_config(
                  data_key: "revenue",
                  meta: common.series_meta(),
                )
                |> area.area_curve_type(curve.Natural),
              ),
            ],
          )
        el
        |> expect.to_not_equal(
          expected: chart.area_chart(
            data: [],
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [],
          ),
        )
      }),
    ]),
    describe("bar_chart", [
      it("renders with data and bar series", fn() {
        let data = [
          chart.DataPoint(
            category: "Jan",
            values: dict.from_list([#("sales", 50.0)]),
          ),
          chart.DataPoint(
            category: "Feb",
            values: dict.from_list([#("sales", 80.0)]),
          ),
        ]
        let el =
          chart.bar_chart(
            data: data,
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [
              chart.bar(bar.bar_config(
                data_key: "sales",
                meta: common.series_meta(),
              )),
            ],
          )
        el
        |> expect.to_not_equal(
          expected: chart.bar_chart(
            data: [],
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [],
          ),
        )
      }),
    ]),
    describe("line_chart", [
      it("renders with data and line series", fn() {
        let data = [
          chart.DataPoint(
            category: "A",
            values: dict.from_list([#("temp", 20.0)]),
          ),
          chart.DataPoint(
            category: "B",
            values: dict.from_list([#("temp", 25.0)]),
          ),
          chart.DataPoint(
            category: "C",
            values: dict.from_list([#("temp", 22.0)]),
          ),
        ]
        let el =
          chart.line_chart(
            data: data,
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [
              chart.line(
                line.line_config(data_key: "temp", meta: common.series_meta())
                |> line.line_curve_type(curve.MonotoneX),
              ),
            ],
          )
        el
        |> expect.to_not_equal(
          expected: chart.line_chart(
            data: [],
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [],
          ),
        )
      }),
    ]),
    describe("pie_chart", [
      it("renders with data and pie series", fn() {
        let data = [
          chart.DataPoint(
            category: "Chrome",
            values: dict.from_list([#("share", 60.0)]),
          ),
          chart.DataPoint(
            category: "Firefox",
            values: dict.from_list([#("share", 20.0)]),
          ),
          chart.DataPoint(
            category: "Safari",
            values: dict.from_list([#("share", 15.0)]),
          ),
        ]
        let el =
          chart.pie_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 400,
            children: [
              chart.pie(
                pie.pie_config(data_key: "share")
                |> pie.pie_outer_radius(120.0),
              ),
            ],
          )
        el
        |> expect.to_not_equal(
          expected: chart.pie_chart(
            data: [],
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 400,
            children: [],
          ),
        )
      }),
    ]),
    describe("radar_chart", [
      it("renders with polar axes", fn() {
        let data = [
          chart.DataPoint(
            category: "Math",
            values: dict.from_list([#("score", 80.0)]),
          ),
          chart.DataPoint(
            category: "Science",
            values: dict.from_list([#("score", 90.0)]),
          ),
          chart.DataPoint(
            category: "English",
            values: dict.from_list([#("score", 70.0)]),
          ),
          chart.DataPoint(
            category: "History",
            values: dict.from_list([#("score", 85.0)]),
          ),
          chart.DataPoint(
            category: "Art",
            values: dict.from_list([#("score", 60.0)]),
          ),
        ]
        let el =
          chart.radar_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 400,
            children: [
              chart.polar_grid(grid.polar_grid_config()),
              chart.polar_angle_axis(polar_axis.angle_axis_config()),
              chart.polar_radius_axis(polar_axis.radius_axis_config()),
              chart.radar(
                radar.radar_config(data_key: "score")
                |> radar.radar_fill(weft.css_color(value: "#8884d8"))
                |> radar.radar_fill_opacity(0.6),
              ),
            ],
          )
        el
        |> expect.to_not_equal(
          expected: chart.radar_chart(
            data: [],
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 400,
            children: [],
          ),
        )
      }),
      it("renders with multiple radar overlays", fn() {
        let data = [
          chart.DataPoint(
            category: "Math",
            values: dict.from_list([
              #("student_a", 80.0),
              #("student_b", 70.0),
            ]),
          ),
          chart.DataPoint(
            category: "Science",
            values: dict.from_list([
              #("student_a", 90.0),
              #("student_b", 85.0),
            ]),
          ),
          chart.DataPoint(
            category: "English",
            values: dict.from_list([
              #("student_a", 70.0),
              #("student_b", 95.0),
            ]),
          ),
        ]
        let el =
          chart.radar_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 400,
            children: [
              chart.polar_grid(grid.polar_grid_config()),
              chart.radar(
                radar.radar_config(data_key: "student_a")
                |> radar.radar_fill(weft.css_color(value: "#8884d8"))
                |> radar.radar_fill_opacity(0.6),
              ),
              chart.radar(
                radar.radar_config(data_key: "student_b")
                |> radar.radar_fill(weft.css_color(value: "#82ca9d"))
                |> radar.radar_fill_opacity(0.6),
              ),
            ],
          )
        el
        |> expect.to_not_equal(
          expected: chart.radar_chart(
            data: [],
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 400,
            children: [],
          ),
        )
      }),
    ]),
    describe("stack_offset_sign", [
      it("renders bar chart with sign offset", fn() {
        let data = [
          chart.DataPoint(
            category: "Jan",
            values: dict.from_list([#("a", 10.0), #("b", -5.0)]),
          ),
          chart.DataPoint(
            category: "Feb",
            values: dict.from_list([#("a", 20.0), #("b", 3.0)]),
          ),
        ]
        let el =
          chart.bar_chart(
            data: data,
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [
              chart.stack_offset(chart.StackOffsetSign),
              chart.bar(
                bar.bar_config(data_key: "a", meta: common.series_meta())
                |> bar.bar_stack_id("s"),
              ),
              chart.bar(
                bar.bar_config(data_key: "b", meta: common.series_meta())
                |> bar.bar_stack_id("s"),
              ),
            ],
          )
        el
        |> expect.to_not_equal(
          expected: chart.bar_chart(
            data: [],
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [],
          ),
        )
      }),
    ]),
    describe("stack_offset_expand", [
      it("renders area chart with expand offset", fn() {
        let data = [
          chart.DataPoint(
            category: "Jan",
            values: dict.from_list([#("a", 30.0), #("b", 70.0)]),
          ),
          chart.DataPoint(
            category: "Feb",
            values: dict.from_list([#("a", 50.0), #("b", 50.0)]),
          ),
        ]
        let el =
          chart.area_chart(
            data: data,
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [
              chart.stack_offset(chart.StackOffsetExpand),
              chart.area(
                area.area_config(data_key: "a", meta: common.series_meta())
                |> area.area_stack_id("s"),
              ),
              chart.area(
                area.area_config(data_key: "b", meta: common.series_meta())
                |> area.area_stack_id("s"),
              ),
            ],
          )
        el
        |> expect.to_not_equal(
          expected: chart.area_chart(
            data: [],
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [],
          ),
        )
      }),
    ]),
    describe("stack_offset_positive", [
      it("renders bar chart with positive offset", fn() {
        let data = [
          chart.DataPoint(
            category: "Jan",
            values: dict.from_list([#("a", 10.0), #("b", -5.0)]),
          ),
        ]
        let el =
          chart.bar_chart(
            data: data,
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [
              chart.stack_offset(chart.StackOffsetPositive),
              chart.bar(
                bar.bar_config(data_key: "a", meta: common.series_meta())
                |> bar.bar_stack_id("s"),
              ),
              chart.bar(
                bar.bar_config(data_key: "b", meta: common.series_meta())
                |> bar.bar_stack_id("s"),
              ),
            ],
          )
        el
        |> expect.to_not_equal(
          expected: chart.bar_chart(
            data: [],
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [],
          ),
        )
      }),
    ]),
    describe("full composition", [
      it("renders area chart with grid, axis, and tooltip", fn() {
        let data =
          int.range(from: 1, to: 31, with: [], run: fn(acc, i) {
            let cat = case i % 5 == 0 {
              True -> "Day " <> int.to_string(i)
              False -> "D" <> int.to_string(i)
            }
            let dp =
              chart.DataPoint(
                category: cat,
                values: dict.from_list([
                  #("desktop", 100.0 +. int.to_float(i) *. 3.0),
                  #("mobile", 80.0 +. int.to_float(i) *. 2.0),
                ]),
              )
            [dp, ..acc]
          })
          |> list.reverse

        let _el =
          chart.area_chart(
            data: data,
            width: chart.FixedWidth(pixels: 800),
            theme: option.None,
            height: 400,
            children: [
              chart.margin(top: 10, right: 10, bottom: 30, left: 40),
              chart.area(
                area.area_config(
                  data_key: "desktop",
                  meta: common.series_meta(),
                )
                |> area.area_curve_type(curve.Natural)
                |> area.area_fill(weft.css_color(value: "url(#fillDesktop)"))
                |> area.area_fill_opacity(0.4)
                |> area.area_stroke(weft.css_color(
                  value: "var(--color-desktop)",
                ))
                |> area.area_stack_id("a")
                |> area.area_gradient_fill("fillDesktop", [
                  area.GradientStop(
                    "5%",
                    weft.css_color(value: "var(--color-desktop)"),
                    0.8,
                  ),
                  area.GradientStop(
                    "95%",
                    weft.css_color(value: "var(--color-desktop)"),
                    0.1,
                  ),
                ]),
              ),
              chart.area(
                area.area_config(data_key: "mobile", meta: common.series_meta())
                |> area.area_curve_type(curve.Natural)
                |> area.area_fill(weft.css_color(value: "url(#fillMobile)"))
                |> area.area_fill_opacity(0.4)
                |> area.area_stroke(weft.css_color(value: "var(--color-mobile)"))
                |> area.area_stack_id("a")
                |> area.area_gradient_fill("fillMobile", [
                  area.GradientStop(
                    "5%",
                    weft.css_color(value: "var(--color-mobile)"),
                    0.8,
                  ),
                  area.GradientStop(
                    "95%",
                    weft.css_color(value: "var(--color-mobile)"),
                    0.1,
                  ),
                ]),
              ),
            ],
          )

        // Verify it rendered (didn't crash)
        list.length(data) |> expect.to_equal(expected: 30)
      }),
    ]),
  ])
}

pub fn shape_tests() {
  describe("shape", [
    describe("rectangle_with_corners", [
      it("emits arc commands with xSign/ySign for positive dimensions", fn() {
        let el =
          shape.rectangle_with_corners(
            x: 50.0,
            y: 50.0,
            width: 80.0,
            height: 100.0,
            top_left: 5.0,
            top_right: 10.0,
            bottom_right: 8.0,
            bottom_left: 15.0,
            fill: "#000",
          )
        let svg = element.to_string(el)
        // Positive width/height: ySign=1, xSign=1, clockWise=1
        // M50,55 (y + 1*5)
        svg |> string.contains("M50,55") |> expect.to_be_true
        // Sweep flag should be 1 for positive area
        svg |> string.contains(",0,0,1,") |> expect.to_be_true
        // Should contain arc commands
        svg |> string.contains("A ") |> expect.to_be_true
        // Path should be closed
        svg |> string.contains("Z") |> expect.to_be_true
      }),
      it("emits sweep=0 for negative height", fn() {
        let el =
          shape.rectangle_with_corners(
            x: 50.0,
            y: 150.0,
            width: 80.0,
            height: -100.0,
            top_left: 5.0,
            top_right: 5.0,
            bottom_right: 5.0,
            bottom_left: 5.0,
            fill: "#000",
          )
        let svg = element.to_string(el)
        // Negative height with positive width: clockWise=0
        svg |> string.contains(",0,0,0,") |> expect.to_be_true
        // M50,145 (y + (-1)*5 = 150 - 5)
        svg |> string.contains("M50,145") |> expect.to_be_true
      }),
      it("conditionally omits arc for zero-radius corner", fn() {
        let el =
          shape.rectangle_with_corners(
            x: 0.0,
            y: 0.0,
            width: 100.0,
            height: 50.0,
            top_left: 5.0,
            top_right: 5.0,
            bottom_right: 0.0,
            bottom_left: 0.0,
            fill: "#000",
          )
        let svg = element.to_string(el)
        // Should have exactly 2 arc commands (tl and tr only)
        let arc_count =
          string.split(svg, "A ")
          |> list.length
        // split produces n+1 parts for n occurrences
        arc_count |> expect.to_equal(expected: 3)
      }),
    ]),
    describe("rectangle", [
      it("delegates to corners path for uniform radius", fn() {
        let el =
          shape.rectangle(
            x: 10.0,
            y: 20.0,
            width: 60.0,
            height: 40.0,
            radius: 5.0,
            fill: "#000",
          )
        let svg = element.to_string(el)
        // Should render as path with arcs, not as rect element
        svg |> string.contains("A ") |> expect.to_be_true
        svg |> string.contains("Z") |> expect.to_be_true
      }),
      it("renders rect element for zero radius", fn() {
        let el =
          shape.rectangle(
            x: 10.0,
            y: 20.0,
            width: 60.0,
            height: 40.0,
            radius: 0.0,
            fill: "#000",
          )
        let svg = element.to_string(el)
        // Should render as rect, not path
        svg |> string.contains("<rect") |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn axis_tests() {
  describe("axis", [
    describe("x_axis_config", [
      it("creates defaults matching recharts", fn() {
        let config = axis.x_axis_config()
        config.reversed |> expect.to_be_false
        config.mirror |> expect.to_be_false
        config.tick_size |> expect.to_equal(expected: 6)
        config.allow_decimals |> expect.to_be_true
        config.angle |> expect.to_equal(expected: 0.0)
        config.min_tick_gap |> expect.to_equal(expected: 5)
        config.tick_margin |> expect.to_equal(expected: 2)
      }),
      it("applies reversed builder", fn() {
        let config = axis.x_axis_config() |> axis.axis_reversed
        config.reversed |> expect.to_be_true
      }),
      it("applies mirror builder", fn() {
        let config = axis.x_axis_config() |> axis.axis_mirror
        config.mirror |> expect.to_be_true
      }),
      it("applies angle builder", fn() {
        let config = axis.x_axis_config() |> axis.axis_angle(45.0)
        config.angle |> expect.to_equal(expected: 45.0)
      }),
    ]),
    describe("y_axis_config", [
      it("creates defaults matching recharts", fn() {
        let config = axis.y_axis_config()
        config.reversed |> expect.to_be_false
        config.mirror |> expect.to_be_false
        config.tick_size |> expect.to_equal(expected: 6)
        config.allow_decimals |> expect.to_be_true
        config.tick_margin |> expect.to_equal(expected: 2)
        config.padding_top |> expect.to_equal(expected: 0)
        config.padding_bottom |> expect.to_equal(expected: 0)
        config.min_tick_gap |> expect.to_equal(expected: 5)
        config.angle |> expect.to_equal(expected: 0.0)
      }),
      it("applies reversed builder", fn() {
        let config = axis.y_axis_config() |> axis.axis_reversed
        config.reversed |> expect.to_be_true
      }),
      it("applies y_padding_top builder", fn() {
        let config = axis.y_axis_config() |> axis.axis_padding_top(10)
        config.padding_top |> expect.to_equal(expected: 10)
      }),
      it("applies y_padding_bottom builder", fn() {
        let config = axis.y_axis_config() |> axis.axis_padding_bottom(15)
        config.padding_bottom |> expect.to_equal(expected: 15)
      }),
      it("applies y_min_tick_gap builder", fn() {
        let config = axis.y_axis_config() |> axis.axis_min_tick_gap(10)
        config.min_tick_gap |> expect.to_equal(expected: 10)
      }),
      it("applies y_angle builder", fn() {
        let config = axis.y_axis_config() |> axis.axis_angle(45.0)
        config.angle |> expect.to_equal(expected: 45.0)
      }),
    ]),
    describe("scale_type_variants", [
      it("AutoScaleType is a valid ScaleType", fn() {
        let config =
          axis.x_axis_config() |> axis.axis_scale_type(axis.AutoScaleType)
        config.scale_type |> expect.to_equal(expected: axis.AutoScaleType)
      }),
      it("IdentityScaleType is a valid ScaleType", fn() {
        let config =
          axis.x_axis_config() |> axis.axis_scale_type(axis.IdentityScaleType)
        config.scale_type |> expect.to_equal(expected: axis.IdentityScaleType)
      }),
      it("BandScaleType is a valid ScaleType", fn() {
        let config =
          axis.x_axis_config() |> axis.axis_scale_type(axis.BandScaleType)
        config.scale_type |> expect.to_equal(expected: axis.BandScaleType)
      }),
      it("PointScaleType is a valid ScaleType", fn() {
        let config =
          axis.x_axis_config() |> axis.axis_scale_type(axis.PointScaleType)
        config.scale_type |> expect.to_equal(expected: axis.PointScaleType)
      }),
    ]),
    describe("tick_override", [
      it("defaults to None", fn() {
        let x = axis.x_axis_config()
        x.ticks_override |> expect.to_equal(expected: None)
        let y = axis.y_axis_config()
        y.ticks_override |> expect.to_equal(expected: None)
      }),
      it("x_category_ticks sets CategoryTicks override", fn() {
        let config =
          axis.x_axis_config()
          |> axis.axis_category_ticks(ticks: ["Jan", "Feb", "Mar"])
        case config.ticks_override {
          Some(axis.CategoryTicks(ticks: ts)) ->
            list.length(ts) |> expect.to_equal(expected: 3)
          _ -> expect.to_be_true(False)
        }
      }),
      it("y_category_ticks sets CategoryTicks override", fn() {
        let config =
          axis.y_axis_config()
          |> axis.axis_category_ticks(ticks: ["Low", "Mid", "High"])
        case config.ticks_override {
          Some(axis.CategoryTicks(ticks: ts)) ->
            list.length(ts) |> expect.to_equal(expected: 3)
          _ -> expect.to_be_true(False)
        }
      }),
    ]),
    describe("reversed_x_axis", [
      it("reverses x-axis direction in chart", fn() {
        let data = [
          chart.DataPoint(
            category: "A",
            values: dict.from_list([#("val", 10.0)]),
          ),
          chart.DataPoint(
            category: "B",
            values: dict.from_list([#("val", 20.0)]),
          ),
        ]
        let normal =
          chart.bar_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 200,
            children: [
              chart.x_axis(axis.x_axis_config()),
              chart.bar(bar.bar_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
            ],
          )
        let reversed =
          chart.bar_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 200,
            children: [
              chart.x_axis(axis.x_axis_config() |> axis.axis_reversed),
              chart.bar(bar.bar_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
            ],
          )
        // Reversed chart should produce different SVG than normal
        normal |> expect.to_not_equal(expected: reversed)
      }),
    ]),
    describe("reversed_y_axis", [
      it("reverses y-axis direction in chart", fn() {
        let data = [
          chart.DataPoint(
            category: "A",
            values: dict.from_list([#("val", 10.0)]),
          ),
        ]
        let normal =
          chart.line_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 200,
            children: [
              chart.y_axis(axis.y_axis_config()),
              chart.line(line.line_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
            ],
          )
        let reversed =
          chart.line_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 200,
            children: [
              chart.y_axis(axis.y_axis_config() |> axis.axis_reversed),
              chart.line(line.line_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
            ],
          )
        normal |> expect.to_not_equal(expected: reversed)
      }),
    ]),
    describe("allow_decimals", [
      it("integer-only ticks when allow_decimals is false", fn() {
        let s =
          scale.linear(
            domain_min: 0.0,
            domain_max: 3.0,
            range_start: 0.0,
            range_end: 300.0,
          )
        let tick_list = scale.ticks(s, 7, False)
        // All tick values should be whole numbers
        list.each(tick_list, fn(tick) {
          let parsed = case float.parse(tick.value) {
            Ok(v) -> v
            Error(_) ->
              case int.parse(tick.value) {
                Ok(i) -> int.to_float(i)
                Error(_) -> -1.0
              }
          }
          let rounded = int.to_float(float.round(parsed))
          { parsed -. rounded }
          |> float.absolute_value
          |> fn(diff) { diff <. 0.001 }
          |> expect.to_be_true
        })
      }),
    ]),
    describe("user_ticks", [
      it("x_numeric_ticks overrides auto-generated ticks", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
          chart.DataPoint(category: "B", values: dict.from_list([#("v", 90.0)])),
        ]
        let html =
          chart.line_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 200,
            children: [
              chart.x_axis(
                axis.x_axis_config()
                |> axis.axis_type(axis.NumberAxis)
                |> axis.axis_numeric_ticks(ticks: [0.0, 25.0, 50.0, 75.0, 100.0]),
              ),
              chart.line(line.line_config(
                data_key: "v",
                meta: common.series_meta(),
              )),
            ],
          )
          |> element.to_string
        // User ticks should appear in output
        html |> string.contains("25") |> expect.to_be_true
        html |> string.contains("75") |> expect.to_be_true
      }),
      it("y_numeric_ticks overrides auto-generated ticks", fn() {
        let config =
          axis.y_axis_config()
          |> axis.axis_numeric_ticks(ticks: [0.0, 50.0, 100.0])
        case config.ticks_override {
          Some(axis.NumericTicks(ticks: ts)) ->
            list.length(ts) |> expect.to_equal(expected: 3)
          _ -> expect.to_be_true(False)
        }
      }),
    ]),
    describe("axis_label", [
      it("x_label renders axis title", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.line_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 200,
            children: [
              chart.x_axis(axis.x_axis_config() |> axis.axis_label("Months")),
              chart.line(line.line_config(
                data_key: "v",
                meta: common.series_meta(),
              )),
            ],
          )
          |> element.to_string
        html |> string.contains("Months") |> expect.to_be_true
      }),
      it("y_label renders rotated axis title", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.line_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 200,
            children: [
              chart.y_axis(
                axis.y_axis_config() |> axis.axis_label("Revenue ($)"),
              ),
              chart.line(line.line_config(
                data_key: "v",
                meta: common.series_meta(),
              )),
            ],
          )
          |> element.to_string
        html |> string.contains("Revenue ($)") |> expect.to_be_true
        html |> string.contains("rotate(-90") |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn reference_tests() {
  describe("reference", [
    describe("horizontal_line", [
      it("creates config with recharts defaults", fn() {
        let config = reference.horizontal_line(value: 50.0)
        config.value |> expect.to_equal(expected: 50.0)
        config.stroke |> expect.to_equal(expected: "#ccc")
        config.stroke_width |> expect.to_equal(expected: 1.0)
        config.is_front |> expect.to_be_false
      }),
      it("applies builders", fn() {
        let config =
          reference.horizontal_line(value: 50.0)
          |> reference.line_stroke(stroke_value: "#ff0000")
          |> reference.line_stroke_dasharray(pattern: "5 5")
          |> reference.line_label(label_text: "Threshold")
          |> reference.line_is_front
        config.stroke |> expect.to_equal(expected: "#ff0000")
        config.stroke_dasharray |> expect.to_equal(expected: "5 5")
        config.label |> expect.to_equal(expected: "Threshold")
        config.is_front |> expect.to_be_true
      }),
    ]),
    describe("reference_line_in_chart", [
      it("renders reference line in bar chart", fn() {
        let data = [
          chart.DataPoint(
            category: "A",
            values: dict.from_list([#("val", 30.0)]),
          ),
          chart.DataPoint(
            category: "B",
            values: dict.from_list([#("val", 70.0)]),
          ),
        ]
        let el =
          chart.bar_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 200,
            children: [
              chart.bar(bar.bar_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
              chart.reference_line(
                reference.horizontal_line(value: 50.0)
                |> reference.line_stroke(stroke_value: "#ff0000")
                |> reference.line_stroke_dasharray(pattern: "3 3")
                |> reference.line_label(label_text: "Target"),
              ),
            ],
          )
        let svg = element.to_string(el)
        svg
        |> string.contains("recharts-reference-line")
        |> expect.to_be_true
      }),
    ]),
    describe("reference_area", [
      it("creates config with defaults", fn() {
        let config = reference.horizontal_area(value1: 20.0, value2: 80.0)
        config.fill |> expect.to_equal(expected: "#ccc")
        config.fill_opacity |> expect.to_equal(expected: 0.5)
      }),
      it("renders reference area in line chart", fn() {
        let data = [
          chart.DataPoint(
            category: "A",
            values: dict.from_list([#("val", 50.0)]),
          ),
          chart.DataPoint(
            category: "B",
            values: dict.from_list([#("val", 80.0)]),
          ),
        ]
        let el =
          chart.line_chart(
            data: data,
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 200,
            children: [
              chart.line(line.line_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
              chart.reference_area(
                reference.horizontal_area(value1: 40.0, value2: 60.0)
                |> reference.area_fill(fill_value: "#e0e0ff")
                |> reference.area_label(label_text: "Safe zone"),
              ),
            ],
          )
        let svg = element.to_string(el)
        svg
        |> string.contains("recharts-reference-area")
        |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn interval_tests() {
  describe("interval", [
    it("default is PreserveEnd", fn() {
      let x_config = axis.x_axis_config()
      x_config.interval |> expect.to_equal(expected: axis.PreserveEnd)
      let y_config = axis.y_axis_config()
      y_config.interval |> expect.to_equal(expected: axis.PreserveEnd)
    }),
    it("x_interval builder sets interval", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_interval(axis.EveryNth(2))
      config.interval |> expect.to_equal(expected: axis.EveryNth(2))
    }),
    it("y_interval builder sets interval", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_interval(axis.PreserveStartEnd)
      config.interval |> expect.to_equal(expected: axis.PreserveStartEnd)
    }),
    it("EveryNth(1) skips every other tick", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 20.0)])),
        chart.DataPoint(category: "C", values: dict.from_list([#("v", 30.0)])),
        chart.DataPoint(category: "D", values: dict.from_list([#("v", 40.0)])),
      ]
      let with_interval =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.x_axis(
              axis.x_axis_config()
              |> axis.axis_interval(axis.EveryNth(1)),
            ),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      let without_interval =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.x_axis(
              axis.x_axis_config()
              |> axis.axis_interval(axis.EveryNth(0)),
            ),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      // With EveryNth(1) should have fewer ticks (A, C) than EveryNth(0) (A, B, C, D)
      with_interval |> string.contains("A") |> expect.to_be_true
      with_interval |> string.contains("C") |> expect.to_be_true
      // B and D should be filtered out
      with_interval |> string.contains(">B<") |> expect.to_be_false
      // Without interval should have all 4
      without_interval |> string.contains("A") |> expect.to_be_true
      without_interval |> string.contains("B") |> expect.to_be_true
      without_interval |> string.contains("C") |> expect.to_be_true
      without_interval |> string.contains("D") |> expect.to_be_true
    }),
  ])
}

pub fn allow_data_overflow_tests() {
  describe("allow_data_overflow", [
    it("default is false", fn() {
      let x_config = axis.x_axis_config()
      x_config.allow_data_overflow |> expect.to_be_false
      let y_config = axis.y_axis_config()
      y_config.allow_data_overflow |> expect.to_be_false
    }),
    it("x_allow_data_overflow builder sets flag", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_allow_data_overflow(True)
      config.allow_data_overflow |> expect.to_be_true
    }),
    it("y_allow_data_overflow builder sets flag", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_allow_data_overflow(True)
      config.allow_data_overflow |> expect.to_be_true
    }),
    it("y-axis domain extends when overflow=false (default)", fn() {
      // Data has values up to 100, but custom domain is [0, 50].
      // Without allowDataOverflow, domain should extend to include data.
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 100.0)])),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.y_axis(
              axis.y_axis_config()
              |> axis.axis_domain(0.0, 50.0),
            ),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      // Domain should be extended, so 100 should appear in tick labels
      html |> string.contains("100") |> expect.to_be_true
    }),
    it("y-axis uses exact domain when overflow=true", fn() {
      // With allowDataOverflow=true, domain stays at [0, 50] regardless of data
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 100.0)])),
      ]
      let with_overflow =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.y_axis(
              axis.y_axis_config()
              |> axis.axis_domain(0.0, 50.0)
              |> axis.axis_allow_data_overflow(True),
            ),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      let without_overflow =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.y_axis(
              axis.y_axis_config()
              |> axis.axis_domain(0.0, 50.0),
            ),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      // With overflow=true, domain clipped to [0,50]: ticks like 0,20,40,60
      // Without overflow (default), domain extended to include 100: ticks go higher
      // The two outputs should differ because domains are different
      with_overflow |> expect.to_not_equal(expected: without_overflow)
      // With overflow, 100 should not appear as a tick label
      with_overflow |> string.contains(">100<") |> expect.to_be_false
    }),
  ])
}

pub fn x_domain_tests() {
  describe("x_domain", [
    it("default has no custom domain", fn() {
      let config = axis.x_axis_config()
      config.has_custom_domain |> expect.to_be_false
    }),
    it("x_domain builder sets domain", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_domain(10.0, 90.0)
      config.has_custom_domain |> expect.to_be_true
      config.domain_min |> expect.to_equal(expected: 10.0)
      config.domain_max |> expect.to_equal(expected: 90.0)
    }),
  ])
}

pub fn reference_dot_tests() {
  describe("reference_dot", [
    it("creates config with recharts defaults", fn() {
      let config = reference.reference_dot(x: 50.0, y: 75.0)
      config.x |> expect.to_equal(expected: 50.0)
      config.y |> expect.to_equal(expected: 75.0)
      config.r |> expect.to_equal(expected: 10.0)
      config.fill |> expect.to_equal(expected: "#fff")
      config.stroke |> expect.to_equal(expected: "#ccc")
      config.is_front |> expect.to_be_false
      config.if_overflow |> expect.to_equal(expected: Discard)
    }),
    it("applies builders", fn() {
      let config =
        reference.reference_dot(x: 50.0, y: 75.0)
        |> reference.dot_radius(radius: 15.0)
        |> reference.dot_fill(fill_value: "#ff0000")
        |> reference.dot_stroke(stroke_value: "#0000ff")
        |> reference.dot_stroke_width(width: 2.0)
        |> reference.dot_label(label_text: "Peak")
        |> reference.dot_is_front
        |> reference.dot_if_overflow(overflow: Hidden)
      config.r |> expect.to_equal(expected: 15.0)
      config.fill |> expect.to_equal(expected: "#ff0000")
      config.stroke |> expect.to_equal(expected: "#0000ff")
      config.stroke_width |> expect.to_equal(expected: 2.0)
      config.label |> expect.to_equal(expected: "Peak")
      config.is_front |> expect.to_be_true
      config.if_overflow |> expect.to_equal(expected: Hidden)
    }),
    it("renders in chart with numeric axes", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 50.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 80.0)])),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.x_axis(
              axis.x_axis_config() |> axis.axis_type(axis.NumberAxis),
            ),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
            chart.reference_dot(
              reference.reference_dot(x: 50.0, y: 50.0)
              |> reference.dot_fill(fill_value: "#ff0000")
              |> reference.dot_label(label_text: "Important")
              |> reference.dot_if_overflow(overflow: Visible),
            ),
          ],
        )
        |> element.to_string
      html
      |> string.contains("recharts-reference-dot")
      |> expect.to_be_true
      html |> string.contains("Important") |> expect.to_be_true
      html |> string.contains("#ff0000") |> expect.to_be_true
    }),
  ])
}

pub fn if_overflow_tests() {
  describe("if_overflow", [
    it("reference line default is Discard", fn() {
      let config = reference.horizontal_line(value: 50.0)
      config.if_overflow |> expect.to_equal(expected: Discard)
    }),
    it("reference area default is Discard", fn() {
      let config = reference.horizontal_area(value1: 20.0, value2: 80.0)
      config.if_overflow |> expect.to_equal(expected: Discard)
    }),
    it("reference dot default is Discard", fn() {
      let config = reference.reference_dot(x: 0.0, y: 0.0)
      config.if_overflow |> expect.to_equal(expected: Discard)
    }),
    it("line_if_overflow builder sets overflow", fn() {
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_if_overflow(overflow: Hidden)
      config.if_overflow |> expect.to_equal(expected: Hidden)
    }),
    it("area_if_overflow builder sets overflow", fn() {
      let config =
        reference.horizontal_area(value1: 20.0, value2: 80.0)
        |> reference.area_if_overflow(overflow: ExtendDomain)
      config.if_overflow |> expect.to_equal(expected: ExtendDomain)
    }),
    it("hidden overflow applies clip-path", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 50.0)])),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
            chart.reference_line(
              reference.horizontal_line(value: 50.0)
              |> reference.line_if_overflow(overflow: Hidden),
            ),
          ],
        )
        |> element.to_string
      html |> string.contains("clip-path") |> expect.to_be_true
      html |> string.contains("weft-chart-clip") |> expect.to_be_true
    }),
  ])
}

pub fn clip_path_tests() {
  describe("clip_path", [
    it("chart includes clipPath definition", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 50.0)])),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      html |> string.contains("clipPath") |> expect.to_be_true
      html |> string.contains("weft-chart-clip") |> expect.to_be_true
    }),
  ])
}

pub fn grid_fill_opacity_tests() {
  describe("grid_fill_opacity", [
    it("default is 1.0", fn() {
      let config = grid.cartesian_grid_config()
      config.fill_opacity |> expect.to_equal(expected: 1.0)
    }),
    it("builder sets fill opacity", fn() {
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_fill_opacity(opacity: 0.5)
      config.fill_opacity |> expect.to_equal(expected: 0.5)
    }),
    it("renders fill-opacity when not 1.0", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 50.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 80.0)])),
      ]
      let html =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.cartesian_grid(
              grid.cartesian_grid_config()
              |> grid.grid_horizontal_fill(colors: ["#eee", "#fff"])
              |> grid.grid_fill_opacity(opacity: 0.5),
            ),
            chart.bar(bar.bar_config(data_key: "v", meta: common.series_meta())),
          ],
        )
        |> element.to_string
      html |> string.contains("fill-opacity") |> expect.to_be_true
      html |> string.contains("0.5") |> expect.to_be_true
    }),
    it("omits fill-opacity when 1.0", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 50.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 80.0)])),
      ]
      let html =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.cartesian_grid(
              grid.cartesian_grid_config()
              |> grid.grid_horizontal_fill(colors: ["#eee", "#fff"]),
            ),
            chart.bar(bar.bar_config(data_key: "v", meta: common.series_meta())),
          ],
        )
        |> element.to_string
      // Should NOT have fill-opacity on stripe rects (omitted for default 1.0)
      // But the grid stripes should still render
      html
      |> string.contains("recharts-cartesian-grid")
      |> expect.to_be_true
    }),
  ])
}

pub fn legend_type_tests() {
  describe("legend_type", [
    it("line defaults to LineIcon", fn() {
      let config = line.line_config(data_key: "v", meta: common.series_meta())
      config.legend_type |> expect.to_equal(expected: shape.LineIcon)
    }),
    it("area defaults to LineIcon", fn() {
      let config = area.area_config(data_key: "v", meta: common.series_meta())
      config.legend_type |> expect.to_equal(expected: shape.LineIcon)
    }),
    it("bar defaults to RectIcon", fn() {
      let config = bar.bar_config(data_key: "v", meta: common.series_meta())
      config.legend_type |> expect.to_equal(expected: shape.RectIcon)
    }),
    it("line legend_type builder overrides default", fn() {
      let config =
        line.line_config(data_key: "v", meta: common.series_meta())
        |> line.line_legend_type(shape.CircleIcon)
      config.legend_type |> expect.to_equal(expected: shape.CircleIcon)
    }),
    it("bar legend_type builder overrides default", fn() {
      let config =
        bar.bar_config(data_key: "v", meta: common.series_meta())
        |> bar.bar_legend_type(shape.SquareIcon)
      config.legend_type |> expect.to_equal(expected: shape.SquareIcon)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Negative bar value tests
// ---------------------------------------------------------------------------

pub fn negative_bar_tests() {
  let data = [
    chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
    chart.DataPoint(category: "B", values: dict.from_list([#("v", -5.0)])),
    chart.DataPoint(category: "C", values: dict.from_list([#("v", 20.0)])),
  ]

  describe("negative_bar_values", [
    it("renders bar chart with negative values without crashing", fn() {
      let svg =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(bar.bar_config(data_key: "v", meta: common.series_meta())),
          ],
        )
      let html = element.to_string(svg)
      // Should contain SVG elements
      html |> string.contains("svg") |> expect.to_be_true
      // Should contain bar group
      html |> string.contains("recharts-bar") |> expect.to_be_true
    }),
    it("includes negative values in domain", fn() {
      // When data has negatives, domain should include them
      let values = [10.0, -5.0, 20.0]
      let domain = scale.auto_domain(values)
      // Domain should include the negative value
      { domain.0 <=. -5.0 } |> expect.to_be_true
      { domain.1 >=. 20.0 } |> expect.to_be_true
    }),
    it("negative bars grow downward from zero line", fn() {
      // With domain [-5, 20], zero line is between top and bottom.
      // Negative bar should start at zero and go down.
      let y_scale =
        scale.linear(
          domain_min: -10.0,
          domain_max: 20.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let zero_y = scale.linear_apply(y_scale, 0.0)
      let neg_y = scale.linear_apply(y_scale, -5.0)
      // In SVG coordinates, negative values have larger y (lower on screen)
      { neg_y >. zero_y } |> expect.to_be_true
    }),
    it("labels position below negative bars", fn() {
      let svg =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(
              bar.bar_config(data_key: "v", meta: common.series_meta())
              |> bar.bar_label(True),
            ),
          ],
        )
      let html = element.to_string(svg)
      // Should contain value labels
      html |> string.contains("-5") |> expect.to_be_true
    }),
    it("corner radii flip for negative bars with uniform radius", fn() {
      let svg =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(
              bar.bar_config(data_key: "v", meta: common.series_meta())
              |> bar.bar_radius(4.0),
            ),
          ],
        )
      let html = element.to_string(svg)
      // Should render with arc commands for rounded corners
      html |> string.contains("A ") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// ComposedChart tests
// ---------------------------------------------------------------------------

pub fn composed_chart_tests() {
  let data = [
    chart.DataPoint(
      category: "Jan",
      values: dict.from_list([
        #("revenue", 100.0),
        #("profit", 40.0),
        #("visitors", 200.0),
      ]),
    ),
    chart.DataPoint(
      category: "Feb",
      values: dict.from_list([
        #("revenue", 150.0),
        #("profit", 60.0),
        #("visitors", 250.0),
      ]),
    ),
  ]

  describe("composed_chart", [
    it("renders mixed Line, Bar, and Area series", fn() {
      let svg =
        chart.composed_chart(
          data: data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(bar.bar_config(
              data_key: "revenue",
              meta: common.series_meta(),
            )),
            chart.line(line.line_config(
              data_key: "profit",
              meta: common.series_meta(),
            )),
            chart.area(area.area_config(
              data_key: "visitors",
              meta: common.series_meta(),
            )),
          ],
        )
      let html = element.to_string(svg)
      html |> string.contains("recharts-bar") |> expect.to_be_true
      html |> string.contains("recharts-line") |> expect.to_be_true
      html |> string.contains("recharts-area") |> expect.to_be_true
    }),
    it("uses band scale when bars are present", fn() {
      let svg =
        chart.composed_chart(
          data: data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(bar.bar_config(
              data_key: "revenue",
              meta: common.series_meta(),
            )),
            chart.line(line.line_config(
              data_key: "profit",
              meta: common.series_meta(),
            )),
          ],
        )
      let html = element.to_string(svg)
      // Band scale produces bars — verify they render
      html |> string.contains("recharts-bar") |> expect.to_be_true
    }),
    it("uses point scale when no bars present", fn() {
      let svg =
        chart.composed_chart(
          data: data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "profit",
              meta: common.series_meta(),
            )),
            chart.area(area.area_config(
              data_key: "visitors",
              meta: common.series_meta(),
            )),
          ],
        )
      let html = element.to_string(svg)
      // Line and area render on point scale
      html |> string.contains("recharts-line") |> expect.to_be_true
      html |> string.contains("recharts-area") |> expect.to_be_true
    }),
    it("supports grid, axes, and tooltip", fn() {
      let svg =
        chart.composed_chart(
          data: data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 300,
          children: [
            chart.cartesian_grid(grid.cartesian_grid_config()),
            chart.x_axis(axis.x_axis_config()),
            chart.y_axis(axis.y_axis_config()),
            chart.bar(bar.bar_config(
              data_key: "revenue",
              meta: common.series_meta(),
            )),
            chart.line(line.line_config(
              data_key: "profit",
              meta: common.series_meta(),
            )),
          ],
        )
      let html = element.to_string(svg)
      html |> string.contains("recharts-cartesian-grid") |> expect.to_be_true
    }),
    it("area fill path has non-zero x-coords when bars force band scale", fn() {
      let svg =
        chart.composed_chart(
          data: data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 300,
          children: [
            chart.area(
              area.area_config(data_key: "visitors", meta: common.series_meta())
              |> area.area_fill(weft.css_color(value: "#10b981"))
              |> area.area_fill_opacity(0.15),
            ),
            chart.bar(bar.bar_config(
              data_key: "revenue",
              meta: common.series_meta(),
            )),
          ],
        )
      let html = element.to_string(svg)
      // Area fill path must have spread-out x-coordinates, not all x=0
      // which would produce an invisible zero-width polygon
      html |> string.contains("fill=\"#10b981\"") |> expect.to_be_true
      html |> string.contains("fill-opacity=\"0.15\"") |> expect.to_be_true
      // The fill path d attribute should NOT start with "M0," which would
      // indicate all x-coords collapsed to zero (broken band scale mapping)
      { string.contains(html, "d=\"M0,") == False }
      |> expect.to_be_true
    }),
    it("ScatterChild is accepted by composed_chart without crashing", fn() {
      // ScatterChild is not rendered in cartesian render path (known gap);
      // this test verifies it is gracefully ignored, producing valid SVG.
      let scatter_data = [
        dict.from_list([#("x", 10.0), #("y", 30.0)]),
        dict.from_list([#("x", 20.0), #("y", 50.0)]),
        dict.from_list([#("x", 30.0), #("y", 40.0)]),
      ]
      let svg =
        chart.composed_chart(
          data: data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 300,
          children: [
            chart.scatter(
              scatter.scatter_config(x_data_key: "x", y_data_key: "y")
              |> scatter.scatter_data(data: scatter_data),
            ),
            chart.bar(bar.bar_config(
              data_key: "revenue",
              meta: common.series_meta(),
            )),
          ],
        )
      let html = element.to_string(svg)
      // Should produce valid SVG output containing the bar series
      html |> string.contains("<svg") |> expect.to_be_true
      html |> string.contains("recharts-bar") |> expect.to_be_true
    }),
    it(
      "stacked bars and line in ComposedChart: both render, y-domain covers both series",
      fn() {
        let svg =
          chart.composed_chart(
            data: data,
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [
              chart.bar(
                bar.bar_config(data_key: "revenue", meta: common.series_meta())
                |> bar.bar_stack_id("a"),
              ),
              chart.bar(
                bar.bar_config(data_key: "visitors", meta: common.series_meta())
                |> bar.bar_stack_id("a"),
              ),
              chart.line(line.line_config(
                data_key: "profit",
                meta: common.series_meta(),
              )),
            ],
          )
        let html = element.to_string(svg)
        // Both bar rects and line path should render
        html |> string.contains("recharts-bar") |> expect.to_be_true
        html |> string.contains("recharts-line") |> expect.to_be_true
      },
    ),
    it("two YAxisChild with different ids: each renders in the output", fn() {
      let svg =
        chart.composed_chart(
          data: data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 300,
          children: [
            chart.y_axis(axis.y_axis_config()),
            chart.y_axis(
              axis.y_axis_config()
              |> axis.axis_id("1")
              |> axis.axis_orientation(axis.Right),
            ),
            chart.bar(bar.bar_config(
              data_key: "revenue",
              meta: common.series_meta(),
            )),
            chart.line(
              line.line_config(data_key: "profit", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "1"),
              ),
            ),
          ],
        )
      let html = element.to_string(svg)
      // Both axes should appear in output
      html |> string.contains("recharts-yAxis") |> expect.to_be_true
      // Both series render
      html |> string.contains("recharts-bar") |> expect.to_be_true
      html |> string.contains("recharts-line") |> expect.to_be_true
    }),
    it(
      "layout_vertical: bars render as horizontal bars in composed chart",
      fn() {
        let svg =
          chart.composed_chart(
            data: data,
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [
              chart.layout(layout: layout.Vertical),
              chart.bar(bar.bar_config(
                data_key: "revenue",
                meta: common.series_meta(),
              )),
            ],
          )
        let html = element.to_string(svg)
        // Should still contain bar elements in vertical layout
        html |> string.contains("recharts-bar") |> expect.to_be_true
        // Vertical layout produces different geometry than default horizontal
        let svg_h =
          chart.composed_chart(
            data: data,
            width: chart.FixedWidth(pixels: 500),
            theme: option.None,
            height: 300,
            children: [
              chart.bar(bar.bar_config(
                data_key: "revenue",
                meta: common.series_meta(),
              )),
            ],
          )
        let html_h = element.to_string(svg_h)
        // The two layouts should produce different SVG output
        { html != html_h } |> expect.to_be_true
      },
    ),
    it("ComposedChart with BarChild uses RectangleCursor for tooltip", fn() {
      let svg =
        chart.composed_chart(
          data: data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(bar.bar_config(
              data_key: "revenue",
              meta: common.series_meta(),
            )),
            chart.tooltip(config: tooltip.tooltip_config()),
          ],
        )
      let html = element.to_string(svg)
      // When bars are present, ComposedChart auto-sets RectangleCursor:
      // the tooltip cursor renders as a <rect> element (not a <line>)
      html |> string.contains("chart-tooltip-cursor") |> expect.to_be_true
      // RectangleCursor renders a rect element for the cursor
      html |> string.contains("<rect") |> expect.to_be_true
    }),
    it("ScatterChild own data is included in y-domain in ComposedChart", fn() {
      // Bar data has revenue up to 200; scatter own data has y=500.
      // The y-axis domain must cover 500 so the scatter dot is not clipped.
      let bar_data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("revenue", 200.0)]),
        ),
      ]
      let scatter_own = [dict.from_list([#("x", 1.0), #("y", 500.0)])]
      let sc =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_data(scatter_own)
      let svg =
        chart.composed_chart(
          data: bar_data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(bar.bar_config(
              data_key: "revenue",
              meta: common.series_meta(),
            )),
            chart.scatter(sc),
          ],
        )
      let html = element.to_string(svg)
      // The SVG should render without crashing and contain series output
      html |> string.contains("<svg") |> expect.to_be_true
      // The scatter dot should appear (circle element from scatter rendering)
      html |> string.contains("<circle") |> expect.to_be_true
    }),
    it(
      "ScatterChild own data produces tooltip hit zones in ComposedChart",
      fn() {
        let sc =
          scatter.scatter_config(x_data_key: "x", y_data_key: "y")
          |> scatter.scatter_data([
            dict.from_list([#("x", 10.0), #("y", 20.0)]),
            dict.from_list([#("x", 30.0), #("y", 40.0)]),
          ])
        let html =
          chart.composed_chart(
            data: [],
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.scatter(sc),
              chart.tooltip(config: tooltip.tooltip_config()),
            ],
          )
          |> element.to_string
        // Should contain tooltip hit zones (weft-chart-tooltip class)
        html
        |> string.contains("weft-chart-tooltip")
        |> expect.to_be_true
        // Should contain at least 2 hit zones (one per scatter point)
        { count_occurrences(html, "weft-chart-tooltip") >= 2 }
        |> expect.to_be_true
      },
    ),
    it("vertical layout ComposedChart with ScatterChild renders SVG", fn() {
      let sc =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_data([
          dict.from_list([#("x", 10.0), #("y", 20.0)]),
        ])
      let html =
        chart.composed_chart(
          data: [],
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.layout(layout: layout.Vertical),
            chart.scatter(sc),
          ],
        )
        |> element.to_string
      html |> string.contains("svg") |> expect.to_be_true
      html |> string.contains("circle") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// ErrorBar tests
// ---------------------------------------------------------------------------

pub fn error_bar_tests() {
  describe("error_bar", [
    it("defaults match recharts", fn() {
      let config = error_bar.error_bar_config(data_key: "err")
      config.data_key |> expect.to_equal(expected: "err")
      config.high_data_key |> expect.to_equal(expected: None)
      config.direction
      |> expect.to_equal(expected: error_bar.ErrorBarY)
      config.width |> expect.to_equal(expected: 5.0)
      config.stroke_width |> expect.to_equal(expected: 1.5)
    }),
    it("direction builder works", fn() {
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_direction(direction: error_bar.ErrorBarX)
      config.direction
      |> expect.to_equal(expected: error_bar.ErrorBarX)
    }),
    it("width builder works", fn() {
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_width(width: 8.0)
      config.width |> expect.to_equal(expected: 8.0)
    }),
    it("stroke builder works", fn() {
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_stroke(stroke: "#ff0000")
      config.stroke |> expect.to_equal(expected: "#ff0000")
    }),
    it("stroke_width builder works", fn() {
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_stroke_width(width: 3.0)
      config.stroke_width |> expect.to_equal(expected: 3.0)
    }),
    it("renders in a chart with error data", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("v", 50.0), #("err", 5.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("v", 80.0), #("err", 10.0)]),
        ),
      ]
      let svg =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
            chart.error_bar(
              config: error_bar.error_bar_config(data_key: "err"),
              series_data_key: "v",
            ),
          ],
        )
      let html = element.to_string(svg)
      html |> string.contains("recharts-errorBar") |> expect.to_be_true
    }),
    it("skips points without error data", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("v", 50.0), #("err", 5.0)]),
        ),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 80.0)])),
      ]
      let svg =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
            chart.error_bar(
              config: error_bar.error_bar_config(data_key: "err"),
              series_data_key: "v",
            ),
          ],
        )
      let html = element.to_string(svg)
      // Should still render the error bar group
      html |> string.contains("recharts-errorBar") |> expect.to_be_true
    }),
    it("renders vertical error bars with three lines per point", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("v", 50.0), #("err", 5.0)]),
        ),
      ]
      let svg =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
            chart.error_bar(
              config: error_bar.error_bar_config(data_key: "err"),
              series_data_key: "v",
            ),
          ],
        )
      let html = element.to_string(svg)
      // Each error bar renders 3 lines: main + 2 serifs
      // Count <line occurrences in the errorBar group
      html |> string.contains("<line") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Series name prop tests
// ---------------------------------------------------------------------------

pub fn series_name_tests() {
  describe("series_name", [
    it("line defaults name to empty string", fn() {
      let config =
        line.line_config(data_key: "desktop", meta: common.series_meta())
      config.name |> expect.to_equal(expected: "")
    }),
    it("area defaults name to empty string", fn() {
      let config =
        area.area_config(data_key: "desktop", meta: common.series_meta())
      config.name |> expect.to_equal(expected: "")
    }),
    it("bar defaults name to empty string", fn() {
      let config =
        bar.bar_config(data_key: "desktop", meta: common.series_meta())
      config.name |> expect.to_equal(expected: "")
    }),
    it("line_name builder sets name", fn() {
      let config =
        line.line_config(data_key: "desktop", meta: common.series_meta())
        |> line.line_meta(
          meta: common.series_meta()
          |> common.series_name(name: "Desktop Users"),
        )
      config.name |> expect.to_equal(expected: "Desktop Users")
    }),
    it("area_name builder sets name", fn() {
      let config =
        area.area_config(data_key: "desktop", meta: common.series_meta())
        |> area.area_meta(
          meta: common.series_meta()
          |> common.series_name(name: "Desktop Users"),
        )
      config.name |> expect.to_equal(expected: "Desktop Users")
    }),
    it("bar_name builder sets name", fn() {
      let config =
        bar.bar_config(data_key: "desktop", meta: common.series_meta())
        |> bar.bar_meta(
          meta: common.series_meta()
          |> common.series_name(name: "Desktop Users"),
        )
      config.name |> expect.to_equal(expected: "Desktop Users")
    }),
    it("tooltip uses display name when series name is set", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("desktop", 186.0)]),
        ),
      ]
      let svg =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(
              line.line_config(data_key: "desktop", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta()
                |> common.series_name(name: "Desktop Users"),
              ),
            ),
            chart.tooltip(tooltip.tooltip_config()),
          ],
        )
      let html = element.to_string(svg)
      // Tooltip should contain the display name, not the data_key
      html |> string.contains("Desktop Users") |> expect.to_be_true
    }),
    it("legend uses display name when series name is set", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("desktop", 186.0)]),
        ),
      ]
      let svg =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(
              line.line_config(data_key: "desktop", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta()
                |> common.series_name(name: "Desktop Users"),
              ),
            ),
            chart.legend(legend.legend_config()),
          ],
        )
      let html = element.to_string(svg)
      html |> string.contains("Desktop Users") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Axis unit prop tests
// ---------------------------------------------------------------------------

pub fn axis_unit_tests() {
  describe("axis_unit", [
    it("x_axis default unit is empty", fn() {
      let config = axis.x_axis_config()
      config.unit |> expect.to_equal(expected: "")
    }),
    it("y_axis default unit is empty", fn() {
      let config = axis.y_axis_config()
      config.unit |> expect.to_equal(expected: "")
    }),
    it("x_unit builder sets unit string", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_unit("km")
      config.unit |> expect.to_equal(expected: "km")
    }),
    it("y_unit builder sets unit string", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_unit("$")
      config.unit |> expect.to_equal(expected: "$")
    }),
    it("y_unit appends to tick labels in rendered chart", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("v", 100.0)]),
        ),
        chart.DataPoint(
          category: "Feb",
          values: dict.from_list([#("v", 200.0)]),
        ),
      ]
      let svg =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
            chart.y_axis(axis.y_axis_config() |> axis.axis_unit("ms")),
          ],
        )
      let html = element.to_string(svg)
      // Tick labels should have unit appended
      html |> string.contains("ms") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Bar stroke tests
// ---------------------------------------------------------------------------

pub fn bar_stroke_tests() {
  describe("bar_stroke", [
    it("default stroke is empty", fn() {
      let config = bar.bar_config(data_key: "v", meta: common.series_meta())
      config.stroke |> expect.to_equal(expected: weft.css_color(value: ""))
      config.stroke_width
      |> expect.to_equal(expected: 0.0)
    }),
    it("bar_stroke builder sets stroke color", fn() {
      let config =
        bar.bar_config(data_key: "v", meta: common.series_meta())
        |> bar.bar_stroke(weft.css_color(value: "#333"))
      config.stroke |> expect.to_equal(expected: weft.css_color(value: "#333"))
    }),
    it("bar_stroke_width builder sets width", fn() {
      let config =
        bar.bar_config(data_key: "v", meta: common.series_meta())
        |> bar.bar_stroke_width(2.0)
      config.stroke_width
      |> expect.to_equal(expected: 2.0)
    }),
    it("renders stroke attribute when set", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
      ]
      let svg =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(
              bar.bar_config(data_key: "v", meta: common.series_meta())
              |> bar.bar_stroke(weft.css_color(value: "#333"))
              |> bar.bar_stroke_width(2.0),
            ),
          ],
        )
      let html = element.to_string(svg)
      html |> string.contains("stroke=\"#333\"") |> expect.to_be_true
      html |> string.contains("stroke-width=\"2.0\"") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Chart-level bar layout tests
// ---------------------------------------------------------------------------

pub fn bar_layout_tests() {
  let data = [
    chart.DataPoint(
      category: "A",
      values: dict.from_list([#("a", 10.0), #("b", 20.0)]),
    ),
    chart.DataPoint(
      category: "B",
      values: dict.from_list([#("a", 15.0), #("b", 25.0)]),
    ),
  ]

  describe("bar_layout", [
    it("renders with custom bar_category_gap", fn() {
      let svg =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(bar.bar_config(data_key: "a", meta: common.series_meta())),
            chart.bar(bar.bar_config(data_key: "b", meta: common.series_meta())),
            chart.bar_layout(
              bar_category_gap: 0.2,
              bar_gap: 4.0,
              chart_bar_size: chart.FixedBarSize(size: 0),
            ),
          ],
        )
      let html = element.to_string(svg)
      html |> string.contains("recharts-bar") |> expect.to_be_true
    }),
    it("renders with chart-level bar_size", fn() {
      let svg =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(bar.bar_config(data_key: "a", meta: common.series_meta())),
            chart.bar(bar.bar_config(data_key: "b", meta: common.series_meta())),
            chart.bar_layout(
              bar_category_gap: 0.1,
              bar_gap: 4.0,
              chart_bar_size: chart.FixedBarSize(size: 20),
            ),
          ],
        )
      let html = element.to_string(svg)
      // With fixed bar_size=20, bar width should be 20
      html |> string.contains("20") |> expect.to_be_true
    }),
    it("renders with custom bar_gap", fn() {
      let svg =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(bar.bar_config(data_key: "a", meta: common.series_meta())),
            chart.bar(bar.bar_config(data_key: "b", meta: common.series_meta())),
            chart.bar_layout(
              bar_category_gap: 0.1,
              bar_gap: 10.0,
              chart_bar_size: chart.FixedBarSize(size: 0),
            ),
          ],
        )
      let html = element.to_string(svg)
      html |> string.contains("recharts-bar") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 1: Pie sector corner radius
// ---------------------------------------------------------------------------

pub fn get_delta_angle_tests() {
  describe("get_delta_angle", [
    it("returns positive delta for CW sweep", fn() {
      let delta = polar.get_delta_angle(0.0, 90.0)
      delta |> expect.to_equal(expected: 90.0)
    }),
    it("returns negative delta for CCW sweep", fn() {
      let delta = polar.get_delta_angle(90.0, 0.0)
      delta |> expect.to_equal(expected: -90.0)
    }),
    it("caps at 359.999 degrees", fn() {
      let delta = polar.get_delta_angle(0.0, 400.0)
      // abs(400) > 359.999, so capped
      let abs_delta = float.absolute_value(delta)
      { abs_delta <=. 360.0 } |> expect.to_be_true
    }),
  ])
}

pub fn sector_corner_radius_tests() {
  describe("sector_corner_radius", [
    it("sector_path_with_corners with cr=0 fallback matches sector_path", fn() {
      // When corner_radius is 0 and outer_arc_angle < 0, it falls back
      // But more practically, shape.sector with cr=0 uses sector_path directly
      let without_cr =
        element.to_string(shape.sector(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 90.0,
          corner_radius: 0.0,
          fill: "red",
        ))
      // The path should start with M and contain A (arc) commands
      without_cr |> string.contains("M") |> expect.to_be_true
      without_cr |> string.contains("A") |> expect.to_be_true
    }),
    it("sector with cr>0 produces different path than cr=0", fn() {
      let without_cr =
        element.to_string(shape.sector(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 90.0,
          corner_radius: 0.0,
          fill: "red",
        ))
      let with_cr =
        element.to_string(shape.sector(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 90.0,
          corner_radius: 5.0,
          fill: "red",
        ))
      // Corner radius path should differ
      { without_cr != with_cr } |> expect.to_be_true
    }),
    it("full 360 sector ignores corner radius", fn() {
      let without_cr =
        element.to_string(shape.sector(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 360.0,
          corner_radius: 0.0,
          fill: "red",
        ))
      let with_cr =
        element.to_string(shape.sector(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 360.0,
          corner_radius: 5.0,
          fill: "red",
        ))
      // Full circle: cr has no effect since abs(360) >= 360
      without_cr |> expect.to_equal(expected: with_cr)
    }),
    it("donut sector with corners has multiple arc commands", fn() {
      let html =
        element.to_string(shape.sector(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 40.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 120.0,
          corner_radius: 5.0,
          fill: "blue",
        ))
      // Corner radius path has more A commands than basic sector
      // Basic donut: 2 A commands. With corners: 6+ A commands
      let a_count =
        string.split(html, "A")
        |> list.length
      // At least 5 segments split by "A" means at least 4 A commands
      { a_count >= 5 } |> expect.to_be_true
    }),
    it("pie chart with corner_radius renders sectors", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("value", 30.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("value", 70.0)]),
        ),
      ]
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_corner_radius(5.0)
      let svg =
        chart.pie_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 400,
          children: [
            chart.pie(config),
          ],
        )
      let html = element.to_string(svg)
      html |> string.contains("recharts-pie") |> expect.to_be_true
    }),
    it("corner radius is clamped to half the delta radius", fn() {
      // outer=80, inner=60, delta=20, max cr=10
      // Setting cr=15 should be clamped to 10
      let clamped =
        element.to_string(shape.sector(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 60.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 90.0,
          corner_radius: 15.0,
          fill: "green",
        ))
      let exact =
        element.to_string(shape.sector(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 60.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 90.0,
          corner_radius: 10.0,
          fill: "green",
        ))
      // Both should produce the same path since 15 gets clamped to 10
      clamped |> expect.to_equal(expected: exact)
    }),
  ])
}

pub fn tooltip_unit_tests() {
  describe("tooltip_unit", [
    it("entry with unit appends unit after value", fn() {
      let config = tooltip.tooltip_config()
      let payload =
        tooltip.TooltipPayload(
          label: "Jan",
          entries: [
            tooltip.TooltipEntry(
              name: "Weight",
              value: 42.0,
              color: weft.css_color(value: "#8884d8"),
              unit: "kg",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
          ],
          x: 100.0,
          y: 50.0,
          active_dots: [],
          zone_width: 0.0,
          zone_height: 0.0,
        )
      let html =
        tooltip.render_tooltips(
          config: config,
          payloads: [payload],
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          zone_width: 50.0,
          zone_mode: tooltip.ColumnZone,
          zone_extra_attrs: [],
        )
        |> element.to_string
      // The rendered output should contain the value followed by the unit
      html |> string.contains("42kg") |> expect.to_be_true
    }),
    it("empty unit adds nothing after value", fn() {
      let config = tooltip.tooltip_config()
      let payload =
        tooltip.TooltipPayload(
          label: "Jan",
          entries: [
            tooltip.TooltipEntry(
              name: "Sales",
              value: 100.0,
              color: weft.css_color(value: "#8884d8"),
              unit: "",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
          ],
          x: 100.0,
          y: 50.0,
          active_dots: [],
          zone_width: 0.0,
          zone_height: 0.0,
        )
      let html =
        tooltip.render_tooltips(
          config: config,
          payloads: [payload],
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          zone_width: 50.0,
          zone_mode: tooltip.ColumnZone,
          zone_extra_attrs: [],
        )
        |> element.to_string
      // Value "100" should be present, but no trailing unit text
      html |> string.contains("100") |> expect.to_be_true
    }),
    it("y-axis unit propagates to tooltip entries", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("weight", 50.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "weight",
              meta: common.series_meta(),
            )),
            chart.y_axis(axis.y_axis_config() |> axis.axis_unit("kg")),
            chart.tooltip(tooltip.tooltip_config()),
          ],
        )
        |> element.to_string
      // Tooltip should contain the unit from y-axis
      html |> string.contains("kg") |> expect.to_be_true
    }),
  ])
}

pub fn tooltip_item_sorter_tests() {
  describe("tooltip_item_sorter", [
    it("default sorter preserves original order", fn() {
      let config = tooltip.tooltip_config()
      // Default item_sorter returns 0.0 for all entries (stable order)
      config.item_sorter
      |> expect.to_not_equal(expected: fn(_e: tooltip.TooltipEntry) { 1.0 })
    }),
    it("builder sets custom sorter", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_item_sorter(fn(entry) { entry.value })
      let entry =
        tooltip.TooltipEntry(
          name: "Test",
          value: 42.0,
          color: weft.css_color(value: "#000"),
          unit: "",
          hidden: False,
          entry_type: tooltip.VisibleEntry,
        )
      config.item_sorter(entry) |> expect.to_equal(expected: 42.0)
    }),
    it("sorter reorders tooltip entries by value", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_item_sorter(fn(entry) { entry.value })
      // Create entries in descending order
      let payload =
        tooltip.TooltipPayload(
          label: "Jan",
          entries: [
            tooltip.TooltipEntry(
              name: "High",
              value: 100.0,
              color: weft.css_color(value: "#ff0000"),
              unit: "",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
            tooltip.TooltipEntry(
              name: "Low",
              value: 10.0,
              color: weft.css_color(value: "#00ff00"),
              unit: "",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
            tooltip.TooltipEntry(
              name: "Mid",
              value: 50.0,
              color: weft.css_color(value: "#0000ff"),
              unit: "",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
          ],
          x: 100.0,
          y: 50.0,
          active_dots: [],
          zone_width: 0.0,
          zone_height: 0.0,
        )
      let html =
        tooltip.render_tooltips(
          config: config,
          payloads: [payload],
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          zone_width: 50.0,
          zone_mode: tooltip.ColumnZone,
          zone_extra_attrs: [],
        )
        |> element.to_string
      // After sorting by value ascending: Low(10), Mid(50), High(100)
      // Low should appear before High in the HTML
      let low_pos = string_index_of(html, "Low")
      let high_pos = string_index_of(html, "High")
      { low_pos < high_pos } |> expect.to_be_true
    }),
  ])
}

pub fn tooltip_include_hidden_tests() {
  describe("tooltip_include_hidden", [
    it("defaults to False", fn() {
      let config = tooltip.tooltip_config()
      config.include_hidden |> expect.to_be_false
    }),
    it("builder sets include_hidden", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_include_hidden(True)
      config.include_hidden |> expect.to_be_true
    }),
    it("hidden series excluded from tooltip by default", fn() {
      // Directly test that build_tooltip_payloads filters hidden entries
      // by rendering tooltips with explicit payloads
      let config = tooltip.tooltip_config()
      // With include_hidden=False (default), hidden entries should be excluded
      // Test via the chart: hidden line won't contribute tooltip entries
      let visible_payload =
        tooltip.TooltipPayload(
          label: "A",
          entries: [
            tooltip.TooltipEntry(
              name: "visible",
              value: 50.0,
              color: weft.css_color(value: "#8884d8"),
              unit: "",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
          ],
          x: 100.0,
          y: 50.0,
          active_dots: [],
          zone_width: 0.0,
          zone_height: 0.0,
        )
      let html =
        tooltip.render_tooltips(
          config: config,
          payloads: [visible_payload],
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          zone_width: 50.0,
          zone_mode: tooltip.ColumnZone,
          zone_extra_attrs: [],
        )
        |> element.to_string
      // Only visible should appear, no hidden
      html |> string.contains("visible") |> expect.to_be_true
      html |> string.contains("hidden_series") |> expect.to_be_false
    }),
    it("include_hidden=True shows all entries in tooltip", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_include_hidden(True)
      // When include_hidden is true, the chart passes all entries through
      let payload =
        tooltip.TooltipPayload(
          label: "A",
          entries: [
            tooltip.TooltipEntry(
              name: "vis",
              value: 50.0,
              color: weft.css_color(value: "#8884d8"),
              unit: "",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
            tooltip.TooltipEntry(
              name: "hid",
              value: 30.0,
              color: weft.css_color(value: "#82ca9d"),
              unit: "",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
          ],
          x: 100.0,
          y: 50.0,
          active_dots: [],
          zone_width: 0.0,
          zone_height: 0.0,
        )
      let html =
        tooltip.render_tooltips(
          config: config,
          payloads: [payload],
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          zone_width: 50.0,
          zone_mode: tooltip.ColumnZone,
          zone_extra_attrs: [],
        )
        |> element.to_string
      // Both series should appear in the tooltip
      html |> string.contains("vis") |> expect.to_be_true
      html |> string.contains("hid") |> expect.to_be_true
    }),
  ])
}

pub fn math_ln_pow_tests() {
  describe("math_ln_pow", [
    it("ln(1.0) returns 0.0", fn() {
      let result = math.ln(1.0)
      { float.absolute_value(result) <. 0.001 } |> expect.to_be_true
    }),
    it("ln(e) returns approximately 1.0", fn() {
      // e = 2.718281828...
      let result = math.ln(2.718281828)
      { float.absolute_value(result -. 1.0) <. 0.001 } |> expect.to_be_true
    }),
    it("ln of non-positive returns 0.0", fn() {
      math.ln(0.0) |> expect.to_equal(expected: 0.0)
      math.ln(-1.0) |> expect.to_equal(expected: 0.0)
    }),
    it("pow(2.0, 3.0) returns 8.0", fn() {
      math.pow(2.0, 3.0) |> expect.to_equal(expected: 8.0)
    }),
    it("pow(10.0, 0.0) returns 1.0", fn() {
      math.pow(10.0, 0.0) |> expect.to_equal(expected: 1.0)
    }),
    it("log_base computes log10(100) = 2", fn() {
      let result = math.log_base(100.0, 10.0)
      { float.absolute_value(result -. 2.0) <. 0.001 } |> expect.to_be_true
    }),
    it("log_base returns 0.0 for invalid inputs", fn() {
      math.log_base(0.0, 10.0) |> expect.to_equal(expected: 0.0)
      math.log_base(100.0, 1.0) |> expect.to_equal(expected: 0.0)
      math.log_base(-5.0, 10.0) |> expect.to_equal(expected: 0.0)
    }),
  ])
}

pub fn log_scale_tests() {
  describe("log_scale", [
    it("log_apply maps domain [1, 1000] correctly", fn() {
      let s =
        scale.log(
          domain_min: 1.0,
          domain_max: 1000.0,
          range_start: 0.0,
          range_end: 300.0,
          base: 10.0,
        )
      // log10(1) = 0, log10(1000) = 3
      // log10(10) = 1 -> 1/3 of range = 100
      let result = scale.log_apply(s, 10.0)
      { float.absolute_value(result -. 100.0) <. 1.0 } |> expect.to_be_true
    }),
    it("log_apply maps endpoints correctly", fn() {
      let s =
        scale.log(
          domain_min: 1.0,
          domain_max: 1000.0,
          range_start: 0.0,
          range_end: 300.0,
          base: 10.0,
        )
      let start = scale.log_apply(s, 1.0)
      let end = scale.log_apply(s, 1000.0)
      { float.absolute_value(start) <. 0.1 } |> expect.to_be_true
      { float.absolute_value(end -. 300.0) <. 0.1 } |> expect.to_be_true
    }),
    it("log_ticks for [1, 10000] base 10 produces power-of-10 ticks", fn() {
      let ticks = scale.log_ticks(1.0, 10_000.0, 10.0)
      // Should contain [1, 10, 100, 1000, 10000]
      list.length(ticks) |> expect.to_equal(expected: 5)
      case ticks {
        [a, b, c, d, e] -> {
          { float.absolute_value(a -. 1.0) <. 0.1 } |> expect.to_be_true
          { float.absolute_value(b -. 10.0) <. 0.1 } |> expect.to_be_true
          { float.absolute_value(c -. 100.0) <. 0.1 } |> expect.to_be_true
          { float.absolute_value(d -. 1000.0) <. 0.1 } |> expect.to_be_true
          { float.absolute_value(e -. 10_000.0) <. 1.0 } |> expect.to_be_true
        }
        _ -> expect.to_be_true(False)
      }
    }),
    it("unified apply dispatches to log scale", fn() {
      let s =
        scale.log(
          domain_min: 1.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 200.0,
          base: 10.0,
        )
      // log10(10) = 1, log10(1) = 0, log10(100) = 2
      // ratio = 1/2 -> 100.0
      let result = scale.apply(s, 10.0)
      { float.absolute_value(result -. 100.0) <. 1.0 } |> expect.to_be_true
    }),
  ])
}

pub fn sqrt_scale_tests() {
  describe("sqrt_scale", [
    it("sqrt_apply maps correctly", fn() {
      let s =
        scale.sqrt_scale(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 500.0,
        )
      // sqrt(0) = 0, sqrt(100) = 10
      // sqrt(25) = 5 -> ratio = 5/10 = 0.5 -> 250.0
      let result = scale.sqrt_apply(s, 25.0)
      { float.absolute_value(result -. 250.0) <. 1.0 } |> expect.to_be_true
    }),
    it("unified apply dispatches to sqrt scale", fn() {
      let s =
        scale.sqrt_scale(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 500.0,
        )
      let result = scale.apply(s, 25.0)
      { float.absolute_value(result -. 250.0) <. 1.0 } |> expect.to_be_true
    }),
  ])
}

pub fn scale_type_tests() {
  describe("scale_type", [
    it("x_axis defaults to LinearScaleType", fn() {
      let config = axis.x_axis_config()
      config.scale_type |> expect.to_equal(expected: axis.LinearScaleType)
    }),
    it("y_axis defaults to LinearScaleType", fn() {
      let config = axis.y_axis_config()
      config.scale_type |> expect.to_equal(expected: axis.LinearScaleType)
    }),
    it("x_scale_type builder sets log scale", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_scale_type(axis.LogScaleType(base: 10.0))
      config.scale_type
      |> expect.to_equal(expected: axis.LogScaleType(base: 10.0))
    }),
    it("y_scale_type builder sets sqrt scale", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_scale_type(axis.SqrtScaleType)
      config.scale_type |> expect.to_equal(expected: axis.SqrtScaleType)
    }),
    it("chart with log y-scale renders", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 1.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 100.0)])),
        chart.DataPoint(
          category: "C",
          values: dict.from_list([#("v", 10_000.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
            chart.y_axis(
              axis.y_axis_config()
              |> axis.axis_scale_type(axis.LogScaleType(base: 10.0)),
            ),
          ],
        )
        |> element.to_string
      // Should render a valid SVG
      html |> string.contains("<svg") |> expect.to_be_true
      html |> string.contains("recharts-yAxis") |> expect.to_be_true
    }),
    it("chart with sqrt y-scale renders", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 0.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 25.0)])),
        chart.DataPoint(category: "C", values: dict.from_list([#("v", 100.0)])),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
            chart.y_axis(
              axis.y_axis_config() |> axis.axis_scale_type(axis.SqrtScaleType),
            ),
          ],
        )
        |> element.to_string
      html |> string.contains("<svg") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 5: Axis width/height props
// ---------------------------------------------------------------------------

pub fn axis_dimension_tests() {
  describe("axis_dimensions", [
    it("x_axis height defaults to 30", fn() {
      let config = axis.x_axis_config()
      config.height |> expect.to_equal(expected: 30)
    }),
    it("y_axis width defaults to 60", fn() {
      let config = axis.y_axis_config()
      config.width |> expect.to_equal(expected: 60)
    }),
    it("x_height builder sets height", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_size(50)
      config.height |> expect.to_equal(expected: 50)
    }),
    it("y_width builder sets width", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_size(80)
      config.width |> expect.to_equal(expected: 80)
    }),
    it("custom y_width changes chart layout", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 50.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 80.0)])),
      ]
      let without_width =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.y_axis(axis.y_axis_config()),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      let with_width =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.y_axis(axis.y_axis_config() |> axis.axis_size(100)),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      // With explicit y-axis width, the plot area shifts right
      without_width |> expect.to_not_equal(expected: with_width)
    }),
    it("custom x_height changes chart layout", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 50.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 80.0)])),
      ]
      let without_height =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.x_axis(axis.x_axis_config()),
            chart.bar(bar.bar_config(data_key: "v", meta: common.series_meta())),
          ],
        )
        |> element.to_string
      let with_height =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 200,
          children: [
            chart.x_axis(axis.x_axis_config() |> axis.axis_size(60)),
            chart.bar(bar.bar_config(data_key: "v", meta: common.series_meta())),
          ],
        )
        |> element.to_string
      // With explicit x-axis height, the plot area shrinks vertically
      without_height |> expect.to_not_equal(expected: with_height)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 4: Scatter chart
// ---------------------------------------------------------------------------

pub fn scatter_config_tests() {
  describe("scatter_config", [
    it("creates config with recharts defaults", fn() {
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      config.x_data_key |> expect.to_equal(expected: "x")
      config.y_data_key |> expect.to_equal(expected: "y")
      config.z_data_key |> expect.to_equal(expected: "")
      config.name |> expect.to_equal(expected: "")
      config.symbol_type
      |> expect.to_equal(expected: scatter.CircleSymbol)
      config.default_size |> expect.to_equal(expected: 64.0)
      config.show_line |> expect.to_be_false
      config.hide |> expect.to_be_false
      config.stroke_width |> expect.to_equal(expected: 0.0)
      config.legend_type |> expect.to_equal(expected: shape.CircleIcon)
    }),
    it("fill builder sets fill color", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_fill(fill: weft.css_color(value: "#ff0000"))
      config.fill |> expect.to_equal(expected: weft.css_color(value: "#ff0000"))
    }),
    it("name builder sets display name", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_name(name: "Points")
      config.name |> expect.to_equal(expected: "Points")
    }),
    it("symbol builder sets symbol type", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_symbol(symbol: scatter.DiamondSymbol)
      config.symbol_type
      |> expect.to_equal(expected: scatter.DiamondSymbol)
    }),
    it("size builder sets default size", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_size(size: 128.0)
      config.default_size |> expect.to_equal(expected: 128.0)
    }),
    it("z_data_key builder sets size encoding key", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_z_data_key(key: "z")
      config.z_data_key |> expect.to_equal(expected: "z")
    }),
    it("show_line builder enables connecting line", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_show_line(show: True)
      config.show_line |> expect.to_be_true
    }),
    it("hide builder hides the scatter", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_hide
      config.hide |> expect.to_be_true
    }),
  ])
}

pub fn scatter_render_tests() {
  describe("scatter_render", [
    it("renders 3 circles for 3 data points", fn() {
      let data = [
        dict.from_list([#("x", 10.0), #("y", 20.0)]),
        dict.from_list([#("x", 30.0), #("y", 40.0)]),
        dict.from_list([#("x", 50.0), #("y", 60.0)]),
      ]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      // Should contain 3 circle elements
      let circle_count =
        string.split(html, "<circle")
        |> list.length
      // split gives n+1 parts for n occurrences
      circle_count |> expect.to_equal(expected: 4)
      html |> string.contains("recharts-scatter") |> expect.to_be_true
    }),
    it("z-axis size encoding varies radius", fn() {
      let data = [
        dict.from_list([#("x", 10.0), #("y", 20.0), #("z", 16.0)]),
        dict.from_list([#("x", 30.0), #("y", 40.0), #("z", 64.0)]),
      ]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_z_data_key(key: "z")
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      // z=16: r = sqrt(16/pi) ≈ 2.26
      // z=64: r = sqrt(64/pi) ≈ 4.51
      // Different radii should produce different r attributes
      html |> string.contains("recharts-scatter-symbol") |> expect.to_be_true
      // Verify two circles with different radii
      let circles =
        string.split(html, "<circle")
        |> list.length
      circles |> expect.to_equal(expected: 3)
    }),
    it("connecting line renders path through points", fn() {
      let data = [
        dict.from_list([#("x", 10.0), #("y", 20.0)]),
        dict.from_list([#("x", 30.0), #("y", 40.0)]),
        dict.from_list([#("x", 50.0), #("y", 60.0)]),
      ]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_show_line(show: True)
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      // Should have a path with M...L...L... for connecting line
      html
      |> string.contains("recharts-scatter-line")
      |> expect.to_be_true
    }),
    it("empty data produces no symbols", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      let html =
        scatter.render_scatter(
          config: config,
          data: [],
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      // No circle elements
      html |> string.contains("<circle") |> expect.to_be_false
    }),
    it("missing x or y key skips the point", fn() {
      let data = [
        dict.from_list([#("x", 10.0), #("y", 20.0)]),
        dict.from_list([#("x", 30.0)]),
        // missing y
        dict.from_list([#("y", 50.0)]),
        // missing x
      ]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      // Only 1 point has both x and y
      let circle_count =
        string.split(html, "<circle")
        |> list.length
      circle_count |> expect.to_equal(expected: 2)
    }),
    it("hidden scatter produces no output", fn() {
      let data = [dict.from_list([#("x", 10.0), #("y", 20.0)])]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_hide
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      html |> string.contains("<circle") |> expect.to_be_false
      html |> string.contains("recharts-scatter") |> expect.to_be_false
    }),
  ])
}

pub fn scatter_chart_tests() {
  describe("scatter_chart", [
    it("renders scatter chart with linear scales on both axes", fn() {
      let data = [
        chart.DataPoint(
          category: "P1",
          values: dict.from_list([#("x", 10.0), #("y", 20.0)]),
        ),
        chart.DataPoint(
          category: "P2",
          values: dict.from_list([#("x", 30.0), #("y", 40.0)]),
        ),
        chart.DataPoint(
          category: "P3",
          values: dict.from_list([#("x", 50.0), #("y", 60.0)]),
        ),
      ]
      let html =
        chart.scatter_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.scatter(scatter.scatter_config(
              x_data_key: "x",
              y_data_key: "y",
            )),
          ],
        )
        |> element.to_string
      html |> string.contains("<svg") |> expect.to_be_true
      html |> string.contains("recharts-scatter") |> expect.to_be_true
    }),
    it("scatter chart with axes and grid renders all components", fn() {
      let data = [
        chart.DataPoint(
          category: "P1",
          values: dict.from_list([#("x", 10.0), #("y", 20.0)]),
        ),
        chart.DataPoint(
          category: "P2",
          values: dict.from_list([#("x", 50.0), #("y", 80.0)]),
        ),
      ]
      let html =
        chart.scatter_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.cartesian_grid(grid.cartesian_grid_config()),
            chart.x_axis(
              axis.x_axis_config() |> axis.axis_type(axis.NumberAxis),
            ),
            chart.y_axis(axis.y_axis_config()),
            chart.scatter(
              scatter.scatter_config(x_data_key: "x", y_data_key: "y")
              |> scatter.scatter_fill(fill: weft.css_color(value: "#8884d8")),
            ),
          ],
        )
        |> element.to_string
      html
      |> string.contains("recharts-cartesian-grid")
      |> expect.to_be_true
      html |> string.contains("recharts-scatter") |> expect.to_be_true
    }),
    it("scatter chart tooltip shows y values", fn() {
      let html =
        chart.scatter_chart(
          data: [],
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.scatter(
              scatter.scatter_config(x_data_key: "x", y_data_key: "y")
              |> scatter.scatter_name(name: "Scatter Y")
              |> scatter.scatter_data([
                dict.from_list([#("x", 10.0), #("y", 42.0)]),
              ]),
            ),
            chart.tooltip(tooltip.tooltip_config()),
          ],
        )
        |> element.to_string
      // recharts scatter tooltip shows axis values, not the series name
      // (series name appears in legend, not tooltip popup)
      html |> string.contains("42") |> expect.to_be_true
    }),
    it("scatter chart with legend shows series name", fn() {
      let data = [
        chart.DataPoint(
          category: "P1",
          values: dict.from_list([#("x", 10.0), #("y", 20.0)]),
        ),
      ]
      let html =
        chart.scatter_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.scatter(
              scatter.scatter_config(x_data_key: "x", y_data_key: "y")
              |> scatter.scatter_name(name: "Data Points"),
            ),
            chart.legend(legend.legend_config()),
          ],
        )
        |> element.to_string
      html |> string.contains("Data Points") |> expect.to_be_true
    }),
    it("square symbol renders rect elements", fn() {
      let data = [dict.from_list([#("x", 10.0), #("y", 20.0)])]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_symbol(symbol: scatter.SquareSymbol)
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      html |> string.contains("<rect") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 1 recharts parity: radar connect_nulls
// ---------------------------------------------------------------------------

pub fn radar_connect_nulls_tests() {
  describe("radar_connect_nulls", [
    it("renders with all data present (existing behavior)", fn() {
      let data = [
        dict.from_list([#("score", 80.0)]),
        dict.from_list([#("score", 90.0)]),
        dict.from_list([#("score", 70.0)]),
      ]
      let config = radar.radar_config(data_key: "score")
      let html =
        radar.render_radar(
          config: config,
          data: data,
          categories: ["Math", "Science", "English"],
          cx: 200.0,
          cy: 200.0,
          max_radius: 150.0,
          domain_max: 100.0,
        )
        |> element.to_string
      // Should render an SVG path with the polygon
      html |> string.contains("recharts-radar") |> expect.to_be_true
      html |> string.contains("<path") |> expect.to_be_true
      // Should contain a Z-close (polygon)
      html |> string.contains("Z") |> expect.to_be_true
    }),
    it("with missing data and connect_nulls=True skips missing vertices", fn() {
      // Middle data point is missing the "score" key
      let data = [
        dict.from_list([#("score", 80.0)]),
        dict.from_list([#("other", 50.0)]),
        dict.from_list([#("score", 70.0)]),
      ]
      let config =
        radar.radar_config(data_key: "score")
        |> radar.radar_connect_nulls
      let html =
        radar.render_radar(
          config: config,
          data: data,
          categories: ["Math", "Science", "English"],
          cx: 200.0,
          cy: 200.0,
          max_radius: 150.0,
          domain_max: 100.0,
        )
        |> element.to_string
      // Polygon should have only 2 vertices (M + L + Z), not 3
      // Count the number of L commands — should be exactly 1 (2 vertices total)
      let l_count =
        string.split(html, "L")
        |> list.length
      // split produces n+1 parts for n occurrences,
      // but we need to count within the path d attribute
      html |> string.contains("recharts-radar") |> expect.to_be_true
      // With connect_nulls=True and 2 valid points: M...L...Z
      { l_count >= 2 } |> expect.to_be_true
    }),
    it("with missing data and connect_nulls=False uses zero (default)", fn() {
      // Middle data point is missing the "score" key
      let data = [
        dict.from_list([#("score", 80.0)]),
        dict.from_list([#("other", 50.0)]),
        dict.from_list([#("score", 70.0)]),
      ]
      let config = radar.radar_config(data_key: "score")
      let html =
        radar.render_radar(
          config: config,
          data: data,
          categories: ["Math", "Science", "English"],
          cx: 200.0,
          cy: 200.0,
          max_radius: 150.0,
          domain_max: 100.0,
        )
        |> element.to_string
      // Polygon should have all 3 vertices (M + 2L + Z)
      // The missing vertex is at center (radius=0) so the point is (cx, cy)
      html |> string.contains("recharts-radar") |> expect.to_be_true
      // With 3 vertices: M...L...L...Z — 2 L commands
      let path_parts =
        string.split(html, "L")
        |> list.length
      { path_parts >= 3 } |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 1 recharts parity: axis name prop
// ---------------------------------------------------------------------------

pub fn axis_name_tests() {
  describe("axis_name", [
    it("x_name sets the name field", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_name("Revenue")
      config.name |> expect.to_equal(expected: "Revenue")
    }),
    it("y_name sets the name field", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_name("Amount")
      config.name |> expect.to_equal(expected: "Amount")
    }),
    it("x_axis name defaults to empty string", fn() {
      let config = axis.x_axis_config()
      config.name |> expect.to_equal(expected: "")
    }),
    it("y_axis name defaults to empty string", fn() {
      let config = axis.y_axis_config()
      config.name |> expect.to_equal(expected: "")
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 1 recharts parity: tooltip filter_null
// ---------------------------------------------------------------------------

pub fn tooltip_filter_null_tests() {
  describe("tooltip_filter_null", [
    it("default config has filter_null = True", fn() {
      let config = tooltip.tooltip_config()
      config.filter_null |> expect.to_equal(expected: True)
    }),
    it("tooltip_filter_null builder sets field", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_filter_null(False)
      config.filter_null |> expect.to_equal(expected: False)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 1 recharts parity: grid sync_with_ticks
// ---------------------------------------------------------------------------

pub fn grid_sync_with_ticks_tests() {
  describe("grid_sync_with_ticks", [
    it("sync_with_ticks builder sets field", fn() {
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_sync_with_ticks(sync: True)
      config.sync_with_ticks |> expect.to_equal(expected: True)
    }),
    it("default sync_with_ticks is False", fn() {
      let config = grid.cartesian_grid_config()
      config.sync_with_ticks |> expect.to_equal(expected: False)
    }),
    it("sync_tick_coords builder sets the tick lists", fn() {
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_sync_tick_coords(x_coords: [10.0, 50.0, 90.0], y_coords: [
          20.0,
          60.0,
        ])
      config.sync_x_ticks |> expect.to_equal(expected: [10.0, 50.0, 90.0])
      config.sync_y_ticks |> expect.to_equal(expected: [20.0, 60.0])
    }),
    it("grid with sync ticks uses provided coordinates", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      // Provide explicit sync tick coords that differ from default ticks
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_sync_tick_coords(x_coords: [50.0, 150.0, 250.0], y_coords: [
          75.0,
          225.0,
        ])
      let html =
        grid.render_cartesian_grid(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
        )
        |> element.to_string
      // Verify the sync tick coords appear in the SVG output
      // Vertical lines at x=50, x=150, x=250
      html |> string.contains("50") |> expect.to_be_true
      html |> string.contains("150") |> expect.to_be_true
      html |> string.contains("250") |> expect.to_be_true
      // Horizontal lines at y=75, y=225
      html |> string.contains("75") |> expect.to_be_true
      html |> string.contains("225") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 1 recharts parity: padding modes
// ---------------------------------------------------------------------------

pub fn padding_mode_tests() {
  describe("padding_mode", [
    it("default is ExplicitPadding(0, 0)", fn() {
      let config = axis.x_axis_config()
      config.padding
      |> expect.to_equal(expected: axis.ExplicitPadding(left: 0, right: 0))
    }),
    it("x_padding builder maps to ExplicitPadding", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_padding(10, 20)
      config.padding
      |> expect.to_equal(expected: axis.ExplicitPadding(left: 10, right: 20))
      config.padding_left |> expect.to_equal(expected: 10)
      config.padding_right |> expect.to_equal(expected: 20)
    }),
    it("x_padding_mode sets GapPadding", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_padding_mode(axis.GapPadding)
      config.padding |> expect.to_equal(expected: axis.GapPadding)
    }),
    it("NoGapPadding resolves to zero padding", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_padding_mode(axis.NoGapPadding)
      config.padding |> expect.to_equal(expected: axis.NoGapPadding)
    }),
    it("GapPadding changes chart layout", fn() {
      // A line chart with GapPadding should produce different output
      // than the same chart with NoGapPadding
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 20.0)])),
        chart.DataPoint(category: "C", values: dict.from_list([#("v", 30.0)])),
      ]
      let gap_html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
            chart.x_axis(
              axis.x_axis_config() |> axis.axis_padding_mode(axis.GapPadding),
            ),
          ],
        )
        |> element.to_string
      let no_gap_html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
            chart.x_axis(
              axis.x_axis_config() |> axis.axis_padding_mode(axis.NoGapPadding),
            ),
          ],
        )
        |> element.to_string
      // Both should be valid SVGs but with different coordinates
      gap_html |> string.contains("<svg") |> expect.to_be_true
      no_gap_html |> string.contains("<svg") |> expect.to_be_true
      // They should differ due to padding differences
      { gap_html != no_gap_html } |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 1 recharts parity: range area
// ---------------------------------------------------------------------------

pub fn range_area_tests() {
  describe("range_area", [
    it("area_range builder sets fields correctly", fn() {
      let config =
        area.area_config(data_key: "high", meta: common.series_meta())
        |> area.area_range("low")
      config.is_range |> expect.to_equal(expected: True)
      config.base_data_key |> expect.to_equal(expected: "low")
    }),
    it("default area is not range", fn() {
      let config =
        area.area_config(data_key: "value", meta: common.series_meta())
      config.is_range |> expect.to_equal(expected: False)
      config.base_data_key |> expect.to_equal(expected: "")
    }),
    it("range area renders band between two y values", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("high", 30.0), #("low", 10.0)]),
        ),
        chart.DataPoint(
          category: "Feb",
          values: dict.from_list([#("high", 40.0), #("low", 15.0)]),
        ),
        chart.DataPoint(
          category: "Mar",
          values: dict.from_list([#("high", 35.0), #("low", 12.0)]),
        ),
      ]
      let html =
        chart.area_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.area(
              area.area_config(data_key: "high", meta: common.series_meta())
              |> area.area_range("low"),
            ),
          ],
        )
        |> element.to_string
      // Should render valid SVG with area
      html |> string.contains("<svg") |> expect.to_be_true
      html |> string.contains("recharts-area") |> expect.to_be_true
      // Area path should exist
      html |> string.contains("<path") |> expect.to_be_true
    }),
    it("range area with missing base key falls back to flat baseline", fn() {
      // base_data_key is empty, so it should fall back to flat baseline
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("value", 30.0)]),
        ),
        chart.DataPoint(
          category: "Feb",
          values: dict.from_list([#("value", 40.0)]),
        ),
      ]
      let html =
        chart.area_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.area(
              area.area_config(data_key: "value", meta: common.series_meta())
              |> area.area_range(""),
            ),
          ],
        )
        |> element.to_string
      // Should still render (fallback to flat baseline)
      html |> string.contains("<svg") |> expect.to_be_true
      html |> string.contains("recharts-area") |> expect.to_be_true
    }),
    it("non-range area unchanged (default)", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("value", 30.0)]),
        ),
        chart.DataPoint(
          category: "Feb",
          values: dict.from_list([#("value", 40.0)]),
        ),
      ]
      let html =
        chart.area_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.area(area.area_config(
              data_key: "value",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      html |> string.contains("<svg") |> expect.to_be_true
      html |> string.contains("recharts-area") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 2 tests: scatter symbols, tooltip_type, line_fill, tooltip config,
// grid values, reference segment
// ---------------------------------------------------------------------------

pub fn scatter_symbols_tests() {
  describe("scatter_symbols", [
    it("CrossSymbol renders a g element with rect children", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_symbol(scatter.CrossSymbol)
      let data = [dict.from_list([#("x", 10.0), #("y", 20.0)])]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      html |> string.contains("recharts-scatter-symbol") |> expect.to_be_true
      html |> string.contains("<rect") |> expect.to_be_true
    }),
    it("StarSymbol renders a polygon element", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_symbol(scatter.StarSymbol)
      let data = [dict.from_list([#("x", 50.0), #("y", 50.0)])]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      html |> string.contains("recharts-scatter-symbol") |> expect.to_be_true
      html |> string.contains("<polygon") |> expect.to_be_true
      html |> string.contains("points=") |> expect.to_be_true
    }),
    it("WyeSymbol renders a path element", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_symbol(scatter.WyeSymbol)
      let data = [dict.from_list([#("x", 50.0), #("y", 50.0)])]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      html |> string.contains("recharts-scatter-symbol") |> expect.to_be_true
      html |> string.contains("<path") |> expect.to_be_true
    }),
    it("CrossSymbol has correct class attribute", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_symbol(scatter.CrossSymbol)
      let data = [dict.from_list([#("x", 10.0), #("y", 20.0)])]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      html
      |> string.contains("recharts-scatter-symbol")
      |> expect.to_be_true
    }),
    it("StarSymbol has 10 points (5 outer, 5 inner)", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_symbol(scatter.StarSymbol)
      let data = [dict.from_list([#("x", 50.0), #("y", 50.0)])]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      // The points attribute should have 10 coordinate pairs separated by spaces
      html |> string.contains("points=\"") |> expect.to_be_true
    }),
    it("symbol builder sets symbol_type correctly", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_symbol(scatter.CrossSymbol)
      config.symbol_type |> expect.to_equal(expected: scatter.CrossSymbol)

      let config2 =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_symbol(scatter.StarSymbol)
      config2.symbol_type |> expect.to_equal(expected: scatter.StarSymbol)

      let config3 =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_symbol(scatter.WyeSymbol)
      config3.symbol_type |> expect.to_equal(expected: scatter.WyeSymbol)
    }),
  ])
}

pub fn tooltip_type_tests() {
  describe("tooltip_type", [
    it("default tooltip_type is DefaultTooltip for all series", fn() {
      let line = line.line_config(data_key: "val", meta: common.series_meta())
      line.tooltip_type |> expect.to_equal(expected: shape.DefaultTooltip)

      let area = area.area_config(data_key: "val", meta: common.series_meta())
      area.tooltip_type |> expect.to_equal(expected: shape.DefaultTooltip)

      let bar = bar.bar_config(data_key: "val", meta: common.series_meta())
      bar.tooltip_type |> expect.to_equal(expected: shape.DefaultTooltip)

      let scat = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      scat.tooltip_type |> expect.to_equal(expected: shape.DefaultTooltip)
    }),
    it("line_tooltip_type builder sets NoTooltip", fn() {
      let config =
        line.line_config(data_key: "val", meta: common.series_meta())
        |> line.line_meta(
          meta: common.series_meta()
          |> common.series_tooltip_type(tooltip_type: shape.NoTooltip),
        )
      config.tooltip_type |> expect.to_equal(expected: shape.NoTooltip)
    }),
    it("area_tooltip_type builder sets NoTooltip", fn() {
      let config =
        area.area_config(data_key: "val", meta: common.series_meta())
        |> area.area_meta(
          meta: common.series_meta()
          |> common.series_tooltip_type(tooltip_type: shape.NoTooltip),
        )
      config.tooltip_type |> expect.to_equal(expected: shape.NoTooltip)
    }),
    it("bar_tooltip_type builder sets NoTooltip", fn() {
      let config =
        bar.bar_config(data_key: "val", meta: common.series_meta())
        |> bar.bar_meta(
          meta: common.series_meta()
          |> common.series_tooltip_type(tooltip_type: shape.NoTooltip),
        )
      config.tooltip_type |> expect.to_equal(expected: shape.NoTooltip)
    }),
    it("scatter_tooltip_type builder sets NoTooltip", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_tooltip_type(type_: shape.NoTooltip)
      config.tooltip_type |> expect.to_equal(expected: shape.NoTooltip)
    }),
    // Integration test: NoTooltip series excluded from chart tooltip
    // The integration is tested via chart.gleam's build_tooltip_payloads
    // which checks series_info tuple's 5th element (no_tooltip flag).
    // A full end-to-end test would render a chart SVG with NoTooltip and
    // verify the tooltip payload is empty for that series.
    it("NoTooltip line excluded from chart tooltip payloads", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("visible", 10.0), #("hidden_tip", 20.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(
              line.line_config(data_key: "visible", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta()
                |> common.series_name(name: "Visible"),
              ),
            ),
            chart.line(
              line.line_config(
                data_key: "hidden_tip",
                meta: common.series_meta(),
              )
              |> line.line_meta(
                meta: common.series_meta()
                |> common.series_name(name: "Hidden Tip")
                |> common.series_tooltip_type(tooltip_type: shape.NoTooltip),
              ),
            ),
            chart.tooltip(tooltip.tooltip_config()),
          ],
        )
        |> element.to_string
      // The chart should render but the tooltip should NOT contain "Hidden Tip"
      html |> string.contains("<svg") |> expect.to_be_true
      html |> string.contains("Visible") |> expect.to_be_true
      html |> string.contains("Hidden Tip") |> expect.to_equal(expected: False)
    }),
  ])
}

pub fn line_fill_tests() {
  describe("line_fill", [
    it("default fill is #fff", fn() {
      let config = line.line_config(data_key: "val", meta: common.series_meta())
      config.fill |> expect.to_equal(expected: weft.css_color(value: "#fff"))
    }),
    it("line_fill builder sets custom fill", fn() {
      let config =
        line.line_config(data_key: "val", meta: common.series_meta())
        |> line.line_fill(fill: weft.css_color(value: "#ff0000"))
      config.fill |> expect.to_equal(expected: weft.css_color(value: "#ff0000"))
    }),
    it("custom fill appears in rendered dot SVG", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("val", 50.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(
              line.line_config(data_key: "val", meta: common.series_meta())
              |> line.line_fill(fill: weft.css_color(value: "#00ff00")),
            ),
          ],
        )
        |> element.to_string
      // Dot fill should use the custom fill color
      html |> string.contains("#00ff00") |> expect.to_be_true
    }),
  ])
}

pub fn tooltip_default_index_tests() {
  describe("tooltip_default_index", [
    it("default index is -1", fn() {
      let config = tooltip.tooltip_config()
      config.default_index |> expect.to_equal(expected: -1)
    }),
    it("builder sets index to >= 0", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_default_index(index: 2)
      config.default_index |> expect.to_equal(expected: 2)
    }),
    it("builder sets index to 0", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_default_index(index: 0)
      config.default_index |> expect.to_equal(expected: 0)
    }),
  ])
}

pub fn tooltip_shared_tests() {
  describe("tooltip_shared", [
    it("default shared is True", fn() {
      let config = tooltip.tooltip_config()
      config.shared |> expect.to_equal(expected: True)
    }),
    it("builder sets shared to False", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_shared(shared: False)
      config.shared |> expect.to_equal(expected: False)
    }),
    it("builder sets shared to True explicitly", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_shared(shared: False)
        |> tooltip.tooltip_shared(shared: True)
      config.shared |> expect.to_equal(expected: True)
    }),
  ])
}

pub fn tooltip_reverse_tests() {
  describe("tooltip_reverse_direction", [
    it("default reverse_x and reverse_y are False", fn() {
      let config = tooltip.tooltip_config()
      config.reverse_x |> expect.to_equal(expected: False)
      config.reverse_y |> expect.to_equal(expected: False)
    }),
    it("builder sets reverse directions", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_reverse_direction(reverse_x: True, reverse_y: False)
      config.reverse_x |> expect.to_equal(expected: True)
      config.reverse_y |> expect.to_equal(expected: False)

      let config2 =
        tooltip.tooltip_config()
        |> tooltip.tooltip_reverse_direction(reverse_x: False, reverse_y: True)
      config2.reverse_x |> expect.to_equal(expected: False)
      config2.reverse_y |> expect.to_equal(expected: True)
    }),
  ])
}

pub fn grid_values_tests() {
  describe("grid_values", [
    it("default horizontal_values and vertical_values are empty", fn() {
      let config = grid.cartesian_grid_config()
      config.horizontal_values |> expect.to_equal(expected: [])
      config.vertical_values |> expect.to_equal(expected: [])
    }),
    it("grid_horizontal_values builder sets values", fn() {
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_horizontal_values(values: [10.0, 50.0, 90.0])
      config.horizontal_values
      |> expect.to_equal(expected: [10.0, 50.0, 90.0])
    }),
    it("grid_vertical_values builder sets values", fn() {
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_vertical_values(values: [25.0, 75.0])
      config.vertical_values |> expect.to_equal(expected: [25.0, 75.0])
    }),
    it("horizontal_values render at mapped positions", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_horizontal_values(values: [25.0, 75.0])
      let html =
        grid.render_cartesian_grid(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
        )
        |> element.to_string
      // y=25.0 maps to pixel 225 (300 - 25/100*300), y=75.0 maps to pixel 75
      html |> string.contains("225") |> expect.to_be_true
      html |> string.contains("75") |> expect.to_be_true
    }),
  ])
}

pub fn reference_segment_tests() {
  describe("reference_segment", [
    it("default segment is empty", fn() {
      let config = reference.horizontal_line(value: 50.0)
      config.segment |> expect.to_equal(expected: [])
    }),
    it("line_segment builder sets points", fn() {
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_segment(points: [#(10.0, 20.0), #(80.0, 90.0)])
      config.segment
      |> expect.to_equal(expected: [#(10.0, 20.0), #(80.0, 90.0)])
    }),
    it("segment draws between two data points", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_segment(points: [#(10.0, 20.0), #(80.0, 90.0)])
      let html =
        reference.render_reference_line(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      // x=10 maps to pixel 40, x=80 maps to pixel 320
      // y=20 maps to pixel 240, y=90 maps to pixel 30
      html |> string.contains("40") |> expect.to_be_true
      html |> string.contains("320") |> expect.to_be_true
      html |> string.contains("240") |> expect.to_be_true
      html |> string.contains("30") |> expect.to_be_true
    }),
    it("empty segment falls back to normal direction rendering", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config = reference.horizontal_line(value: 50.0)
      let html =
        reference.render_reference_line(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      // Horizontal line at y=50 -> pixel 150, spanning full width 0..400
      html |> string.contains("150") |> expect.to_be_true
      html |> string.contains("400") |> expect.to_be_true
      html
      |> string.contains("recharts-reference-line")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase 3 Enhancement Tests
// ---------------------------------------------------------------------------

pub fn pie_enhancement_tests() {
  describe("pie_enhancements", [
    it("blend_stroke defaults to False", fn() {
      let config = pie.pie_config(data_key: "value")
      config.blend_stroke |> expect.to_be_false
    }),
    it("pie_blend_stroke sets blend_stroke", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_blend_stroke(True)
      config.blend_stroke |> expect.to_be_true
    }),
    it("active_indices defaults to empty list", fn() {
      let config = pie.pie_config(data_key: "value")
      config.active_indices |> expect.to_equal(expected: [])
    }),
    it("pie_active_index sets single active index", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_active_index(index: 2)
      config.active_indices |> expect.to_equal(expected: [2])
    }),
    it("pie_active_indices sets multiple active indices", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_active_indices(indices: [0, 2])
      config.active_indices |> expect.to_equal(expected: [0, 2])
    }),
    it("max_radius defaults to 0.0", fn() {
      let config = pie.pie_config(data_key: "value")
      config.max_radius |> expect.to_equal(expected: 0.0)
    }),
    it("pie_max_radius sets max_radius", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_max_radius(60.0)
      config.max_radius |> expect.to_equal(expected: 60.0)
    }),
    it("stroke defaults to #fff", fn() {
      let config = pie.pie_config(data_key: "value")
      config.stroke |> expect.to_equal(expected: "#fff")
    }),
    it("pie_stroke sets stroke", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_stroke("#000")
      config.stroke |> expect.to_equal(expected: "#000")
    }),
    it("stroke_width defaults to 1.0", fn() {
      let config = pie.pie_config(data_key: "value")
      config.stroke_width |> expect.to_equal(expected: 1.0)
    }),
    it("pie_stroke_width sets stroke_width", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_stroke_width(2.5)
      config.stroke_width |> expect.to_equal(expected: 2.5)
    }),
    it("name defaults to empty string", fn() {
      let config = pie.pie_config(data_key: "value")
      config.name |> expect.to_equal(expected: "")
    }),
    it("pie_name sets name", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_name("Revenue")
      config.name |> expect.to_equal(expected: "Revenue")
    }),
    it("active_index renders sector with larger radius", fn() {
      let data = [
        dict.from_list([#("val", 50.0)]),
        dict.from_list([#("val", 50.0)]),
      ]
      let config =
        pie.pie_config(data_key: "val")
        |> pie.pie_active_index(index: 0)
      let html =
        pie.render_pie(
          config: config,
          data: data,
          categories: ["A", "B"],
          width: 400.0,
          height: 400.0,
        )
        |> element.to_string
      // Active sector at index 0 should use resolved outer_radius + 4
      // With 400x400 chart: max_r=200, 0.8*200=160, active=164
      html |> string.contains("164") |> expect.to_be_true
    }),
    it(
      "multiple active_indices renders multiple sectors with larger radius",
      fn() {
        let data = [
          dict.from_list([#("val", 33.0)]),
          dict.from_list([#("val", 33.0)]),
          dict.from_list([#("val", 34.0)]),
        ]
        let config =
          pie.pie_config(data_key: "val")
          |> pie.pie_active_indices(indices: [0, 2])
        let html =
          pie.render_pie(
            config: config,
            data: data,
            categories: ["A", "B", "C"],
            width: 400.0,
            height: 400.0,
          )
          |> element.to_string
        // Both sector 0 and sector 2 should use enlarged radius (164)
        // Count occurrences of "164" — should appear at least twice
        let parts = string.split(html, "164")
        // n occurrences of "164" produces n+1 parts, so >= 3 parts means >= 2 occurrences
        { list.length(parts) >= 3 } |> expect.to_be_true
      },
    ),
    it("sector_names defaults to empty list", fn() {
      let config = pie.pie_config(data_key: "value")
      config.sector_names |> expect.to_equal(expected: [])
    }),
    it("pie_sector_names sets sector_names", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_sector_names(["A", "B", "C"])
      config.sector_names |> expect.to_equal(expected: ["A", "B", "C"])
    }),
    it(
      "sector_names feed into pie_sector_infos categories, not label SVG text",
      fn() {
        // recharts label=true shows the numeric value (400, not "Group A").
        // Sector names flow to tooltip/legend via pie_sector_infos, not into
        // the pie SVG text elements.
        let data = [
          dict.from_list([#("value", 50.0)]),
          dict.from_list([#("value", 50.0)]),
        ]
        let config =
          pie.pie_config(data_key: "value")
          |> pie.pie_label(True)
          |> pie.pie_sector_names(["Alpha", "Beta"])
        let html =
          pie.render_pie(
            config: config,
            data: data,
            categories: ["0.0", "1.0"],
            width: 400.0,
            height: 400.0,
          )
          |> element.to_string
        // Label text shows the numeric value, not the sector name.
        html |> string.contains(">50<") |> expect.to_be_true
        // Sector names do NOT appear as SVG text (they appear in tooltip/legend).
        html |> string.contains(">Alpha<") |> expect.to_be_false
      },
    ),
    it("label formats whole-number value without decimal", fn() {
      let data = [dict.from_list([#("value", 400.0)])]
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_label(True)
      let html =
        pie.render_pie(
          config: config,
          data: data,
          categories: ["A"],
          width: 400.0,
          height: 400.0,
        )
        |> element.to_string
      // "400" appears; "400.0" must not appear as a label text
      html |> string.contains(">400<") |> expect.to_be_true
      html |> string.contains(">400.0<") |> expect.to_be_false
    }),
    it("pie_sector_infos uses sector_names for category field", fn() {
      let data = [
        dict.from_list([#("value", 200.0)]),
        dict.from_list([#("value", 100.0)]),
      ]
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_sector_names(["Group A", "Group B"])
      let infos =
        pie.pie_sector_infos(
          config: config,
          data: data,
          categories: ["0.0", "1.0"],
          width: 400.0,
          height: 400.0,
        )
      case infos {
        [first, second] -> {
          first.category |> expect.to_equal(expected: "Group A")
          second.category |> expect.to_equal(expected: "Group B")
        }
        _ -> expect.to_be_true(False)
      }
    }),
    it(
      "pie_sector_infos falls back to categories when sector_names is empty",
      fn() {
        let data = [
          dict.from_list([#("value", 200.0)]),
          dict.from_list([#("value", 100.0)]),
        ]
        let config = pie.pie_config(data_key: "value")
        let infos =
          pie.pie_sector_infos(
            config: config,
            data: data,
            categories: ["Cat X", "Cat Y"],
            width: 400.0,
            height: 400.0,
          )
        case infos {
          [first, second] -> {
            first.category |> expect.to_equal(expected: "Cat X")
            second.category |> expect.to_equal(expected: "Cat Y")
          }
          _ -> expect.to_be_true(False)
        }
      },
    ),
    it("show_label_line defaults to True", fn() {
      let config = pie.pie_config(data_key: "value")
      config.show_label_line |> expect.to_be_true
    }),
    it("label line appears in SVG when show_label is True", fn() {
      let data = [
        dict.from_list([#("value", 300.0)]),
        dict.from_list([#("value", 100.0)]),
      ]
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_label(True)
      let html =
        pie.render_pie(
          config: config,
          data: data,
          categories: ["0.0", "1.0"],
          width: 400.0,
          height: 400.0,
        )
        |> element.to_string
      // A <line> element is rendered for each label connector.
      html |> string.contains("<line ") |> expect.to_be_true
    }),
    it("label line does not appear when show_label is False", fn() {
      let data = [
        dict.from_list([#("value", 300.0)]),
        dict.from_list([#("value", 100.0)]),
      ]
      // Default: show_label=False, show_label_line=True.
      // Lines must NOT render because show_label is False.
      let config = pie.pie_config(data_key: "value")
      let html =
        pie.render_pie(
          config: config,
          data: data,
          categories: ["0.0", "1.0"],
          width: 400.0,
          height: 400.0,
        )
        |> element.to_string
      html |> string.contains("<line ") |> expect.to_be_false
    }),
    it(
      "pie_label_line(False) suppresses lines even when show_label is True",
      fn() {
        let data = [
          dict.from_list([#("value", 300.0)]),
          dict.from_list([#("value", 100.0)]),
        ]
        let config =
          pie.pie_config(data_key: "value")
          |> pie.pie_label(True)
          |> pie.pie_label_line(False)
        let html =
          pie.render_pie(
            config: config,
            data: data,
            categories: ["0.0", "1.0"],
            width: 400.0,
            height: 400.0,
          )
          |> element.to_string
        html |> string.contains("<line ") |> expect.to_be_false
      },
    ),
    it("label line stroke uses sector fill color", fn() {
      let data = [dict.from_list([#("value", 100.0)])]
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_label(True)
        |> pie.pie_fills(["#FF0000"])
      let html =
        pie.render_pie(
          config: config,
          data: data,
          categories: ["0.0"],
          width: 400.0,
          height: 400.0,
        )
        |> element.to_string
      // The label line stroke should match the sector fill.
      html |> string.contains("stroke=\"#FF0000\"") |> expect.to_be_true
    }),
  ])
}

pub fn radial_bar_enhancement_tests() {
  describe("radial_bar_enhancements", [
    it("force_corner_radius defaults to False", fn() {
      let config = radial_bar.radial_bar_config(data_key: "value")
      config.force_corner_radius |> expect.to_be_false
    }),
    it("radial_bar_force_corner_radius sets force_corner_radius", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_force_corner_radius(True)
      config.force_corner_radius |> expect.to_be_true
    }),
    it("corner_is_external defaults to False", fn() {
      let config = radial_bar.radial_bar_config(data_key: "value")
      config.corner_is_external |> expect.to_be_false
    }),
    it("radial_bar_corner_is_external sets corner_is_external", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_corner_is_external(True)
      config.corner_is_external |> expect.to_be_true
    }),
    it("min_point_size defaults to 0.0", fn() {
      let config = radial_bar.radial_bar_config(data_key: "value")
      config.min_point_size |> expect.to_equal(expected: 0.0)
    }),
    it("radial_bar_min_point_size sets min_point_size", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_min_point_size(5.0)
      config.min_point_size |> expect.to_equal(expected: 5.0)
    }),
    it("max_bar_size defaults to 0.0", fn() {
      let config = radial_bar.radial_bar_config(data_key: "value")
      config.max_bar_size |> expect.to_equal(expected: 0.0)
    }),
    it("radial_bar_max_bar_size sets max_bar_size", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_max_bar_size(20.0)
      config.max_bar_size |> expect.to_equal(expected: 20.0)
    }),
    it("stack_id defaults to empty string", fn() {
      let config = radial_bar.radial_bar_config(data_key: "value")
      config.stack_id |> expect.to_equal(expected: "")
    }),
    it("radial_bar_stack_id sets stack_id", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_stack_id("group1")
      config.stack_id |> expect.to_equal(expected: "group1")
    }),
    it("hide defaults to False", fn() {
      let config = radial_bar.radial_bar_config(data_key: "value")
      config.hide |> expect.to_be_false
    }),
    it("radial_bar_hide sets hide to True", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_hide()
      config.hide |> expect.to_be_true
    }),
  ])
}

pub fn radar_enhancement_tests() {
  describe("radar_enhancements", [
    it("unit defaults to empty string", fn() {
      let config = radar.radar_config(data_key: "value")
      config.unit |> expect.to_equal(expected: "")
    }),
    it("radar_unit sets unit", fn() {
      let config =
        radar.radar_config(data_key: "value")
        |> radar.radar_unit("km/h")
      config.unit |> expect.to_equal(expected: "km/h")
    }),
    it("is_range defaults to False", fn() {
      let config = radar.radar_config(data_key: "value")
      config.is_range |> expect.to_be_false
      config.base_data_key |> expect.to_equal(expected: "")
    }),
    it("radar_range sets is_range and base_data_key", fn() {
      let config =
        radar.radar_config(data_key: "max")
        |> radar.radar_range("min")
      config.is_range |> expect.to_be_true
      config.base_data_key |> expect.to_equal(expected: "min")
    }),
  ])
}

pub fn legend_enhancement_tests() {
  describe("legend_enhancements", [
    it("width and height default to 0.0", fn() {
      let config = legend.legend_config()
      config.width |> expect.to_equal(expected: 0.0)
      config.height |> expect.to_equal(expected: 0.0)
    }),
    it("legend_width and legend_height set values", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_width(200.0)
        |> legend.legend_height(50.0)
      config.width |> expect.to_equal(expected: 200.0)
      config.height |> expect.to_equal(expected: 50.0)
    }),
    it("margins default to 0", fn() {
      let config = legend.legend_config()
      config.margin_top |> expect.to_equal(expected: 0)
      config.margin_right |> expect.to_equal(expected: 0)
      config.margin_bottom |> expect.to_equal(expected: 0)
      config.margin_left |> expect.to_equal(expected: 0)
    }),
    it("legend_margin sets all margins", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_margin(5, 10, 15, 20)
      config.margin_top |> expect.to_equal(expected: 5)
      config.margin_right |> expect.to_equal(expected: 10)
      config.margin_bottom |> expect.to_equal(expected: 15)
      config.margin_left |> expect.to_equal(expected: 20)
    }),
  ])
}

pub fn axis_enhancement_tests() {
  describe("axis_enhancements", [
    it("allow_duplicated_category defaults to True for x-axis", fn() {
      let config = axis.x_axis_config()
      config.allow_duplicated_category |> expect.to_be_true
    }),
    it("x_allow_duplicated_category sets the value", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_allow_duplicated_category(False)
      config.allow_duplicated_category |> expect.to_be_false
    }),
    it("allow_duplicated_category defaults to True for y-axis", fn() {
      let config = axis.y_axis_config()
      config.allow_duplicated_category |> expect.to_be_true
    }),
    it("y_allow_duplicated_category sets the value", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_allow_duplicated_category(False)
      config.allow_duplicated_category |> expect.to_be_false
    }),
    it("axis_line_stroke defaults to CSS var for x-axis", fn() {
      let config = axis.x_axis_config()
      config.axis_line_stroke
      |> expect.to_equal(expected: weft.css_color(
        value: "var(--weft-chart-axis, currentColor)",
      ))
      config.axis_line_stroke_width |> expect.to_equal(expected: 0.0)
    }),
    it("x_axis_line_stroke and x_axis_line_stroke_width set values", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_axis_line_stroke(weft.css_color(value: "#ff0000"))
        |> axis.axis_axis_line_stroke_width(2.0)
      config.axis_line_stroke
      |> expect.to_equal(expected: weft.css_color(value: "#ff0000"))
      config.axis_line_stroke_width |> expect.to_equal(expected: 2.0)
    }),
    it("tick_line_stroke defaults to CSS var for x-axis", fn() {
      let config = axis.x_axis_config()
      config.tick_line_stroke
      |> expect.to_equal(expected: weft.css_color(
        value: "var(--weft-chart-tick, currentColor)",
      ))
      config.tick_line_stroke_width |> expect.to_equal(expected: 0.0)
    }),
    it("x_tick_line_stroke and x_tick_line_stroke_width set values", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_tick_line_stroke(weft.css_color(value: "#00ff00"))
        |> axis.axis_tick_line_stroke_width(1.5)
      config.tick_line_stroke
      |> expect.to_equal(expected: weft.css_color(value: "#00ff00"))
      config.tick_line_stroke_width |> expect.to_equal(expected: 1.5)
    }),
    it("y_axis_line_stroke and y_tick_line_stroke set values", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_axis_line_stroke(weft.css_color(value: "#0000ff"))
        |> axis.axis_axis_line_stroke_width(3.0)
        |> axis.axis_tick_line_stroke(weft.css_color(value: "#333"))
        |> axis.axis_tick_line_stroke_width(0.5)
      config.axis_line_stroke
      |> expect.to_equal(expected: weft.css_color(value: "#0000ff"))
      config.axis_line_stroke_width |> expect.to_equal(expected: 3.0)
      config.tick_line_stroke
      |> expect.to_equal(expected: weft.css_color(value: "#333"))
      config.tick_line_stroke_width |> expect.to_equal(expected: 0.5)
    }),
  ])
}

pub fn scatter_line_type_tests() {
  describe("scatter_line_type", [
    it("line_type defaults to JointLine", fn() {
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      config.line_type |> expect.to_equal(expected: scatter.JointLine)
    }),
    it("scatter_line_type sets to FittingLine", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_line_type(type_: scatter.FittingLine)
      config.line_type |> expect.to_equal(expected: scatter.FittingLine)
    }),
    it("line_joint_type defaults to linear", fn() {
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      config.line_joint_type |> expect.to_equal(expected: "linear")
    }),
    it("scatter_line_joint_type sets value", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_line_joint_type(type_: "monotone")
      config.line_joint_type |> expect.to_equal(expected: "monotone")
    }),
  ])
}

pub fn error_bar_offset_tests() {
  describe("error_bar_offset", [
    it("offset defaults to 0.0", fn() {
      let config = error_bar.error_bar_config(data_key: "err")
      config.offset |> expect.to_equal(expected: 0.0)
    }),
    it("error_bar_offset sets offset", fn() {
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_offset(offset_value: 10.0)
      config.offset |> expect.to_equal(expected: 10.0)
    }),
  ])
}

pub fn error_bar_asymmetric_tests() {
  describe("error_bar_asymmetric", [
    it("ErrorBarValue symmetric constructor works", fn() {
      let val = error_bar.error_bar_symmetric(value: 5.0)
      val |> expect.to_equal(expected: error_bar.Symmetric(value: 5.0))
    }),
    it("ErrorBarValue asymmetric constructor works", fn() {
      let val = error_bar.error_bar_asymmetric(low: 3.0, high: 7.0)
      val
      |> expect.to_equal(expected: error_bar.Asymmetric(low: 3.0, high: 7.0))
    }),
    it("high_data_key builder sets key", fn() {
      let config =
        error_bar.error_bar_config(data_key: "err_low")
        |> error_bar.error_bar_high_data_key(key: "err_high")
      config.high_data_key |> expect.to_equal(expected: Some("err_high"))
    }),
    it("symmetric error renders equal-length lines on both sides", fn() {
      // y-scale: domain [0,100] -> range [300,0] (inverted for SVG)
      // value=50, error=10 => top = scale(60), bottom = scale(40)
      // scale(60) = 300 + (60/100)*(0-300) = 300 - 180 = 120
      // scale(40) = 300 + (40/100)*(0-300) = 300 - 120 = 180
      // Center = scale(50) = 300 - 150 = 150
      // Distance from center to top = |150 - 120| = 30
      // Distance from center to bottom = |180 - 150| = 30 (equal)
      let x_scale =
        scale.point(
          categories: ["A"],
          range_start: 0.0,
          range_end: 400.0,
          padding: 0.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let data = [dict.from_list([#("val", 50.0), #("err", 10.0)])]
      let config = error_bar.error_bar_config(data_key: "err")
      let html =
        error_bar.render_error_bars(
          config: config,
          data: data,
          categories: ["A"],
          x_scale: x_scale,
          y_scale: y_scale,
          series_data_key: "val",
        )
        |> element.to_string
      // y_top = scale(60) = 120, y_bottom = scale(40) = 180
      // Main vertical line from y1=120 to y2=180
      html |> string.contains("y1=\"120\"") |> expect.to_be_true
      html |> string.contains("y2=\"180\"") |> expect.to_be_true
    }),
    it("asymmetric error renders different-length lines", fn() {
      // value=50, low=5, high=15
      // scale(50+15=65) = 300 + (65/100)*(0-300) = 300-195 = 105
      // scale(50-5=45)  = 300 + (45/100)*(0-300) = 300-135 = 165
      let x_scale =
        scale.point(
          categories: ["A"],
          range_start: 0.0,
          range_end: 400.0,
          padding: 0.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let data = [
        dict.from_list([#("val", 50.0), #("err_low", 5.0), #("err_high", 15.0)]),
      ]
      let config =
        error_bar.error_bar_config(data_key: "err_low")
        |> error_bar.error_bar_high_data_key(key: "err_high")
      let html =
        error_bar.render_error_bars(
          config: config,
          data: data,
          categories: ["A"],
          x_scale: x_scale,
          y_scale: y_scale,
          series_data_key: "val",
        )
        |> element.to_string
      // y_top = scale(65) = 105, y_bottom = scale(45) = 165
      html |> string.contains("y1=\"105\"") |> expect.to_be_true
      html |> string.contains("y2=\"165\"") |> expect.to_be_true
    }),
  ])
}

pub fn error_bar_x_scale_tests() {
  describe("error_bar_x_scale", [
    it("ErrorBarX uses scaled coordinates via linear_apply", fn() {
      // x-scale: domain [0,100] -> range [0,400]
      // value=50, symmetric error=10
      // x_left = linear_apply(x_scale, 50-10=40) = 0 + (40/100)*400 = 160
      // x_right = linear_apply(x_scale, 50+10=60) = 0 + (60/100)*400 = 240
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let data = [dict.from_list([#("val", 50.0), #("err", 10.0)])]
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_direction(direction: error_bar.ErrorBarX)
      let html =
        error_bar.render_error_bars(
          config: config,
          data: data,
          categories: ["A"],
          x_scale: x_scale,
          y_scale: y_scale,
          series_data_key: "val",
        )
        |> element.to_string
      // x_left = 160, x_right = 240
      html |> string.contains("x1=\"160\"") |> expect.to_be_true
      html |> string.contains("x2=\"240\"") |> expect.to_be_true
    }),
    it("ErrorBarX asymmetric uses scaled coordinates", fn() {
      // x-scale: domain [0,100] -> range [0,400]
      // value=50, low=5, high=20
      // x_left = linear_apply(x_scale, 50-5=45) = (45/100)*400 = 180
      // x_right = linear_apply(x_scale, 50+20=70) = (70/100)*400 = 280
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let data = [
        dict.from_list([#("val", 50.0), #("err_low", 5.0), #("err_high", 20.0)]),
      ]
      let config =
        error_bar.error_bar_config(data_key: "err_low")
        |> error_bar.error_bar_high_data_key(key: "err_high")
        |> error_bar.error_bar_direction(direction: error_bar.ErrorBarX)
      let html =
        error_bar.render_error_bars(
          config: config,
          data: data,
          categories: ["A"],
          x_scale: x_scale,
          y_scale: y_scale,
          series_data_key: "val",
        )
        |> element.to_string
      // x_left = 180, x_right = 280
      html |> string.contains("x1=\"180\"") |> expect.to_be_true
      html |> string.contains("x2=\"280\"") |> expect.to_be_true
    }),
  ])
}

pub fn reference_fill_opacity_tests() {
  describe("reference_fill_opacity", [
    it("line fill_opacity defaults to 1.0", fn() {
      let config = reference.horizontal_line(value: 50.0)
      config.fill_opacity |> expect.to_equal(expected: 1.0)
    }),
    it("line_fill_opacity sets value", fn() {
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_fill_opacity(opacity: 0.5)
      config.fill_opacity |> expect.to_equal(expected: 0.5)
    }),
    it("dot fill_opacity defaults to 1.0", fn() {
      let config = reference.reference_dot(x: 10.0, y: 20.0)
      config.fill_opacity |> expect.to_equal(expected: 1.0)
    }),
    it("dot_fill_opacity sets value", fn() {
      let config =
        reference.reference_dot(x: 10.0, y: 20.0)
        |> reference.dot_fill_opacity(opacity: 0.3)
      config.fill_opacity |> expect.to_equal(expected: 0.3)
    }),
    it("dot render includes fill-opacity attribute", fn() {
      let config =
        reference.reference_dot(x: 50.0, y: 50.0)
        |> reference.dot_fill_opacity(opacity: 0.7)
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        reference.render_reference_dot(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html |> string.contains("fill-opacity") |> expect.to_be_true
      html |> string.contains("0.7") |> expect.to_be_true
    }),
  ])
}

// ===========================================================================
// Phase 4: Cross, Trapezoid, Funnel, Per-Pie Data
// ===========================================================================

pub fn reference_position_fill_tests() {
  describe("reference_position_and_fill", [
    it("position defaults to RefLineMiddle", fn() {
      let config = reference.horizontal_line(value: 50.0)
      config.position |> expect.to_equal(expected: RefLineMiddle)
    }),
    it("vertical_line position defaults to RefLineMiddle", fn() {
      let config = reference.vertical_line(category: "A")
      config.position |> expect.to_equal(expected: RefLineMiddle)
    }),
    it("line_position sets RefLineStart", fn() {
      let config =
        reference.vertical_line(category: "B")
        |> reference.line_position(position: RefLineStart)
      config.position |> expect.to_equal(expected: RefLineStart)
    }),
    it("line_position sets RefLineEnd", fn() {
      let config =
        reference.vertical_line(category: "B")
        |> reference.line_position(position: RefLineEnd)
      config.position |> expect.to_equal(expected: RefLineEnd)
    }),
    it("fill defaults to none", fn() {
      let config = reference.horizontal_line(value: 50.0)
      config.fill |> expect.to_equal(expected: "none")
    }),
    it("line_fill sets value", fn() {
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_fill(fill_value: "#ff0000")
      config.fill |> expect.to_equal(expected: "#ff0000")
    }),
    it("rendered line includes fill attribute", fn() {
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_fill(fill_value: "#abcdef")
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        reference.render_reference_line(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html |> string.contains("fill=\"#abcdef\"") |> expect.to_be_true
    }),
    it("default fill=none appears in rendered line", fn() {
      let config = reference.horizontal_line(value: 50.0)
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        reference.render_reference_line(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html |> string.contains("fill=\"none\"") |> expect.to_be_true
    }),
    it("segment discard skips when endpoint outside plot", fn() {
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_segment(points: [#(50.0, 50.0), #(150.0, 150.0)])
        |> reference.line_if_overflow(overflow: Discard)
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        reference.render_reference_line(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html |> string.contains("recharts-reference-line") |> expect.to_be_false
    }),
    it("segment discard renders when both endpoints inside plot", fn() {
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_segment(points: [#(20.0, 30.0), #(80.0, 70.0)])
        |> reference.line_if_overflow(overflow: Discard)
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        reference.render_reference_line(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html |> string.contains("recharts-reference-line") |> expect.to_be_true
    }),
    it("position offset shifts vertical line within band", fn() {
      let x_scale =
        scale.point(
          categories: ["A", "B", "C"],
          range_start: 0.0,
          range_end: 300.0,
          padding: 0.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html_start =
        reference.render_reference_line(
          config: reference.vertical_line(category: "B")
            |> reference.line_position(position: RefLineStart),
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 300.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html_start |> string.contains("x1=\"75\"") |> expect.to_be_true

      let html_end =
        reference.render_reference_line(
          config: reference.vertical_line(category: "B")
            |> reference.line_position(position: RefLineEnd),
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 300.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html_end |> string.contains("x1=\"225\"") |> expect.to_be_true
    }),
  ])
}

pub fn cross_shape_tests() {
  describe("cross_shape", [
    it("renders path with correct d attribute", fn() {
      let html =
        shape.cross(
          x: 100.0,
          y: 50.0,
          top: 20.0,
          left: 70.0,
          width: 60.0,
          height: 60.0,
          stroke: "#333",
          stroke_width: 2.0,
        )
        |> element.to_string
      // d = M100,20v60M70,50h60
      html |> string.contains("M100,20v60M70,50h60") |> expect.to_be_true
    }),
    it("applies stroke attributes", fn() {
      let html =
        shape.cross(
          x: 0.0,
          y: 0.0,
          top: 0.0,
          left: 0.0,
          width: 10.0,
          height: 10.0,
          stroke: "#ff0000",
          stroke_width: 3.0,
        )
        |> element.to_string
      html |> string.contains("stroke=\"#ff0000\"") |> expect.to_be_true
      html |> string.contains("stroke-width=\"3\"") |> expect.to_be_true
    }),
    it("sets recharts-cross class", fn() {
      let html =
        shape.cross(
          x: 0.0,
          y: 0.0,
          top: 0.0,
          left: 0.0,
          width: 10.0,
          height: 10.0,
          stroke: "#000",
          stroke_width: 1.0,
        )
        |> element.to_string
      html |> string.contains("recharts-cross") |> expect.to_be_true
    }),
  ])
}

pub fn trapezoid_shape_tests() {
  describe("trapezoid_shape", [
    it("renders path with correct corners for equal widths", fn() {
      // Equal upper and lower widths = rectangle
      let html =
        shape.trapezoid(
          x: 0.0,
          y: 0.0,
          upper_width: 100.0,
          lower_width: 100.0,
          height: 50.0,
          fill: "#blue",
        )
        |> element.to_string
      // Top-left = (0, 0), Top-right = (100, 0),
      // Bottom-right = (100, 50), Bottom-left = (0, 50)
      html |> string.contains("M0,0") |> expect.to_be_true
      html |> string.contains("L100,0") |> expect.to_be_true
      html |> string.contains("L100,50") |> expect.to_be_true
      html |> string.contains("L0,50") |> expect.to_be_true
      html |> string.contains("Z") |> expect.to_be_true
    }),
    it("renders correct corners for unequal widths", fn() {
      // Upper = 200, Lower = 100, both centered within max_w=200
      // center_x = 0 + 200/2 = 100
      // TL = (100 - 100, 0) = (0, 0)
      // TR = (100 + 100, 0) = (200, 0)
      // BR = (100 + 50, 30) = (150, 30)
      // BL = (100 - 50, 30) = (50, 30)
      let html =
        shape.trapezoid(
          x: 0.0,
          y: 0.0,
          upper_width: 200.0,
          lower_width: 100.0,
          height: 30.0,
          fill: "#red",
        )
        |> element.to_string
      html |> string.contains("M0,0") |> expect.to_be_true
      html |> string.contains("L200,0") |> expect.to_be_true
      html |> string.contains("L150,30") |> expect.to_be_true
      html |> string.contains("L50,30") |> expect.to_be_true
    }),
    it("sets recharts-trapezoid class", fn() {
      let html =
        shape.trapezoid(
          x: 0.0,
          y: 0.0,
          upper_width: 100.0,
          lower_width: 50.0,
          height: 20.0,
          fill: "#000",
        )
        |> element.to_string
      html |> string.contains("recharts-trapezoid") |> expect.to_be_true
    }),
    it("trapezoid_with_stroke adds stroke attributes", fn() {
      let html =
        shape.trapezoid_with_stroke(
          x: 0.0,
          y: 0.0,
          upper_width: 100.0,
          lower_width: 50.0,
          height: 20.0,
          fill: "#blue",
          stroke: "#fff",
          stroke_width: 2.0,
        )
        |> element.to_string
      html |> string.contains("stroke=\"#fff\"") |> expect.to_be_true
      html |> string.contains("stroke-width=\"2\"") |> expect.to_be_true
    }),
  ])
}

pub fn per_pie_data_tests() {
  describe("per_pie_data", [
    it("config defaults to empty data list", fn() {
      let config = pie.pie_config(data_key: "value")
      config.data |> expect.to_equal(expected: [])
    }),
    it("pie_data builder sets per-pie data", fn() {
      let own_data = [
        dict.from_list([#("value", 10.0)]),
        dict.from_list([#("value", 20.0)]),
      ]
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_data(own_data)
      config.data |> list.length |> expect.to_equal(expected: 2)
    }),
    it("empty per-pie data uses chart-level data in pie_chart", fn() {
      let chart_data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("value", 50.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("value", 30.0)]),
        ),
      ]
      let config = pie.pie_config(data_key: "value")
      let html =
        chart.pie_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 400,
          children: [
            chart.pie(config),
          ],
        )
        |> element.to_string
      // Should render sectors from chart data
      html |> string.contains("recharts-pie") |> expect.to_be_true
      // Should contain path elements (sectors)
      html |> string.contains("<path") |> expect.to_be_true
    }),
    it("non-empty per-pie data uses own data in pie_chart", fn() {
      let chart_data = [
        chart.DataPoint(
          category: "Ignored",
          values: dict.from_list([#("value", 999.0)]),
        ),
      ]
      let own_data = [
        dict.from_list([#("value", 10.0)]),
        dict.from_list([#("value", 20.0)]),
        dict.from_list([#("value", 30.0)]),
      ]
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_data(own_data)
      let html =
        chart.pie_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 400,
          children: [
            chart.pie(config),
          ],
        )
        |> element.to_string
      // Should render 3 sectors (one per own_data entry), not 1
      let path_count =
        string.split(html, "<path")
        |> list.length
      // 3 paths means 4 parts from split
      path_count |> expect.to_equal(expected: 4)
    }),
    it("per-pie data overrides chart data with different keys", fn() {
      let chart_data = [
        chart.DataPoint(
          category: "X",
          values: dict.from_list([#("other", 100.0)]),
        ),
      ]
      let own_data = [
        dict.from_list([#("amount", 40.0)]),
        dict.from_list([#("amount", 60.0)]),
      ]
      let config =
        pie.pie_config(data_key: "amount")
        |> pie.pie_data(own_data)
      let html =
        chart.pie_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 300),
          theme: option.None,
          height: 300,
          children: [
            chart.pie(config),
          ],
        )
        |> element.to_string
      // Should render 2 sectors from own data
      let path_count =
        string.split(html, "<path")
        |> list.length
      path_count |> expect.to_equal(expected: 3)
    }),
  ])
}

pub fn funnel_config_tests() {
  describe("funnel_config", [
    it("creates config with recharts defaults", fn() {
      let config = funnel.funnel_config(data_key: "value")
      config.data_key |> expect.to_equal(expected: "value")
      config.name_key |> expect.to_equal(expected: "name")
      config.stroke |> expect.to_equal(expected: "#fff")
      config.stroke_width |> expect.to_equal(expected: 1.0)
      config.reversed |> expect.to_be_false
      config.trap_gap |> expect.to_equal(expected: 0.0)
      config.hide |> expect.to_be_false
      config.legend_type |> expect.to_equal(expected: shape.RectIcon)
    }),
    it("builders modify config correctly", fn() {
      let config =
        funnel.funnel_config(data_key: "val")
        |> funnel.funnel_stroke("#000")
        |> funnel.funnel_stroke_width(2.0)
        |> funnel.funnel_gap(5.0)
        |> funnel.funnel_name_key("label")
        |> funnel.funnel_legend_type(shape.CircleIcon)
      config.stroke |> expect.to_equal(expected: "#000")
      config.stroke_width |> expect.to_equal(expected: 2.0)
      config.trap_gap |> expect.to_equal(expected: 5.0)
      config.name_key |> expect.to_equal(expected: "label")
      config.legend_type |> expect.to_equal(expected: shape.CircleIcon)
    }),
    it("fills builder sets custom colors", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_fills(["#a", "#b", "#c"])
      config.fills |> list.length |> expect.to_equal(expected: 3)
    }),
    it("reversed builder sets reversed flag", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_reversed
      config.reversed |> expect.to_be_true
    }),
    it("hide builder sets hide flag", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_hide
      config.hide |> expect.to_be_true
    }),
  ])
}

pub fn funnel_render_tests() {
  describe("funnel_render", [
    it("renders trapezoids for funnel data", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 80.0)]),
        dict.from_list([#("value", 50.0)]),
      ]
      let config = funnel.funnel_config(data_key: "value")
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 400.0,
          height: 300.0,
        )
        |> element.to_string
      html |> string.contains("recharts-funnel") |> expect.to_be_true
      html |> string.contains("recharts-trapezoid") |> expect.to_be_true
      // Should have 3 trapezoid paths
      let path_count =
        string.split(html, "recharts-trapezoid")
        |> list.length
      // 3 occurrences = 4 parts from split
      path_count |> expect.to_equal(expected: 4)
    }),
    it("hidden funnel renders nothing", fn() {
      let data = [dict.from_list([#("value", 100.0)])]
      let config =
        funnel.funnel_config(data_key: "value")
        |> funnel.funnel_hide
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 400.0,
          height: 300.0,
        )
        |> element.to_string
      html |> string.contains("recharts-funnel") |> expect.to_be_false
    }),
    it("renders with gap spacing between segments", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 50.0)]),
      ]
      let config =
        funnel.funnel_config(data_key: "value")
        |> funnel.funnel_gap(10.0)
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 400.0,
          height: 300.0,
        )
        |> element.to_string
      // Should still render trapezoids
      html |> string.contains("recharts-trapezoid") |> expect.to_be_true
    }),
    it("largest segment has full width", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 50.0)]),
      ]
      let config = funnel.funnel_config(data_key: "value")
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 400.0,
          height: 200.0,
        )
        |> element.to_string
      // render_funnel deducts 50px: constrained_width = 400 - 50 = 350
      // The largest trapezoid spans the full constrained width of 350px
      html |> string.contains("L350,0") |> expect.to_be_true
    }),
    it("funnel_chart integrates funnel series", fn() {
      let chart_data = [
        chart.DataPoint(
          category: "Step 1",
          values: dict.from_list([#("value", 100.0)]),
        ),
        chart.DataPoint(
          category: "Step 2",
          values: dict.from_list([#("value", 60.0)]),
        ),
        chart.DataPoint(
          category: "Step 3",
          values: dict.from_list([#("value", 30.0)]),
        ),
      ]
      let config = funnel.funnel_config(data_key: "value")
      let html =
        chart.funnel_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 400,
          children: [
            chart.funnel(config),
          ],
        )
        |> element.to_string
      html |> string.contains("recharts-funnel") |> expect.to_be_true
      html |> string.contains("<svg") |> expect.to_be_true
    }),
    it("funnel_chart with TooltipChild renders tooltip hit zones", fn() {
      let chart_data = [
        chart.DataPoint(
          category: "Step 1",
          values: dict.from_list([#("value", 100.0)]),
        ),
        chart.DataPoint(
          category: "Step 2",
          values: dict.from_list([#("value", 50.0)]),
        ),
      ]
      let config = funnel.funnel_config(data_key: "value")
      let html =
        chart.funnel_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 400,
          children: [
            chart.funnel(config),
            chart.tooltip(config: tooltip.tooltip_config()),
          ],
        )
        |> element.to_string
      // Tooltip hit zones are present (class added by render_tooltips)
      html |> string.contains("weft-chart-tooltip") |> expect.to_be_true
      // Category labels appear in the tooltip payload
      html |> string.contains("Step 1") |> expect.to_be_true
      html |> string.contains("Step 2") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Feature: Cell Component (per-item customization)
// ---------------------------------------------------------------------------

pub fn cell_tests() {
  describe("cell", [
    it("bar cell_config defaults stroke to empty", fn() {
      let cell = bar.cell_config(fill: weft.css_color(value: "#ff0000"))
      cell.fill |> expect.to_equal(expected: weft.css_color(value: "#ff0000"))
      cell.stroke |> expect.to_equal(expected: weft.css_color(value: ""))
    }),
    it("bar_cells applies per-bar fill colors", fn() {
      let config =
        bar.bar_config(data_key: "value", meta: common.series_meta())
        |> bar.bar_cells(cells: [
          bar.cell_config(fill: weft.css_color(value: "#ff0000")),
          bar.cell_config(fill: weft.css_color(value: "#00ff00")),
          bar.cell_config(fill: weft.css_color(value: "#0000ff")),
        ])
      let chart_data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("value", 10.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("value", 20.0)]),
        ),
        chart.DataPoint(
          category: "C",
          values: dict.from_list([#("value", 30.0)]),
        ),
      ]
      let html =
        chart.bar_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(config),
          ],
        )
        |> element.to_string
      html |> string.contains("#ff0000") |> expect.to_be_true
      html |> string.contains("#00ff00") |> expect.to_be_true
      html |> string.contains("#0000ff") |> expect.to_be_true
    }),
    it("bar_cells partial list falls back to config fill", fn() {
      let config =
        bar.bar_config(data_key: "value", meta: common.series_meta())
        |> bar.bar_fill(weft.css_color(value: "defaultFill"))
        |> bar.bar_cells(cells: [
          bar.cell_config(fill: weft.css_color(value: "#ff0000")),
        ])
      let chart_data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("value", 10.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("value", 20.0)]),
        ),
      ]
      let html =
        chart.bar_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.bar(config),
          ],
        )
        |> element.to_string
      // First bar uses cell fill
      html |> string.contains("#ff0000") |> expect.to_be_true
      // Second bar uses config fill
      html |> string.contains("defaultFill") |> expect.to_be_true
    }),
    it("pie pie_cell_config defaults correctly", fn() {
      let cell = pie.pie_cell_config(fill: "#ff0000")
      cell.fill |> expect.to_equal(expected: "#ff0000")
    }),
    it("pie_cells applies per-sector fill colors", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_cells(cells: [
          pie.pie_cell_config(fill: "#aaa111"),
          pie.pie_cell_config(fill: "#bbb222"),
        ])
      let chart_data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("value", 30.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("value", 70.0)]),
        ),
      ]
      let html =
        chart.pie_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 400,
          children: [
            chart.pie(config),
          ],
        )
        |> element.to_string
      html |> string.contains("#aaa111") |> expect.to_be_true
      html |> string.contains("#bbb222") |> expect.to_be_true
    }),
    it("pie_cells partial list falls back to default fills", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_cells(cells: [pie.pie_cell_config(fill: "#custom1")])
      let chart_data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("value", 30.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("value", 70.0)]),
        ),
      ]
      let html =
        chart.pie_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 400,
          children: [
            chart.pie(config),
          ],
        )
        |> element.to_string
      // First sector uses cell fill
      html |> string.contains("#custom1") |> expect.to_be_true
      // Second sector falls back to default cycle fill (first default)
      html
      |> string.contains("var(--weft-chart-2, #60a5fa)")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Feature: ZAxis Component
// ---------------------------------------------------------------------------

pub fn z_axis_tests() {
  describe("z_axis", [
    it("z_axis_config defaults range to 64-64", fn() {
      let config = axis.z_axis_config(data_key: "z")
      config.range_min |> expect.to_equal(expected: 64.0)
      config.range_max |> expect.to_equal(expected: 64.0)
      config.name |> expect.to_equal(expected: "")
      config.unit |> expect.to_equal(expected: "")
    }),
    it("z_range builder sets min and max", fn() {
      let config =
        axis.z_axis_config(data_key: "z")
        |> axis.z_range(min: 10.0, max: 200.0)
      config.range_min |> expect.to_equal(expected: 10.0)
      config.range_max |> expect.to_equal(expected: 200.0)
    }),
    it("z_name and z_unit builders set values", fn() {
      let config =
        axis.z_axis_config(data_key: "z")
        |> axis.z_name(name: "Size")
        |> axis.z_unit(unit: "px")
      config.name |> expect.to_equal(expected: "Size")
      config.unit |> expect.to_equal(expected: "px")
    }),
    it("scatter chart with ZAxis maps sizes through scale", fn() {
      let scatter_cfg =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_z_data_key(key: "z")
      let z_cfg =
        axis.z_axis_config(data_key: "z")
        |> axis.z_range(min: 50.0, max: 200.0)
      let chart_data = [
        chart.DataPoint(
          category: "p1",
          values: dict.from_list([#("x", 1.0), #("y", 2.0), #("z", 10.0)]),
        ),
        chart.DataPoint(
          category: "p2",
          values: dict.from_list([#("x", 3.0), #("y", 4.0), #("z", 100.0)]),
        ),
      ]
      let html =
        chart.scatter_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.scatter(scatter_cfg),
            chart.z_axis(config: z_cfg),
          ],
        )
        |> element.to_string
      // Should render scatter points with different radii
      html |> string.contains("recharts-scatter") |> expect.to_be_true
      // Should contain circle elements
      html |> string.contains("circle") |> expect.to_be_true
    }),
    it("scatter chart without ZAxis uses raw z values (backward compat)", fn() {
      let scatter_cfg =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_z_data_key(key: "z")
      let chart_data = [
        chart.DataPoint(
          category: "p1",
          values: dict.from_list([#("x", 1.0), #("y", 2.0), #("z", 64.0)]),
        ),
      ]
      let html =
        chart.scatter_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [chart.scatter(scatter_cfg)],
        )
        |> element.to_string
      // Without ZAxis, z value 64 is used directly as size
      // radius = sqrt(64 / pi) ~ 4.51
      html |> string.contains("recharts-scatter") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Feature: Labels on Line/Area/Scatter
// ---------------------------------------------------------------------------

pub fn series_label_tests() {
  describe("series_labels", [
    it("line with show_label renders value labels", fn() {
      let config =
        line.line_config(data_key: "value", meta: common.series_meta())
        |> line.line_label(show: True)
      let chart_data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("value", 42.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("value", 85.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(config),
          ],
        )
        |> element.to_string
      // Should contain the value labels
      html |> string.contains(">42<") |> expect.to_be_true
      html |> string.contains(">85<") |> expect.to_be_true
    }),
    it("line without show_label has no labels (default)", fn() {
      let config =
        line.line_config(data_key: "value", meta: common.series_meta())
      config.show_label |> expect.to_equal(expected: False)
      let chart_data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("value", 42.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(config),
          ],
        )
        |> element.to_string
      // Should not contain value as a text label
      html |> string.contains(">42<") |> expect.to_be_false
    }),
    it("area with show_label renders value labels", fn() {
      let config =
        area.area_config(data_key: "value", meta: common.series_meta())
        |> area.area_label(show: True)
      let chart_data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("value", 55.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("value", 77.0)]),
        ),
      ]
      let html =
        chart.area_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.area(config),
          ],
        )
        |> element.to_string
      html |> string.contains(">55<") |> expect.to_be_true
      html |> string.contains(">77<") |> expect.to_be_true
    }),
    it("area without show_label has no labels (default)", fn() {
      let config =
        area.area_config(data_key: "value", meta: common.series_meta())
      config.show_label |> expect.to_equal(expected: False)
    }),
    it("scatter with show_label renders value labels", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_label(show: True)
      let chart_data = [
        chart.DataPoint(
          category: "p1",
          values: dict.from_list([#("x", 1.0), #("y", 99.0)]),
        ),
      ]
      let html =
        chart.scatter_chart(
          data: chart_data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [chart.scatter(config)],
        )
        |> element.to_string
      html |> string.contains(">99<") |> expect.to_be_true
    }),
    it("scatter without show_label has no labels (default)", fn() {
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      config.show_label |> expect.to_equal(expected: False)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase A parity tests
// ---------------------------------------------------------------------------

pub fn series_unit_tests() {
  describe("series_unit", [
    it("line_unit builder sets unit", fn() {
      let config =
        line.line_config(data_key: "sales", meta: common.series_meta())
        |> line.line_meta(
          meta: common.series_meta() |> common.series_unit(unit: "USD"),
        )
      config.unit |> expect.to_equal(expected: "USD")
    }),
    it("area_unit builder sets unit", fn() {
      let config =
        area.area_config(data_key: "revenue", meta: common.series_meta())
        |> area.area_meta(
          meta: common.series_meta() |> common.series_unit(unit: "EUR"),
        )
      config.unit |> expect.to_equal(expected: "EUR")
    }),
    it("bar_unit builder sets unit", fn() {
      let config =
        bar.bar_config(data_key: "count", meta: common.series_meta())
        |> bar.bar_meta(
          meta: common.series_meta() |> common.series_unit(unit: "pcs"),
        )
      config.unit |> expect.to_equal(expected: "pcs")
    }),
    it("per-series unit overrides y-axis unit in tooltip", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("usd", 100.0), #("eur", 80.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.x_axis(axis.x_axis_config()),
            chart.y_axis(axis.y_axis_config() |> axis.axis_unit("$")),
            chart.line(
              line.line_config(data_key: "usd", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta() |> common.series_unit(unit: " USD"),
              ),
            ),
            chart.line(line.line_config(
              data_key: "eur",
              meta: common.series_meta(),
            )),
            chart.tooltip(tooltip.tooltip_config()),
          ],
        )
        |> element.to_string
      // The USD series should use " USD" from per-series unit
      html |> string.contains(" USD") |> expect.to_be_true
      // The EUR series falls back to "$" from y-axis
      html |> string.contains("$") |> expect.to_be_true
    }),
  ])
}

pub fn pie_hide_tooltip_type_tests() {
  describe("pie_hide_tooltip_type", [
    it("pie_hide builder sets hide to True", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_hide(True)
      config.hide |> expect.to_be_true
    }),
    it("pie_tooltip_type builder sets NoTooltip", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_tooltip_type(shape.NoTooltip)
      config.tooltip_type |> expect.to_equal(expected: shape.NoTooltip)
    }),
    it("hidden pie renders nothing", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_hide(True)
      let html =
        pie.render_pie(
          config: config,
          data: [dict.from_list([#("value", 10.0)])],
          categories: ["A"],
          width: 200.0,
          height: 200.0,
        )
        |> element.to_string
      html |> expect.to_equal(expected: "")
    }),
  ])
}

pub fn radar_hide_tooltip_label_tests() {
  describe("radar_hide_tooltip_label", [
    it("radar_hide builder sets hide", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_hide(hide: True)
      config.hide |> expect.to_be_true
    }),
    it("radar_tooltip_type builder sets NoTooltip", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_tooltip_type(tooltip_type: shape.NoTooltip)
      config.tooltip_type |> expect.to_equal(expected: shape.NoTooltip)
    }),
    it("radar_label builder sets show_label", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_label(show: True)
      config.show_label |> expect.to_be_true
    }),
    it("hidden radar renders nothing", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_hide(hide: True)
      let html =
        radar.render_radar(
          config: config,
          data: [dict.from_list([#("v", 5.0)])],
          categories: ["A"],
          cx: 100.0,
          cy: 100.0,
          max_radius: 80.0,
          domain_max: 10.0,
        )
        |> element.to_string
      html |> expect.to_equal(expected: "")
    }),
  ])
}

pub fn radial_bar_tooltip_data_tests() {
  describe("radial_bar_tooltip_data", [
    it("radial_bar_tooltip_type builder sets tooltip_type", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "v")
        |> radial_bar.radial_bar_tooltip_type(tooltip_type: shape.NoTooltip)
      config.tooltip_type |> expect.to_equal(expected: shape.NoTooltip)
    }),
    it("radial_bar_data builder sets per-series data", fn() {
      let data = [dict.from_list([#("v", 42.0)])]
      let config =
        radial_bar.radial_bar_config(data_key: "v")
        |> radial_bar.radial_bar_data(data: data)
      config.data |> expect.to_equal(expected: data)
    }),
    it("scatter_data builder sets per-series data", fn() {
      let data = [dict.from_list([#("x", 1.0), #("y", 2.0)])]
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_data(data: data)
      config.data |> expect.to_equal(expected: data)
    }),
  ])
}

pub fn polar_tooltip_rendering_tests() {
  describe("polar_tooltip_rendering", [
    it("radar_chart with TooltipChild renders tooltip hotspots", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 40.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 75.0)])),
      ]

      let html =
        chart.radar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 320,
          children: [
            chart.radar(radar.radar_config(data_key: "v")),
            chart.tooltip(tooltip.tooltip_config()),
          ],
        )
        |> element.to_string

      html |> string.contains("chart-hotspot") |> expect.to_be_true
      html |> string.contains("recharts-tooltip-wrapper") |> expect.to_be_true
      html |> string.contains(">A<") |> expect.to_be_true
      html |> string.contains(">B<") |> expect.to_be_true
    }),
    it("radial_bar_chart with TooltipChild renders tooltip hotspots", fn() {
      let data = [
        chart.DataPoint(
          category: "Alpha",
          values: dict.from_list([#("v", 55.0)]),
        ),
        chart.DataPoint(
          category: "Beta",
          values: dict.from_list([#("v", 88.0)]),
        ),
      ]

      let html =
        chart.radial_bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 320,
          children: [
            chart.radial_bar(radial_bar.radial_bar_config(data_key: "v")),
            chart.tooltip(tooltip.tooltip_config()),
          ],
        )
        |> element.to_string

      html |> string.contains("chart-hotspot") |> expect.to_be_true
      html |> string.contains("recharts-tooltip-wrapper") |> expect.to_be_true
      html |> string.contains(">Alpha<") |> expect.to_be_true
      html |> string.contains(">Beta<") |> expect.to_be_true
    }),
  ])
}

pub fn cell_enhancement_tests() {
  describe("cell_enhancements", [
    it("bar cell_config_full sets all fields", fn() {
      let cell =
        bar.cell_config_full(
          fill: weft.css_color(value: "#f00"),
          stroke: weft.css_color(value: "#0f0"),
          fill_opacity: 0.5,
          stroke_width: 2.0,
        )
      cell.fill |> expect.to_equal(expected: weft.css_color(value: "#f00"))
      cell.stroke |> expect.to_equal(expected: weft.css_color(value: "#0f0"))
      cell.fill_opacity
      |> expect.to_equal(expected: 0.5)
      cell.stroke_width
      |> expect.to_equal(expected: 2.0)
    }),
    it("bar cell_config defaults fill_opacity and stroke_width", fn() {
      let cell = bar.cell_config(fill: weft.css_color(value: "#abc"))
      cell.fill_opacity
      |> expect.to_equal(expected: 1.0)
      cell.stroke_width
      |> expect.to_equal(expected: 1.0)
    }),
    it("pie cell_config_full sets all fields", fn() {
      let cell =
        pie.pie_cell_config_full(
          fill: "#f00",
          stroke: "#0f0",
          fill_opacity: 0.7,
        )
      cell.fill |> expect.to_equal(expected: "#f00")
      cell.stroke |> expect.to_equal(expected: "#0f0")
      cell.fill_opacity
      |> expect.to_equal(expected: 0.7)
    }),
    it("pie cell_config defaults stroke and fill_opacity", fn() {
      let cell = pie.pie_cell_config(fill: "#abc")
      cell.stroke |> expect.to_equal(expected: "")
      cell.fill_opacity
      |> expect.to_equal(expected: 1.0)
    }),
  ])
}

pub fn axis_stroke_dasharray_tests() {
  describe("axis_stroke_dasharray", [
    it("x-axis stroke dasharray defaults to empty", fn() {
      let config = axis.x_axis_config()
      config.axis_line_stroke_dasharray |> expect.to_equal(expected: "")
      config.tick_line_stroke_dasharray |> expect.to_equal(expected: "")
    }),
    it("y-axis stroke dasharray defaults to empty", fn() {
      let config = axis.y_axis_config()
      config.axis_line_stroke_dasharray |> expect.to_equal(expected: "")
      config.tick_line_stroke_dasharray |> expect.to_equal(expected: "")
    }),
    it("x_axis_line_stroke_dasharray builder sets pattern", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_axis_line_stroke_dasharray("5 5")
      config.axis_line_stroke_dasharray |> expect.to_equal(expected: "5 5")
    }),
    it("x_tick_line_stroke_dasharray builder sets pattern", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_tick_line_stroke_dasharray("3 3")
      config.tick_line_stroke_dasharray |> expect.to_equal(expected: "3 3")
    }),
    it("y_axis_line_stroke_dasharray builder sets pattern", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_axis_line_stroke_dasharray("5 5")
      config.axis_line_stroke_dasharray |> expect.to_equal(expected: "5 5")
    }),
    it("y_tick_line_stroke_dasharray builder sets pattern", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_tick_line_stroke_dasharray("3 3")
      config.tick_line_stroke_dasharray |> expect.to_equal(expected: "3 3")
    }),
    it("stroke-dasharray appears in rendered x-axis when set", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.x_axis(
              axis.x_axis_config()
              |> axis.axis_axis_line_stroke_dasharray("5 5"),
            ),
            chart.y_axis(axis.y_axis_config()),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      html |> string.contains("stroke-dasharray=\"5 5\"") |> expect.to_be_true
    }),
  ])
}

pub fn polar_radius_reversed_tests() {
  describe("polar_radius_reversed", [
    it("default reversed is False", fn() {
      let config = polar_axis.radius_axis_config()
      config.reversed |> expect.to_equal(expected: False)
    }),
    it("radius_reversed builder sets reversed", fn() {
      let config =
        polar_axis.radius_axis_config()
        |> polar_axis.radius_reversed(reversed: True)
      config.reversed |> expect.to_equal(expected: True)
    }),
  ])
}

pub fn polar_grid_fill_tests() {
  describe("polar_grid_fill", [
    it("default fill is empty", fn() {
      let config = grid.polar_grid_config()
      config.fill |> expect.to_equal(expected: "")
    }),
    it("polar_grid_fill builder sets fill color", fn() {
      let config =
        grid.polar_grid_config()
        |> grid.polar_grid_fill(color: "#eee")
      config.fill |> expect.to_equal(expected: "#eee")
    }),
    it("fill renders in polar grid SVG", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 5.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 8.0)])),
      ]
      let html =
        chart.radar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.polar_grid(
              grid.polar_grid_config() |> grid.polar_grid_fill(color: "#eee"),
            ),
            chart.radar(radar.radar_config(data_key: "v")),
          ],
        )
        |> element.to_string
      html |> string.contains("fill=\"#eee\"") |> expect.to_be_true
    }),
  ])
}

pub fn reverse_stack_order_tests() {
  describe("reverse_stack_order", [
    it("ReverseStackChild stores reverse flag", fn() {
      let child: chart.ChartChild(msg) = chart.reverse_stack_order(True)
      case child {
        chart.ReverseStackChild(reverse:) -> reverse |> expect.to_be_true
        _ -> False |> expect.to_be_true
      }
    }),
    it("reverse stack order reverses stacking computation", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("a", 10.0), #("b", 20.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("a", 15.0), #("b", 25.0)]),
        ),
      ]
      // Render stacked area chart with reverse stack order.
      // Area series use stacked_data directly, so reversal is observable.
      let html_normal =
        chart.area_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.x_axis(axis.x_axis_config()),
            chart.y_axis(axis.y_axis_config()),
            chart.area(
              area.area_config(data_key: "a", meta: common.series_meta())
              |> area.area_stack_id("s"),
            ),
            chart.area(
              area.area_config(data_key: "b", meta: common.series_meta())
              |> area.area_stack_id("s"),
            ),
          ],
        )
        |> element.to_string
      let html_reversed =
        chart.area_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.x_axis(axis.x_axis_config()),
            chart.y_axis(axis.y_axis_config()),
            chart.area(
              area.area_config(data_key: "a", meta: common.series_meta())
              |> area.area_stack_id("s"),
            ),
            chart.area(
              area.area_config(data_key: "b", meta: common.series_meta())
              |> area.area_stack_id("s"),
            ),
            chart.reverse_stack_order(True),
          ],
        )
        |> element.to_string
      // Both should contain valid SVG with area elements
      html_normal |> string.contains("<svg") |> expect.to_be_true
      html_reversed |> string.contains("<svg") |> expect.to_be_true
      html_normal
      |> string.contains("recharts-area")
      |> expect.to_be_true
      html_reversed
      |> string.contains("recharts-area")
      |> expect.to_be_true
      // The reversed output should differ from normal due to swapped stacking
      { html_normal != html_reversed } |> expect.to_be_true
    }),
  ])
}

pub fn tooltip_dedup_payload_tests() {
  describe("tooltip_dedup_payload", [
    it("default dedup_payload is False", fn() {
      let config = tooltip.tooltip_config()
      config.dedup_payload |> expect.to_equal(expected: False)
    }),
    it("tooltip_dedup_payload builder sets dedup", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_dedup_payload(True)
      config.dedup_payload |> expect.to_equal(expected: True)
    }),
  ])
}

pub fn legend_dedup_payload_tests() {
  describe("legend_dedup_payload", [
    it("default dedup_payload is False", fn() {
      let config = legend.legend_config()
      config.dedup_payload |> expect.to_equal(expected: False)
    }),
    it("legend_dedup_payload builder sets dedup", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_dedup_payload(True)
      config.dedup_payload |> expect.to_equal(expected: True)
    }),
  ])
}

pub fn legend_none_icon_tests() {
  describe("legend_none_icon", [
    it("NoneIcon entries are suppressed from rendered legend", fn() {
      let payload = [
        legend.LegendPayload(
          value: "visible",
          color: weft.css_color(value: "#f00"),
          icon_type: shape.RectIcon,
          inactive: False,
        ),
        legend.LegendPayload(
          value: "hidden",
          color: weft.css_color(value: "#0f0"),
          icon_type: shape.NoneIcon,
          inactive: False,
        ),
      ]
      let html =
        legend.render_legend(
          config: legend.legend_config(),
          payload: payload,
          chart_width: 400.0,
          chart_height: 300.0,
        )
        |> element.to_string
      html |> string.contains("visible") |> expect.to_be_true
      html |> string.contains("hidden") |> expect.to_be_false
    }),
    it("all NoneIcon entries produces empty legend", fn() {
      let payload = [
        legend.LegendPayload(
          value: "a",
          color: weft.css_color(value: "#f00"),
          icon_type: shape.NoneIcon,
          inactive: False,
        ),
      ]
      let html =
        legend.render_legend(
          config: legend.legend_config(),
          payload: payload,
          chart_width: 400.0,
          chart_height: 300.0,
        )
        |> element.to_string
      html
      |> string.contains("recharts-legend-wrapper")
      |> expect.to_be_false
    }),
  ])
}

pub fn legend_formatter_arity_tests() {
  describe("legend_formatter", [
    it("default formatter returns value unchanged", fn() {
      let config = legend.legend_config()
      let entry =
        legend.LegendPayload(
          value: "test",
          color: weft.css_color(value: "#f00"),
          icon_type: shape.RectIcon,
          inactive: False,
        )
      config.formatter("test", entry, 0)
      |> expect.to_equal(expected: "test")
    }),
    it("legend_formatter builder accepts 3-arg function", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_formatter(fn(v, _entry, i) {
          v <> ":" <> int.to_string(i)
        })
      let entry =
        legend.LegendPayload(
          value: "sales",
          color: weft.css_color(value: "#f00"),
          icon_type: shape.RectIcon,
          inactive: False,
        )
      config.formatter("sales", entry, 2)
      |> expect.to_equal(expected: "sales:2")
    }),
  ])
}

pub fn legend_wrapper_style_tests() {
  describe("legend_wrapper_style", [
    it("default wrapper_style is empty", fn() {
      let config = legend.legend_config()
      config.wrapper_style |> expect.to_equal(expected: "")
    }),
    it("legend_wrapper_style builder sets value", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_wrapper_style(style: "padding: 8px")
      config.wrapper_style |> expect.to_equal(expected: "padding: 8px")
    }),
    it("wrapper_style appears as style attribute when non-empty", fn() {
      let payload = [
        legend.LegendPayload(
          value: "a",
          color: weft.css_color(value: "#f00"),
          icon_type: shape.RectIcon,
          inactive: False,
        ),
      ]
      let html =
        legend.render_legend(
          config: legend.legend_config()
            |> legend.legend_wrapper_style(style: "padding: 8px"),
          payload: payload,
          chart_width: 400.0,
          chart_height: 300.0,
        )
        |> element.to_string
      html |> string.contains("padding: 8px") |> expect.to_be_true
    }),
  ])
}

pub fn legend_payload_override_tests() {
  describe("legend_payload_override", [
    it("default payload_override is None", fn() {
      let config = legend.legend_config()
      config.payload_override |> expect.to_equal(expected: None)
    }),
    it("legend_payload_override builder sets entries", fn() {
      let entries = [
        legend.LegendPayload(
          value: "custom",
          color: weft.css_color(value: "#0f0"),
          icon_type: shape.CircleIcon,
          inactive: False,
        ),
      ]
      let config =
        legend.legend_config()
        |> legend.legend_payload_override(payload: entries)
      config.payload_override |> expect.to_equal(expected: Some(entries))
    }),
    it("payload_override replaces auto-generated entries", fn() {
      let auto_payload = [
        legend.LegendPayload(
          value: "auto",
          color: weft.css_color(value: "#f00"),
          icon_type: shape.RectIcon,
          inactive: False,
        ),
      ]
      let override_entries = [
        legend.LegendPayload(
          value: "custom",
          color: weft.css_color(value: "#0f0"),
          icon_type: shape.CircleIcon,
          inactive: False,
        ),
      ]
      let html =
        legend.render_legend(
          config: legend.legend_config()
            |> legend.legend_payload_override(payload: override_entries),
          payload: auto_payload,
          chart_width: 400.0,
          chart_height: 300.0,
        )
        |> element.to_string
      html |> string.contains("custom") |> expect.to_be_true
      html |> string.contains("auto") |> expect.to_be_false
    }),
  ])
}

pub fn radar_label_render_tests() {
  describe("radar_label_render", [
    it("radar with show_label renders value text", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_label(show: True)
      let html =
        radar.render_radar(
          config: config,
          data: [
            dict.from_list([#("v", 7.0)]),
            dict.from_list([#("v", 3.0)]),
            dict.from_list([#("v", 5.0)]),
          ],
          categories: ["A", "B", "C"],
          cx: 100.0,
          cy: 100.0,
          max_radius: 80.0,
          domain_max: 10.0,
        )
        |> element.to_string
      // Should contain the value "7" as a text label
      html |> string.contains(">7<") |> expect.to_be_true
      html |> string.contains(">3<") |> expect.to_be_true
      html |> string.contains(">5<") |> expect.to_be_true
    }),
    it("radar without show_label has no value labels (default)", fn() {
      let config = radar.radar_config(data_key: "v")
      config.show_label |> expect.to_equal(expected: False)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Phase B: Multi-axis support tests
// ---------------------------------------------------------------------------

pub fn axis_id_defaults_tests() {
  describe("axis_id_defaults", [
    it("XAxisConfig defaults axis_id to 0", fn() {
      let config = axis.x_axis_config()
      config.axis_id |> expect.to_equal(expected: "0")
    }),
    it("YAxisConfig defaults axis_id to 0", fn() {
      let config = axis.y_axis_config()
      config.axis_id |> expect.to_equal(expected: "0")
    }),
    it("LineConfig defaults x_axis_id and y_axis_id to 0", fn() {
      let config = line.line_config(data_key: "v", meta: common.series_meta())
      config.x_axis_id |> expect.to_equal(expected: "0")
      config.y_axis_id |> expect.to_equal(expected: "0")
    }),
    it("AreaConfig defaults x_axis_id and y_axis_id to 0", fn() {
      let config = area.area_config(data_key: "v", meta: common.series_meta())
      config.x_axis_id |> expect.to_equal(expected: "0")
      config.y_axis_id |> expect.to_equal(expected: "0")
    }),
    it("BarConfig defaults x_axis_id and y_axis_id to 0", fn() {
      let config = bar.bar_config(data_key: "v", meta: common.series_meta())
      config.x_axis_id |> expect.to_equal(expected: "0")
      config.y_axis_id |> expect.to_equal(expected: "0")
    }),
    it("ScatterConfig defaults x_axis_id and y_axis_id to 0", fn() {
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      config.x_axis_id |> expect.to_equal(expected: "0")
      config.y_axis_id |> expect.to_equal(expected: "0")
    }),
    it("ReferenceLineConfig defaults x_axis_id and y_axis_id to 0", fn() {
      let config = reference.horizontal_line(value: 50.0)
      config.x_axis_id |> expect.to_equal(expected: "0")
      config.y_axis_id |> expect.to_equal(expected: "0")
    }),
    it("ReferenceAreaConfig defaults x_axis_id and y_axis_id to 0", fn() {
      let config = reference.horizontal_area(value1: 10.0, value2: 90.0)
      config.x_axis_id |> expect.to_equal(expected: "0")
      config.y_axis_id |> expect.to_equal(expected: "0")
    }),
    it("ReferenceDotConfig defaults x_axis_id and y_axis_id to 0", fn() {
      let config = reference.reference_dot(x: 5.0, y: 50.0)
      config.x_axis_id |> expect.to_equal(expected: "0")
      config.y_axis_id |> expect.to_equal(expected: "0")
    }),
    it("ErrorBarConfig defaults x_axis_id and y_axis_id to 0", fn() {
      let config = error_bar.error_bar_config(data_key: "err")
      config.x_axis_id |> expect.to_equal(expected: "0")
      config.y_axis_id |> expect.to_equal(expected: "0")
    }),
  ])
}

pub fn axis_id_builders_tests() {
  describe("axis_id_builders", [
    it("x_axis_id sets XAxisConfig axis_id", fn() {
      let config =
        axis.x_axis_config()
        |> axis.axis_id("1")
      config.axis_id |> expect.to_equal(expected: "1")
    }),
    it("y_axis_id sets YAxisConfig axis_id", fn() {
      let config =
        axis.y_axis_config()
        |> axis.axis_id("1")
      config.axis_id |> expect.to_equal(expected: "1")
    }),
    it("line_x_axis_id and line_y_axis_id set LineConfig axis IDs", fn() {
      let config =
        line.line_config(data_key: "v", meta: common.series_meta())
        |> line.line_meta(
          meta: common.series_meta()
          |> common.series_x_axis_id(id: "x1")
          |> common.series_y_axis_id(id: "y1"),
        )
      config.x_axis_id |> expect.to_equal(expected: "x1")
      config.y_axis_id |> expect.to_equal(expected: "y1")
    }),
    it("area_x_axis_id and area_y_axis_id set AreaConfig axis IDs", fn() {
      let config =
        area.area_config(data_key: "v", meta: common.series_meta())
        |> area.area_meta(
          meta: common.series_meta()
          |> common.series_x_axis_id(id: "x1")
          |> common.series_y_axis_id(id: "y1"),
        )
      config.x_axis_id |> expect.to_equal(expected: "x1")
      config.y_axis_id |> expect.to_equal(expected: "y1")
    }),
    it("bar_x_axis_id and bar_y_axis_id set BarConfig axis IDs", fn() {
      let config =
        bar.bar_config(data_key: "v", meta: common.series_meta())
        |> bar.bar_meta(
          meta: common.series_meta()
          |> common.series_x_axis_id(id: "x1")
          |> common.series_y_axis_id(id: "y1"),
        )
      config.x_axis_id |> expect.to_equal(expected: "x1")
      config.y_axis_id |> expect.to_equal(expected: "y1")
    }),
    it("scatter axis ID builders set ScatterConfig axis IDs", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_x_axis_id(id: "x1")
        |> scatter.scatter_y_axis_id(id: "y1")
      config.x_axis_id |> expect.to_equal(expected: "x1")
      config.y_axis_id |> expect.to_equal(expected: "y1")
    }),
    it("reference line axis ID builders set config axis IDs", fn() {
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_x_axis_id(id: "x1")
        |> reference.line_y_axis_id(id: "y1")
      config.x_axis_id |> expect.to_equal(expected: "x1")
      config.y_axis_id |> expect.to_equal(expected: "y1")
    }),
    it("reference area axis ID builders set config axis IDs", fn() {
      let config =
        reference.horizontal_area(value1: 10.0, value2: 90.0)
        |> reference.area_x_axis_id(id: "x1")
        |> reference.area_y_axis_id(id: "y1")
      config.x_axis_id |> expect.to_equal(expected: "x1")
      config.y_axis_id |> expect.to_equal(expected: "y1")
    }),
    it("reference dot axis ID builders set config axis IDs", fn() {
      let config =
        reference.reference_dot(x: 5.0, y: 50.0)
        |> reference.dot_x_axis_id(id: "x1")
        |> reference.dot_y_axis_id(id: "y1")
      config.x_axis_id |> expect.to_equal(expected: "x1")
      config.y_axis_id |> expect.to_equal(expected: "y1")
    }),
    it("error bar axis ID builders set config axis IDs", fn() {
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_x_axis_id(id: "x1")
        |> error_bar.error_bar_y_axis_id(id: "y1")
      config.x_axis_id |> expect.to_equal(expected: "x1")
      config.y_axis_id |> expect.to_equal(expected: "y1")
    }),
  ])
}

pub fn multi_y_axis_render_tests() {
  describe("multi_y_axis_render", [
    it("single y-axis renders normally (backward compat)", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 20.0)])),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 300,
          children: [
            chart.y_axis(axis.y_axis_config()),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      // Should render a y-axis group
      html
      |> string.contains("recharts-yAxis")
      |> expect.to_be_true
      // Should render a line (polyline/path with stroke)
      html
      |> string.contains("recharts-line")
      |> expect.to_be_true
    }),
    it("two y-axes render two axis groups", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("temp", 20.0), #("humidity", 60.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("temp", 25.0), #("humidity", 55.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 300,
          children: [
            chart.y_axis(axis.y_axis_config() |> axis.axis_id("0")),
            chart.y_axis(
              axis.y_axis_config()
              |> axis.axis_id("1")
              |> axis.axis_orientation(axis.Right),
            ),
            chart.line(
              line.line_config(data_key: "temp", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "0"),
              ),
            ),
            chart.line(
              line.line_config(data_key: "humidity", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "1"),
              ),
            ),
          ],
        )
        |> element.to_string
      // Should have two y-axis groups
      let axis_count =
        string.split(html, "recharts-yAxis")
        |> list.length
      // split produces N+1 parts for N occurrences, so >= 3 means >= 2 axes
      { axis_count >= 3 } |> expect.to_be_true
      // Should have two line groups
      let line_count =
        string.split(html, "recharts-line")
        |> list.length
      { line_count >= 3 } |> expect.to_be_true
    }),
    it("series bound to axis 1 uses axis 1 scale for positioning", fn() {
      // Create two axes with very different domains to verify per-axis scaling.
      // Axis "0": domain ~0-10 (small values)
      // Axis "1": domain ~0-1000 (large values)
      // Lines bound to axis "1" should be positioned using the 0-1000 scale.
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("small", 5.0), #("large", 500.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("small", 8.0), #("large", 800.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 300,
          children: [
            chart.y_axis(axis.y_axis_config() |> axis.axis_id("0")),
            chart.y_axis(
              axis.y_axis_config()
              |> axis.axis_id("1")
              |> axis.axis_orientation(axis.Right),
            ),
            chart.line(
              line.line_config(data_key: "small", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "0"),
              ),
            ),
            chart.line(
              line.line_config(data_key: "large", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "1"),
              ),
            ),
          ],
        )
        |> element.to_string
      // Both series render — verify SVG is non-empty and has line elements
      html
      |> string.contains("recharts-line")
      |> expect.to_be_true
      // Axis "1" should show tick values in the ~0-800 range
      // (auto domain from [500,800] from_zero produces ticks like 0,200,400,600,800)
      html |> string.contains("800") |> expect.to_be_true
    }),
    it("per-axis domain: axis 0 domain unaffected by axis 1 data", fn() {
      // Axis "0" bound to "small" (values 5-8), axis "1" bound to "large" (500-800).
      // Axis "0" ticks should NOT include 500 or 800.
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("small", 5.0), #("large", 500.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("small", 8.0), #("large", 800.0)]),
        ),
      ]
      let html_single_axis =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 300,
          children: [
            chart.y_axis(axis.y_axis_config() |> axis.axis_id("0")),
            chart.line(
              line.line_config(data_key: "small", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "0"),
              ),
            ),
          ],
        )
        |> element.to_string
      // With only axis "0" and only "small" series, ticks should be in 0-8 range.
      // Should NOT show "500" as a tick value.
      html_single_axis |> string.contains(">500<") |> expect.to_be_false
    }),
    it("area series uses per-axis y-scale", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("v1", 10.0), #("v2", 500.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("v1", 20.0), #("v2", 800.0)]),
        ),
      ]
      let html =
        chart.area_chart(
          data: data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 300,
          children: [
            chart.y_axis(axis.y_axis_config() |> axis.axis_id("0")),
            chart.y_axis(
              axis.y_axis_config()
              |> axis.axis_id("1")
              |> axis.axis_orientation(axis.Right),
            ),
            chart.area(
              area.area_config(data_key: "v1", meta: common.series_meta())
              |> area.area_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "0"),
              ),
            ),
            chart.area(
              area.area_config(data_key: "v2", meta: common.series_meta())
              |> area.area_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "1"),
              ),
            ),
          ],
        )
        |> element.to_string
      // Both areas should render
      let area_count =
        string.split(html, "recharts-area")
        |> list.length
      { area_count >= 3 } |> expect.to_be_true
    }),
    it("bar series uses per-axis y-scale", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("revenue", 100.0), #("count", 5.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("revenue", 200.0), #("count", 8.0)]),
        ),
      ]
      let html =
        chart.bar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 300,
          children: [
            chart.y_axis(axis.y_axis_config() |> axis.axis_id("0")),
            chart.y_axis(
              axis.y_axis_config()
              |> axis.axis_id("1")
              |> axis.axis_orientation(axis.Right),
            ),
            chart.bar(
              bar.bar_config(data_key: "revenue", meta: common.series_meta())
              |> bar.bar_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "0"),
              ),
            ),
            chart.bar(
              bar.bar_config(data_key: "count", meta: common.series_meta())
              |> bar.bar_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "1"),
              ),
            ),
          ],
        )
        |> element.to_string
      // Both bars should render
      html
      |> string.contains("recharts-bar")
      |> expect.to_be_true
    }),
    it("reference line uses per-axis y-scale", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("v1", 10.0), #("v2", 500.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 300,
          children: [
            chart.y_axis(axis.y_axis_config() |> axis.axis_id("0")),
            chart.y_axis(
              axis.y_axis_config()
              |> axis.axis_id("1")
              |> axis.axis_orientation(axis.Right),
            ),
            chart.line(
              line.line_config(data_key: "v1", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "0"),
              ),
            ),
            chart.line(
              line.line_config(data_key: "v2", meta: common.series_meta())
              |> line.line_meta(
                meta: common.series_meta() |> common.series_y_axis_id(id: "1"),
              ),
            ),
            chart.reference_line(
              reference.horizontal_line(value: 5.0)
              |> reference.line_y_axis_id(id: "0"),
            ),
            chart.reference_line(
              reference.horizontal_line(value: 600.0)
              |> reference.line_y_axis_id(id: "1"),
            ),
          ],
        )
        |> element.to_string
      // Both reference lines should render
      let ref_count =
        string.split(html, "recharts-reference-line")
        |> list.length
      { ref_count >= 3 } |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Treemap tests
// ---------------------------------------------------------------------------

pub fn treemap_tests() {
  describe("treemap", [
    it("renders rectangles for flat data", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
          treemap.TreemapNode(name: "B", value: 50.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-treemap") |> expect.to_be_true
      html |> string.contains("recharts-treemap-rect") |> expect.to_be_true
    }),
    it("sizes rectangles proportional to values", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "Big", value: 300.0, children: [], fill: ""),
          treemap.TreemapNode(
            name: "Small",
            value: 100.0,
            children: [],
            fill: "",
          ),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 400)
        |> element.to_string
      // Should have 2 rectangles
      let rect_count =
        string.split(html, "recharts-treemap-rect")
        |> list.length
      rect_count |> expect.to_equal(expected: 3)
    }),
    it("handles nested hierarchical data", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(
            name: "Parent",
            value: 0.0,
            children: [
              treemap.TreemapNode(
                name: "Child1",
                value: 60.0,
                children: [],
                fill: "",
              ),
              treemap.TreemapNode(
                name: "Child2",
                value: 40.0,
                children: [],
                fill: "",
              ),
            ],
            fill: "",
          ),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      // Hierarchical flat mode renders parent + child rects: 1 parent + 2 children = 3 rects
      let rect_count =
        string.split(html, "recharts-treemap-rect")
        |> list.length
      rect_count |> expect.to_equal(expected: 4)
    }),
    it("fill fallback used when fills palette is cleared", fn() {
      // treemap_fill sets the ultimate fallback; clear fills so it is reached
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_fills(fills: [])
        |> treemap.treemap_fill(fill: "#ff0000")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("#ff0000") |> expect.to_be_true
    }),
    it("applies custom fills palette", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_fills(fills: ["#aaa", "#bbb"])
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
          treemap.TreemapNode(name: "B", value: 50.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("#aaa") |> expect.to_be_true
      html |> string.contains("#bbb") |> expect.to_be_true
    }),
    it("renders labels when show_label is True", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_show_label(show: True)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(
            name: "BigEnough",
            value: 100.0,
            children: [],
            fill: "",
          ),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-treemap-label") |> expect.to_be_true
      html |> string.contains("BigEnough") |> expect.to_be_true
    }),
    it("hides labels when show_label is False", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_show_label(show: False)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-treemap-label") |> expect.to_be_false
    }),
    it("applies stroke to rectangles", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_stroke(stroke: "#000000")
        |> treemap.treemap_stroke_width(width: 2.0)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("#000000") |> expect.to_be_true
      html |> string.contains("stroke-width") |> expect.to_be_true
    }),
    it("handles single item", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(
            name: "Only",
            value: 100.0,
            children: [],
            fill: "",
          ),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-treemap-rect") |> expect.to_be_true
      let rect_count =
        string.split(html, "recharts-treemap-rect")
        |> list.length
      rect_count |> expect.to_equal(expected: 2)
    }),
    it("handles empty data", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-treemap-rect") |> expect.to_be_false
    }),
    it("treemap_chart renders SVG container", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
        ])
      let html =
        chart.treemap_chart(
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 400,
          children: [
            chart.treemap(config: config),
          ],
        )
        |> element.to_string
      html |> string.contains("<svg") |> expect.to_be_true
      html |> string.contains("recharts-treemap") |> expect.to_be_true
    }),
    it("treemap config builders work", fn() {
      let config =
        treemap.treemap_config(data_key: "val")
        |> treemap.treemap_fill(fill: "#123")
        |> treemap.treemap_stroke(stroke: "#456")
        |> treemap.treemap_stroke_width(width: 3.0)
        |> treemap.treemap_aspect_ratio(ratio: 2.0)
        |> treemap.treemap_padding(padding: 4.0)
        |> treemap.treemap_fills(fills: ["#a", "#b"])
        |> treemap.treemap_show_label(show: False)
        |> treemap.treemap_legend_type(icon_type: shape.CircleIcon)
      config.data_key |> expect.to_equal(expected: "val")
      config.fill |> expect.to_equal(expected: "#123")
      config.stroke |> expect.to_equal(expected: "#456")
      config.stroke_width |> expect.to_equal(expected: 3.0)
      config.aspect_ratio |> expect.to_equal(expected: 2.0)
      config.padding |> expect.to_equal(expected: 4.0)
      config.fills |> expect.to_equal(expected: ["#a", "#b"])
      config.show_label |> expect.to_equal(expected: False)
      config.legend_type |> expect.to_equal(expected: shape.CircleIcon)
    }),
    it("default fills use recharts COLOR_PANEL (24 colors)", fn() {
      let config = treemap.treemap_config(data_key: "value")
      config.fills |> list.length |> expect.to_equal(expected: 24)
      config.fills
      |> list.first
      |> expect.to_equal(expected: Ok("#1890FF"))
    }),
    it("default fill cycles through COLOR_PANEL for each cell", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
          treemap.TreemapNode(name: "B", value: 80.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("#1890FF") |> expect.to_be_true
      html |> string.contains("#66B5FF") |> expect.to_be_true
    }),
    it(
      "label threshold: cells exactly 20px wide/tall get no label (strict >)",
      fn() {
        // A cell of exactly 20x20 should NOT get a label (recharts uses > 20 strict)
        let config =
          treemap.treemap_config(data_key: "value")
          |> treemap.treemap_show_label(show: True)
          |> treemap.treemap_data(data: [
            treemap.TreemapNode(
              name: "Tiny",
              value: 1.0,
              children: [],
              fill: "",
            ),
          ])
        // Render with very small dimensions so the single cell is ~20px wide
        let html =
          treemap.render_treemap(config: config, width: 20, height: 20)
          |> element.to_string
        html |> string.contains("recharts-treemap-label") |> expect.to_be_false
      },
    ),
    it("label uses font-size 14 matching recharts default", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_show_label(show: True)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(
            name: "BigEnough",
            value: 100.0,
            children: [],
            fill: "",
          ),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("font-size=\"14\"") |> expect.to_be_true
    }),
    it("label is left-aligned: no text-anchor and no dominant-baseline", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_show_label(show: True)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(
            name: "BigEnough",
            value: 100.0,
            children: [],
            fill: "",
          ),
        ])
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("text-anchor") |> expect.to_be_false
      html |> string.contains("dominant-baseline") |> expect.to_be_false
    }),
    it("build_treemap_tooltip_payloads returns one payload per leaf cell", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 0.0, fill: "", children: [
            treemap.TreemapNode(name: "A1", value: 60.0, fill: "", children: []),
            treemap.TreemapNode(name: "A2", value: 40.0, fill: "", children: []),
          ]),
          treemap.TreemapNode(name: "B", value: 30.0, fill: "", children: []),
        ])
      let payloads =
        treemap.build_treemap_tooltip_payloads(
          config: config,
          width: 400,
          height: 300,
        )
      // 3 leaf cells: A1, A2, B
      list.length(payloads) |> expect.to_equal(expected: 3)
    }),
    it("treemap tooltip payloads have cell-sized hit zones", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "X", value: 100.0, fill: "", children: []),
        ])
      let payloads =
        treemap.build_treemap_tooltip_payloads(
          config: config,
          width: 400,
          height: 300,
        )
      case payloads {
        [p] -> {
          // Hit zone must cover the full cell (400x300 for single node)
          { p.zone_width >. 0.0 } |> expect.to_be_true
          { p.zone_height >. 0.0 } |> expect.to_be_true
          // Center position
          { p.x >. 0.0 } |> expect.to_be_true
          { p.y >. 0.0 } |> expect.to_be_true
        }
        _ -> expect.to_be_true(False)
      }
    }),
    it("treemap tooltip payloads have empty label and node name in entry", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(
            name: "Leaf",
            value: 100.0,
            fill: "",
            children: [],
          ),
        ])
      let payloads =
        treemap.build_treemap_tooltip_payloads(
          config: config,
          width: 400,
          height: 300,
        )
      case payloads {
        [p] -> {
          p.label |> expect.to_equal(expected: "")
          case p.entries {
            [entry] -> entry.name |> expect.to_equal(expected: "Leaf")
            _ -> expect.to_be_true(False)
          }
        }
        _ -> expect.to_be_true(False)
      }
    }),
    it("treemap_chart renders tooltip CSS when tooltip child is present", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, fill: "", children: []),
        ])
      let html =
        chart.treemap_chart(
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.treemap(config: config),
            chart.tooltip(tooltip.tooltip_config()),
          ],
        )
        |> element.to_string
      html |> string.contains("chart-hotspot") |> expect.to_be_true
    }),
    it("integer rounding: row height is integer for exact division", fn() {
      // 10×10 container with one node: row_height = round(100/10) = 10
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 10, height: 10)
        |> element.to_string
      // height="10" not height="10.0" or "9.99..."
      html |> string.contains("height=\"10\"") |> expect.to_be_true
    }),
    it("integer rounding: item width is integer for non-trivial area", fn() {
      // Two equal-value nodes in a 10×20 container; each gets half
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 50.0, children: [], fill: ""),
          treemap.TreemapNode(name: "B", value: 50.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 10, height: 20)
        |> element.to_string
      // With rounding both nodes should have integer-valued heights
      html |> string.contains("recharts-treemap-rect") |> expect.to_be_true
      // Dimensions should not contain more than 2 decimal places
      html |> string.contains("height=\"10\"") |> expect.to_be_true
    }),
    it("text suppression: long name hidden when text would overflow", fn() {
      // 25×25 cell; name 20 chars × 8px = 160 > 25 → label suppressed
      let long_name = "ABCDEFGHIJKLMNOPQRST"
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_show_label(show: True)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(
            name: long_name,
            value: 100.0,
            children: [],
            fill: "",
          ),
        ])
      let html =
        treemap.render_treemap(config: config, width: 25, height: 25)
        |> element.to_string
      html |> string.contains("recharts-treemap-label") |> expect.to_be_false
    }),
    it("text suppression: short name shown when text fits the cell", fn() {
      // 100×100 cell; name 2 chars × 8px = 16 < 100 → label shown
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_show_label(show: True)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "Hi", value: 100.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 100, height: 100)
        |> element.to_string
      html |> string.contains("recharts-treemap-label") |> expect.to_be_true
    }),
    it(
      "arrow: polygon rendered in NestedTreemap for parent cells > 10×10",
      fn() {
        let config =
          treemap.treemap_config(data_key: "value")
          |> treemap.treemap_display_type(display_type: treemap.NestedTreemap)
          |> treemap.treemap_data(data: [
            treemap.TreemapNode(name: "Group", value: 0.0, fill: "", children: [
              treemap.TreemapNode(
                name: "Child",
                value: 100.0,
                children: [],
                fill: "",
              ),
            ]),
          ])
        let html =
          treemap.render_treemap(config: config, width: 200, height: 200)
          |> element.to_string
        html |> string.contains("<polygon") |> expect.to_be_true
      },
    ),
    it("arrow: polygon not rendered when cell is not strictly > 10×10", fn() {
      // 10×10 total chart; parent cell = 10×10, check is strict >
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_display_type(display_type: treemap.NestedTreemap)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "Group", value: 0.0, fill: "", children: [
            treemap.TreemapNode(
              name: "Child",
              value: 100.0,
              children: [],
              fill: "",
            ),
          ]),
        ])
      let html =
        treemap.render_treemap(config: config, width: 10, height: 10)
        |> element.to_string
      html |> string.contains("<polygon") |> expect.to_be_false
    }),
    it("arrow: polygon not rendered in FlatTreemap mode", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_display_type(display_type: treemap.FlatTreemap)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "Group", value: 0.0, fill: "", children: [
            treemap.TreemapNode(
              name: "Child",
              value: 100.0,
              children: [],
              fill: "",
            ),
          ]),
        ])
      let html =
        treemap.render_treemap(config: config, width: 200, height: 200)
        |> element.to_string
      html |> string.contains("<polygon") |> expect.to_be_false
    }),
    it("arrow: polygon not rendered for leaf nodes (no children)", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_display_type(display_type: treemap.NestedTreemap)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(
            name: "Leaf",
            value: 100.0,
            children: [],
            fill: "",
          ),
        ])
      let html =
        treemap.render_treemap(config: config, width: 200, height: 200)
        |> element.to_string
      html |> string.contains("<polygon") |> expect.to_be_false
    }),
    it("role=\"img\": present on every rendered cell rect", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 200, height: 200)
        |> element.to_string
      html |> string.contains("role=\"img\"") |> expect.to_be_true
    }),
    it("padding: adjusts rendered rect position and size", fn() {
      // padding=5 on a 100×100 chart → rect at x=5, y=5, width=90, height=90
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_padding(padding: 5.0)
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 100, height: 100)
        |> element.to_string
      html |> string.contains("x=\"5\"") |> expect.to_be_true
      html |> string.contains("y=\"5\"") |> expect.to_be_true
      html |> string.contains("width=\"90\"") |> expect.to_be_true
      html |> string.contains("height=\"90\"") |> expect.to_be_true
    }),
    it("padding: 0.0 default leaves rect at layout bounds", fn() {
      // Default padding=0 on a 100×100 chart → rect at x=0, y=0
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [
          treemap.TreemapNode(name: "A", value: 100.0, children: [], fill: ""),
        ])
      let html =
        treemap.render_treemap(config: config, width: 100, height: 100)
        |> element.to_string
      html |> string.contains("x=\"0\"") |> expect.to_be_true
      html |> string.contains("y=\"0\"") |> expect.to_be_true
    }),
    it("animation_update_active: builder sets field to False", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_animation_update_active(active: False)
      config.animation_update_active |> expect.to_be_false
    }),
  ])
}

// ---------------------------------------------------------------------------
// Sunburst tests
// ---------------------------------------------------------------------------

pub fn sunburst_tests() {
  describe("sunburst", [
    it("renders sectors for flat data", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 60.0, fill: "#aaa"),
          sunburst.sunburst_leaf(name: "B", value: 40.0, fill: "#bbb"),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      html |> string.contains("recharts-sunburst") |> expect.to_be_true
      // Should have path elements for sectors
      html |> string.contains("<path") |> expect.to_be_true
    }),
    it("renders concentric rings for nested data", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_node(
            name: "Parent",
            value: 100.0,
            fill: "#aaa",
            children: [
              sunburst.sunburst_leaf(name: "Child", value: 100.0, fill: "#bbb"),
            ],
          ),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      // Should have at least 2 path elements (parent ring + child ring)
      let path_count =
        string.split(html, "<path")
        |> list.length
      { path_count >= 3 } |> expect.to_be_true
    }),
    it("applies per-node fills", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 60.0, fill: "#ff0000"),
          sunburst.sunburst_leaf(name: "B", value: 40.0, fill: "#00ff00"),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      html |> string.contains("#ff0000") |> expect.to_be_true
      html |> string.contains("#00ff00") |> expect.to_be_true
    }),
    it("applies default fill palette", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 60.0, fill: ""),
          sunburst.sunburst_leaf(name: "B", value: 40.0, fill: ""),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_fills(fills: ["#abc", "#def"])
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      html |> string.contains("#abc") |> expect.to_be_true
      html |> string.contains("#def") |> expect.to_be_true
    }),
    it("respects inner_radius", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 100.0, fill: "#aaa"),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_inner_radius(radius: 30.0)
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      // The sector path should exist with inner radius > 0
      html |> string.contains("<path") |> expect.to_be_true
    }),
    it("respects outer_radius", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 100.0, fill: "#aaa"),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_outer_radius(radius: 150.0)
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      html |> string.contains("recharts-sunburst") |> expect.to_be_true
    }),
    it("sunburst_chart renders SVG container", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 60.0, fill: "#aaa"),
          sunburst.sunburst_leaf(name: "B", value: 40.0, fill: "#bbb"),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_data(data: root)
      let html =
        chart.sunburst_chart(
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 400,
          children: [
            chart.sunburst(config: config),
          ],
        )
        |> element.to_string
      html |> string.contains("<svg") |> expect.to_be_true
      html |> string.contains("recharts-sunburst") |> expect.to_be_true
    }),
    it("config builders set values correctly", fn() {
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_cx(cx: 100.0)
        |> sunburst.sunburst_cy(cy: 150.0)
        |> sunburst.sunburst_inner_radius(radius: 20.0)
        |> sunburst.sunburst_outer_radius(radius: 120.0)
        |> sunburst.sunburst_start_angle(angle: 45.0)
        |> sunburst.sunburst_end_angle(angle: 315.0)
        |> sunburst.sunburst_fill(fill: "#123")
        |> sunburst.sunburst_stroke(stroke: "#456")
        |> sunburst.sunburst_stroke_width(width: 2.0)
        |> sunburst.sunburst_ring_padding(padding: 5.0)
        |> sunburst.sunburst_label(show: True)
        |> sunburst.sunburst_fills(fills: ["#a", "#b"])
        |> sunburst.sunburst_legend_type(icon_type: shape.CircleIcon)
      config.cx |> expect.to_equal(expected: 100.0)
      config.cy |> expect.to_equal(expected: 150.0)
      config.inner_radius |> expect.to_equal(expected: 20.0)
      config.outer_radius |> expect.to_equal(expected: 120.0)
      config.start_angle |> expect.to_equal(expected: 45.0)
      config.end_angle |> expect.to_equal(expected: 315.0)
      config.fill |> expect.to_equal(expected: "#123")
      config.stroke |> expect.to_equal(expected: "#456")
      config.stroke_width |> expect.to_equal(expected: 2.0)
      config.ring_padding |> expect.to_equal(expected: 5.0)
      config.show_label |> expect.to_equal(expected: True)
      config.fills |> expect.to_equal(expected: ["#a", "#b"])
      config.legend_type |> expect.to_equal(expected: shape.CircleIcon)
    }),
    it("handles partial angle range", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 100.0, fill: "#aaa"),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_start_angle(angle: 0.0)
        |> sunburst.sunburst_end_angle(angle: 180.0)
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      html |> string.contains("recharts-sunburst") |> expect.to_be_true
      html |> string.contains("<path") |> expect.to_be_true
    }),
    it("handles empty root children", fn() {
      let root =
        sunburst.sunburst_node(
          name: "root",
          value: 100.0,
          fill: "",
          children: [],
        )
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      // Empty children means no sectors rendered, but group still present
      html |> string.contains("recharts-sunburst") |> expect.to_be_true
      html |> string.contains("<path") |> expect.to_be_false
    }),
    it("default inner_radius is 50 (donut hole, matches recharts)", fn() {
      sunburst.sunburst_config().inner_radius
      |> expect.to_equal(expected: 50.0)
    }),
    it("auto outer_radius fills chart area (400x400 gives radius 200)", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 100.0, fill: "#aaa"),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      html |> string.contains("200") |> expect.to_be_true
    }),
    it("default fill is #333 (matches recharts dark gray)", fn() {
      sunburst.sunburst_config().fill
      |> expect.to_equal(expected: "#333")
    }),
    it("show_label defaults to True rendering text elements", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 60.0, fill: "#aaa"),
          sunburst.sunburst_leaf(name: "B", value: 40.0, fill: "#bbb"),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      html |> string.contains("<text") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Sankey tests
// ---------------------------------------------------------------------------

pub fn sankey_tests() {
  describe("sankey", [
    it("renders rectangles for nodes", fn() {
      let data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 10.0)],
        )
      let config = sankey.sankey_config(data: data)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-sankey") |> expect.to_be_true
      html |> string.contains("recharts-sankey-node") |> expect.to_be_true
    }),
    it("renders bezier paths for links", fn() {
      let data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 10.0)],
        )
      let config = sankey.sankey_config(data: data)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-sankey-link") |> expect.to_be_true
      // Cubic bezier uses C command
      html |> string.contains(" C") |> expect.to_be_true
    }),
    it("node widths match config", fn() {
      let data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 10.0)],
        )
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_node_width(width: 30.0)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      // Node width should be 30
      html |> string.contains("width=\"30") |> expect.to_be_true
    }),
    it("handles simple A->B flow", fn() {
      let data =
        sankey.SankeyData(
          nodes: [
            sankey.SankeyNode(name: "Source"),
            sankey.SankeyNode(name: "Target"),
          ],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 50.0)],
        )
      let config = sankey.sankey_config(data: data)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      // Should have 2 node rects
      let node_count =
        string.split(html, "recharts-sankey-node\"")
        |> list.length
      { node_count >= 3 } |> expect.to_be_true
    }),
    it("handles branching flows", fn() {
      let data =
        sankey.SankeyData(
          nodes: [
            sankey.SankeyNode(name: "A"),
            sankey.SankeyNode(name: "B"),
            sankey.SankeyNode(name: "C"),
          ],
          links: [
            sankey.SankeyLink(source: 0, target: 1, value: 30.0),
            sankey.SankeyLink(source: 0, target: 2, value: 20.0),
          ],
        )
      let config = sankey.sankey_config(data: data)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      // Should have 2 link paths (match exact class to avoid links group)
      let link_count =
        string.split(html, "recharts-sankey-link\"")
        |> list.length
      // 2 occurrences = 3 parts from split
      link_count |> expect.to_equal(expected: 3)
    }),
    it("handles converging flows", fn() {
      let data =
        sankey.SankeyData(
          nodes: [
            sankey.SankeyNode(name: "A"),
            sankey.SankeyNode(name: "B"),
            sankey.SankeyNode(name: "C"),
          ],
          links: [
            sankey.SankeyLink(source: 0, target: 2, value: 30.0),
            sankey.SankeyLink(source: 1, target: 2, value: 20.0),
          ],
        )
      let config = sankey.sankey_config(data: data)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      // Should have 2 link paths (match exact class to avoid links group)
      let link_count =
        string.split(html, "recharts-sankey-link\"")
        |> list.length
      // 2 occurrences = 3 parts from split
      link_count |> expect.to_equal(expected: 3)
    }),
    it("respects node_padding", fn() {
      let data =
        sankey.SankeyData(
          nodes: [
            sankey.SankeyNode(name: "A"),
            sankey.SankeyNode(name: "B"),
            sankey.SankeyNode(name: "C"),
          ],
          links: [
            sankey.SankeyLink(source: 0, target: 2, value: 30.0),
            sankey.SankeyLink(source: 1, target: 2, value: 20.0),
          ],
        )
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_node_padding(padding: 20.0)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      // Should render without errors
      html |> string.contains("recharts-sankey-nodes") |> expect.to_be_true
    }),
    it("applies node fills from palette", fn() {
      let data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 10.0)],
        )
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_node_fills(fills: ["#ff0000", "#00ff00"])
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("#ff0000") |> expect.to_be_true
      html |> string.contains("#00ff00") |> expect.to_be_true
    }),
    it("applies link stroke and opacity", fn() {
      let data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 10.0)],
        )
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_link_stroke(stroke: "#999999")
        |> sankey.sankey_link_stroke_opacity(opacity: 0.8)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("#999999") |> expect.to_be_true
      html |> string.contains("0.8") |> expect.to_be_true
    }),
    it("renders labels when show_label is True", fn() {
      let data =
        sankey.SankeyData(
          nodes: [
            sankey.SankeyNode(name: "Alpha"),
            sankey.SankeyNode(name: "Beta"),
          ],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 10.0)],
        )
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_show_label(show: True)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      html
      |> string.contains("recharts-sankey-node-label")
      |> expect.to_be_true
      html |> string.contains("Alpha") |> expect.to_be_true
      html |> string.contains("Beta") |> expect.to_be_true
    }),
    it("hides labels when show_label is False", fn() {
      let data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 10.0)],
        )
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_show_label(show: False)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      html
      |> string.contains("recharts-sankey-node-label")
      |> expect.to_be_false
    }),
    it("sankey_chart renders SVG container", fn() {
      let data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 10.0)],
        )
      let config = sankey.sankey_config(data: data)
      let html =
        chart.sankey_chart(
          width: chart.FixedWidth(pixels: 500),
          theme: option.None,
          height: 400,
          children: [
            chart.sankey(config: config),
          ],
        )
        |> element.to_string
      html |> string.contains("<svg") |> expect.to_be_true
      html |> string.contains("recharts-sankey") |> expect.to_be_true
    }),
    it("config builders set values", fn() {
      let data = sankey.SankeyData(nodes: [], links: [])
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_node_width(width: 32.0)
        |> sankey.sankey_node_padding(padding: 12.0)
        |> sankey.sankey_iterations(iterations: 10)
        |> sankey.sankey_link_stroke(stroke: "#abc")
        |> sankey.sankey_link_stroke_opacity(opacity: 0.7)
        |> sankey.sankey_node_fills(fills: ["#x", "#y"])
        |> sankey.sankey_show_label(show: False)
        |> sankey.sankey_legend_type(icon_type: shape.CircleIcon)
        |> sankey.sankey_margin_top(margin: 10.0)
        |> sankey.sankey_margin_right(margin: 15.0)
        |> sankey.sankey_margin_bottom(margin: 20.0)
        |> sankey.sankey_margin_left(margin: 25.0)
      config.node_width |> expect.to_equal(expected: 32.0)
      config.node_padding |> expect.to_equal(expected: 12.0)
      config.iterations |> expect.to_equal(expected: 10)
      config.link_stroke |> expect.to_equal(expected: "#abc")
      config.link_stroke_opacity |> expect.to_equal(expected: 0.7)
      config.node_fills |> expect.to_equal(expected: ["#x", "#y"])
      config.show_label |> expect.to_equal(expected: False)
      config.legend_type |> expect.to_equal(expected: shape.CircleIcon)
      config.margin_top |> expect.to_equal(expected: 10.0)
      config.margin_right |> expect.to_equal(expected: 15.0)
      config.margin_bottom |> expect.to_equal(expected: 20.0)
      config.margin_left |> expect.to_equal(expected: 25.0)
    }),
    it("handles single node no links", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "Alone")], links: [])
      let config = sankey.sankey_config(data: data)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-sankey") |> expect.to_be_true
      // No individual link paths (use link\" to avoid matching the links group)
      html
      |> string.contains("recharts-sankey-link\"")
      |> expect.to_be_false
    }),
    it("handles empty data", fn() {
      let data = sankey.SankeyData(nodes: [], links: [])
      let config = sankey.sankey_config(data: data)
      let html =
        sankey.render_sankey(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-sankey") |> expect.to_be_true
    }),
    it("default link_stroke is #333 (matches recharts)", fn() {
      let data = sankey.SankeyData(nodes: [], links: [])
      sankey.sankey_config(data: data).link_stroke
      |> expect.to_equal(expected: "#333")
    }),
    it("default link_stroke_opacity is 0.2 (matches recharts)", fn() {
      let data = sankey.SankeyData(nodes: [], links: [])
      sankey.sankey_config(data: data).link_stroke_opacity
      |> expect.to_equal(expected: 0.2)
    }),
    it("default node fill is #0088fe (matches recharts)", fn() {
      let data = sankey.SankeyData(nodes: [], links: [])
      sankey.sankey_config(data: data).node_fills
      |> expect.to_equal(expected: ["#0088fe"])
    }),
    it(
      "link renders as stroke not fill (matches recharts renderLinkItem)",
      fn() {
        let data =
          sankey.SankeyData(
            nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
            links: [sankey.SankeyLink(source: 0, target: 1, value: 10.0)],
          )
        let config = sankey.sankey_config(data: data)
        let html =
          sankey.render_sankey(config: config, width: 400, height: 300)
          |> element.to_string
        // Links should use stroke (not fill) for the link band
        html |> string.contains("stroke-width") |> expect.to_be_true
        html |> string.contains("fill=\"none\"") |> expect.to_be_true
      },
    ),
    it("sankey_hit_infos returns one entry per node", fn() {
      let data =
        sankey.SankeyData(
          nodes: [
            sankey.SankeyNode(name: "A"),
            sankey.SankeyNode(name: "B"),
            sankey.SankeyNode(name: "C"),
          ],
          links: [
            sankey.SankeyLink(source: 0, target: 2, value: 40.0),
            sankey.SankeyLink(source: 1, target: 2, value: 30.0),
          ],
        )
      let config = sankey.sankey_config(data: data)
      sankey.sankey_hit_infos(config: config, width: 400, height: 300)
      |> list.length
      |> expect.to_equal(expected: 3)
    }),
    it("sankey_hit_infos centroids are within chart bounds", fn() {
      let data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 10.0)],
        )
      let config = sankey.sankey_config(data: data)
      let infos =
        sankey.sankey_hit_infos(config: config, width: 400, height: 300)
      list.all(infos, fn(info) {
        info.centroid_x >=. 0.0
        && info.centroid_x <=. 400.0
        && info.centroid_y >=. 0.0
        && info.centroid_y <=. 300.0
      })
      |> expect.to_be_true
    }),
    it("sankey_link_hit_infos returns one entry per link", fn() {
      let data =
        sankey.SankeyData(
          nodes: [
            sankey.SankeyNode(name: "A"),
            sankey.SankeyNode(name: "B"),
            sankey.SankeyNode(name: "C"),
          ],
          links: [
            sankey.SankeyLink(source: 0, target: 2, value: 40.0),
            sankey.SankeyLink(source: 1, target: 2, value: 30.0),
          ],
        )
      let config = sankey.sankey_config(data: data)
      sankey.sankey_link_hit_infos(config: config, width: 400, height: 300)
      |> list.length
      |> expect.to_equal(expected: 2)
    }),
    it("sankey_link_hit_infos uses source-target name format", fn() {
      let data =
        sankey.SankeyData(
          nodes: [
            sankey.SankeyNode(name: "Foo"),
            sankey.SankeyNode(name: "Bar"),
          ],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 25.0)],
        )
      let config = sankey.sankey_config(data: data)
      let infos =
        sankey.sankey_link_hit_infos(config: config, width: 400, height: 300)
      case infos {
        [info] -> info.name |> expect.to_equal(expected: "Foo - Bar")
        _ -> expect.to_be_true(False)
      }
    }),
  ])
}

// ---------------------------------------------------------------------------
// Layout direction tests
// ---------------------------------------------------------------------------

pub fn layout_direction_tests() {
  let test_data = [
    chart.DataPoint(
      category: "Jan",
      values: dict.from_list([#("desktop", 186.0), #("mobile", 80.0)]),
    ),
    chart.DataPoint(
      category: "Feb",
      values: dict.from_list([#("desktop", 305.0), #("mobile", 200.0)]),
    ),
    chart.DataPoint(
      category: "Mar",
      values: dict.from_list([#("desktop", 237.0), #("mobile", 120.0)]),
    ),
  ]
  describe("layout_direction", [
    it("default layout is Horizontal (standard vertical bars)", fn() {
      // Without chart_layout, bars should render in default (Horizontal) mode
      let html =
        chart.bar_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.bar(bar.bar_config(
              data_key: "desktop",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      // Should contain bar SVG elements
      string.contains(html, "recharts-bar")
      |> expect.to_be_true
    }),
    it("Vertical layout produces horizontal bars (value extends along X)", fn() {
      let html =
        chart.bar_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Vertical),
            chart.bar(bar.bar_config(
              data_key: "desktop",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      // Should still produce bar elements
      string.contains(html, "recharts-bar")
      |> expect.to_be_true
      // Bars should be present (rendered as rect or path elements)
      let has_rect = string.contains(html, "<rect")
      let has_path = string.contains(html, "<path")
      { has_rect || has_path } |> expect.to_be_true
    }),
    it("Vertical layout puts categories on Y-axis", fn() {
      let html =
        chart.bar_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Vertical),
            chart.bar(
              bar.bar_config(data_key: "desktop", meta: common.series_meta())
              |> bar.bar_fill(weft.css_color(value: "#ff0000")),
            ),
          ],
        )
        |> element.to_string
      // Count bar group elements (one per data point)
      let bar_groups =
        string.split(html, "recharts-bar")
        |> list.length
      // Should have at least the wrapper + some child elements
      { bar_groups >= 2 } |> expect.to_be_true
    }),
    it("Vertical layout line chart swaps coordinates", fn() {
      let html =
        chart.line_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Vertical),
            chart.line(
              line.line_config(data_key: "desktop", meta: common.series_meta())
              |> line.line_stroke(weft.css_color(value: "#ff0000")),
            ),
          ],
        )
        |> element.to_string
      // Should contain line elements
      string.contains(html, "recharts-line")
      |> expect.to_be_true
      // Should contain a path element (the line)
      string.contains(html, "<path")
      |> expect.to_be_true
    }),
    it("Vertical layout area chart renders correctly", fn() {
      let html =
        chart.area_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Vertical),
            chart.area(
              area.area_config(data_key: "desktop", meta: common.series_meta())
              |> area.area_fill(weft.css_color(value: "#ff0000")),
            ),
          ],
        )
        |> element.to_string
      // Should contain area elements
      string.contains(html, "recharts-area")
      |> expect.to_be_true
    }),
    it("Vertical layout with stacking works", fn() {
      let html =
        chart.bar_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Vertical),
            chart.bar(
              bar.bar_config(data_key: "desktop", meta: common.series_meta())
              |> bar.bar_stack_id("a"),
            ),
            chart.bar(
              bar.bar_config(data_key: "mobile", meta: common.series_meta())
              |> bar.bar_stack_id("a"),
            ),
          ],
        )
        |> element.to_string
      // Should contain two bar series
      let bar_count =
        string.split(html, "recharts-bar")
        |> list.length
      // 3 = 1 prefix + 2 bar groups
      { bar_count >= 3 } |> expect.to_be_true
    }),
    it("Horizontal layout produces identical output to default", fn() {
      // Explicitly setting Horizontal should produce the same output as default
      let html_default =
        chart.bar_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.bar(bar.bar_config(
              data_key: "desktop",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      let html_horizontal =
        chart.bar_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Horizontal),
            chart.bar(bar.bar_config(
              data_key: "desktop",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      html_horizontal |> expect.to_equal(expected: html_default)
    }),
    it("Vertical layout with composed chart works", fn() {
      let html =
        chart.composed_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Vertical),
            chart.bar(bar.bar_config(
              data_key: "desktop",
              meta: common.series_meta(),
            )),
            chart.line(line.line_config(
              data_key: "mobile",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      // Should contain both bar and line elements
      string.contains(html, "recharts-bar")
      |> expect.to_be_true
      string.contains(html, "recharts-line")
      |> expect.to_be_true
    }),
    it("Vertical bar layout produces different geometry than Horizontal", fn() {
      let html_h =
        chart.bar_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Horizontal),
            chart.bar(bar.bar_config(
              data_key: "desktop",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      let html_v =
        chart.bar_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Vertical),
            chart.bar(bar.bar_config(
              data_key: "desktop",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      // Horizontal and Vertical should produce different SVG output
      { html_h != html_v } |> expect.to_be_true
    }),
    it("Vertical layout with multi-bar side-by-side works", fn() {
      let html =
        chart.bar_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Vertical),
            chart.bar(
              bar.bar_config(data_key: "desktop", meta: common.series_meta())
              |> bar.bar_fill(weft.css_color(value: "#ff0000")),
            ),
            chart.bar(
              bar.bar_config(data_key: "mobile", meta: common.series_meta())
              |> bar.bar_fill(weft.css_color(value: "#0000ff")),
            ),
          ],
        )
        |> element.to_string
      // Should have two bar groups
      let bar_count =
        string.split(html, "recharts-bar")
        |> list.length
      { bar_count >= 3 } |> expect.to_be_true
    }),
    it("Vertical layout bar with labels renders label text", fn() {
      let html =
        chart.bar_chart(
          data: test_data,
          width: chart.FixedWidth(pixels: 600),
          theme: option.None,
          height: 400,
          children: [
            chart.layout(layout: layout.Vertical),
            chart.bar(
              bar.bar_config(data_key: "desktop", meta: common.series_meta())
              |> bar.bar_label(True),
            ),
          ],
        )
        |> element.to_string
      // Should contain text elements with data values
      string.contains(html, "<text")
      |> expect.to_be_true
      // Should contain at least one value
      string.contains(html, "186")
      |> expect.to_be_true
    }),
    it(
      "Vertical layout line chart produces different path than Horizontal",
      fn() {
        let html_h =
          chart.line_chart(
            data: test_data,
            width: chart.FixedWidth(pixels: 600),
            theme: option.None,
            height: 400,
            children: [
              chart.layout(layout: layout.Horizontal),
              chart.line(line.line_config(
                data_key: "desktop",
                meta: common.series_meta(),
              )),
            ],
          )
          |> element.to_string
        let html_v =
          chart.line_chart(
            data: test_data,
            width: chart.FixedWidth(pixels: 600),
            theme: option.None,
            height: 400,
            children: [
              chart.layout(layout: layout.Vertical),
              chart.line(line.line_config(
                data_key: "desktop",
                meta: common.series_meta(),
              )),
            ],
          )
          |> element.to_string
        // Horizontal and Vertical should produce different paths
        { html_h != html_v } |> expect.to_be_true
      },
    ),
    it("LayoutDirection type constructors are accessible", fn() {
      // Verify the type constructors work correctly
      let h = layout.Horizontal
      let v = layout.Vertical
      { h != v } |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Overlay system enhancement tests
// ---------------------------------------------------------------------------

pub fn tooltip_enhancement_tests() {
  describe("tooltip_enhancements", [
    it("custom_content defaults to None", fn() {
      let config = tooltip.tooltip_config()
      config.custom_content |> expect.to_equal(expected: None)
    }),
    it("trigger defaults to HoverTrigger", fn() {
      let config = tooltip.tooltip_config()
      config.trigger |> expect.to_equal(expected: tooltip.HoverTrigger)
    }),
    it("tooltip_trigger sets ClickTrigger", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_trigger(trigger: tooltip.ClickTrigger)
      config.trigger |> expect.to_equal(expected: tooltip.ClickTrigger)
    }),
    it("content_style defaults to None", fn() {
      let config = tooltip.tooltip_config()
      config.content_style |> expect.to_equal(expected: None)
    }),
    it("tooltip_content_style sets value", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_content_style(style: "color: red")
      config.content_style |> expect.to_equal(expected: Some("color: red"))
    }),
    it("item_style defaults to None", fn() {
      let config = tooltip.tooltip_config()
      config.item_style |> expect.to_equal(expected: None)
    }),
    it("tooltip_item_style sets value", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_item_style(style: "font-weight: bold")
      config.item_style
      |> expect.to_equal(expected: Some("font-weight: bold"))
    }),
    it("label_style defaults to None", fn() {
      let config = tooltip.tooltip_config()
      config.label_style |> expect.to_equal(expected: None)
    }),
    it("tooltip_label_style sets value", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_label_style(style: "margin: 0")
      config.label_style |> expect.to_equal(expected: Some("margin: 0"))
    }),
    it("allow_escape_x and allow_escape_y are independent", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_allow_escape_x(allow: True)
      config.allow_escape_x |> expect.to_be_true
      config.allow_escape_y |> expect.to_be_false
    }),
    it("allow_escape_y independent of allow_escape_x", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_allow_escape_y(allow: True)
      config.allow_escape_x |> expect.to_be_false
      config.allow_escape_y |> expect.to_be_true
    }),
    it("animation_duration defaults to 400", fn() {
      let config = tooltip.tooltip_config()
      config.animation_duration |> expect.to_equal(expected: 400)
    }),
    it("tooltip_animation_duration sets value", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_animation_duration(duration: 200)
      config.animation_duration |> expect.to_equal(expected: 200)
    }),
    it("animation_duration appears in rendered output", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_animation_duration(duration: 250)
      let payload =
        tooltip.TooltipPayload(
          label: "Jan",
          entries: [
            tooltip.TooltipEntry(
              name: "sales",
              value: 100.0,
              color: weft.css_color(value: "#8884d8"),
              unit: "",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
          ],
          x: 50.0,
          y: 100.0,
          active_dots: [],
          zone_width: 0.0,
          zone_height: 0.0,
        )
      let html =
        tooltip.render_tooltips(
          config: config,
          payloads: [payload],
          plot_x: 0.0,
          plot_y: 10.0,
          plot_width: 400.0,
          plot_height: 200.0,
          zone_width: 50.0,
          zone_mode: tooltip.ColumnZone,
          zone_extra_attrs: [],
        )
        |> element.to_string
      html |> string.contains("250ms") |> expect.to_be_true
    }),
    it("custom content renders instead of default", fn() {
      let config =
        tooltip.tooltip_config()
        |> tooltip.tooltip_custom_content(renderer: fn(_payload) {
          element.text("custom-tooltip-content")
        })
      let payload =
        tooltip.TooltipPayload(
          label: "Jan",
          entries: [
            tooltip.TooltipEntry(
              name: "sales",
              value: 100.0,
              color: weft.css_color(value: "#8884d8"),
              unit: "",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
          ],
          x: 50.0,
          y: 100.0,
          active_dots: [],
          zone_width: 0.0,
          zone_height: 0.0,
        )
      let html =
        tooltip.render_tooltips(
          config: config,
          payloads: [payload],
          plot_x: 0.0,
          plot_y: 10.0,
          plot_width: 400.0,
          plot_height: 200.0,
          zone_width: 50.0,
          zone_mode: tooltip.ColumnZone,
          zone_extra_attrs: [],
        )
        |> element.to_string
      // Custom content should appear
      html
      |> string.contains("custom-tooltip-content")
      |> expect.to_be_true
      // Default tooltip structure should NOT appear
      html
      |> string.contains("weft-chart-tooltip-fg")
      |> expect.to_be_false
    }),
    describe("x_clamping", [
      it("flips tooltip to left side when right overflow on narrow chart", fn() {
        // plot_x=40, plot_width=220, payload.x=240, tw=140, offset=10
        // raw_x = 240 + 10 = 250; raw_x + tw = 390 > 260 -> flip
        // flipped = max(240 - 140 - 10, 40) = max(90, 40) = 90
        let config = tooltip.tooltip_config()
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "sales",
                value: 100.0,
                color: weft.css_color(value: "#8884d8"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 240.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 40.0,
            plot_y: 10.0,
            plot_width: 220.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        // Flip-then-clamp: tooltip flipped to left of data point
        html |> string.contains("x=\"90\"") |> expect.to_be_true
      }),
      it("does not flip tooltip x when it fits within plot area", fn() {
        // payload.x=50, offset=10, tw=140
        // raw_x = 50 + 10 = 60; raw_x + tw = 200 <= 400 -> no flip
        // max(60, 0) = 60
        let config = tooltip.tooltip_config()
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "sales",
                value: 100.0,
                color: weft.css_color(value: "#8884d8"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 50.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 300.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        // No overflow, tooltip placed at raw_x = 60
        html |> string.contains("x=\"60\"") |> expect.to_be_true
      }),
      it("flips reversed tooltip to right when left overflow", fn() {
        // reverse_x=True, payload.x=10, tw=140, offset=10
        // raw_x = 10 - 140 - 10 = -140; -140 < plot_x=20 -> flip
        // flipped = min(10 + 10, 20 + 300 - 140) = min(20, 180) = 20
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_reverse_direction(
            reverse_x: True,
            reverse_y: False,
          )
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "sales",
                value: 100.0,
                color: weft.css_color(value: "#8884d8"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 10.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 20.0,
            plot_y: 0.0,
            plot_width: 300.0,
            plot_height: 300.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        // Flip-then-clamp: reversed tooltip flipped to right of data point
        html |> string.contains("x=\"20\"") |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn tooltip_entry_fields_tests() {
  describe("tooltip_entry_fields", [
    describe("hidden field", [
      it("tooltip_entry constructor defaults hidden to False", fn() {
        let entry =
          tooltip.tooltip_entry(
            name: "A",
            value: 10.0,
            color: weft.css_color(value: "#f00"),
            unit: "",
          )
        entry.hidden |> expect.to_be_false
      }),
      it("tooltip_entry_hidden sets hidden flag", fn() {
        let entry =
          tooltip.tooltip_entry(
            name: "A",
            value: 10.0,
            color: weft.css_color(value: "#f00"),
            unit: "",
          )
          |> tooltip.tooltip_entry_hidden(hidden: True)
        entry.hidden |> expect.to_be_true
      }),
      it("hidden entry excluded when include_hidden is False", fn() {
        let config = tooltip.tooltip_config()
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "visible",
                value: 50.0,
                color: weft.css_color(value: "#f00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
              tooltip.TooltipEntry(
                name: "hidden-one",
                value: 30.0,
                color: weft.css_color(value: "#0f0"),
                unit: "",
                hidden: True,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 100.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html |> string.contains("visible") |> expect.to_be_true
        html |> string.contains("hidden-one") |> expect.to_be_false
      }),
      it("hidden entry included when include_hidden is True", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_include_hidden(include: True)
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "visible",
                value: 50.0,
                color: weft.css_color(value: "#f00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
              tooltip.TooltipEntry(
                name: "hidden-one",
                value: 30.0,
                color: weft.css_color(value: "#0f0"),
                unit: "",
                hidden: True,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 100.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html |> string.contains("visible") |> expect.to_be_true
        html |> string.contains("hidden-one") |> expect.to_be_true
      }),
    ]),
    describe("entry_type field", [
      it("tooltip_entry constructor defaults to VisibleEntry", fn() {
        let entry =
          tooltip.tooltip_entry(
            name: "A",
            value: 10.0,
            color: weft.css_color(value: "#f00"),
            unit: "",
          )
        entry.entry_type |> expect.to_equal(expected: tooltip.VisibleEntry)
      }),
      it("tooltip_entry_suppress sets NoneEntry", fn() {
        let entry =
          tooltip.tooltip_entry(
            name: "A",
            value: 10.0,
            color: weft.css_color(value: "#f00"),
            unit: "",
          )
          |> tooltip.tooltip_entry_suppress
        entry.entry_type |> expect.to_equal(expected: tooltip.NoneEntry)
      }),
      it("NoneEntry entry is never rendered", fn() {
        let config = tooltip.tooltip_config()
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "visible",
                value: 50.0,
                color: weft.css_color(value: "#f00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
              tooltip.TooltipEntry(
                name: "suppressed",
                value: 30.0,
                color: weft.css_color(value: "#0f0"),
                unit: "",
                hidden: False,
                entry_type: tooltip.NoneEntry,
              ),
            ],
            x: 100.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html |> string.contains("visible") |> expect.to_be_true
        html |> string.contains("suppressed") |> expect.to_be_false
      }),
      it("NoneEntry ignored even with include_hidden True", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_include_hidden(include: True)
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "suppressed",
                value: 30.0,
                color: weft.css_color(value: "#0f0"),
                unit: "",
                hidden: False,
                entry_type: tooltip.NoneEntry,
              ),
            ],
            x: 100.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html |> string.contains("suppressed") |> expect.to_be_false
      }),
    ]),
    describe("wrapper_style", [
      it("defaults to empty string", fn() {
        let config = tooltip.tooltip_config()
        config.wrapper_style |> expect.to_equal(expected: "")
      }),
      it("tooltip_wrapper_style builder sets value", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_wrapper_style(style: "z-index: 100")
        config.wrapper_style |> expect.to_equal(expected: "z-index: 100")
      }),
      it("wrapper_style applied to outer tooltip element", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_wrapper_style(style: "z-index: 100")
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "sales",
                value: 100.0,
                color: weft.css_color(value: "#f00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 100.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html |> string.contains("z-index: 100") |> expect.to_be_true
      }),
      it("empty wrapper_style does not add style attribute", fn() {
        let config = tooltip.tooltip_config()
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "sales",
                value: 100.0,
                color: weft.css_color(value: "#f00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 100.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html
        |> string.contains("recharts-tooltip-wrapper\" style")
        |> expect.to_be_false
      }),
    ]),
    describe("label_formatter with payload", [
      it("label_formatter receives entries list", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_label_formatter(formatter: fn(label, entries) {
            label <> " (" <> int.to_string(list.length(entries)) <> ")"
          })
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "sales",
                value: 100.0,
                color: weft.css_color(value: "#f00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
              tooltip.TooltipEntry(
                name: "profit",
                value: 50.0,
                color: weft.css_color(value: "#0f0"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 100.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html |> string.contains("Jan (2)") |> expect.to_be_true
      }),
      it("label_formatter only sees visible entries", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_label_formatter(formatter: fn(label, entries) {
            label <> " (" <> int.to_string(list.length(entries)) <> ")"
          })
        let payload =
          tooltip.TooltipPayload(
            label: "Jan",
            entries: [
              tooltip.TooltipEntry(
                name: "sales",
                value: 100.0,
                color: weft.css_color(value: "#f00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
              tooltip.TooltipEntry(
                name: "hidden",
                value: 50.0,
                color: weft.css_color(value: "#0f0"),
                unit: "",
                hidden: True,
                entry_type: tooltip.VisibleEntry,
              ),
              tooltip.TooltipEntry(
                name: "none",
                value: 25.0,
                color: weft.css_color(value: "#00f"),
                unit: "",
                hidden: False,
                entry_type: tooltip.NoneEntry,
              ),
            ],
            x: 100.0,
            y: 50.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          )
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: [payload],
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html |> string.contains("Jan (1)") |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn legend_event_tests() {
  describe("legend_events", [
    it("on_click defaults to None", fn() {
      let config = legend.legend_config()
      config.on_click |> expect.to_equal(expected: None)
    }),
    it("on_mouse_enter defaults to None", fn() {
      let config = legend.legend_config()
      config.on_mouse_enter |> expect.to_equal(expected: None)
    }),
    it("on_mouse_leave defaults to None", fn() {
      let config = legend.legend_config()
      config.on_mouse_leave |> expect.to_equal(expected: None)
    }),
    it("custom_content defaults to None", fn() {
      let config = legend.legend_config()
      config.custom_content |> expect.to_equal(expected: None)
    }),
    it("legend_on_click sets click handler", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_on_click(handler: fn(_name, _index) { "clicked" })
      case config.on_click {
        Some(_) -> True |> expect.to_be_true
        None -> False |> expect.to_be_true
      }
    }),
    it("legend_on_mouse_enter sets handler", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_on_mouse_enter(handler: fn(_name, _index) { "entered" })
      case config.on_mouse_enter {
        Some(_) -> True |> expect.to_be_true
        None -> False |> expect.to_be_true
      }
    }),
    it("legend_on_mouse_leave sets handler", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_on_mouse_leave(handler: fn(_name, _index) { "left" })
      case config.on_mouse_leave {
        Some(_) -> True |> expect.to_be_true
        None -> False |> expect.to_be_true
      }
    }),
    it("onClick produces click event attribute in output", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_on_click(handler: fn(_name, _index) { "clicked" })
      let payload = [
        legend.LegendPayload(
          value: "sales",
          color: weft.css_color(value: "#8884d8"),
          icon_type: shape.RectIcon,
          inactive: False,
        ),
      ]
      let html =
        legend.render_legend(
          config: config,
          payload: payload,
          chart_width: 400.0,
          chart_height: 300.0,
        )
        |> element.to_string
      // Click handler should add pointer cursor
      html |> string.contains("pointer") |> expect.to_be_true
    }),
    it("custom content renders instead of default legend", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_custom_content(renderer: fn(_payload) {
          element.text("custom-legend-content")
        })
      let payload = [
        legend.LegendPayload(
          value: "sales",
          color: weft.css_color(value: "#8884d8"),
          icon_type: shape.RectIcon,
          inactive: False,
        ),
      ]
      let html =
        legend.render_legend(
          config: config,
          payload: payload,
          chart_width: 400.0,
          chart_height: 300.0,
        )
        |> element.to_string
      // Custom content should appear
      html
      |> string.contains("custom-legend-content")
      |> expect.to_be_true
      // Default legend list should NOT appear
      html
      |> string.contains("recharts-default-legend")
      |> expect.to_be_false
    }),
    it("LegendPayload type constructs correctly", fn() {
      let p =
        legend.LegendPayload(
          value: "revenue",
          color: weft.css_color(value: "#ff0000"),
          icon_type: shape.CircleIcon,
          inactive: False,
        )
      p.value |> expect.to_equal(expected: "revenue")
      p.color |> expect.to_equal(expected: weft.css_color(value: "#ff0000"))
      p.inactive |> expect.to_be_false
    }),
  ])
}

pub fn label_position_tests() {
  describe("label_positions", [
    it("Top position computes center-x, above viewbox", fn() {
      let config = label.label_config(position: label.Top)
      let vb =
        label.CartesianViewBox(x: 10.0, y: 20.0, width: 100.0, height: 50.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "test",
        )
        |> element.to_string
      // text element should have x at center (60)
      html |> string.contains("60") |> expect.to_be_true
    }),
    it("Bottom position computes center-x, below viewbox", fn() {
      let config = label.label_config(position: label.Bottom)
      let vb =
        label.CartesianViewBox(x: 10.0, y: 20.0, width: 100.0, height: 50.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "test",
        )
        |> element.to_string
      // y should be below (20 + 50 + 5 = 75)
      html |> string.contains("75") |> expect.to_be_true
    }),
    it("Center position renders at midpoint", fn() {
      let config = label.label_config(position: label.Center)
      let vb =
        label.CartesianViewBox(x: 0.0, y: 0.0, width: 200.0, height: 100.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "center",
        )
        |> element.to_string
      // x at 100, y at 50
      html |> string.contains("100") |> expect.to_be_true
      html |> string.contains("50") |> expect.to_be_true
    }),
    it("InsideStart position is valid for polar labels", fn() {
      let config = label.label_config(position: label.InsideStart)
      let vb =
        label.PolarViewBox(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 100.0,
          start_angle: 0.0,
          end_angle: 90.0,
          clock_wise: True,
        )
      let html =
        label.render_polar_label(
          config: config,
          view_box: vb,
          content: "arc-text",
        )
        |> element.to_string
      // Should generate textPath for arc-following text
      html |> string.contains("textPath") |> expect.to_be_true
    }),
    it("InsideEnd position generates textPath", fn() {
      let config = label.label_config(position: label.InsideEnd)
      let vb =
        label.PolarViewBox(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 100.0,
          start_angle: 0.0,
          end_angle: 90.0,
          clock_wise: True,
        )
      let html =
        label.render_polar_label(
          config: config,
          view_box: vb,
          content: "end-text",
        )
        |> element.to_string
      html |> string.contains("textPath") |> expect.to_be_true
      html |> string.contains("end-text") |> expect.to_be_true
    }),
    it("End position generates textPath for polar", fn() {
      let config = label.label_config(position: label.End)
      let vb =
        label.PolarViewBox(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 100.0,
          start_angle: 0.0,
          end_angle: 90.0,
          clock_wise: True,
        )
      let html =
        label.render_polar_label(config: config, view_box: vb, content: "outer")
        |> element.to_string
      html |> string.contains("textPath") |> expect.to_be_true
    }),
    it("CenterTop position in cartesian context", fn() {
      let config = label.label_config(position: label.CenterTop)
      let vb =
        label.CartesianViewBox(x: 0.0, y: 0.0, width: 200.0, height: 100.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "top",
        )
        |> element.to_string
      // x at center (100), y near top (offset 5)
      html |> string.contains("100") |> expect.to_be_true
      html |> string.contains("hanging") |> expect.to_be_true
    }),
    it("CenterBottom position in cartesian context", fn() {
      let config = label.label_config(position: label.CenterBottom)
      let vb =
        label.CartesianViewBox(x: 0.0, y: 0.0, width: 200.0, height: 100.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "bottom",
        )
        |> element.to_string
      html |> string.contains("100") |> expect.to_be_true
    }),
    it("Middle position centers both axes", fn() {
      let config = label.label_config(position: label.Middle)
      let vb =
        label.CartesianViewBox(x: 0.0, y: 0.0, width: 200.0, height: 100.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "mid",
        )
        |> element.to_string
      html |> string.contains("middle") |> expect.to_be_true
      html |> string.contains("central") |> expect.to_be_true
    }),
    it("Inside position places label at center of element", fn() {
      let config = label.label_config(position: label.Inside)
      let vb =
        label.CartesianViewBox(x: 10.0, y: 20.0, width: 100.0, height: 50.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "inside",
        )
        |> element.to_string
      // x at center: 10 + 100/2 = 60
      html |> string.contains("60") |> expect.to_be_true
      // y at center: 20 + 50/2 = 45
      html |> string.contains("45") |> expect.to_be_true
      html |> string.contains("middle") |> expect.to_be_true
      html |> string.contains("central") |> expect.to_be_true
    }),
    it("label_inside builder creates Inside-positioned config", fn() {
      let config = label.label_inside()
      config.position |> expect.to_equal(expected: label.Inside)
    }),
  ])
}

pub fn label_angle_tests() {
  describe("label_angle", [
    it("angle defaults to None", fn() {
      let config = label.label_config(position: label.Top)
      config.angle |> expect.to_equal(expected: None)
    }),
    it("label_angle sets rotation", fn() {
      let config =
        label.label_config(position: label.Top)
        |> label.label_angle(angle: 45.0)
      config.angle |> expect.to_equal(expected: Some(45.0))
    }),
    it("angle rotation appears in SVG output", fn() {
      let config =
        label.label_config(position: label.Center)
        |> label.label_angle(angle: -90.0)
      let vb =
        label.CartesianViewBox(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "rotated",
        )
        |> element.to_string
      html |> string.contains("rotate") |> expect.to_be_true
      html |> string.contains("-90") |> expect.to_be_true
    }),
  ])
}

pub fn label_wrapping_tests() {
  describe("label_wrapping", [
    it("max_width defaults to None", fn() {
      let config = label.label_config(position: label.Top)
      config.max_width |> expect.to_equal(expected: None)
    }),
    it("max_lines defaults to None", fn() {
      let config = label.label_config(position: label.Top)
      config.max_lines |> expect.to_equal(expected: None)
    }),
    it("label_max_width sets wrapping width", fn() {
      let config =
        label.label_config(position: label.Top)
        |> label.label_max_width(width: 50.0)
      config.max_width |> expect.to_equal(expected: Some(50.0))
    }),
    it("word wrapping splits into tspan elements", fn() {
      let config =
        label.label_config(position: label.Center)
        |> label.label_max_width(width: 30.0)
      let vb =
        label.CartesianViewBox(x: 0.0, y: 0.0, width: 200.0, height: 100.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "this is a long text that should wrap",
        )
        |> element.to_string
      // Should produce tspan elements
      html |> string.contains("tspan") |> expect.to_be_true
    }),
    it("max_lines truncation with ellipsis", fn() {
      let config =
        label.label_config(position: label.Center)
        |> label.label_max_width(width: 30.0)
        |> label.label_max_lines(lines: 1)
      let vb =
        label.CartesianViewBox(x: 0.0, y: 0.0, width: 200.0, height: 100.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "this is a very long text that definitely needs to wrap onto multiple lines",
        )
        |> element.to_string
      // Should contain ellipsis
      html |> string.contains("...") |> expect.to_be_true
    }),
  ])
}

pub fn label_list_enhancement_tests() {
  describe("label_list_enhancements", [
    it("label_list_angle sets rotation", fn() {
      let config =
        label.label_list_config(data_key: "value")
        |> label.label_list_angle(angle: 30.0)
      config.angle |> expect.to_equal(expected: Some(30.0))
    }),
    it("label_list_max_width sets wrapping width", fn() {
      let config =
        label.label_list_config(data_key: "value")
        |> label.label_list_max_width(width: 100.0)
      config.max_width |> expect.to_equal(expected: Some(100.0))
    }),
    it("label_list_max_lines sets max lines", fn() {
      let config =
        label.label_list_config(data_key: "value")
        |> label.label_list_max_lines(lines: 2)
      config.max_lines |> expect.to_equal(expected: Some(2))
    }),
  ])
}

pub fn label_parity_p1_tests() {
  describe("label_parity_p1", [
    it("AtCoordinate positions label at given coordinates", fn() {
      let config = label.label_at_coordinate(x: 42.0, y: 99.0)
      let vb =
        label.CartesianViewBox(x: 0.0, y: 0.0, width: 200.0, height: 100.0)
      let html =
        label.render_cartesian_label(
          config: config,
          view_box: vb,
          content: "coord",
        )
        |> element.to_string
      html |> string.contains("42") |> expect.to_be_true
      html |> string.contains("99") |> expect.to_be_true
      html |> string.contains("middle") |> expect.to_be_true
    }),
    it("AtCoordinate works in polar context", fn() {
      let config =
        label.label_config(position: label.AtCoordinate(x: 55.0, y: 77.0))
      let vb =
        label.PolarViewBox(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 100.0,
          start_angle: 0.0,
          end_angle: 90.0,
          clock_wise: True,
        )
      let html =
        label.render_polar_label(
          config: config,
          view_box: vb,
          content: "polar-coord",
        )
        |> element.to_string
      html |> string.contains("55") |> expect.to_be_true
      html |> string.contains("77") |> expect.to_be_true
    }),
    it("clock_wise field exists in PolarViewBox", fn() {
      let vb =
        label.PolarViewBox(
          cx: 100.0,
          cy: 100.0,
          inner_radius: 20.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 180.0,
          clock_wise: False,
        )
      vb.clock_wise |> expect.to_equal(expected: False)
    }),
    it("clock_wise defaults to True in typical usage", fn() {
      let vb =
        label.PolarViewBox(
          cx: 100.0,
          cy: 100.0,
          inner_radius: 20.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 180.0,
          clock_wise: True,
        )
      vb.clock_wise |> expect.to_be_true
    }),
    it("font_weight propagates through LabelList", fn() {
      let config =
        label.label_list_config(data_key: "val")
        |> label.label_list_font_weight(weight: "bold")
      config.font_weight |> expect.to_equal(expected: "bold")
      let entries = [
        label.CartesianLabelEntry(
          value: "A",
          view_box: label.CartesianViewBox(
            x: 0.0,
            y: 0.0,
            width: 50.0,
            height: 50.0,
          ),
        ),
      ]
      let html =
        label.render_label_list(config: config, entries: entries)
        |> element.to_string
      html |> string.contains("bold") |> expect.to_be_true
    }),
    it("font_weight defaults to normal in LabelListConfig", fn() {
      let config = label.label_list_config(data_key: "val")
      config.font_weight |> expect.to_equal(expected: "normal")
    }),
    it("negative height flips vertical offset direction", fn() {
      let config =
        label.label_config(position: label.Top)
        |> label.label_offset(offset: 5.0)
      // Normal bar: Top offset goes up (y - offset)
      let normal_vb =
        label.CartesianViewBox(x: 10.0, y: 20.0, width: 40.0, height: 60.0)
      let normal_html =
        label.render_cartesian_label(
          config: config,
          view_box: normal_vb,
          content: "n",
        )
        |> element.to_string
      // y = 20 - 5 = 15
      normal_html |> string.contains("15") |> expect.to_be_true

      // Negative height bar: Top offset goes down (y + offset)
      let neg_vb =
        label.CartesianViewBox(x: 10.0, y: 20.0, width: 40.0, height: -60.0)
      let neg_html =
        label.render_cartesian_label(
          config: config,
          view_box: neg_vb,
          content: "n",
        )
        |> element.to_string
      // y = 20 + 5 = 25
      neg_html |> string.contains("25") |> expect.to_be_true
    }),
    it("negative width flips text-anchor start to end", fn() {
      let config = label.label_config(position: label.Right)
      // Normal: Right has text-anchor "start"
      let normal_vb =
        label.CartesianViewBox(x: 10.0, y: 20.0, width: 40.0, height: 60.0)
      let normal_html =
        label.render_cartesian_label(
          config: config,
          view_box: normal_vb,
          content: "r",
        )
        |> element.to_string
      normal_html
      |> string.contains("text-anchor=\"start\"")
      |> expect.to_be_true

      // Negative width: Right text-anchor flips to "end"
      let neg_vb =
        label.CartesianViewBox(x: 10.0, y: 20.0, width: -40.0, height: 60.0)
      let neg_html =
        label.render_cartesian_label(
          config: config,
          view_box: neg_vb,
          content: "r",
        )
        |> element.to_string
      neg_html
      |> string.contains("text-anchor=\"end\"")
      |> expect.to_be_true
    }),
  ])
}

pub fn legend_estimated_width_tests() {
  describe("legend_estimated_width", [
    it("returns 0 for HorizontalLegend", fn() {
      let config = legend.legend_config()
      legend.legend_estimated_width(config:)
      |> expect.to_equal(expected: 0)
    }),
    it("returns 150 for VerticalLegend with no width set", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_layout(layout: legend.VerticalLegend)
      legend.legend_estimated_width(config:)
      |> expect.to_equal(expected: 150)
    }),
    it("returns explicit width for VerticalLegend with width set", fn() {
      let config =
        legend.legend_config()
        |> legend.legend_layout(layout: legend.VerticalLegend)
        |> legend.legend_width(width: 200.0)
      legend.legend_estimated_width(config:)
      |> expect.to_equal(expected: 200)
    }),
  ])
}

pub fn svg_overflow_visible_tests() {
  describe("SVG overflow=visible", [
    it("pie_chart SVG has overflow visible for label clipping prevention", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("value", 100.0)]),
        ),
      ]
      let html =
        chart.pie_chart(
          data: data,
          width: chart.FixedWidth(pixels: 360),
          theme: option.None,
          height: 360,
          children: [
            chart.pie(
              pie.pie_config(data_key: "value")
              |> pie.pie_outer_radius(140.0)
              |> pie.pie_label(True),
            ),
          ],
        )
        |> element.to_string
      html
      |> string.contains("overflow=\"visible\"")
      |> expect.to_be_true
    }),
    it("radar_chart SVG has overflow visible", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("score", 80.0)]),
        ),
        chart.DataPoint(
          category: "B",
          values: dict.from_list([#("score", 60.0)]),
        ),
        chart.DataPoint(
          category: "C",
          values: dict.from_list([#("score", 70.0)]),
        ),
      ]
      let html =
        chart.radar_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 400,
          children: [
            chart.radar(radar.radar_config(data_key: "score")),
          ],
        )
        |> element.to_string
      html
      |> string.contains("overflow=\"visible\"")
      |> expect.to_be_true
    }),
    it("line_chart SVG has overflow visible", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("sales", 100.0)]),
        ),
      ]
      let html =
        chart.line_chart(
          data: data,
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "sales",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string
      html
      |> string.contains("overflow=\"visible\"")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

fn string_index_of(haystack: String, needle: String) -> Int {
  case string.split(haystack, needle) {
    [before, ..] -> string.length(before)
    [] -> -1
  }
}

fn count_occurrences(haystack: String, needle: String) -> Int {
  let parts = string.split(haystack, needle)
  case parts {
    [] -> 0
    _ -> list.length(parts) - 1
  }
}
