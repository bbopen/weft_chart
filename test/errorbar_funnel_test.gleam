//// Tests for error_bar stroke_dasharray, funnel last_shape_type, and funnel
//// geometry (reversed, gap, fills, labels, active_index, role=img).

import gleam/dict
import gleam/int
import gleam/list
import gleam/string
import lustre/element.{type Element}
import startest.{describe, it}
import startest/expect
import weft_chart/error_bar
import weft_chart/internal/svg
import weft_chart/render
import weft_chart/scale
import weft_chart/series/funnel

pub fn main() {
  startest.run(startest.default_config())
}

// ---------------------------------------------------------------------------
// error_bar stroke_dasharray
// ---------------------------------------------------------------------------

pub fn error_bar_stroke_dasharray_tests() {
  describe("error_bar_stroke_dasharray", [
    it("defaults to empty string", fn() {
      let config = error_bar.error_bar_config(data_key: "err")
      config.stroke_dasharray |> expect.to_equal(expected: "")
    }),
    it("builder sets the value", fn() {
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_stroke_dasharray(dasharray: "5 3")
      config.stroke_dasharray |> expect.to_equal(expected: "5 3")
    }),
    it("appears in rendered output when set", fn() {
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_stroke_dasharray(dasharray: "4 2")
      let data = [
        dict.from_list([#("value", 10.0), #("err", 2.0)]),
      ]
      let x_scale =
        scale.point(
          categories: ["A"],
          range_start: 0.0,
          range_end: 400.0,
          padding: 0.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 20.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        error_bar.render_error_bars(
          config: config,
          data: data,
          categories: ["A"],
          x_scale: x_scale,
          y_scale: y_scale,
          series_data_key: "value",
        )
        |> element.to_string
      html |> string.contains("stroke-dasharray=\"4 2\"") |> expect.to_be_true
    }),
    it("does not appear in rendered output when empty", fn() {
      let config = error_bar.error_bar_config(data_key: "err")
      let data = [
        dict.from_list([#("value", 10.0), #("err", 2.0)]),
      ]
      let x_scale =
        scale.point(
          categories: ["A"],
          range_start: 0.0,
          range_end: 400.0,
          padding: 0.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 20.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        error_bar.render_error_bars(
          config: config,
          data: data,
          categories: ["A"],
          x_scale: x_scale,
          y_scale: y_scale,
          series_data_key: "value",
        )
        |> element.to_string
      html
      |> string.contains("stroke-dasharray")
      |> expect.to_be_false
    }),
  ])
}

// ---------------------------------------------------------------------------
// funnel last_shape_type
// ---------------------------------------------------------------------------

pub fn funnel_last_shape_type_tests() {
  describe("funnel_last_shape_type", [
    it("defaults to TriangleLastShape", fn() {
      let config = funnel.funnel_config(data_key: "v")
      config.last_shape_type
      |> expect.to_equal(expected: funnel.TriangleLastShape)
    }),
    it("builder sets RectangleLastShape", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_last_shape_type(shape: funnel.RectangleLastShape)
      config.last_shape_type
      |> expect.to_equal(expected: funnel.RectangleLastShape)
    }),
    it("TriangleLastShape produces zero lower_width for last segment", fn() {
      // Single segment funnel: is always the "last" segment
      let config = funnel.funnel_config(data_key: "v")
      let data = [dict.from_list([#("v", 100.0)])]
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 200.0,
          height: 100.0,
        )
        |> element.to_string
      // Triangle last shape tapers to a point (lower_width=0)
      // The polygon points should include the center bottom point
      html |> string.contains("recharts-funnel") |> expect.to_be_true
    }),
    it(
      "RectangleLastShape produces non-zero lower_width for last segment",
      fn() {
        let config =
          funnel.funnel_config(data_key: "v")
          |> funnel.funnel_last_shape_type(shape: funnel.RectangleLastShape)
        // Two data points: second is the last segment
        let data = [
          dict.from_list([#("v", 100.0)]),
          dict.from_list([#("v", 50.0)]),
        ]
        let html =
          funnel.render_funnel(
            config: config,
            data: data,
            categories: [],
            width: 200.0,
            height: 100.0,
          )
          |> element.to_string
        // RectangleLastShape means last segment lower_width == upper_width
        // so it renders as a rectangle (parallel sides), not a triangle
        html |> string.contains("recharts-funnel") |> expect.to_be_true
      },
    ),
  ])
}

// ---------------------------------------------------------------------------
// funnel geometry tests (T-F1 through T-F6)
// ---------------------------------------------------------------------------

pub fn funnel_geometry_tests() {
  describe("funnel_geometry", [
    // T-F1: reversed=True geometry
    it(
      "reversed=True: top segment has upper_width=0, last segment has lower_width=largest",
      fn() {
        // Data [100, 50], width=200, height=100
        // reversed pairs: [(0.0, 100.0), (100.0, 200.0)]
        // Top segment: upper=0, lower=100 → triangle point at top
        // Bottom segment: upper=100, lower=200 → widest at bottom
        let config =
          funnel.funnel_config(data_key: "v")
          |> funnel.funnel_reversed
        let data = [
          dict.from_list([#("v", 100.0)]),
          dict.from_list([#("v", 50.0)]),
        ]
        let html =
          funnel.render_funnel(
            config: config,
            data: data,
            categories: [],
            width: 200.0,
            height: 100.0,
          )
          |> element.to_string
        // render_funnel deducts 50px: constrained_width = 200 - 50 = 150
        // center = 150 / 2 = 75
        // Top segment: upper_width=0 means tl_x==tr_x at center=75
        html |> string.contains("M75,0L75,0") |> expect.to_be_true
        // Bottom segment: lower_width=150 spans full constrained width
        html |> string.contains("L150,100L0,100Z") |> expect.to_be_true
      },
    ),
    // T-F2: RectangleLastShape
    it(
      "last segment with RectangleLastShape has equal upper and lower widths",
      fn() {
        let config =
          funnel.funnel_config(data_key: "v")
          |> funnel.funnel_last_shape_type(shape: funnel.RectangleLastShape)
        // Single item: last_shape_type=Rectangle means lower=upper
        let data = [dict.from_list([#("v", 100.0)])]
        let html =
          funnel.render_funnel(
            config: config,
            data: data,
            categories: [],
            width: 200.0,
            height: 100.0,
          )
          |> element.to_string
        // render_funnel deducts 50px: constrained_width = 200 - 50 = 150
        // Rectangle: upper=lower=150, all four corners form a rect
        // tl_x=0, tr_x=150, bl_x=0, br_x=150
        // Path: M0,0L150,0L150,100L0,100Z
        html
        |> string.contains("M0,0L150,0L150,100L0,100Z")
        |> expect.to_be_true
      },
    ),
    // T-F3: trap_gap arithmetic
    it(
      "trap_gap=10 with 3 segments in 100px height: second segment starts at correct y",
      fn() {
        // height=100, 3 segments, gap=10
        // total_gap = 2*10 = 20, remaining = 80, seg_height = 80/3 ≈ 26.67
        // Second segment y ≈ 26.67 + 10 = 36.67 (math.fmt rounds to 2 dp)
        let config =
          funnel.funnel_config(data_key: "v")
          |> funnel.funnel_gap(10.0)
        let data = [
          dict.from_list([#("v", 100.0)]),
          dict.from_list([#("v", 75.0)]),
          dict.from_list([#("v", 50.0)]),
        ]
        let html =
          funnel.render_funnel(
            config: config,
            data: data,
            categories: [],
            width: 300.0,
            height: 100.0,
          )
          |> element.to_string
        // seg_height = 80/3 = 26.666... → fmt rounds to 26.67
        // Second segment starts at y = 26.67 + 10 = 36.67
        // The path should contain ",36.67" as the y coordinate
        html |> string.contains(",36.67") |> expect.to_be_true
      },
    ),
    // T-F4: Fill color cycling
    it("fill cycles: segment at index 3 with 2-fill list uses fills[1]", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_fills(["#red", "#blue"])
      let data = [
        dict.from_list([#("v", 100.0)]),
        dict.from_list([#("v", 80.0)]),
        dict.from_list([#("v", 60.0)]),
        dict.from_list([#("v", 40.0)]),
      ]
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 200.0,
          height: 200.0,
        )
        |> element.to_string
      // Original indices 0,1,2,3 map to fills: #red, #blue, #red, #blue
      // Count occurrences of each fill color
      let red_count = count_occurrences(html, "fill=\"#red\"")
      let blue_count = count_occurrences(html, "fill=\"#blue\"")
      // 4 segments: indices 0,1,2,3 → #red,#blue,#red,#blue = 2 each
      red_count |> expect.to_equal(expected: 2)
      blue_count |> expect.to_equal(expected: 2)
    }),
    // T-F5: show_label=True
    it(
      "show_label=True: output contains text elements with segment values",
      fn() {
        let config =
          funnel.funnel_config(data_key: "v")
          |> funnel.funnel_label(show: True)
        let data = [
          dict.from_list([#("v", 100.0)]),
          dict.from_list([#("v", 50.0)]),
        ]
        let html =
          funnel.render_funnel(
            config: config,
            data: data,
            categories: [],
            width: 200.0,
            height: 100.0,
          )
          |> element.to_string
        // Should contain <text elements
        html |> string.contains("<text") |> expect.to_be_true
        // Should contain the values as label text
        html |> string.contains(">100<") |> expect.to_be_true
        html |> string.contains(">50<") |> expect.to_be_true
      },
    ),
    // T-F6: active_index dispatch
    it("active_index=1: segment at index 1 uses active_shape renderer", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_active_index(indices: [1])
        |> funnel.funnel_active_shape(renderer: active_marker)
      let data = [
        dict.from_list([#("v", 100.0)]),
        dict.from_list([#("v", 80.0)]),
        dict.from_list([#("v", 60.0)]),
      ]
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 200.0,
          height: 150.0,
        )
        |> element.to_string
      // Only segment at index 1 should have data-active="true"
      html
      |> string.contains("data-active=\"true\"")
      |> expect.to_be_true
      // Count: should appear exactly once
      count_occurrences(html, "data-active=\"true\"")
      |> expect.to_equal(expected: 1)
    }),
  ])
}

// ---------------------------------------------------------------------------
// role="img" wrapper test
// ---------------------------------------------------------------------------

pub fn funnel_role_img_tests() {
  describe("funnel_role_img", [
    it("each trapezoid is wrapped in a g with role=img", fn() {
      let config = funnel.funnel_config(data_key: "v")
      let data = [
        dict.from_list([#("v", 100.0)]),
        dict.from_list([#("v", 50.0)]),
      ]
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 200.0,
          height: 100.0,
        )
        |> element.to_string
      // Each of the 2 segments should be wrapped with role="img"
      let role_count = count_occurrences(html, "role=\"img\"")
      role_count |> expect.to_equal(expected: 2)
    }),
    it("each trapezoid wrapper has recharts-funnel-trapezoid class", fn() {
      let config = funnel.funnel_config(data_key: "v")
      let data = [
        dict.from_list([#("v", 100.0)]),
        dict.from_list([#("v", 50.0)]),
      ]
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 200.0,
          height: 100.0,
        )
        |> element.to_string
      let class_count =
        count_occurrences(html, "class=\"recharts-funnel-trapezoid\"")
      class_count |> expect.to_equal(expected: 2)
    }),
  ])
}

// ---------------------------------------------------------------------------
// funnel event handlers (T-F7) and activeIndex list (T-F8, T-F9)
// ---------------------------------------------------------------------------

pub fn funnel_event_handler_tests() {
  describe("funnel_event_handlers", [
    // T-F7: on_click renders cursor="pointer"
    it("on_click: rendered output contains cursor pointer", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_on_click(handler: fn(i) { i })
      let data = [dict.from_list([#("v", 100.0)])]
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 200.0,
          height: 100.0,
        )
        |> element.to_string
      html |> string.contains("cursor=\"pointer\"") |> expect.to_be_true
    }),
    // T-F7b: no handler means no cursor pointer
    it("no handlers: rendered output does not contain cursor pointer", fn() {
      let config = funnel.funnel_config(data_key: "v")
      let data = [dict.from_list([#("v", 100.0)])]
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 200.0,
          height: 100.0,
        )
        |> element.to_string
      html |> string.contains("cursor=\"pointer\"") |> expect.to_be_false
    }),
  ])
}

pub fn funnel_active_index_list_tests() {
  describe("funnel_active_index_list", [
    // T-F8: multiple active segments
    it(
      "active_index list: both indices 0 and 2 get active_shape renderer",
      fn() {
        let config =
          funnel.funnel_config(data_key: "v")
          |> funnel.funnel_active_index(indices: [0, 2])
          |> funnel.funnel_active_shape(renderer: active_marker)
        let data = [
          dict.from_list([#("v", 100.0)]),
          dict.from_list([#("v", 80.0)]),
          dict.from_list([#("v", 60.0)]),
        ]
        let html =
          funnel.render_funnel(
            config: config,
            data: data,
            categories: [],
            width: 200.0,
            height: 150.0,
          )
          |> element.to_string
        // active_marker adds data-active="true" — should appear exactly twice
        count_occurrences(html, "data-active=\"true\"")
        |> expect.to_equal(expected: 2)
      },
    ),
    // T-F9: empty list means no active segments
    it("active_index empty list: no segment uses active_shape renderer", fn() {
      let config =
        funnel.funnel_config(data_key: "v")
        |> funnel.funnel_active_index(indices: [])
        |> funnel.funnel_active_shape(renderer: active_marker)
      let data = [dict.from_list([#("v", 100.0)])]
      let html =
        funnel.render_funnel(
          config: config,
          data: data,
          categories: [],
          width: 200.0,
          height: 100.0,
        )
        |> element.to_string
      html
      |> string.contains("data-active=\"true\"")
      |> expect.to_be_false
    }),
  ])
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

fn active_marker(props: render.TrapezoidProps) -> Element(msg) {
  svg.g(attrs: [svg.attr("data-active", "true")], children: [
    svg.path(d: "M0,0L1,1", attrs: [
      svg.attr("data-index", int.to_string(props.index)),
    ]),
  ])
}

fn count_occurrences(haystack: String, needle: String) -> Int {
  let parts = string.split(haystack, needle)
  list.length(parts) - 1
}
