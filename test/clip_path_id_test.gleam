//// Regression tests for chart-scoped clip-path identifiers.
////
//// Ensures clip-path ids are chart-scoped so multiple charts in one
//// document do not collide.

import gleam/dict
import gleam/option
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/chart
import weft_chart/series/common
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

fn sample_data_c() -> List(chart.DataPoint) {
  [
    chart.DataPoint(category: "Q", values: dict.from_list([#("w", 30.0)])),
    chart.DataPoint(category: "R", values: dict.from_list([#("w", 40.0)])),
  ]
}

fn sample_data_precision_a() -> List(chart.DataPoint) {
  [
    chart.DataPoint(
      category: "A",
      values: dict.from_list([#("v", 10.123456781)]),
    ),
    chart.DataPoint(
      category: "B",
      values: dict.from_list([#("v", 20.123456781)]),
    ),
  ]
}

fn sample_data_precision_b() -> List(chart.DataPoint) {
  [
    chart.DataPoint(
      category: "A",
      values: dict.from_list([#("v", 10.123456789)]),
    ),
    chart.DataPoint(
      category: "B",
      values: dict.from_list([#("v", 20.123456789)]),
    ),
  ]
}

fn sample_data_unicode_a() -> List(chart.DataPoint) {
  [
    chart.DataPoint(
      category: "Ångström",
      values: dict.from_list([#("v", 10.0)]),
    ),
    chart.DataPoint(category: "東京", values: dict.from_list([#("v", 20.0)])),
  ]
}

fn sample_data_unicode_b() -> List(chart.DataPoint) {
  [
    chart.DataPoint(
      category: "Angstrom",
      values: dict.from_list([#("v", 10.0)]),
    ),
    chart.DataPoint(category: "Tokyo", values: dict.from_list([#("v", 20.0)])),
  ]
}

fn sample_data_order_a() -> List(chart.DataPoint) {
  [
    chart.DataPoint(
      category: "A",
      values: dict.from_list([#("x", 1.0), #("y", 2.0)]),
    ),
    chart.DataPoint(
      category: "B",
      values: dict.from_list([#("x", 3.0), #("y", 4.0)]),
    ),
  ]
}

fn sample_data_order_b() -> List(chart.DataPoint) {
  [
    chart.DataPoint(
      category: "A",
      values: dict.from_list([#("y", 2.0), #("x", 1.0)]),
    ),
    chart.DataPoint(
      category: "B",
      values: dict.from_list([#("y", 4.0), #("x", 3.0)]),
    ),
  ]
}

pub fn clip_path_id_tests() {
  describe("clip_path_id", [
    it("uses chart id to scope clip-path ids", fn() {
      let html_a =
        chart.line_chart(
          data: sample_data_a(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.id(id: "chart-a"),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let html_b =
        chart.line_chart(
          data: sample_data_a(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.id(id: "chart-b"),
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
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
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let html_b =
        chart.line_chart(
          data: sample_data_b(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let id_a = first_clip_path_id(html_a)
      let id_b = first_clip_path_id(html_b)

      { id_a != "" } |> expect.to_be_true
      { id_b != "" } |> expect.to_be_true
      { id_a != id_b } |> expect.to_be_true
    }),
    it("fallback clip-path id avoids old equal-length collisions", fn() {
      let html_a =
        chart.line_chart(
          data: sample_data_a(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let html_c =
        chart.line_chart(
          data: sample_data_c(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "w",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let id_a = first_clip_path_id(html_a)
      let id_c = first_clip_path_id(html_c)

      { id_a != "" } |> expect.to_be_true
      { id_c != "" } |> expect.to_be_true
      { id_a != id_c } |> expect.to_be_true
    }),
    it("fallback clip-path id changes with plot geometry", fn() {
      let html_default =
        chart.line_chart(
          data: sample_data_a(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let html_taller =
        chart.line_chart(
          data: sample_data_a(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 420,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let id_default = first_clip_path_id(html_default)
      let id_taller = first_clip_path_id(html_taller)

      { id_default != "" } |> expect.to_be_true
      { id_taller != "" } |> expect.to_be_true
      { id_default != id_taller } |> expect.to_be_true
    }),
    it("fallback clip-path id preserves near-equal float distinctions", fn() {
      let html_a =
        chart.line_chart(
          data: sample_data_precision_a(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let html_b =
        chart.line_chart(
          data: sample_data_precision_b(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let id_a = first_clip_path_id(html_a)
      let id_b = first_clip_path_id(html_b)

      { id_a != "" } |> expect.to_be_true
      { id_b != "" } |> expect.to_be_true
      { id_a != id_b } |> expect.to_be_true
    }),
    it("fallback clip-path id changes for non-ascii category differences", fn() {
      let html_a =
        chart.line_chart(
          data: sample_data_unicode_a(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let html_b =
        chart.line_chart(
          data: sample_data_unicode_b(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )
        |> element.to_string

      let id_a = first_clip_path_id(html_a)
      let id_b = first_clip_path_id(html_b)

      { id_a != "" } |> expect.to_be_true
      { id_b != "" } |> expect.to_be_true
      { id_a != id_b } |> expect.to_be_true
    }),
    it(
      "fallback clip-path id is stable for equivalent dict key orderings",
      fn() {
        let html_a =
          chart.line_chart(
            data: sample_data_order_a(),
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.line(line.line_config(
                data_key: "x",
                meta: common.series_meta(),
              )),
            ],
          )
          |> element.to_string

        let html_b =
          chart.line_chart(
            data: sample_data_order_b(),
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.line(line.line_config(
                data_key: "x",
                meta: common.series_meta(),
              )),
            ],
          )
          |> element.to_string

        let id_a = first_clip_path_id(html_a)
        let id_b = first_clip_path_id(html_b)

        { id_a != "" } |> expect.to_be_true
        { id_a == id_b } |> expect.to_be_true
      },
    ),
    it("fallback clip-path id is deterministic across repeated renders", fn() {
      let chart_html =
        chart.line_chart(
          data: sample_data_unicode_a(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "v",
              meta: common.series_meta(),
            )),
          ],
        )

      let id_a = chart_html |> element.to_string |> first_clip_path_id
      let id_b = chart_html |> element.to_string |> first_clip_path_id

      { id_a != "" } |> expect.to_be_true
      { id_a == id_b } |> expect.to_be_true
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
