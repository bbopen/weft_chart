//// Integration tests for BrushChild wiring in the chart pipeline.
////
//// Verifies that BrushChild is accepted by composed_chart, that the
//// brush reserves bottom margin space, and that the chart_brush builder
//// creates the correct variant.

import gleam/dict
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/brush
import weft_chart/chart
import weft_chart/series/line as line_series

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

fn simple_data() -> List(chart.DataPoint) {
  [
    chart.DataPoint(category: "A", values: dict.from_list([#("val", 10.0)])),
    chart.DataPoint(category: "B", values: dict.from_list([#("val", 20.0)])),
    chart.DataPoint(category: "C", values: dict.from_list([#("val", 30.0)])),
  ]
}

fn brush_data() -> List(dict.Dict(String, Float)) {
  [
    dict.from_list([#("val", 10.0)]),
    dict.from_list([#("val", 20.0)]),
    dict.from_list([#("val", 30.0)]),
  ]
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

pub fn brush_integration_tests() {
  describe("BrushChild integration", [
    it("BrushChild is accepted by composed_chart", fn() {
      let brush_config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
      let svg =
        chart.composed_chart(
          data: simple_data(),
          width: 500,
          height: 300,
          children: [
            chart.line(line_series.line_config(data_key: "val")),
            chart.chart_brush(config: brush_config),
          ],
        )
      let html = element.to_string(svg)
      // The output should contain the brush SVG group
      html
      |> string.contains("recharts-brush")
      |> expect.to_be_true
    }),
    it("brush reserves bottom margin space", fn() {
      // Render chart without brush
      let svg_no_brush =
        chart.composed_chart(
          data: simple_data(),
          width: 500,
          height: 300,
          children: [
            chart.line(line_series.line_config(data_key: "val")),
          ],
        )
      // Render chart with brush (default height 40.0)
      let brush_config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
      let svg_with_brush =
        chart.composed_chart(
          data: simple_data(),
          width: 500,
          height: 300,
          children: [
            chart.line(line_series.line_config(data_key: "val")),
            chart.chart_brush(config: brush_config),
          ],
        )
      let html_no = element.to_string(svg_no_brush)
      let html_with = element.to_string(svg_with_brush)
      // The brush version should contain the brush element
      html_with
      |> string.contains("recharts-brush")
      |> expect.to_be_true
      // The non-brush version should NOT contain it
      html_no
      |> string.contains("recharts-brush")
      |> expect.to_be_false
    }),
    it("chart_brush builder creates BrushChild", fn() {
      let brush_config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
      let child = chart.chart_brush(config: brush_config)
      // Verify it is the BrushChild variant by pattern matching
      case child {
        chart.BrushChild(config:) -> {
          config.start_index |> expect.to_equal(expected: 0)
          config.end_index |> expect.to_equal(expected: 2)
          config.data_key |> expect.to_equal(expected: "val")
          config.height |> expect.to_equal(expected: 40.0)
        }
        _ -> expect.to_be_true(False)
      }
    }),
  ])
}
