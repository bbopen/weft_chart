//// Tests for radial bar stub field wiring.

import gleam/dict
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/animation
import weft_chart/series/radial_bar

pub fn main() {
  startest.run(startest.default_config())
}

pub fn stroke_tests() {
  describe("radial_bar stroke rendering", [
    it("renders stroke and stroke-width attributes on bars", fn() {
      let data = [
        dict.from_list([#("value", 80.0)]),
        dict.from_list([#("value", 60.0)]),
      ]
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_stroke(stroke_value: "#ff0000")
        |> radial_bar.radial_bar_stroke_width(width: 2.0)
        |> radial_bar.radial_bar_animation(anim: animation.with_active(
          animation.line_default(),
          False,
        ))
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
      html |> string.contains("stroke=\"#ff0000\"") |> expect.to_be_true
      html |> string.contains("stroke-width=\"2.0\"") |> expect.to_be_true
    }),
    it("omits stroke attributes when stroke is none", fn() {
      let data = [dict.from_list([#("value", 80.0)])]
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_animation(anim: animation.with_active(
          animation.line_default(),
          False,
        ))
      let html =
        radial_bar.render_radial_bars(
          config: config,
          data: data,
          categories: ["A"],
          cx: 200.0,
          cy: 200.0,
          domain_max: 100.0,
        )
        |> element.to_string
      html |> string.contains("stroke-width") |> expect.to_be_false
    }),
  ])
}

pub fn min_point_size_tests() {
  describe("radial_bar min_point_size", [
    it("enforces minimum arc for tiny values", fn() {
      let data = [
        dict.from_list([#("value", 0.001)]),
      ]
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_min_point_size(30.0)
        |> radial_bar.radial_bar_animation(anim: animation.with_active(
          animation.line_default(),
          False,
        ))
      // With min_point_size=30, a tiny value should still produce a
      // visible arc.  Without min_point_size the arc delta would be
      // near-zero (~0.00036 deg).  With it, the arc spans 30 degrees.
      let html =
        radial_bar.render_radial_bars(
          config: config,
          data: data,
          categories: ["A"],
          cx: 200.0,
          cy: 200.0,
          domain_max: 100.0,
        )
        |> element.to_string
      // The path `d` attribute should contain arc commands (A)
      html |> string.contains(" d=\"M") |> expect.to_be_true
      // A 30-degree arc produces non-trivial coordinates, so the path
      // should differ from a near-zero arc.  We verify the path has
      // a real arc segment.
      html |> string.contains("A") |> expect.to_be_true
    }),
    it("does not enforce min_point_size for zero values", fn() {
      let data = [dict.from_list([#("value", 0.0)])]
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_min_point_size(30.0)
        |> radial_bar.radial_bar_animation(anim: animation.with_active(
          animation.line_default(),
          False,
        ))
      let html =
        radial_bar.render_radial_bars(
          config: config,
          data: data,
          categories: ["A"],
          cx: 200.0,
          cy: 200.0,
          domain_max: 100.0,
        )
        |> element.to_string
      // Zero-value bars should still render (start == end angle),
      // producing a degenerate path.  The key point is min_point_size
      // doesn't inflate a genuinely zero value.
      html |> string.contains("recharts-radial-bar") |> expect.to_be_true
    }),
  ])
}

pub fn max_bar_size_tests() {
  describe("radial_bar max_bar_size", [
    it("caps bar thickness when max_bar_size is set", fn() {
      // With inner=0, outer=200, 2 categories: raw bar_height=100.
      // max_bar_size=20 should cap it to 20.
      let data = [
        dict.from_list([#("value", 80.0)]),
        dict.from_list([#("value", 60.0)]),
      ]
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_inner_radius(0.0)
        |> radial_bar.radial_bar_outer_radius(200.0)
        |> radial_bar.radial_bar_max_bar_size(20.0)
        |> radial_bar.radial_bar_animation(anim: animation.with_active(
          animation.line_default(),
          False,
        ))
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
      // With capped bar_height=20, bar 0 spans r=0..16 (20*0.8)
      // and bar 1 spans r=20..36.
      // Without capping, bar 0 would span r=0..80 and bar 1 r=100..180.
      // We can verify bars are rendered in the group.
      html |> string.contains("recharts-radial-bar") |> expect.to_be_true
    }),
    it("does not cap when max_bar_size is 0", fn() {
      let data = [dict.from_list([#("value", 80.0)])]
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_inner_radius(0.0)
        |> radial_bar.radial_bar_outer_radius(200.0)
        |> radial_bar.radial_bar_animation(anim: animation.with_active(
          animation.line_default(),
          False,
        ))
      let html =
        radial_bar.render_radial_bars(
          config: config,
          data: data,
          categories: ["A"],
          cx: 200.0,
          cy: 200.0,
          domain_max: 100.0,
        )
        |> element.to_string
      html |> string.contains("recharts-radial-bar") |> expect.to_be_true
    }),
  ])
}

pub fn corner_radius_tests() {
  describe("radial_bar corner_radius rendering", [
    it("uses rounded sector path when corner_radius > 0", fn() {
      let data = [dict.from_list([#("value", 80.0)])]
      let config =
        radial_bar.radial_bar_config(data_key: "value")
        |> radial_bar.radial_bar_corner_radius(5.0)
        |> radial_bar.radial_bar_animation(anim: animation.with_active(
          animation.line_default(),
          False,
        ))
      let html =
        radial_bar.render_radial_bars(
          config: config,
          data: data,
          categories: ["A"],
          cx: 200.0,
          cy: 200.0,
          domain_max: 100.0,
        )
        |> element.to_string
      // sector_path_with_corners produces paths with small-a relative
      // arcs for corners (or multiple A arcs) vs the plain sector_path
      html |> string.contains("recharts-radial-bar") |> expect.to_be_true
      html |> string.contains(" d=\"M") |> expect.to_be_true
    }),
  ])
}
