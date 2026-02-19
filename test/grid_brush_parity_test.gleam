//// Parity tests for grid render order and brush defaults/new fields.
////
//// Verifies:
//// - PolarGrid renders radial lines before concentric rings (recharts order)
//// - Concentric ring elements have fill="none"
//// - Brush defaults match recharts BrushDefaultProps (stroke #666, fill #fff)
//// - New brush fields: traveller_width, gap, on_drag_end, brush_padding

import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/brush
import weft_chart/chart
import weft_chart/grid
import weft_chart/scale
import weft_chart/series/radar

// ---------------------------------------------------------------------------
// PolarGrid render order tests
// ---------------------------------------------------------------------------

pub fn polar_grid_parity_tests() {
  describe("PolarGrid render order", [
    it("renders radial lines (angle group) before concentric rings", fn() {
      let config = grid.polar_grid_config()
      let html =
        grid.render_polar_grid(
          config: config,
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 100.0,
          angles: [0.0, 90.0, 180.0, 270.0],
          radii: [25.0, 50.0, 75.0, 100.0],
        )
        |> element.to_string

      // Angle group should appear before concentric group in the output
      let angle_pos = find_index(html, "recharts-polar-grid-angle")
      let concentric_pos = find_index(html, "recharts-polar-grid-concentric")

      // Both groups must be present
      { angle_pos >= 0 } |> expect.to_be_true
      { concentric_pos >= 0 } |> expect.to_be_true

      // Angle (radial lines) must come before concentric (rings)
      { angle_pos < concentric_pos } |> expect.to_be_true
    }),
    it("forces fill=none on concentric circle rings", fn() {
      let config =
        grid.polar_grid_config()
        |> grid.polar_grid_type(grid_type: grid.CircleGrid)
        |> grid.polar_grid_fill(color: "#ff0000")

      let html =
        grid.render_polar_grid(
          config: config,
          cx: 100.0,
          cy: 100.0,
          inner_radius: 0.0,
          outer_radius: 80.0,
          angles: [0.0, 120.0, 240.0],
          radii: [40.0, 80.0],
        )
        |> element.to_string

      // The ring elements should have fill="none" overriding the config fill.
      // Each <circle> in the concentric group should contain fill="none".
      // Since fill="none" is prepended before base_attrs (which has fill="#ff0000"),
      // the first fill attribute wins in SVG, so fill="none" takes effect.
      html
      |> string.contains("recharts-polar-grid-concentric")
      |> expect.to_be_true

      // Verify the output contains fill="none" (the override)
      html |> string.contains("fill=\"none\"") |> expect.to_be_true
    }),
    it("forces fill=none on concentric polygon rings", fn() {
      let config =
        grid.polar_grid_config()
        |> grid.polar_grid_type(grid_type: grid.PolygonGrid)
        |> grid.polar_grid_fill(color: "#00ff00")

      let html =
        grid.render_polar_grid(
          config: config,
          cx: 100.0,
          cy: 100.0,
          inner_radius: 0.0,
          outer_radius: 80.0,
          angles: [0.0, 90.0, 180.0, 270.0],
          radii: [40.0, 80.0],
        )
        |> element.to_string

      html
      |> string.contains("recharts-polar-grid-concentric")
      |> expect.to_be_true

      html |> string.contains("fill=\"none\"") |> expect.to_be_true
    }),
    it("polygon grid with 6 angles renders hexagon (6 vertices)", fn() {
      let config =
        grid.polar_grid_config()
        |> grid.polar_grid_type(grid_type: grid.PolygonGrid)
      // Angles matching recharts convention: 0=top, clockwise
      let six_angles = [0.0, 60.0, 120.0, 180.0, 240.0, 300.0]
      let html =
        grid.render_polar_grid(
          config: config,
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 100.0,
          angles: six_angles,
          radii: [50.0, 100.0],
        )
        |> element.to_string
      // Each polygon path has 1 M + 5 L = 6 vertices
      // 2 paths * 5 L = 10 L commands from polygon paths
      let l_count = count_char(html, "L")
      { l_count >= 10 } |> expect.to_be_true
    }),
    it(
      "full radar chart with 6 categories renders hexagonal polygon grid",
      fn() {
        let data = [
          chart.DataPoint(category: "A", values: dict.from_list([#("v", 80.0)])),
          chart.DataPoint(category: "B", values: dict.from_list([#("v", 90.0)])),
          chart.DataPoint(category: "C", values: dict.from_list([#("v", 70.0)])),
          chart.DataPoint(category: "D", values: dict.from_list([#("v", 85.0)])),
          chart.DataPoint(category: "E", values: dict.from_list([#("v", 60.0)])),
          chart.DataPoint(category: "F", values: dict.from_list([#("v", 75.0)])),
        ]
        let html =
          chart.radar_chart(data: data, width: 400, height: 400, children: [
            chart.polar_grid(grid.polar_grid_config()),
            chart.radar(radar.radar_config(data_key: "v")),
          ])
          |> element.to_string

        // All expected groups are present
        { find_index(html, "recharts-polar-grid-concentric") >= 0 }
        |> expect.to_be_true
        { find_index(html, "recharts-radar") >= 0 }
        |> expect.to_be_true
        { find_index(html, "recharts-polar-grid-angle") >= 0 }
        |> expect.to_be_true

        // 5 grid polygon paths * 5 L each + 1 radar path * 5 L = 30 L
        let total_l = count_char(html, "L")
        { total_l >= 30 } |> expect.to_be_true
      },
    ),
    it("polar grid first spoke points to top matching recharts", fn() {
      let data = [
        chart.DataPoint(category: "A", values: dict.from_list([#("v", 80.0)])),
        chart.DataPoint(category: "B", values: dict.from_list([#("v", 90.0)])),
        chart.DataPoint(category: "C", values: dict.from_list([#("v", 70.0)])),
        chart.DataPoint(category: "D", values: dict.from_list([#("v", 85.0)])),
        chart.DataPoint(category: "E", values: dict.from_list([#("v", 60.0)])),
        chart.DataPoint(category: "F", values: dict.from_list([#("v", 75.0)])),
      ]
      let html =
        chart.radar_chart(data: data, width: 400, height: 400, children: [
          chart.polar_grid(grid.polar_grid_config()),
          chart.radar(radar.radar_config(data_key: "v")),
        ])
        |> element.to_string

      // First spoke goes to top: x2=cx (200), y2 near top of chart.
      // With center at (200, 200) and max_radius ~ 160,
      // the first spoke should end at approximately (200, 40).
      // Verify x2="200" appears in the first line element.
      html
      |> string.contains("x2=\"200\"")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Brush defaults tests
// ---------------------------------------------------------------------------

fn brush_data() -> List(dict.Dict(String, Float)) {
  [
    dict.from_list([#("val", 10.0)]),
    dict.from_list([#("val", 20.0)]),
    dict.from_list([#("val", 30.0)]),
  ]
}

pub fn brush_defaults_parity_tests() {
  describe("Brush defaults match recharts BrushDefaultProps", [
    it("default stroke is #666", fn() {
      let config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
      config.stroke |> expect.to_equal(expected: "#666")
    }),
    it("default fill is #fff", fn() {
      let config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
      config.fill |> expect.to_equal(expected: "#fff")
    }),
    it("default traveller_width is 5.0", fn() {
      let config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
      config.traveller_width |> expect.to_equal(expected: 5.0)
    }),
    it("default gap is 1", fn() {
      let config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
      config.gap |> expect.to_equal(expected: 1)
    }),
    it("default on_drag_end is None", fn() {
      let config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
      config.on_drag_end |> expect.to_equal(expected: None)
    }),
    it("default brush_padding is 2.0", fn() {
      let config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
      config.brush_padding |> expect.to_equal(expected: 2.0)
    }),
  ])
}

pub fn cartesian_grid_stripe_direction_tests() {
  describe("CartesianGrid stripe direction", [
    it(
      "horizontal_fill produces ordered non-overlapping bands with descending coordinates",
      fn() {
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
        let config =
          grid.cartesian_grid_config()
          |> grid.grid_horizontal_fill(colors: ["#111", "#222"])
          |> grid.grid_horizontal_values(values: [0.0, 25.0, 50.0, 75.0, 100.0])
        let html =
          grid.render_cartesian_grid(
            config: config,
            x_scale: x_scale,
            y_scale: y_scale,
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 300.0,
          )
          |> element.to_string
        // Bands should be split across multiple ordered y starts.
        html |> string.contains("y=\"0\"") |> expect.to_be_true
        html |> string.contains("y=\"75\"") |> expect.to_be_true
        html |> string.contains("y=\"150\"") |> expect.to_be_true
        html |> string.contains("y=\"225\"") |> expect.to_be_true
      },
    ),
  ])
}

// ---------------------------------------------------------------------------
// Brush builder tests
// ---------------------------------------------------------------------------

pub fn brush_builder_parity_tests() {
  describe("Brush builder functions", [
    it("brush_traveller_width sets traveller_width", fn() {
      let config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
        |> brush.brush_traveller_width(width: 10.0)
      config.traveller_width |> expect.to_equal(expected: 10.0)
    }),
    it("brush_gap sets gap", fn() {
      let config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
        |> brush.brush_gap(gap: 3)
      config.gap |> expect.to_equal(expected: 3)
    }),
    it("brush_on_drag_end sets on_drag_end callback", fn() {
      let handler = fn(s: Int, e: Int) { #(s, e) }
      let config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
        |> brush.brush_on_drag_end(callback: handler)
      case config.on_drag_end {
        Some(_) -> expect.to_be_true(True)
        None -> expect.to_be_true(False)
      }
    }),
    it("brush_set_padding sets brush_padding", fn() {
      let config =
        brush.new(
          start_index: 0,
          end_index: 2,
          data_key: "val",
          data: brush_data(),
        )
        |> brush.brush_set_padding(padding: 4.0)
      config.brush_padding |> expect.to_equal(expected: 4.0)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Find the byte position of a substring, or -1 if not found.
fn find_index(haystack: String, needle: String) -> Int {
  find_index_loop(haystack, needle, 0)
}

fn find_index_loop(haystack: String, needle: String, pos: Int) -> Int {
  case string.starts_with(haystack, needle) {
    True -> pos
    False ->
      case string.pop_grapheme(haystack) {
        Ok(#(_, rest)) -> find_index_loop(rest, needle, pos + 1)
        Error(_) -> -1
      }
  }
}

/// Count occurrences of a single-character needle in a string.
fn count_char(haystack: String, needle: String) -> Int {
  count_char_loop(haystack, needle, 0)
}

fn count_char_loop(haystack: String, needle: String, acc: Int) -> Int {
  case string.pop_grapheme(haystack) {
    Ok(#(c, rest)) ->
      case c == needle {
        True -> count_char_loop(rest, needle, acc + 1)
        False -> count_char_loop(rest, needle, acc)
      }
    Error(_) -> acc
  }
}
