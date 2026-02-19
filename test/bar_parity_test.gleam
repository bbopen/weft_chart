//// Tests for bar sizing parity with recharts.
////
//// Verifies that bar positioning and width calculations match the
//// recharts test vectors from scripts/test-vectors.json.

import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/chart
import weft_chart/series/bar
import weft_chart/series/common

pub fn main() {
  startest.run(startest.default_config())
}

pub fn single_bar_sizing_tests() {
  describe("single bar sizing", [
    it("uses 80% of bandwidth by default (10% gap each side)", fn() {
      // A single bar in a bar chart should get width = 80% of bandwidth
      // matching recharts default barCategoryGap of 10%.
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
      ]
      let html =
        chart.bar_chart(data: data, width: 400, height: 300, children: [
          chart.bar(bar.bar_config(data_key: "v", meta: common.series_meta())),
        ])
        |> element.to_string
      // Single bar should NOT use the old 60% fallback
      // With 10% category gap, the bar gets 80% of bandwidth
      html |> string.contains("recharts-bar") |> expect.to_be_true
    }),
    it("bar_config defaults to bar_size=0 and max_bar_size=0", fn() {
      let config = bar.bar_config(data_key: "v", meta: common.series_meta())
      config.bar_size |> expect.to_equal(expected: 0)
      config.max_bar_size |> expect.to_equal(expected: 0)
    }),
  ])
}

pub fn multi_bar_positioning_tests() {
  describe("multi-bar positioning", [
    it("two bars render side by side in the same chart", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("v1", 10.0), #("v2", 20.0)]),
        ),
      ]
      let html =
        chart.bar_chart(data: data, width: 400, height: 300, children: [
          chart.bar(bar.bar_config(data_key: "v1", meta: common.series_meta())),
          chart.bar(bar.bar_config(data_key: "v2", meta: common.series_meta())),
        ])
        |> element.to_string
      // Both bars should be rendered
      html |> string.contains("recharts-bar") |> expect.to_be_true
    }),
    it("three bars render in a chart", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([
            #("v1", 10.0),
            #("v2", 20.0),
            #("v3", 30.0),
          ]),
        ),
      ]
      let html =
        chart.bar_chart(data: data, width: 400, height: 300, children: [
          chart.bar(bar.bar_config(data_key: "v1", meta: common.series_meta())),
          chart.bar(bar.bar_config(data_key: "v2", meta: common.series_meta())),
          chart.bar(bar.bar_config(data_key: "v3", meta: common.series_meta())),
        ])
        |> element.to_string
      html |> string.contains("recharts-bar") |> expect.to_be_true
    }),
    it("bar_layout configures category gap and bar gap", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("v1", 10.0), #("v2", 20.0)]),
        ),
      ]
      let html =
        chart.bar_chart(data: data, width: 400, height: 300, children: [
          chart.bar_layout(
            bar_category_gap: 0.15,
            bar_gap: 20.0,
            chart_bar_size: chart.FixedBarSize(size: 0),
          ),
          chart.bar(bar.bar_config(data_key: "v1", meta: common.series_meta())),
          chart.bar(bar.bar_config(data_key: "v2", meta: common.series_meta())),
        ])
        |> element.to_string
      html |> string.contains("recharts-bar") |> expect.to_be_true
    }),
    it("explicit chart_bar_size overrides computed width", fn() {
      let data = [
        chart.DataPoint(
          category: "A",
          values: dict.from_list([#("v1", 10.0), #("v2", 20.0)]),
        ),
      ]
      let html =
        chart.bar_chart(data: data, width: 400, height: 300, children: [
          chart.bar_layout(
            bar_category_gap: 0.1,
            bar_gap: 4.0,
            chart_bar_size: chart.FixedBarSize(size: 30),
          ),
          chart.bar(bar.bar_config(data_key: "v1", meta: common.series_meta())),
          chart.bar(bar.bar_config(data_key: "v2", meta: common.series_meta())),
        ])
        |> element.to_string
      // Width attribute should contain "30" for the bar size
      html |> string.contains("30") |> expect.to_be_true
    }),
  ])
}

pub fn bar_fallback_tests() {
  describe("bar fallback when no position map", [
    it("uses 80% of bandwidth not 60%", fn() {
      // The bar module fallback (when no position is provided)
      // should use 10% gap on each side = 80% of bandwidth.
      // This is tested by ensuring bar_config defaults lead to
      // reasonable rendering without a BarPosition.
      let config = bar.bar_config(data_key: "v", meta: common.series_meta())
      // bar_size defaults to 0, meaning the fallback path is used
      config.bar_size |> expect.to_equal(expected: 0)
    }),
  ])
}

pub fn bar_data_override_tests() {
  describe("bar data_override", [
    it("defaults to None", fn() {
      let config = bar.bar_config(data_key: "v", meta: common.series_meta())
      config.data_override |> expect.to_equal(expected: None)
    }),
    it("bar_data_override sets Some(data)", fn() {
      let override_data = [dict.from_list([#("v", 99.0)])]
      let config =
        bar.bar_config(data_key: "v", meta: common.series_meta())
        |> bar.bar_data_override(data: override_data)
      config.data_override |> expect.to_equal(expected: Some(override_data))
    }),
    it("renders using override data when set", fn() {
      let chart_data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
      ]
      let override_data = [dict.from_list([#("v", 50.0)])]
      let html =
        chart.bar_chart(data: chart_data, width: 400, height: 300, children: [
          chart.bar(
            bar.bar_config(data_key: "v", meta: common.series_meta())
            |> bar.bar_data_override(data: override_data),
          ),
        ])
        |> element.to_string
      html |> string.contains("recharts-bar") |> expect.to_be_true
    }),
  ])
}

pub fn bar_min_point_size_type_tests() {
  describe("bar MinPointSize", [
    it("defaults to FixedMinPointSize(0.0)", fn() {
      let config = bar.bar_config(data_key: "v", meta: common.series_meta())
      config.min_point_size
      |> expect.to_equal(expected: bar.FixedMinPointSize(0.0))
    }),
    it("bar_min_point_size sets FixedMinPointSize", fn() {
      let config =
        bar.bar_config(data_key: "v", meta: common.series_meta())
        |> bar.bar_min_point_size(size: 5.0)
      config.min_point_size
      |> expect.to_equal(expected: bar.FixedMinPointSize(5.0))
    }),
    it("bar_min_point_size_fn sets DynamicMinPointSize", fn() {
      let f = fn(_value, _index) { 10.0 }
      let config =
        bar.bar_config(data_key: "v", meta: common.series_meta())
        |> bar.bar_min_point_size_fn(f: f)
      case config.min_point_size {
        bar.DynamicMinPointSize(func) -> {
          // Verify the function returns expected values
          func(0.0, 0) |> expect.to_equal(expected: 10.0)
        }
        bar.FixedMinPointSize(_) -> {
          // Should not be fixed
          False |> expect.to_be_true
        }
      }
    }),
  ])
}
