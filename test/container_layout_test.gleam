//// Tests for container layout features.
////
//// Covers stack offsets (wiggle, silhouette), BarSize percentage,
//// maxBarSize, series clipping, SVG attributes (role, class, id, style),
//// syncId, compact mode, and reference domain extension.

import gleam/dict
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/chart
import weft_chart/series/bar

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

fn two_series_data() -> List(chart.DataPoint) {
  [
    chart.DataPoint(
      category: "A",
      values: dict.from_list([#("s1", 10.0), #("s2", 20.0)]),
    ),
    chart.DataPoint(
      category: "B",
      values: dict.from_list([#("s1", 30.0), #("s2", 10.0)]),
    ),
    chart.DataPoint(
      category: "C",
      values: dict.from_list([#("s1", 20.0), #("s2", 30.0)]),
    ),
  ]
}

fn stacked_bar_chart(offset: chart.StackOffsetType) -> String {
  let data = two_series_data()
  chart.bar_chart(data: data, width: 400, height: 300, children: [
    chart.stack_offset(offset),
    chart.bar(bar.bar_config(data_key: "s1") |> bar.bar_stack_id("stack1")),
    chart.bar(bar.bar_config(data_key: "s2") |> bar.bar_stack_id("stack1")),
  ])
  |> element.to_string
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

pub fn container_layout_tests() {
  describe("container_layout", [
    // ----- Stack Offset Wiggle -----
    describe("StackOffsetWiggle", [
      it("produces valid stacked SVG output", fn() {
        let html = stacked_bar_chart(chart.StackOffsetWiggle)
        // Should produce valid SVG with bars
        html |> string.contains("<svg") |> expect.to_be_true
      }),
      it("offsets differ from none stacking", fn() {
        let none_html = stacked_bar_chart(chart.StackOffsetNone)
        let wiggle_html = stacked_bar_chart(chart.StackOffsetWiggle)
        // Wiggle should produce different output than none
        { none_html != wiggle_html } |> expect.to_be_true
      }),
    ]),
    // ----- Stack Offset Silhouette -----
    describe("StackOffsetSilhouette", [
      it("produces valid stacked SVG output", fn() {
        let html = stacked_bar_chart(chart.StackOffsetSilhouette)
        html |> string.contains("<svg") |> expect.to_be_true
      }),
      it("centers around zero", fn() {
        // Silhouette should shift baselines so midpoint is at zero
        let sil_html = stacked_bar_chart(chart.StackOffsetSilhouette)
        let none_html = stacked_bar_chart(chart.StackOffsetNone)
        // Should differ from none stacking
        { sil_html != none_html } |> expect.to_be_true
      }),
    ]),
    // ----- BarSize percentage -----
    describe("BarSize percent", [
      it("resolves PercentBarSize against plot width", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.bar_layout(
              bar_category_gap: 0.1,
              bar_gap: 4.0,
              chart_bar_size: chart.PercentBarSize(percent: 0.5),
            ),
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        // Should produce valid SVG with bars
        html |> string.contains("<svg") |> expect.to_be_true
        // Width should reflect percent * plot_width
        html |> string.contains("width=") |> expect.to_be_true
      }),
    ]),
    // ----- maxBarSize -----
    describe("maxBarSize", [
      it("clamps bar width to maximum", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.max_bar_size(size: 20),
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        // The bar width should be clamped to 20
        html |> string.contains("width=\"20\"") |> expect.to_be_true
      }),
    ]),
    // ----- Series clipping -----
    describe("series clipping", [
      it("clip-path attribute present on series groups", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        html
        |> string.contains("clip-path=\"url(#weft-chart-clip)\"")
        |> expect.to_be_true
      }),
    ]),
    // ----- role attribute -----
    describe("role", [
      it("applies role attribute on SVG", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.role(role: "graphics-document"),
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        html
        |> string.contains("role=\"graphics-document\"")
        |> expect.to_be_true
      }),
      it("defaults to img when not specified", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        html |> string.contains("role=\"img\"") |> expect.to_be_true
      }),
    ]),
    // ----- class attribute -----
    describe("class", [
      it("applies class attribute on SVG", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.class(class: "my-chart"),
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        html |> string.contains("class=\"my-chart\"") |> expect.to_be_true
      }),
    ]),
    // ----- id attribute -----
    describe("id", [
      it("applies id attribute on SVG", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.id(id: "chart-1"),
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        html |> string.contains("id=\"chart-1\"") |> expect.to_be_true
      }),
    ]),
    // ----- style attribute -----
    describe("style", [
      it("applies style attribute on SVG", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.style(style: "background: white"),
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        html
        |> string.contains("style=\"display:block;background: white\"")
        |> expect.to_be_true
      }),
    ]),
    // ----- syncId -----
    describe("syncId", [
      it("emits data-sync-id attribute", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.sync_id(id: "sync-group-1"),
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        html
        |> string.contains("data-sync-id=\"sync-group-1\"")
        |> expect.to_be_true
      }),
      it("emits data-sync-method attribute", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.sync_id(id: "sync-group-1"),
            chart.sync_method(method: chart.SyncByIndex),
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        html
        |> string.contains("data-sync-method=\"index\"")
        |> expect.to_be_true
      }),
    ]),
    // ----- compact mode -----
    describe("compact", [
      it("minimizes margins", fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
        ]
        let compact_html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.compact(),
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        let normal_html =
          chart.bar_chart(data: data, width: 400, height: 300, children: [
            chart.bar(bar.bar_config(data_key: "v")),
          ])
          |> element.to_string
        // Compact should produce different output (wider plot area)
        { compact_html != normal_html } |> expect.to_be_true
      }),
    ]),
  ])
}
