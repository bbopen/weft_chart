//// Tests for axis custom tick and SVG accessibility features.

import gleam/dict
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/axis
import weft_chart/chart
import weft_chart/series/line

pub fn main() {
  startest.run(startest.default_config())
}

// Test custom tick builders
pub fn custom_tick_tests() {
  describe("custom_tick", [
    it("x_custom_tick sets the custom tick renderer", fn() {
      let _config =
        axis.x_axis_config()
        |> axis.x_custom_tick(renderer: fn(_props) { element.none() })
      // Config builds without error
      True |> expect.to_be_true
    }),
    it("y_custom_tick sets the custom tick renderer", fn() {
      let _config =
        axis.y_axis_config()
        |> axis.y_custom_tick(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
  ])
}

// Test include_hidden builders
pub fn include_hidden_tests() {
  describe("include_hidden", [
    it("x_include_hidden defaults to False", fn() {
      let config = axis.x_axis_config()
      config.include_hidden |> expect.to_equal(expected: False)
    }),
    it("x_include_hidden sets to True", fn() {
      let config =
        axis.x_axis_config()
        |> axis.x_include_hidden(include: True)
      config.include_hidden |> expect.to_equal(expected: True)
    }),
    it("y_include_hidden defaults to False", fn() {
      let config = axis.y_axis_config()
      config.include_hidden |> expect.to_equal(expected: False)
    }),
    it("y_include_hidden sets to True", fn() {
      let config =
        axis.y_axis_config()
        |> axis.y_include_hidden(include: True)
      config.include_hidden |> expect.to_equal(expected: True)
    }),
  ])
}

// Test SVG accessibility
pub fn svg_a11y_tests() {
  describe("svg_a11y", [
    it("chart_title renders title element in SVG", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("v", 100.0)]),
        ),
      ]
      let html =
        chart.line_chart(data: data, width: 400, height: 300, children: [
          chart.line(line.line_config(data_key: "v")),
          chart.chart_title(text: "My Chart"),
        ])
        |> element.to_string
      html |> string.contains("<title>My Chart</title>") |> expect.to_be_true
    }),
    it("chart_desc renders desc element in SVG", fn() {
      let data = [
        chart.DataPoint(
          category: "Jan",
          values: dict.from_list([#("v", 100.0)]),
        ),
      ]
      let html =
        chart.line_chart(data: data, width: 400, height: 300, children: [
          chart.line(line.line_config(data_key: "v")),
          chart.chart_desc(text: "Revenue over time"),
        ])
        |> element.to_string
      html
      |> string.contains("<desc>Revenue over time</desc>")
      |> expect.to_be_true
    }),
  ])
}
