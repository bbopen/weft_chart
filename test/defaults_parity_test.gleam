//// Tests for default value parity with recharts.

import startest.{describe, it}
import startest/expect
import weft_chart/axis
import weft_chart/series/area
import weft_chart/series/common
import weft_chart/series/pie

pub fn main() {
  startest.run(startest.default_config())
}

pub fn area_fill_opacity_tests() {
  describe("area_config fill_opacity", [
    it("defaults to 0.6 matching recharts", fn() {
      let config = area.area_config(data_key: "x", meta: common.series_meta())
      config.fill_opacity |> expect.to_equal(expected: 0.6)
    }),
  ])
}

pub fn area_base_value_tests() {
  describe("area_config base_value", [
    it("defaults to Auto", fn() {
      let config = area.area_config(data_key: "x", meta: common.series_meta())
      config.base_value |> expect.to_equal(expected: area.Auto)
    }),
  ])
}

pub fn pie_outer_radius_tests() {
  describe("pie_config outer_radius", [
    it("defaults to 0.8 (80%) matching recharts", fn() {
      let config = pie.pie_config(data_key: "x")
      config.outer_radius |> expect.to_equal(expected: 0.8)
    }),
    it("percentage mode resolves to pixels for 200x200 chart", fn() {
      // With width=200, height=200: max_r = 100, effective = 0.8 * 100 = 80
      let config = pie.pie_config(data_key: "value")
      let max_r = 100.0
      let effective = config.outer_radius *. max_r
      effective |> expect.to_equal(expected: 80.0)
    }),
    it("fixed pixel mode used when outer_radius > 1.0", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_outer_radius(60.0)
      // Value > 1.0 means fixed pixel mode
      { config.outer_radius >. 1.0 } |> expect.to_be_true
      config.outer_radius |> expect.to_equal(expected: 60.0)
    }),
  ])
}

pub fn x_axis_tick_margin_tests() {
  describe("x_axis_config tick_margin", [
    it("defaults to 2 matching recharts CartesianAxis.defaultProps", fn() {
      let config = axis.x_axis_config()
      config.tick_margin |> expect.to_equal(expected: 2)
    }),
  ])
}
