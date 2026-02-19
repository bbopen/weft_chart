//// Tests for treemap display type feature.

import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/series/treemap

pub fn main() {
  startest.run(startest.default_config())
}

pub fn treemap_display_type_tests() {
  describe("treemap_display_type", [
    it("defaults to FlatTreemap", fn() {
      let config = treemap.treemap_config(data_key: "value")
      config.display_type
      |> expect.to_equal(expected: treemap.FlatTreemap)
    }),
    it("builder sets NestedTreemap", fn() {
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_display_type(display_type: treemap.NestedTreemap)
      config.display_type
      |> expect.to_equal(expected: treemap.NestedTreemap)
    }),
    it("flat mode renders all leaf nodes", fn() {
      let data = [
        treemap.TreemapNode(name: "A", value: 0.0, fill: "", children: [
          treemap.TreemapNode(name: "A1", value: 50.0, fill: "", children: []),
          treemap.TreemapNode(name: "A2", value: 30.0, fill: "", children: []),
        ]),
        treemap.TreemapNode(name: "B", value: 0.0, fill: "", children: [
          treemap.TreemapNode(name: "B1", value: 20.0, fill: "", children: []),
        ]),
      ]
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: data)
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      // Flat mode: should contain treemap rects for leaf nodes
      html |> string.contains("recharts-treemap") |> expect.to_be_true
      html |> string.contains("recharts-treemap-rect") |> expect.to_be_true
    }),
    it("nested mode renders only depth-0 cells initially", fn() {
      // In NestedTreemap, only top-level (depth-0) cells are visible.
      // Children are not rendered until the application drills into a node
      // by swapping data — matching recharts type="nest" initial behavior.
      let data = [
        treemap.TreemapNode(name: "A", value: 0.0, fill: "", children: [
          treemap.TreemapNode(name: "A1", value: 0.0, fill: "", children: [
            treemap.TreemapNode(
              name: "A1a",
              value: 30.0,
              fill: "",
              children: [],
            ),
          ]),
          treemap.TreemapNode(name: "A2", value: 20.0, fill: "", children: []),
        ]),
      ]
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: data)
        |> treemap.treemap_display_type(display_type: treemap.NestedTreemap)
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      // Nested mode should render depth-0 cells
      html |> string.contains("recharts-treemap") |> expect.to_be_true
      html |> string.contains("recharts-treemap-depth-0") |> expect.to_be_true
      // depth-1 children are NOT rendered — app swaps data on drill-down
      html |> string.contains("recharts-treemap-depth-1") |> expect.to_be_false
    }),
    it("nested mode renders leaf-only top-level nodes", fn() {
      let data = [
        treemap.TreemapNode(name: "Leaf", value: 100.0, fill: "", children: []),
      ]
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: data)
        |> treemap.treemap_display_type(display_type: treemap.NestedTreemap)
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-treemap-rect") |> expect.to_be_true
    }),
    it("nested mode returns empty for zero-value data", fn() {
      let data = [
        treemap.TreemapNode(name: "Empty", value: 0.0, fill: "", children: []),
      ]
      let config =
        treemap.treemap_config(data_key: "value")
        |> treemap.treemap_data(data: data)
        |> treemap.treemap_display_type(display_type: treemap.NestedTreemap)
      let html =
        treemap.render_treemap(config: config, width: 400, height: 300)
        |> element.to_string
      html |> string.contains("recharts-treemap-rect") |> expect.to_be_false
    }),
  ])
}
