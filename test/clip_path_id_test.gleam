//// Regression tests for chart-scoped clip-path identifiers.
////
//// Ensures clip-path ids are chart-scoped so multiple charts in one
//// document do not collide.

import gleam/dict
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/chart
import weft_chart/series/line

pub fn main() {
  startest.run(startest.default_config())
}

fn sample_data_a() -> List(chart.DataPoint) {
  [
    chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
    chart.DataPoint(category: "B", values: dict.from_list([#("v", 20.0)])),
  ]
}

fn sample_data_b() -> List(chart.DataPoint) {
  [
    chart.DataPoint(category: "Q1", values: dict.from_list([#("v", 10.0)])),
    chart.DataPoint(category: "Q2", values: dict.from_list([#("v", 20.0)])),
  ]
}

pub fn clip_path_id_tests() {
  describe("clip_path_id", [
    it("uses chart id to scope clip-path ids", fn() {
      let html_a =
        chart.line_chart(
          data: sample_data_a(),
          width: 400,
          height: 300,
          children: [
            chart.id(id: "chart-a"),
            chart.line(line.line_config(data_key: "v")),
          ],
        )
        |> element.to_string

      let html_b =
        chart.line_chart(
          data: sample_data_a(),
          width: 400,
          height: 300,
          children: [
            chart.id(id: "chart-b"),
            chart.line(line.line_config(data_key: "v")),
          ],
        )
        |> element.to_string

      html_a
      |> string.contains("clipPath id=\"weft-chart-clip-chart-a\"")
      |> expect.to_be_true
      html_b
      |> string.contains("clipPath id=\"weft-chart-clip-chart-b\"")
      |> expect.to_be_true
    }),
    it("fallback clip-path id changes with data signature", fn() {
      let html_a =
        chart.line_chart(
          data: sample_data_a(),
          width: 400,
          height: 300,
          children: [
            chart.line(line.line_config(data_key: "v")),
          ],
        )
        |> element.to_string

      let html_b =
        chart.line_chart(
          data: sample_data_b(),
          width: 400,
          height: 300,
          children: [
            chart.line(line.line_config(data_key: "v")),
          ],
        )
        |> element.to_string

      let id_a = first_clip_path_id(html_a)
      let id_b = first_clip_path_id(html_b)

      { id_a != "" } |> expect.to_be_true
      { id_b != "" } |> expect.to_be_true
      { id_a != id_b } |> expect.to_be_true
    }),
  ])
}

fn first_clip_path_id(html: String) -> String {
  case string.split(html, "<clipPath id=\"") {
    [_, rest, ..] ->
      case string.split(rest, "\"") {
        [id, ..] -> id
        _ -> ""
      }
    _ -> ""
  }
}
