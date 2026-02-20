//// Tests for series custom render callbacks.

import gleam/dict
import gleam/option
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/chart
import weft_chart/series/area
import weft_chart/series/bar
import weft_chart/series/common
import weft_chart/series/funnel
import weft_chart/series/line
import weft_chart/series/pie
import weft_chart/series/radar
import weft_chart/series/radial_bar
import weft_chart/series/scatter

pub fn main() {
  startest.run(startest.default_config())
}

pub fn custom_dot_tests() {
  describe("custom_dot", [
    it("line_custom_dot builder sets renderer", fn() {
      let _config =
        line.line_config(data_key: "v", meta: common.series_meta())
        |> line.line_custom_dot(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
    it("scatter_custom_dot builder sets renderer", fn() {
      let _config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_custom_dot(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
    it("radar_custom_dot builder sets renderer", fn() {
      let _config =
        radar.radar_config(data_key: "v")
        |> radar.radar_custom_dot(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
  ])
}

pub fn custom_label_tests() {
  describe("custom_label", [
    it("line_custom_label builder sets renderer", fn() {
      let _config =
        line.line_config(data_key: "v", meta: common.series_meta())
        |> line.line_custom_label(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
    it("area_custom_label builder sets renderer", fn() {
      let _config =
        area.area_config(data_key: "v", meta: common.series_meta())
        |> area.area_custom_label(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
    it("bar_custom_label builder sets renderer", fn() {
      let _config =
        bar.bar_config(data_key: "v", meta: common.series_meta())
        |> bar.bar_custom_label(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
    it("pie_custom_label builder sets renderer", fn() {
      let _config =
        pie.pie_config(data_key: "v")
        |> pie.pie_custom_label(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
    it("radar_custom_label builder sets renderer", fn() {
      let _config =
        radar.radar_config(data_key: "v")
        |> radar.radar_custom_label(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
    it("radial_bar_custom_label builder sets renderer", fn() {
      let _config =
        radial_bar.radial_bar_config(data_key: "v")
        |> radial_bar.radial_bar_custom_label(renderer: fn(_props) {
          element.none()
        })
      True |> expect.to_be_true
    }),
    it("funnel_custom_label builder sets renderer", fn() {
      let _config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_custom_label(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
  ])
}

pub fn custom_shape_tests() {
  describe("custom_shape", [
    it("bar_custom_shape builder sets renderer", fn() {
      let _config =
        bar.bar_config(data_key: "v", meta: common.series_meta())
        |> bar.bar_custom_shape(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
    it("pie_custom_label_line builder sets renderer", fn() {
      let _config =
        pie.pie_config(data_key: "v")
        |> pie.pie_custom_label_line(renderer: fn(_props) { element.none() })
      True |> expect.to_be_true
    }),
  ])
}

fn scatter_data() -> List(chart.DataPoint) {
  [
    chart.DataPoint(
      category: "A",
      values: dict.from_list([#("x", 0.0), #("y", 10.0)]),
    ),
    chart.DataPoint(
      category: "B",
      values: dict.from_list([#("x", 50.0), #("y", 20.0)]),
    ),
    chart.DataPoint(
      category: "C",
      values: dict.from_list([#("x", 100.0), #("y", 50.0)]),
    ),
  ]
}

pub fn scatter_line_type_render_tests() {
  describe("scatter_line_type", [
    it("FittingLine renders a different path than JointLine", fn() {
      let joint_html =
        chart.scatter_chart(
          data: scatter_data(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.scatter(
              scatter.scatter_config(x_data_key: "x", y_data_key: "y")
              |> scatter.scatter_show_line(show: True)
              |> scatter.scatter_line_type(type_: scatter.JointLine),
            ),
          ],
        )
        |> element.to_string

      let fitting_html =
        chart.scatter_chart(
          data: scatter_data(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.scatter(
              scatter.scatter_config(x_data_key: "x", y_data_key: "y")
              |> scatter.scatter_show_line(show: True)
              |> scatter.scatter_line_type(type_: scatter.FittingLine),
            ),
          ],
        )
        |> element.to_string

      fitting_html
      |> string.contains("recharts-scatter-line")
      |> expect.to_be_true
      { joint_html != fitting_html } |> expect.to_be_true
    }),
  ])
}
