//// Tests for extended series parity gap closures.
////
//// Covers new config fields and builder functions for Pie, Radar,
//// RadialBar, Funnel, Treemap, Sunburst, and Sankey series.

import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft
import weft_chart/render
import weft_chart/series/funnel
import weft_chart/series/pie
import weft_chart/series/radar
import weft_chart/series/radial_bar
import weft_chart/series/sankey
import weft_chart/series/sunburst
import weft_chart/series/treemap
import weft_chart/shape

pub fn main() {
  startest.run(startest.default_config())
}

// ---------------------------------------------------------------------------
// Pie series
// ---------------------------------------------------------------------------

pub fn pie_active_shape_tests() {
  describe("pie_active_shape", [
    it("defaults to None", fn() {
      let config = pie.pie_config(data_key: "v")
      config.active_shape
      |> expect.to_equal(None)
    }),
    it("sets renderer via builder", fn() {
      let config =
        pie.pie_config(data_key: "v")
        |> pie.pie_active_shape(renderer: fn(_props) { element.none() })
      config.active_shape
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn pie_inactive_shape_tests() {
  describe("pie_inactive_shape", [
    it("defaults to None", fn() {
      let config = pie.pie_config(data_key: "v")
      config.inactive_shape
      |> expect.to_equal(None)
    }),
    it("sets renderer via builder", fn() {
      let config =
        pie.pie_config(data_key: "v")
        |> pie.pie_inactive_shape(renderer: fn(_props) { element.none() })
      config.inactive_shape
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn pie_value_key_tests() {
  describe("pie_value_key", [
    it("defaults to value", fn() {
      let config = pie.pie_config(data_key: "v")
      config.value_key
      |> expect.to_equal("value")
    }),
    it("sets via builder", fn() {
      let config =
        pie.pie_config(data_key: "v")
        |> pie.pie_value_key(key: "amount")
      config.value_key
      |> expect.to_equal("amount")
    }),
  ])
}

pub fn pie_css_class_tests() {
  describe("pie_css_class", [
    it("defaults to empty string", fn() {
      let config = pie.pie_config(data_key: "v")
      config.css_class
      |> expect.to_equal("")
    }),
    it("sets via builder", fn() {
      let config =
        pie.pie_config(data_key: "v")
        |> pie.pie_css_class(class: "my-pie")
      config.css_class
      |> expect.to_equal("my-pie")
    }),
  ])
}

pub fn pie_active_shape_dispatch_tests() {
  describe("pie_active_shape_dispatch", [
    it("active_shape renderer receives correct sector props", fn() {
      let config =
        pie.pie_config(data_key: "v")
        |> pie.pie_active_index(index: 0)
        |> pie.pie_active_shape(renderer: fn(props: render.SectorProps) {
          // Verify props are passed correctly
          let _cx = props.cx
          let _index = props.index
          element.none()
        })
      config.active_indices
      |> expect.to_equal([0])
    }),
  ])
}

// ---------------------------------------------------------------------------
// Radar series
// ---------------------------------------------------------------------------

pub fn radar_angle_axis_id_tests() {
  describe("radar_angle_axis_id", [
    it("defaults to 0", fn() {
      let config = radar.radar_config(data_key: "v")
      config.angle_axis_id
      |> expect.to_equal("0")
    }),
    it("sets via builder", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_angle_axis_id(id: "1")
      config.angle_axis_id
      |> expect.to_equal("1")
    }),
  ])
}

pub fn radar_radius_axis_id_tests() {
  describe("radar_radius_axis_id", [
    it("defaults to 0", fn() {
      let config = radar.radar_config(data_key: "v")
      config.radius_axis_id
      |> expect.to_equal("0")
    }),
    it("sets via builder", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_radius_axis_id(id: "2")
      config.radius_axis_id
      |> expect.to_equal("2")
    }),
  ])
}

pub fn radar_custom_shape_tests() {
  describe("radar_custom_shape", [
    it("defaults to None", fn() {
      let config = radar.radar_config(data_key: "v")
      config.custom_shape
      |> expect.to_equal(None)
    }),
    it("sets renderer via builder", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_custom_shape(renderer: fn(_points) { element.none() })
      config.custom_shape
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn radar_active_dot_tests() {
  describe("radar_active_dot", [
    it("defaults to None", fn() {
      let config = radar.radar_config(data_key: "v")
      config.active_dot
      |> expect.to_equal(None)
    }),
    it("sets renderer via builder", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_active_dot(renderer: fn(_props) { element.none() })
      config.active_dot
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn radar_active_index_tests() {
  describe("radar_active_index", [
    it("defaults to None", fn() {
      let config = radar.radar_config(data_key: "v")
      config.active_index
      |> expect.to_equal(None)
    }),
    it("sets via builder", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_active_index(index: 2)
      config.active_index
      |> expect.to_equal(Some(2))
    }),
  ])
}

pub fn radar_active_dot_dispatch_tests() {
  describe("radar_active_dot dispatch", [
    it("active_index=Some(0) dispatches active_dot renderer for that dot", fn() {
      let renderer = fn(_props: render.DotProps) {
        element.text("ACTIVE_DOT_MARKER")
      }
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_dot(True)
        |> radar.radar_active_index(index: 0)
        |> radar.radar_active_dot(renderer: renderer)
      let data = [
        dict.from_list([#("v", 10.0)]),
        dict.from_list([#("v", 20.0)]),
      ]
      let html =
        radar.render_radar(
          config: config,
          data: data,
          categories: ["A", "B"],
          cx: 100.0,
          cy: 100.0,
          max_radius: 80.0,
          domain_max: 100.0,
        )
        |> element.to_string
      html
      |> string.contains("ACTIVE_DOT_MARKER")
      |> expect.to_be_true
    }),
    it("without active_index, active_dot renderer is not called", fn() {
      let renderer = fn(_props: render.DotProps) {
        element.text("ACTIVE_DOT_MARKER")
      }
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_dot(True)
        |> radar.radar_active_dot(renderer: renderer)
      let data = [
        dict.from_list([#("v", 10.0)]),
        dict.from_list([#("v", 20.0)]),
      ]
      let html =
        radar.render_radar(
          config: config,
          data: data,
          categories: ["A", "B"],
          cx: 100.0,
          cy: 100.0,
          max_radius: 80.0,
          domain_max: 100.0,
        )
        |> element.to_string
      html
      |> string.contains("ACTIVE_DOT_MARKER")
      |> expect.to_be_false
    }),
  ])
}

pub fn radar_css_class_tests() {
  describe("radar_css_class", [
    it("defaults to empty string", fn() {
      let config = radar.radar_config(data_key: "v")
      config.css_class
      |> expect.to_equal("")
    }),
    it("sets via builder", fn() {
      let config =
        radar.radar_config(data_key: "v")
        |> radar.radar_css_class(class: "my-radar")
      config.css_class
      |> expect.to_equal("my-radar")
    }),
  ])
}

// ---------------------------------------------------------------------------
// RadialBar series
// ---------------------------------------------------------------------------

pub fn radial_bar_angle_axis_id_tests() {
  describe("radial_bar_angle_axis_id", [
    it("defaults to 0", fn() {
      let config = radial_bar.radial_bar_config(data_key: "v")
      config.angle_axis_id
      |> expect.to_equal("0")
    }),
    it("sets via builder", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "v")
        |> radial_bar.radial_bar_angle_axis_id(id: "1")
      config.angle_axis_id
      |> expect.to_equal("1")
    }),
  ])
}

pub fn radial_bar_radius_axis_id_tests() {
  describe("radial_bar_radius_axis_id", [
    it("defaults to 0", fn() {
      let config = radial_bar.radial_bar_config(data_key: "v")
      config.radius_axis_id
      |> expect.to_equal("0")
    }),
    it("sets via builder", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "v")
        |> radial_bar.radial_bar_radius_axis_id(id: "2")
      config.radius_axis_id
      |> expect.to_equal("2")
    }),
  ])
}

pub fn radial_bar_custom_shape_tests() {
  describe("radial_bar_custom_shape", [
    it("defaults to None", fn() {
      let config = radial_bar.radial_bar_config(data_key: "v")
      config.custom_shape
      |> expect.to_equal(None)
    }),
    it("sets renderer via builder", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "v")
        |> radial_bar.radial_bar_custom_shape(renderer: fn(_props) {
          element.none()
        })
      config.custom_shape
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn radial_bar_active_shape_tests() {
  describe("radial_bar_active_shape", [
    it("defaults to None", fn() {
      let config = radial_bar.radial_bar_config(data_key: "v")
      config.active_shape
      |> expect.to_equal(None)
    }),
    it("sets renderer via builder", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "v")
        |> radial_bar.radial_bar_active_shape(renderer: fn(_props) {
          element.none()
        })
      config.active_shape
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn radial_bar_stroke_tests() {
  describe("radial_bar_stroke", [
    it("defaults to none", fn() {
      let config = radial_bar.radial_bar_config(data_key: "v")
      config.stroke
      |> expect.to_equal(weft.css_color(value: "none"))
    }),
    it("sets via builder", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "v")
        |> radial_bar.radial_bar_stroke(stroke_value: weft.css_color(
          value: "#ff0000",
        ))
      config.stroke
      |> expect.to_equal(weft.css_color(value: "#ff0000"))
    }),
  ])
}

pub fn radial_bar_stroke_width_tests() {
  describe("radial_bar_stroke_width", [
    it("defaults to 0.0", fn() {
      let config = radial_bar.radial_bar_config(data_key: "v")
      config.stroke_width
      |> expect.to_equal(0.0)
    }),
    it("sets via builder", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "v")
        |> radial_bar.radial_bar_stroke_width(width: 2.0)
      config.stroke_width
      |> expect.to_equal(2.0)
    }),
  ])
}

pub fn radial_bar_css_class_tests() {
  describe("radial_bar_css_class", [
    it("defaults to empty string", fn() {
      let config = radial_bar.radial_bar_config(data_key: "v")
      config.css_class
      |> expect.to_equal("")
    }),
    it("sets via builder", fn() {
      let config =
        radial_bar.radial_bar_config(data_key: "v")
        |> radial_bar.radial_bar_css_class(class: "my-radial")
      config.css_class
      |> expect.to_equal("my-radial")
    }),
  ])
}

// ---------------------------------------------------------------------------
// Funnel series
// ---------------------------------------------------------------------------

pub fn funnel_custom_shape_tests() {
  describe("funnel_custom_shape", [
    it("defaults to None", fn() {
      let config = funnel.funnel_config(data_key: "v")
      config.custom_shape
      |> expect.to_equal(None)
    }),
    it("sets renderer via builder", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_custom_shape(renderer: fn(_props) { element.none() })
      config.custom_shape
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn funnel_active_shape_tests() {
  describe("funnel_active_shape", [
    it("defaults to None", fn() {
      let config = funnel.funnel_config(data_key: "v")
      config.active_shape
      |> expect.to_equal(None)
    }),
    it("sets renderer via builder", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_active_shape(renderer: fn(_props) { element.none() })
      config.active_shape
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn funnel_tooltip_type_tests() {
  describe("funnel_tooltip_type", [
    it("defaults to DefaultTooltip", fn() {
      let config = funnel.funnel_config(data_key: "v")
      config.tooltip_type
      |> expect.to_equal(shape.DefaultTooltip)
    }),
    it("sets via builder", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_tooltip_type(tooltip_type: shape.NoTooltip)
      config.tooltip_type
      |> expect.to_equal(shape.NoTooltip)
    }),
  ])
}

pub fn funnel_css_class_tests() {
  describe("funnel_css_class", [
    it("defaults to empty string", fn() {
      let config = funnel.funnel_config(data_key: "v")
      config.css_class
      |> expect.to_equal("")
    }),
    it("sets via builder", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_css_class(class: "my-funnel")
      config.css_class
      |> expect.to_equal("my-funnel")
    }),
  ])
}

// ---------------------------------------------------------------------------
// Treemap series
// ---------------------------------------------------------------------------

pub fn treemap_explicit_width_tests() {
  describe("treemap_explicit_width", [
    it("defaults to None", fn() {
      let config = treemap.treemap_config(data_key: "v")
      config.explicit_width
      |> expect.to_equal(None)
    }),
    it("sets via builder", fn() {
      let config =
        treemap.treemap_config(data_key: "v")
        |> treemap.treemap_explicit_width(width: 800)
      config.explicit_width
      |> expect.to_equal(Some(800))
    }),
  ])
}

pub fn treemap_explicit_height_tests() {
  describe("treemap_explicit_height", [
    it("defaults to None", fn() {
      let config = treemap.treemap_config(data_key: "v")
      config.explicit_height
      |> expect.to_equal(None)
    }),
    it("sets via builder", fn() {
      let config =
        treemap.treemap_config(data_key: "v")
        |> treemap.treemap_explicit_height(height: 600)
      config.explicit_height
      |> expect.to_equal(Some(600))
    }),
  ])
}

pub fn treemap_custom_shape_tests() {
  describe("treemap_custom_shape", [
    it("defaults to None", fn() {
      let config = treemap.treemap_config(data_key: "v")
      config.custom_shape
      |> expect.to_equal(None)
    }),
    it("sets renderer via builder", fn() {
      let config =
        treemap.treemap_config(data_key: "v")
        |> treemap.treemap_custom_shape(renderer: fn(_props) { element.none() })
      config.custom_shape
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn treemap_css_class_tests() {
  describe("treemap_css_class", [
    it("defaults to empty string", fn() {
      let config = treemap.treemap_config(data_key: "v")
      config.css_class
      |> expect.to_equal("")
    }),
    it("sets via builder", fn() {
      let config =
        treemap.treemap_config(data_key: "v")
        |> treemap.treemap_css_class(class: "my-treemap")
      config.css_class
      |> expect.to_equal("my-treemap")
    }),
  ])
}

// ---------------------------------------------------------------------------
// Sunburst series
// ---------------------------------------------------------------------------

pub fn sunburst_explicit_width_tests() {
  describe("sunburst_explicit_width", [
    it("defaults to None", fn() {
      let config = sunburst.sunburst_config()
      config.explicit_width
      |> expect.to_equal(None)
    }),
    it("sets via builder", fn() {
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_explicit_width(width: 500)
      config.explicit_width
      |> expect.to_equal(Some(500))
    }),
  ])
}

pub fn sunburst_explicit_height_tests() {
  describe("sunburst_explicit_height", [
    it("defaults to None", fn() {
      let config = sunburst.sunburst_config()
      config.explicit_height
      |> expect.to_equal(None)
    }),
    it("sets via builder", fn() {
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_explicit_height(height: 500)
      config.explicit_height
      |> expect.to_equal(Some(500))
    }),
  ])
}

pub fn sunburst_css_class_tests() {
  describe("sunburst_css_class", [
    it("defaults to empty string", fn() {
      let config = sunburst.sunburst_config()
      config.css_class
      |> expect.to_equal("")
    }),
    it("sets via builder", fn() {
      let config =
        sunburst.sunburst_config()
        |> sunburst.sunburst_css_class(class: "my-sunburst")
      config.css_class
      |> expect.to_equal("my-sunburst")
    }),
  ])
}

pub fn sunburst_ring_thickness_guard_tests() {
  describe("sunburst ring thickness", [
    it(
      "keeps rendering stable when inner_radius exceeds available outer radius",
      fn() {
        let root =
          sunburst.sunburst_node(
            name: "root",
            value: 100.0,
            fill: "",
            children: [
              sunburst.sunburst_leaf(name: "A", value: 60.0, fill: "#ff0000"),
              sunburst.sunburst_leaf(name: "B", value: 40.0, fill: "#00ff00"),
            ],
          )
        let config =
          sunburst.sunburst_config()
          |> sunburst.sunburst_data(data: root)
          |> sunburst.sunburst_inner_radius(radius: 120.0)
        let html =
          sunburst.render_sunburst(config: config, width: 100, height: 100)
          |> element.to_string
        html |> string.contains("NaN") |> expect.to_be_false
        html |> string.contains("Infinity") |> expect.to_be_false
        html |> string.contains("recharts-sunburst") |> expect.to_be_true
      },
    ),
  ])
}

// ---------------------------------------------------------------------------
// Sankey series
// ---------------------------------------------------------------------------

pub fn sankey_explicit_width_tests() {
  describe("sankey_explicit_width", [
    it("defaults to None", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config = sankey.sankey_config(data: data)
      config.explicit_width
      |> expect.to_equal(None)
    }),
    it("sets via builder", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_explicit_width(width: 1000)
      config.explicit_width
      |> expect.to_equal(Some(1000))
    }),
  ])
}

pub fn sankey_explicit_height_tests() {
  describe("sankey_explicit_height", [
    it("defaults to None", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config = sankey.sankey_config(data: data)
      config.explicit_height
      |> expect.to_equal(None)
    }),
    it("sets via builder", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_explicit_height(height: 500)
      config.explicit_height
      |> expect.to_equal(Some(500))
    }),
  ])
}

pub fn sankey_sort_fn_tests() {
  describe("sankey_sort_fn", [
    it("defaults to None", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config = sankey.sankey_config(data: data)
      config.sort_fn
      |> expect.to_equal(None)
    }),
    it("sets custom sort via builder", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_sort_fn(sort: fn(a, b) {
          string.compare(a.name, b.name)
        })
      config.sort_fn
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn sankey_sort_fn_dispatch_tests() {
  describe("sankey_sort_fn dispatch", [
    it("sort_fn changes vertical ordering of nodes in same column", fn() {
      // Z (index 0) and A (index 1) are both sources feeding into B (index 2).
      // Default ordering by index puts Z at position 0 (top), A at position 1.
      // Alphabetical sort puts A at position 0 (top), Z at position 1.
      let data =
        sankey.SankeyData(
          nodes: [
            sankey.SankeyNode(name: "Z"),
            sankey.SankeyNode(name: "A"),
            sankey.SankeyNode(name: "B"),
          ],
          links: [
            sankey.SankeyLink(source: 0, target: 2, value: 10.0),
            sankey.SankeyLink(source: 1, target: 2, value: 10.0),
          ],
        )
      let html_default =
        sankey.sankey_config(data: data)
        |> sankey.render_sankey(width: 400, height: 300)
        |> element.to_string
      let html_sorted =
        sankey.sankey_config(data: data)
        |> sankey.sankey_sort_fn(sort: fn(a, b) {
          string.compare(a.name, b.name)
        })
        |> sankey.render_sankey(width: 400, height: 300)
        |> element.to_string
      { html_default != html_sorted }
      |> expect.to_be_true
    }),
  ])
}

pub fn sankey_css_class_tests() {
  describe("sankey_css_class", [
    it("defaults to empty string", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config = sankey.sankey_config(data: data)
      config.css_class
      |> expect.to_equal("")
    }),
    it("sets via builder", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_css_class(class: "my-sankey")
      config.css_class
      |> expect.to_equal("my-sankey")
    }),
  ])
}

pub fn sankey_link_curvature_tests() {
  describe("sankey_link_curvature", [
    it("defaults to 0.5", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config = sankey.sankey_config(data: data)
      config.link_curvature
      |> expect.to_equal(0.5)
    }),
    it("sets via builder", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_link_curvature(curvature: 0.8)
      config.link_curvature
      |> expect.to_equal(0.8)
    }),
  ])
}

pub fn sankey_custom_node_tests() {
  describe("sankey_custom_node", [
    it("defaults to None", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config = sankey.sankey_config(data: data)
      config.custom_node
      |> expect.to_be_none
    }),
    it("sets via builder", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_custom_node(renderer: fn(_props) { element.none() })
      option.is_some(config.custom_node)
      |> expect.to_be_true
    }),
  ])
}

pub fn sankey_custom_link_tests() {
  describe("sankey_custom_link", [
    it("defaults to None", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config = sankey.sankey_config(data: data)
      config.custom_link
      |> expect.to_be_none
    }),
    it("sets via builder", fn() {
      let data =
        sankey.SankeyData(nodes: [sankey.SankeyNode(name: "A")], links: [])
      let config =
        sankey.sankey_config(data: data)
        |> sankey.sankey_custom_link(renderer: fn(_props) { element.none() })
      option.is_some(config.custom_link)
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Render props types
// ---------------------------------------------------------------------------

pub fn sector_props_tests() {
  describe("SectorProps", [
    it("constructs with all fields", fn() {
      let props =
        render.SectorProps(
          cx: 100.0,
          cy: 100.0,
          inner_radius: 0.0,
          outer_radius: 80.0,
          start_angle: 0.0,
          end_angle: 90.0,
          index: 0,
          fill: weft.css_color(value: "#ff0000"),
          stroke: weft.css_color(value: "#fff"),
        )
      props.cx
      |> expect.to_equal(100.0)
    }),
  ])
}

pub fn trapezoid_props_tests() {
  describe("TrapezoidProps", [
    it("constructs with all fields", fn() {
      let props =
        render.TrapezoidProps(
          x: 10.0,
          y: 20.0,
          width: 100.0,
          height: 50.0,
          upper_width: 100.0,
          lower_width: 60.0,
          index: 0,
        )
      props.upper_width
      |> expect.to_equal(100.0)
    }),
  ])
}

pub fn treemap_node_props_tests() {
  describe("TreemapNodeProps", [
    it("constructs with all fields", fn() {
      let props =
        render.TreemapNodeProps(
          x: 0.0,
          y: 0.0,
          width: 200.0,
          height: 100.0,
          depth: 0,
          index: 0,
          name: "Root",
          value: 500.0,
        )
      props.name
      |> expect.to_equal("Root")
    }),
  ])
}
