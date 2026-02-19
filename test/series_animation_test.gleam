//// Tests for animation support in cartesian series.

import gleam/dict
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/animation
import weft_chart/curve
import weft_chart/easing
import weft_chart/internal/layout
import weft_chart/scale
import weft_chart/series/area
import weft_chart/series/bar
import weft_chart/series/line
import weft_chart/series/scatter

pub fn main() {
  startest.run(startest.default_config())
}

pub fn series_animation_tests() {
  describe("series animation", [
    bar_config_tests(),
    line_config_tests(),
    area_config_tests(),
    scatter_config_tests(),
    curve_path_length_tests(),
    bar_render_tests(),
    line_render_tests(),
    area_render_tests(),
    scatter_render_tests(),
  ])
}

fn bar_config_tests() {
  describe("bar animation config", [
    it("bar_config has animation with bar_default values", fn() {
      let config = bar.bar_config(data_key: "value")
      config.animation.active |> expect.to_be_true
      config.animation.duration |> expect.to_equal(expected: 400)
      config.animation.easing |> expect.to_equal(expected: easing.Ease)
    }),
    it("bar_animation sets custom animation config", fn() {
      let custom =
        animation.bar_default()
        |> animation.with_duration(duration: 800)
        |> animation.with_active(active: False)
      let config =
        bar.bar_config(data_key: "value")
        |> bar.bar_animation(anim: custom)
      config.animation.active |> expect.to_be_false
      config.animation.duration |> expect.to_equal(expected: 800)
    }),
  ])
}

fn line_config_tests() {
  describe("line animation config", [
    it("line_config has animation with line_default values", fn() {
      let config = line.line_config(data_key: "value")
      config.animation.active |> expect.to_be_true
      config.animation.duration |> expect.to_equal(expected: 1500)
    }),
    it("line_animation sets custom animation config", fn() {
      let custom =
        animation.line_default()
        |> animation.with_duration(duration: 2000)
      let config =
        line.line_config(data_key: "value")
        |> line.line_animation(anim: custom)
      config.animation.duration |> expect.to_equal(expected: 2000)
    }),
  ])
}

fn area_config_tests() {
  describe("area animation config", [
    it("area_config has animation with line_default values", fn() {
      let config = area.area_config(data_key: "value")
      config.animation.active |> expect.to_be_true
      config.animation.duration |> expect.to_equal(expected: 1500)
    }),
    it("area_animation sets custom animation config", fn() {
      let custom =
        animation.line_default()
        |> animation.with_active(active: False)
      let config =
        area.area_config(data_key: "value")
        |> area.area_animation(anim: custom)
      config.animation.active |> expect.to_be_false
    }),
  ])
}

fn scatter_config_tests() {
  describe("scatter animation config", [
    it("scatter_config has animation with scatter_default values", fn() {
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      config.animation.active |> expect.to_be_true
      config.animation.duration |> expect.to_equal(expected: 400)
      config.animation.easing |> expect.to_equal(expected: easing.Linear)
    }),
    it("scatter_animation sets custom animation config", fn() {
      let custom =
        animation.scatter_default()
        |> animation.with_delay(delay: 100)
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_animation(anim: custom)
      config.animation.delay |> expect.to_equal(expected: 100)
    }),
  ])
}

fn curve_path_length_tests() {
  describe("approximate_path_length", [
    it("returns 0.0 for empty list", fn() {
      curve.approximate_path_length(points: [])
      |> expect.to_equal(expected: 0.0)
    }),
    it("returns 0.0 for single point", fn() {
      curve.approximate_path_length(points: [#(3.0, 4.0)])
      |> expect.to_equal(expected: 0.0)
    }),
    it("returns chord sum times 1.2 for straight line", fn() {
      // Distance from (0,0) to (3,4) = 5.0, times 1.2 = 6.0
      let result =
        curve.approximate_path_length(points: [#(0.0, 0.0), #(3.0, 4.0)])
      result |> expect.to_equal(expected: 6.0)
    }),
    it("sums distances for multiple points", fn() {
      // (0,0) to (3,0) = 3.0, (3,0) to (3,4) = 4.0
      // total = 7.0 * 1.2 = 8.4
      let result =
        curve.approximate_path_length(points: [
          #(0.0, 0.0),
          #(3.0, 0.0),
          #(3.0, 4.0),
        ])
      result |> expect.to_equal(expected: 8.4)
    }),
  ])
}

fn bar_render_tests() {
  describe("bar render with animation", [
    it("active animation produces animate elements", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 200.0)]),
      ]
      let categories = ["A", "B"]
      let x_scale =
        scale.band(
          categories: categories,
          range_start: 0.0,
          range_end: 400.0,
          padding_inner: 0.1,
          padding_outer: 0.1,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 300.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config = bar.bar_config(data_key: "value")
      let html =
        bar.render_bars(
          config: config,
          data: data,
          categories: categories,
          x_scale: x_scale,
          y_scale: y_scale,
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_true
    }),
    it("inactive animation does not produce animate elements", fn() {
      let data = [dict.from_list([#("value", 100.0)])]
      let categories = ["A"]
      let x_scale =
        scale.band(
          categories: categories,
          range_start: 0.0,
          range_end: 400.0,
          padding_inner: 0.1,
          padding_outer: 0.1,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 300.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let inactive_anim =
        animation.bar_default()
        |> animation.with_active(active: False)
      let config =
        bar.bar_config(data_key: "value")
        |> bar.bar_animation(anim: inactive_anim)
      let html =
        bar.render_bars(
          config: config,
          data: data,
          categories: categories,
          x_scale: x_scale,
          y_scale: y_scale,
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_false
    }),
  ])
}

fn line_render_tests() {
  describe("line render with animation", [
    it("active animation produces stroke-dashoffset", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 200.0)]),
      ]
      let categories = ["A", "B"]
      let x_scale =
        scale.point(
          categories: categories,
          range_start: 0.0,
          range_end: 400.0,
          padding: 0.1,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 300.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config = line.line_config(data_key: "value")
      let html =
        line.render_line(
          config: config,
          data: data,
          categories: categories,
          x_scale: x_scale,
          y_scale: y_scale,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("stroke-dashoffset") |> expect.to_be_true
      html |> string.contains("stroke-dasharray") |> expect.to_be_true
    }),
    it("inactive animation does not produce stroke-dashoffset", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 200.0)]),
      ]
      let categories = ["A", "B"]
      let x_scale =
        scale.point(
          categories: categories,
          range_start: 0.0,
          range_end: 400.0,
          padding: 0.1,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 300.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let inactive_anim =
        animation.line_default()
        |> animation.with_active(active: False)
      let config =
        line.line_config(data_key: "value")
        |> line.line_animation(anim: inactive_anim)
      let html =
        line.render_line(
          config: config,
          data: data,
          categories: categories,
          x_scale: x_scale,
          y_scale: y_scale,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("stroke-dashoffset") |> expect.to_be_false
    }),
  ])
}

fn area_render_tests() {
  describe("area render with animation", [
    it("active animation produces clipPath", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 200.0)]),
      ]
      let categories = ["A", "B"]
      let x_scale =
        scale.point(
          categories: categories,
          range_start: 0.0,
          range_end: 400.0,
          padding: 0.1,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 300.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config = area.area_config(data_key: "value")
      let html =
        area.render_area(
          config: config,
          data: data,
          categories: categories,
          x_scale: x_scale,
          y_scale: y_scale,
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("clipPath") |> expect.to_be_true
      html |> string.contains("area-clip-value") |> expect.to_be_true
    }),
    it("inactive animation does not produce clipPath", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 200.0)]),
      ]
      let categories = ["A", "B"]
      let x_scale =
        scale.point(
          categories: categories,
          range_start: 0.0,
          range_end: 400.0,
          padding: 0.1,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 300.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let inactive_anim =
        animation.line_default()
        |> animation.with_active(active: False)
      let config =
        area.area_config(data_key: "value")
        |> area.area_animation(anim: inactive_anim)
      let html =
        area.render_area(
          config: config,
          data: data,
          categories: categories,
          x_scale: x_scale,
          y_scale: y_scale,
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("clipPath") |> expect.to_be_false
    }),
  ])
}

fn scatter_render_tests() {
  describe("scatter render with animation", [
    it("active animation produces animate element", fn() {
      let data = [
        dict.from_list([#("x", 10.0), #("y", 20.0)]),
        dict.from_list([#("x", 30.0), #("y", 40.0)]),
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
      html |> string.contains("animate") |> expect.to_be_true
      html |> string.contains("opacity") |> expect.to_be_true
    }),
    it("inactive animation does not produce animate element", fn() {
      let data = [
        dict.from_list([#("x", 10.0), #("y", 20.0)]),
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
      let inactive_anim =
        animation.scatter_default()
        |> animation.with_active(active: False)
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_animation(anim: inactive_anim)
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_false
    }),
  ])
}
