//// Tests for clip-path correctness on area/line dots.
////
//// Verifies that dots are rendered outside the clipped group by default
//// (matching recharts clipDot={false}), and inside the clipped group
//// when clip_dot is True.

import gleam/dict
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/chart
import weft_chart/series/area
import weft_chart/series/line

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

fn simple_data() -> List(chart.DataPoint) {
  [
    chart.DataPoint(category: "A", values: dict.from_list([#("v", 10.0)])),
    chart.DataPoint(category: "B", values: dict.from_list([#("v", 20.0)])),
    chart.DataPoint(category: "C", values: dict.from_list([#("v", 15.0)])),
  ]
}

pub fn main() {
  startest.run(startest.default_config())
}

// ---------------------------------------------------------------------------
// Area clip_dot config tests
// ---------------------------------------------------------------------------

pub fn area_clip_dot_config_tests() {
  describe("area_clip_dot config", [
    it("defaults to True", fn() {
      let config = area.area_config(data_key: "v")
      config.clip_dot
      |> expect.to_equal(True)
    }),
    it("sets to True via builder", fn() {
      let config =
        area.area_config(data_key: "v")
        |> area.area_clip_dot(clip: True)
      config.clip_dot
      |> expect.to_equal(True)
    }),
    it("sets to False via builder", fn() {
      let config =
        area.area_config(data_key: "v")
        |> area.area_clip_dot(clip: True)
        |> area.area_clip_dot(clip: False)
      config.clip_dot
      |> expect.to_equal(False)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Line clip_dot config tests
// ---------------------------------------------------------------------------

pub fn line_clip_dot_config_tests() {
  describe("line_clip_dot config", [
    it("defaults to True", fn() {
      let config = line.line_config(data_key: "v")
      config.clip_dot
      |> expect.to_equal(True)
    }),
    it("sets to True via builder", fn() {
      let config =
        line.line_config(data_key: "v")
        |> line.line_clip_dot(clip: True)
      config.clip_dot
      |> expect.to_equal(True)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Area chart rendering — dot placement relative to clip-path
// ---------------------------------------------------------------------------

pub fn area_dot_clip_rendering_tests() {
  describe("area dot clip rendering", [
    it("area path group has clip-path attribute", fn() {
      let html =
        chart.area_chart(
          data: simple_data(),
          width: 400,
          height: 300,
          children: [
            chart.area(
              area.area_config(data_key: "v")
              |> area.dot(True),
            ),
          ],
        )
        |> element.to_string

      // The paths group should be inside a clip-path group
      html
      |> string.contains("clip-path=\"url(#weft-chart-clip-")
      |> expect.to_be_true
    }),
    it("dots are inside clip-path by default (clip_dot=True)", fn() {
      let html =
        chart.area_chart(
          data: simple_data(),
          width: 400,
          height: 300,
          children: [
            chart.area(
              area.area_config(data_key: "v")
              |> area.dot(True),
            ),
          ],
        )
        |> element.to_string

      // The recharts-area-dots group should be inside a clip-path group
      // because clip_dot defaults to True (matching recharts default).
      html |> string.contains("recharts-area-dots") |> expect.to_be_true

      // Count clip-path occurrences in the area section.
      // With clip_dot=True (default), both paths and dots get clip-path wrappers = 2.
      let area_section = extract_area_section(html)
      let clip_count = count_occurrences(area_section, "clip-path=\"url(#")
      clip_count |> expect.to_equal(2)
    }),
    it("dots are inside clip-path when clip_dot=True", fn() {
      let html =
        chart.area_chart(
          data: simple_data(),
          width: 400,
          height: 300,
          children: [
            chart.area(
              area.area_config(data_key: "v")
              |> area.dot(True)
              |> area.area_clip_dot(clip: True),
            ),
          ],
        )
        |> element.to_string

      let area_section = extract_area_section(html)
      // With clip_dot=True, both paths and dots get clip-path wrappers = 2
      let clip_count = count_occurrences(area_section, "clip-path=\"url(#")
      clip_count |> expect.to_equal(2)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Line chart rendering — dot placement relative to clip-path
// ---------------------------------------------------------------------------

pub fn line_dot_clip_rendering_tests() {
  describe("line dot clip rendering", [
    it("line path group has clip-path attribute", fn() {
      let html =
        chart.line_chart(
          data: simple_data(),
          width: 400,
          height: 300,
          children: [
            chart.line(line.line_config(data_key: "v")),
          ],
        )
        |> element.to_string

      html
      |> string.contains("clip-path=\"url(#weft-chart-clip-")
      |> expect.to_be_true
    }),
    it("dots are inside clip-path by default (clip_dot=True)", fn() {
      let html =
        chart.line_chart(
          data: simple_data(),
          width: 400,
          height: 300,
          children: [
            chart.line(line.line_config(data_key: "v")),
          ],
        )
        |> element.to_string

      html |> string.contains("recharts-line-dots") |> expect.to_be_true

      let line_section = extract_line_section(html)
      let clip_count = count_occurrences(line_section, "clip-path=\"url(#")
      // clip_dot defaults to True, so both paths and dots get clip-path wrappers = 2
      clip_count |> expect.to_equal(2)
    }),
    it("dots are inside clip-path when clip_dot=True", fn() {
      let html =
        chart.line_chart(
          data: simple_data(),
          width: 400,
          height: 300,
          children: [
            chart.line(
              line.line_config(data_key: "v")
              |> line.line_clip_dot(clip: True),
            ),
          ],
        )
        |> element.to_string

      let line_section = extract_line_section(html)
      // With clip_dot=True, both paths and dots get clip-path wrappers = 2
      let clip_count = count_occurrences(line_section, "clip-path=\"url(#")
      clip_count |> expect.to_equal(2)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Extract the area series section from HTML for isolated counting.
fn extract_area_section(html: String) -> String {
  case string.split(html, "recharts-area\"") {
    [_, rest, ..] -> rest
    _ -> html
  }
}

/// Extract the line series section from HTML for isolated counting.
fn extract_line_section(html: String) -> String {
  case string.split(html, "recharts-line\"") {
    [_, rest, ..] -> rest
    _ -> html
  }
}

/// Count how many times a substring appears in a string.
fn count_occurrences(haystack: String, needle: String) -> Int {
  let parts = string.split(haystack, needle)
  // Number of occurrences = number of parts - 1
  case parts {
    [] -> 0
    _ -> list.length(parts) - 1
  }
}

import gleam/list
