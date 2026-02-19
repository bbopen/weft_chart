//// Additive v2 API compatibility tests.
////
//// Verifies that new axis and series v2 APIs coexist with legacy
//// constructors/builders without behavioral regressions.

import gleam/dict
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/axis
import weft_chart/chart
import weft_chart/series/area
import weft_chart/series/bar
import weft_chart/series/common
import weft_chart/series/line

pub fn main() {
  startest.run(startest.default_config())
}

fn sample_data() -> List(chart.DataPoint) {
  [
    chart.DataPoint(category: "A", values: dict.from_list([#("value", 10.0)])),
    chart.DataPoint(category: "B", values: dict.from_list([#("value", 20.0)])),
    chart.DataPoint(category: "C", values: dict.from_list([#("value", 15.0)])),
  ]
}

pub fn axis_v2_compat_tests() {
  describe("axis v2 compatibility", [
    it("x_axis_v2 and y_axis_v2 match legacy default rendering", fn() {
      let legacy =
        chart.bar_chart(data: sample_data(), width: 500, height: 320, children: [
          chart.x_axis(axis.x_axis_config()),
          chart.y_axis(axis.y_axis_config()),
          chart.bar(bar.bar_config(data_key: "value")),
        ])
        |> element.to_string

      let v2 =
        chart.bar_chart(data: sample_data(), width: 500, height: 320, children: [
          chart.x_axis_v2(axis.x_axis_base_config()),
          chart.y_axis_v2(axis.y_axis_base_config()),
          chart.bar(bar.bar_config(data_key: "value")),
        ])
        |> element.to_string

      v2 |> expect.to_equal(expected: legacy)
    }),
    it("axis_size and axis_padding map by role", fn() {
      let x_config =
        axis.axis_to_x(
          config: axis.x_axis_base_config()
          |> axis.axis_padding(start: 8, end: 12)
          |> axis.axis_size(size: 40),
        )

      let y_config =
        axis.axis_to_y(
          config: axis.y_axis_base_config()
          |> axis.axis_padding(start: 3, end: 7)
          |> axis.axis_size(size: 90),
        )

      x_config.padding_left |> expect.to_equal(expected: 8)
      x_config.padding_right |> expect.to_equal(expected: 12)
      x_config.height |> expect.to_equal(expected: 40)
      y_config.padding_top |> expect.to_equal(expected: 3)
      y_config.padding_bottom |> expect.to_equal(expected: 7)
      y_config.width |> expect.to_equal(expected: 90)
    }),
  ])
}

pub fn series_v2_compat_tests() {
  describe("series v2 compatibility", [
    it("line_config_v2 maps shared metadata fields", fn() {
      let meta =
        common.series_meta()
        |> common.series_name(name: "Revenue")
        |> common.series_hide(hide: True)
        |> common.series_unit(unit: "USD")
        |> common.series_css_class(class: "line-v2")

      let config = line.line_config_v2(data_key: "value", meta: meta)

      config.name |> expect.to_equal(expected: "Revenue")
      config.hide |> expect.to_equal(expected: True)
      config.unit |> expect.to_equal(expected: "USD")
      config.css_class |> expect.to_equal(expected: "line-v2")
    }),
    it("area_config_v2 default metadata matches legacy constructor", fn() {
      let legacy =
        chart.area_chart(
          data: sample_data(),
          width: 500,
          height: 320,
          children: [chart.area(area.area_config(data_key: "value"))],
        )
        |> element.to_string

      let v2 =
        chart.area_chart(
          data: sample_data(),
          width: 500,
          height: 320,
          children: [
            chart.area(area.area_config_v2(
              data_key: "value",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      v2 |> expect.to_equal(expected: legacy)
    }),
    it("bar_config_v2 default metadata matches legacy constructor", fn() {
      let legacy =
        chart.bar_chart(data: sample_data(), width: 500, height: 320, children: [
          chart.bar(bar.bar_config(data_key: "value")),
        ])
        |> element.to_string

      let v2 =
        chart.bar_chart(data: sample_data(), width: 500, height: 320, children: [
          chart.bar(bar.bar_config_v2(
            data_key: "value",
            meta: common.series_meta(),
          )),
        ])
        |> element.to_string

      v2 |> expect.to_equal(expected: legacy)
    }),
  ])
}
