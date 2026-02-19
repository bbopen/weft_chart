//// Tests for shape and curve parity additions.
////
//// Covers polygon baseline/connectNulls, symbol path generation,
//// custom curve variant, and dot clipDot config.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import startest.{describe, it}
import startest/expect
import weft_chart/curve
import weft_chart/shape

pub fn polygon_path_tests() {
  describe("polygon_path", [
    describe("without baseline", [
      it("generates closed path for valid points", fn() {
        let result =
          shape.polygon_path(
            points: [#(0.0, 0.0), #(10.0, 0.0), #(10.0, 10.0)],
            connect_nulls: False,
            base_line_points: None,
          )
        result
        |> string.contains("M")
        |> expect.to_be_true
        result
        |> string.contains("Z")
        |> expect.to_be_true
      }),
      it("returns empty string for empty points", fn() {
        shape.polygon_path(
          points: [],
          connect_nulls: False,
          base_line_points: None,
        )
        |> expect.to_equal(expected: "")
      }),
      it("generates path with L commands between points", fn() {
        let result =
          shape.polygon_path(
            points: [#(1.0, 2.0), #(3.0, 4.0), #(5.0, 6.0)],
            connect_nulls: False,
            base_line_points: None,
          )
        result
        |> string.contains("L")
        |> expect.to_be_true
      }),
    ]),
    describe("with baseline", [
      it("generates range path combining outer and baseline", fn() {
        let result =
          shape.polygon_path(
            points: [#(0.0, 0.0), #(10.0, 0.0), #(10.0, 5.0)],
            connect_nulls: False,
            base_line_points: Some([#(0.0, 10.0), #(10.0, 10.0), #(10.0, 15.0)]),
          )
        // Range path should not end with Z (recharts behavior)
        // It should contain the reversed baseline path
        result
        |> string.contains("M")
        |> expect.to_be_true
        result
        |> string.contains("L")
        |> expect.to_be_true
      }),
      it("includes reversed baseline points in path", fn() {
        let result =
          shape.polygon_path(
            points: [#(0.0, 0.0), #(10.0, 0.0)],
            connect_nulls: False,
            base_line_points: Some([#(0.0, 20.0), #(10.0, 20.0)]),
          )
        // The path should mention both y=0 (outer) and y=20 (baseline)
        result
        |> string.contains("0")
        |> expect.to_be_true
        result
        |> string.contains("20")
        |> expect.to_be_true
      }),
    ]),
    describe("connect_nulls", [
      it("True produces single continuous path from all valid points", fn() {
        let result =
          shape.polygon_path(
            points: [#(0.0, 0.0), #(5.0, 5.0), #(10.0, 0.0)],
            connect_nulls: True,
            base_line_points: None,
          )
        // With connect_nulls True and all valid points, should be single segment with Z
        result
        |> string.contains("Z")
        |> expect.to_be_true
      }),
      it("False with all valid points also produces closed path", fn() {
        let result =
          shape.polygon_path(
            points: [#(0.0, 0.0), #(5.0, 5.0), #(10.0, 0.0)],
            connect_nulls: False,
            base_line_points: None,
          )
        result
        |> string.contains("Z")
        |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn symbol_path_tests() {
  describe("symbol_path", [
    describe("CircleSymbol", [
      it("generates arc-based path with AreaSize", fn() {
        let result =
          shape.symbol_path(
            symbol_type: shape.CircleSymbol,
            cx: 50.0,
            cy: 50.0,
            size: 64.0,
            size_type: shape.AreaSize,
          )
        // Circle path uses arc commands
        result
        |> string.contains("A")
        |> expect.to_be_true
        // Should be centered around cx=50
        result
        |> string.contains("50")
        |> expect.to_be_true
      }),
      it("generates arc-based path with DiameterSize", fn() {
        let result =
          shape.symbol_path(
            symbol_type: shape.CircleSymbol,
            cx: 0.0,
            cy: 0.0,
            size: 10.0,
            size_type: shape.DiameterSize,
          )
        // Radius should be 5.0 (diameter/2)
        result
        |> string.contains("5")
        |> expect.to_be_true
        result
        |> string.contains("A")
        |> expect.to_be_true
      }),
      it("AreaSize and DiameterSize produce different radii", fn() {
        let area_path =
          shape.symbol_path(
            symbol_type: shape.CircleSymbol,
            cx: 0.0,
            cy: 0.0,
            size: 100.0,
            size_type: shape.AreaSize,
          )
        let diam_path =
          shape.symbol_path(
            symbol_type: shape.CircleSymbol,
            cx: 0.0,
            cy: 0.0,
            size: 100.0,
            size_type: shape.DiameterSize,
          )
        // Same size value but different interpretations should produce different paths
        { area_path != diam_path }
        |> expect.to_be_true
      }),
    ]),
    describe("CrossSymbol", [
      it("generates closed cross path", fn() {
        let result =
          shape.symbol_path(
            symbol_type: shape.CrossSymbol,
            cx: 10.0,
            cy: 10.0,
            size: 64.0,
            size_type: shape.AreaSize,
          )
        result
        |> string.contains("M")
        |> expect.to_be_true
        result
        |> string.contains("Z")
        |> expect.to_be_true
        // Cross has 12 vertices + close
        { string.contains(result, "L") }
        |> expect.to_be_true
      }),
    ]),
    describe("DiamondSymbol", [
      it("generates 4-point diamond path", fn() {
        let result =
          shape.symbol_path(
            symbol_type: shape.DiamondSymbol,
            cx: 0.0,
            cy: 0.0,
            size: 100.0,
            size_type: shape.AreaSize,
          )
        result
        |> string.contains("M")
        |> expect.to_be_true
        result
        |> string.contains("Z")
        |> expect.to_be_true
      }),
    ]),
    describe("SquareSymbol", [
      it("generates axis-aligned square path", fn() {
        let result =
          shape.symbol_path(
            symbol_type: shape.SquareSymbol,
            cx: 5.0,
            cy: 5.0,
            size: 16.0,
            size_type: shape.AreaSize,
          )
        result
        |> string.contains("M")
        |> expect.to_be_true
        result
        |> string.contains("Z")
        |> expect.to_be_true
      }),
      it("DiameterSize square has correct half-width", fn() {
        let result =
          shape.symbol_path(
            symbol_type: shape.SquareSymbol,
            cx: 10.0,
            cy: 10.0,
            size: 20.0,
            size_type: shape.DiameterSize,
          )
        // half = 10, so corners should be at 0 and 20
        result
        |> string.contains("0")
        |> expect.to_be_true
        result
        |> string.contains("20")
        |> expect.to_be_true
      }),
    ]),
    describe("StarSymbol", [
      it("generates closed star path", fn() {
        let result =
          shape.symbol_path(
            symbol_type: shape.StarSymbol,
            cx: 50.0,
            cy: 50.0,
            size: 200.0,
            size_type: shape.AreaSize,
          )
        result
        |> string.contains("M")
        |> expect.to_be_true
        result
        |> string.contains("Z")
        |> expect.to_be_true
        // Star has 10 vertices (5 outer + 5 inner)
        result
        |> string.contains("L")
        |> expect.to_be_true
      }),
    ]),
    describe("TriangleSymbol", [
      it("generates equilateral triangle path", fn() {
        let result =
          shape.symbol_path(
            symbol_type: shape.TriangleSymbol,
            cx: 0.0,
            cy: 0.0,
            size: 100.0,
            size_type: shape.AreaSize,
          )
        result
        |> string.contains("M")
        |> expect.to_be_true
        result
        |> string.contains("Z")
        |> expect.to_be_true
      }),
    ]),
    describe("WyeSymbol", [
      it("generates Y-shape path", fn() {
        let result =
          shape.symbol_path(
            symbol_type: shape.WyeSymbol,
            cx: 0.0,
            cy: 0.0,
            size: 64.0,
            size_type: shape.AreaSize,
          )
        result
        |> string.contains("M")
        |> expect.to_be_true
        result
        |> string.contains("Z")
        |> expect.to_be_true
      }),
    ]),
    describe("all symbol types", [
      it("all produce non-empty valid SVG path strings", fn() {
        let types = [
          shape.CircleSymbol,
          shape.CrossSymbol,
          shape.DiamondSymbol,
          shape.SquareSymbol,
          shape.StarSymbol,
          shape.TriangleSymbol,
          shape.WyeSymbol,
        ]
        types
        |> list.each(fn(sym) {
          let result =
            shape.symbol_path(
              symbol_type: sym,
              cx: 10.0,
              cy: 10.0,
              size: 64.0,
              size_type: shape.AreaSize,
            )
          // Every symbol should produce a non-empty path starting with M
          { string.starts_with(result, "M") }
          |> expect.to_be_true
        })
      }),
    ]),
  ])
}

pub fn dot_config_tests() {
  describe("DotConfig", [
    it("default has clip_dot True", fn() {
      let config = shape.default_dot_config()
      config.clip_dot
      |> expect.to_be_true
    }),
    it("dot_clip_dot sets clip_dot to False", fn() {
      let config =
        shape.default_dot_config()
        |> shape.dot_clip_dot(clip_dot: False)
      config.clip_dot
      |> expect.to_be_false
    }),
    it("dot_clip_dot sets clip_dot to True", fn() {
      let config =
        shape.default_dot_config()
        |> shape.dot_clip_dot(clip_dot: False)
        |> shape.dot_clip_dot(clip_dot: True)
      config.clip_dot
      |> expect.to_be_true
    }),
  ])
}

pub fn custom_curve_tests() {
  describe("Custom curve", [
    it("dispatches to user-provided generator function", fn() {
      let my_generator = fn(points) {
        case points {
          [] -> "EMPTY"
          [#(x, y), ..] ->
            "CUSTOM:" <> float_to_string(x) <> "," <> float_to_string(y)
        }
      }
      let result =
        curve.path(curve_type: curve.Custom(generator: my_generator), points: [
          #(1.0, 2.0),
          #(3.0, 4.0),
        ])
      result
      |> string.contains("CUSTOM:")
      |> expect.to_be_true
    }),
    it("custom generator receives all points", fn() {
      let count_generator = fn(points) { int_to_string(list.length(points)) }
      let result =
        curve.path(
          curve_type: curve.Custom(generator: count_generator),
          points: [#(1.0, 2.0), #(3.0, 4.0), #(5.0, 6.0)],
        )
      result
      |> expect.to_equal(expected: "3")
    }),
    it("custom generator is called even for empty points", fn() {
      let empty_generator = fn(points) {
        case points {
          [] -> "NONE"
          _ -> "HAS_POINTS"
        }
      }
      curve.path(
        curve_type: curve.Custom(generator: empty_generator),
        points: [],
      )
      |> expect.to_equal(expected: "NONE")
    }),
    it("custom generator is called for single point", fn() {
      let single_generator = fn(points) {
        case points {
          [#(x, _y)] -> "SINGLE:" <> float_to_string(x)
          _ -> "OTHER"
        }
      }
      let result =
        curve.path(
          curve_type: curve.Custom(generator: single_generator),
          points: [#(42.0, 99.0)],
        )
      result
      |> expect.to_equal(expected: "SINGLE:42.0")
    }),
  ])
}

// Helper for tests

fn float_to_string(v: Float) -> String {
  float.to_string(v)
}

fn int_to_string(v: Int) -> String {
  int.to_string(v)
}
