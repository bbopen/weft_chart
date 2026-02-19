//// Tests for layout series animation (treemap, funnel, sankey).

import gleam/dict
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/animation
import weft_chart/easing
import weft_chart/series/funnel
import weft_chart/series/sankey
import weft_chart/series/treemap

pub fn main() {
  startest.run(startest.default_config())
}

pub fn layout_animation_tests() {
  describe("layout animation", [
    treemap_config_tests(),
    funnel_config_tests(),
    sankey_config_tests(),
    treemap_render_tests(),
    funnel_render_tests(),
    sankey_render_tests(),
  ])
}

fn treemap_config_tests() {
  describe("treemap animation config", [
    it("treemap_config has animation with line_default timing", fn() {
      let config = treemap.treemap_config(data_key: "value")
      config.animation.active |> expect.to_be_false
      config.animation.duration |> expect.to_equal(expected: 1500)
      config.animation.delay |> expect.to_equal(expected: 0)
      config.animation.easing |> expect.to_equal(expected: easing.Ease)
    }),
    it("treemap_animation builder sets custom animation", fn() {
      let custom =
        animation.line_default()
        |> animation.with_duration(duration: 800)
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_animation(animation: custom)
      config.animation.duration |> expect.to_equal(expected: 800)
      config.animation.active |> expect.to_be_true
    }),
  ])
}

fn funnel_config_tests() {
  describe("funnel animation config", [
    it("funnel_config has animation with pie_default timing", fn() {
      let config = funnel.funnel_config(data_key: "value")
      config.animation.active |> expect.to_be_false
      config.animation.duration |> expect.to_equal(expected: 1500)
      config.animation.delay |> expect.to_equal(expected: 400)
      config.animation.easing |> expect.to_equal(expected: easing.Ease)
    }),
    it("funnel_animation builder sets custom animation", fn() {
      let custom =
        animation.pie_default()
        |> animation.with_duration(duration: 500)
      let config =
        funnel.funnel_config(data_key: "value")
        |> funnel.funnel_animation(animation: custom)
      config.animation.duration |> expect.to_equal(expected: 500)
    }),
  ])
}

fn sankey_config_tests() {
  describe("sankey animation config", [
    it("sankey_config has animation with line_default timing", fn() {
      let sankey_data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 100.0)],
        )
      let config = sankey.sankey_config(data: sankey_data)
      config.animation.active |> expect.to_be_false
      config.animation.duration |> expect.to_equal(expected: 1500)
      config.animation.delay |> expect.to_equal(expected: 0)
      config.animation.easing |> expect.to_equal(expected: easing.Ease)
    }),
    it("sankey_animation builder sets custom animation", fn() {
      let sankey_data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 100.0)],
        )
      let custom =
        animation.line_default()
        |> animation.with_active(active: False)
      let config =
        sankey.sankey_config(data: sankey_data)
        |> sankey.sankey_animation(animation: custom)
      config.animation.active |> expect.to_be_false
    }),
  ])
}

fn treemap_render_tests() {
  describe("treemap render animation", [
    it("render with animation active contains animate elements", fn() {
      let node =
        treemap.TreemapNode(
          name: "root",
          value: 100.0,
          children: [
            treemap.TreemapNode(
              name: "a",
              value: 60.0,
              children: [],
              fill: "#ff0000",
            ),
            treemap.TreemapNode(
              name: "b",
              value: 40.0,
              children: [],
              fill: "#00ff00",
            ),
          ],
          fill: "#0000ff",
        )
      let active_anim =
        animation.line_default()
        |> animation.with_active(active: True)
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [node])
        |> treemap.treemap_animation(animation: active_anim)
      let el = treemap.render_treemap(config: config, width: 400, height: 300)
      let html = element.to_string(el)
      html |> string.contains("animate") |> expect.to_be_true
    }),
    it("render with animation inactive does not contain animate", fn() {
      let node =
        treemap.TreemapNode(
          name: "root",
          value: 100.0,
          children: [
            treemap.TreemapNode(
              name: "a",
              value: 60.0,
              children: [],
              fill: "#ff0000",
            ),
          ],
          fill: "#0000ff",
        )
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: [node])
      let el = treemap.render_treemap(config: config, width: 400, height: 300)
      let html = element.to_string(el)
      html |> string.contains("animate") |> expect.to_be_false
    }),
  ])
}

fn funnel_render_tests() {
  describe("funnel render animation", [
    it("render with animation active contains animate elements", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 60.0)]),
      ]
      let active_anim =
        animation.pie_default()
        |> animation.with_active(active: True)
      let config =
        funnel.funnel_config(data_key: "value")
        |> funnel.funnel_animation(animation: active_anim)
      let el =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 200.0,
          height: 300.0,
        )
      let html = element.to_string(el)
      html |> string.contains("animate") |> expect.to_be_true
    }),
    it("render with animation inactive does not contain animate", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 60.0)]),
      ]
      let config = funnel.funnel_config(data_key: "value")
      let el =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 200.0,
          height: 300.0,
        )
      let html = element.to_string(el)
      html |> string.contains("animate") |> expect.to_be_false
    }),
  ])
}

fn sankey_render_tests() {
  describe("sankey render animation", [
    it("render with animation active contains animate elements", fn() {
      let sankey_data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 100.0)],
        )
      let active_anim =
        animation.line_default()
        |> animation.with_active(active: True)
      let config =
        sankey.sankey_config(data: sankey_data)
        |> sankey.sankey_animation(animation: active_anim)
      let el = sankey.render_sankey(config: config, width: 400, height: 300)
      let html = element.to_string(el)
      html |> string.contains("animate") |> expect.to_be_true
    }),
    it("render with animation inactive does not contain animate", fn() {
      let sankey_data =
        sankey.SankeyData(
          nodes: [sankey.SankeyNode(name: "A"), sankey.SankeyNode(name: "B")],
          links: [sankey.SankeyLink(source: 0, target: 1, value: 100.0)],
        )
      let config = sankey.sankey_config(data: sankey_data)
      let el = sankey.render_sankey(config: config, width: 400, height: 300)
      let html = element.to_string(el)
      html |> string.contains("animate") |> expect.to_be_false
    }),
  ])
}
