//// Tests for polar series animation support.

import gleam/dict
import gleam/list
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/animation
import weft_chart/easing
import weft_chart/series/pie
import weft_chart/series/radar
import weft_chart/series/radial_bar
import weft_chart/series/sunburst

pub fn main() {
  startest.run(startest.default_config())
}

pub fn polar_animation_tests() {
  describe("polar_animation", [
    pie_config_tests(),
    radar_config_tests(),
    radial_bar_config_tests(),
    sunburst_config_tests(),
    pie_render_tests(),
    radar_render_tests(),
    radial_bar_render_tests(),
    sunburst_render_tests(),
  ])
}

fn pie_config_tests() {
  describe("pie animation config", [
    it("pie_config has animation field with pie_default values", fn() {
      let config = pie.pie_config(data_key: "value")
      config.animation.active |> expect.to_be_true
      config.animation.duration |> expect.to_equal(expected: 1500)
      config.animation.delay |> expect.to_equal(expected: 400)
      config.animation.easing |> expect.to_equal(expected: easing.Ease)
    }),
    it("pie_animation builder sets custom animation", fn() {
      let custom =
        animation.pie_default()
        |> animation.with_duration(duration: 800)
        |> animation.with_delay(delay: 100)
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_animation(anim: custom)
      config.animation.duration |> expect.to_equal(expected: 800)
      config.animation.delay |> expect.to_equal(expected: 100)
    }),
    it("pie_animation can disable animation", fn() {
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_animation(anim: animation.with_active(
          config: animation.pie_default(),
          active: False,
        ))
      config.animation.active |> expect.to_be_false
    }),
  ])
}

fn radar_config_tests() {
  describe("radar animation config", [
    it("radar_config has animation with line_default values", fn() {
      let config = radar.radar_config(data_key: "score")
      config.animation.active |> expect.to_be_true
      config.animation.duration |> expect.to_equal(expected: 1500)
      config.animation.delay |> expect.to_equal(expected: 0)
      config.animation.easing |> expect.to_equal(expected: easing.Ease)
    }),
    it("radar_animation builder sets custom animation", fn() {
      let custom =
        animation.line_default()
        |> animation.with_duration(duration: 500)
      let config =
        radar.radar_config(data_key: "score")
        |> radar.radar_animation(anim: custom)
      config.animation.duration |> expect.to_equal(expected: 500)
    }),
  ])
}

fn radial_bar_config_tests() {
  describe("radial_bar animation config", [
    it("radial_bar_config has animation with line_default values", fn() {
      let config = radial_bar.radial_bar_config(data_key: "value")
      config.animation.active |> expect.to_be_true
      config.animation.duration |> expect.to_equal(expected: 1500)
      config.animation.delay |> expect.to_equal(expected: 0)
    }),
    it("radial_bar_animation builder sets custom animation", fn() {
      let custom =
        animation.line_default()
        |> animation.with_duration(duration: 600)
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_animation(anim: custom)
      config.animation.duration |> expect.to_equal(expected: 600)
    }),
  ])
}

fn sunburst_config_tests() {
  describe("sunburst animation config", [
    it("sunburst_config has animation with pie_default values", fn() {
      let config = sunburst.sunburst_config()
      config.animation.active |> expect.to_be_true
      config.animation.duration |> expect.to_equal(expected: 1500)
      config.animation.delay |> expect.to_equal(expected: 400)
    }),
    it("sunburst_animation builder sets custom animation", fn() {
      let custom =
        animation.pie_default()
        |> animation.with_duration(duration: 900)
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_animation(anim: custom)
      config.animation.duration |> expect.to_equal(expected: 900)
    }),
  ])
}

fn pie_render_tests() {
  describe("pie animation rendering", [
    it("render pie with animation active produces animate element", fn() {
      let pie_data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 200.0)]),
      ]
      let config = pie.pie_config(data_key: "value")
      let html =
        pie.render_pie(
          config: config,
          data: pie_data,
          categories: ["A", "B"],
          width: 400.0,
          height: 400.0,
        )
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_true
    }),
    it("render pie with animation inactive omits animate element", fn() {
      let pie_data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 200.0)]),
      ]
      let config =
        pie.pie_config(data_key: "value")
        |> pie.pie_animation(anim: animation.with_active(
          config: animation.pie_default(),
          active: False,
        ))
      let html =
        pie.render_pie(
          config: config,
          data: pie_data,
          categories: ["A", "B"],
          width: 400.0,
          height: 400.0,
        )
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_false
    }),
    it("pie sector baked path has multiple keyframes in values attribute", fn() {
      let pie_data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 200.0)]),
      ]
      let config = pie.pie_config(data_key: "value")
      let html =
        pie.render_pie(
          config: config,
          data: pie_data,
          categories: ["A", "B"],
          width: 400.0,
          height: 400.0,
        )
        |> element.to_string
      // Baked with 30 steps means 31 keyframes separated by semicolons
      // The values attribute should have many semicolons
      let semicolons = string.split(html, ";") |> list.length
      // At least 30 semicolons (from keyTimes + values, 2 attributes)
      { semicolons > 30 } |> expect.to_be_true
    }),
  ])
}

fn radar_render_tests() {
  describe("radar animation rendering", [
    it("render radar with animation active produces animate element", fn() {
      let data = [
        dict.from_list([#("score", 80.0)]),
        dict.from_list([#("score", 60.0)]),
        dict.from_list([#("score", 90.0)]),
      ]
      let config = radar.radar_config(data_key: "score")
      let html =
        radar.render_radar(
          config: config,
          data: data,
          categories: ["Math", "Science", "English"],
          cx: 200.0,
          cy: 200.0,
          max_radius: 150.0,
          domain_max: 100.0,
        )
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_true
    }),
    it("render radar with animation inactive omits animate element", fn() {
      let data = [
        dict.from_list([#("score", 80.0)]),
        dict.from_list([#("score", 60.0)]),
        dict.from_list([#("score", 90.0)]),
      ]
      let config =
        radar.radar_config(data_key: "score")
        |> radar.radar_animation(anim: animation.with_active(
          config: animation.line_default(),
          active: False,
        ))
      let html =
        radar.render_radar(
          config: config,
          data: data,
          categories: ["Math", "Science", "English"],
          cx: 200.0,
          cy: 200.0,
          max_radius: 150.0,
          domain_max: 100.0,
        )
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_false
    }),
  ])
}

fn radial_bar_render_tests() {
  describe("radial_bar animation rendering", [
    it("render radial_bar with animation active produces animate element", fn() {
      let data = [
        dict.from_list([#("value", 80.0)]),
        dict.from_list([#("value", 60.0)]),
      ]
      let config = radial_bar.radial_bar_config(data_key: "value")
      let html =
        radial_bar.render_radial_bars(
          config: config,
          data: data,
          categories: ["A", "B"],
          cx: 200.0,
          cy: 200.0,
          domain_max: 100.0,
        )
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_true
    }),
  ])
}

fn sunburst_render_tests() {
  describe("sunburst animation rendering", [
    it("render sunburst with animation active produces animate element", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 60.0, fill: "#ff0000"),
          sunburst.sunburst_leaf(name: "B", value: 40.0, fill: "#00ff00"),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_data(data: root)
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_true
    }),
    it("render sunburst with animation inactive omits animate element", fn() {
      let root =
        sunburst.sunburst_node(name: "root", value: 100.0, fill: "", children: [
          sunburst.sunburst_leaf(name: "A", value: 60.0, fill: "#ff0000"),
          sunburst.sunburst_leaf(name: "B", value: 40.0, fill: "#00ff00"),
        ])
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_data(data: root)
        |> sunburst.sunburst_animation(anim: animation.with_active(
          config: animation.pie_default(),
          active: False,
        ))
      let html =
        sunburst.render_sunburst(config: config, width: 400, height: 400)
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_false
    }),
  ])
}
