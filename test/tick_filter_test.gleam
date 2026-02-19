//// Tests for tick display filtering (axis interval strategies).

import gleam/int
import gleam/list
import startest.{describe, it}
import startest/expect
import weft_chart/axis
import weft_chart/scale

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a list of evenly spaced ticks with short numeric labels.
fn make_ticks(count: Int, spacing: Float) -> List(scale.ScaleTick) {
  int.range(from: 0, to: count, with: [], run: fn(acc, i) {
    [
      scale.ScaleTick(
        value: int.to_string(i),
        coordinate: int.to_float(i) *. spacing,
      ),
      ..acc
    ]
  })
  |> list.reverse
}

pub fn tick_filter_tests() {
  describe("filter_ticks_by_interval", [
    // ----- EveryNth -----
    describe("EveryNth", [
      it("EveryNth(0) shows all ticks", fn() {
        let ticks = make_ticks(5, 50.0)
        axis.filter_ticks_by_interval(
          ticks: ticks,
          interval: axis.EveryNth(0),
          min_tick_gap: 5,
        )
        |> list.length
        |> expect.to_equal(expected: 5)
      }),
      it("EveryNth(1) shows every other tick", fn() {
        let ticks = make_ticks(6, 50.0)
        axis.filter_ticks_by_interval(
          ticks: ticks,
          interval: axis.EveryNth(1),
          min_tick_gap: 5,
        )
        |> list.length
        |> expect.to_equal(expected: 3)
      }),
      it("EveryNth(2) shows every third tick", fn() {
        let ticks = make_ticks(9, 50.0)
        axis.filter_ticks_by_interval(
          ticks: ticks,
          interval: axis.EveryNth(2),
          min_tick_gap: 5,
        )
        |> list.length
        |> expect.to_equal(expected: 3)
      }),
    ]),
    // ----- PreserveStart -----
    describe("PreserveStart", [
      it("keeps first tick and filters overlapping neighbours", fn() {
        // 10 ticks at 10px spacing, labels ~1 char = 7px wide, gap = 5
        // threshold = 5 + 7 = 12, spacing = 10 < 12 => some filtered
        let ticks = make_ticks(10, 10.0)
        let result =
          axis.filter_ticks_by_interval(
            ticks: ticks,
            interval: axis.PreserveStart,
            min_tick_gap: 5,
          )
        let first = get_first_tick(result)
        first.coordinate |> expect.to_equal(expected: 0.0)
        // Should filter out some ticks due to overlap
        { list.length(result) < 10 } |> expect.to_be_true
      }),
      it("shows all ticks when spacing exceeds threshold", fn() {
        // 5 ticks at 100px spacing, labels ~1 char = 7px, gap = 5
        // threshold = 12, spacing = 100 >> 12 => all shown
        let ticks = make_ticks(5, 100.0)
        axis.filter_ticks_by_interval(
          ticks: ticks,
          interval: axis.PreserveStart,
          min_tick_gap: 5,
        )
        |> list.length
        |> expect.to_equal(expected: 5)
      }),
    ]),
    // ----- PreserveEnd -----
    describe("PreserveEnd", [
      it("keeps last tick and filters overlapping neighbours", fn() {
        let ticks = make_ticks(10, 10.0)
        let result =
          axis.filter_ticks_by_interval(
            ticks: ticks,
            interval: axis.PreserveEnd,
            min_tick_gap: 5,
          )
        let last = get_last_tick(result)
        // Last tick should be at coordinate 90.0 (index 9 * 10.0)
        last.coordinate |> expect.to_equal(expected: 90.0)
        { list.length(result) < 10 } |> expect.to_be_true
      }),
    ]),
    // ----- PreserveStartEnd -----
    describe("PreserveStartEnd", [
      it("keeps both first and last ticks", fn() {
        let ticks = make_ticks(10, 10.0)
        let result =
          axis.filter_ticks_by_interval(
            ticks: ticks,
            interval: axis.PreserveStartEnd,
            min_tick_gap: 5,
          )
        let first = get_first_tick(result)
        let last = get_last_tick(result)
        first.coordinate |> expect.to_equal(expected: 0.0)
        last.coordinate |> expect.to_equal(expected: 90.0)
      }),
    ]),
    // ----- EquidistantPreserveStart -----
    describe("EquidistantPreserveStart", [
      it("finds optimal equidistant step from first tick", fn() {
        let ticks = make_ticks(10, 10.0)
        let result =
          axis.filter_ticks_by_interval(
            ticks: ticks,
            interval: axis.EquidistantPreserveStart,
            min_tick_gap: 5,
          )
        let first = get_first_tick(result)
        first.coordinate |> expect.to_equal(expected: 0.0)
        // With gap=5 and label width ~7, threshold=12, spacing=10
        // step=1 fails (10 < 12), step=2 gives spacing=20 >= 12 => pass
        list.length(result) |> expect.to_equal(expected: 5)
      }),
    ]),
    // ----- Y-axis (decreasing coordinates) -----
    describe("y-axis decreasing coordinates", [
      it("PreserveEnd keeps all y-axis ticks when well-spaced", fn() {
        // Y-axis ticks have decreasing coordinates (high pixel value at
        // bottom, low pixel value at top) because SVG y increases downward.
        let ticks = [
          scale.ScaleTick(value: "0", coordinate: 350.0),
          scale.ScaleTick(value: "2500", coordinate: 275.0),
          scale.ScaleTick(value: "5000", coordinate: 200.0),
          scale.ScaleTick(value: "7500", coordinate: 125.0),
          scale.ScaleTick(value: "10000", coordinate: 50.0),
        ]
        axis.filter_ticks_by_interval(
          ticks: ticks,
          interval: axis.PreserveEnd,
          min_tick_gap: 5,
        )
        |> list.length
        |> expect.to_equal(expected: 5)
      }),
      it("PreserveStart keeps all y-axis ticks when well-spaced", fn() {
        let ticks = [
          scale.ScaleTick(value: "0", coordinate: 350.0),
          scale.ScaleTick(value: "2500", coordinate: 275.0),
          scale.ScaleTick(value: "5000", coordinate: 200.0),
          scale.ScaleTick(value: "7500", coordinate: 125.0),
          scale.ScaleTick(value: "10000", coordinate: 50.0),
        ]
        axis.filter_ticks_by_interval(
          ticks: ticks,
          interval: axis.PreserveStart,
          min_tick_gap: 5,
        )
        |> list.length
        |> expect.to_equal(expected: 5)
      }),
      it("PreserveStartEnd keeps all y-axis ticks when well-spaced", fn() {
        let ticks = [
          scale.ScaleTick(value: "0", coordinate: 350.0),
          scale.ScaleTick(value: "2500", coordinate: 275.0),
          scale.ScaleTick(value: "5000", coordinate: 200.0),
          scale.ScaleTick(value: "7500", coordinate: 125.0),
          scale.ScaleTick(value: "10000", coordinate: 50.0),
        ]
        axis.filter_ticks_by_interval(
          ticks: ticks,
          interval: axis.PreserveStartEnd,
          min_tick_gap: 5,
        )
        |> list.length
        |> expect.to_equal(expected: 5)
      }),
      it(
        "EquidistantPreserveStart keeps all y-axis ticks when well-spaced",
        fn() {
          let ticks = [
            scale.ScaleTick(value: "0", coordinate: 350.0),
            scale.ScaleTick(value: "2500", coordinate: 275.0),
            scale.ScaleTick(value: "5000", coordinate: 200.0),
            scale.ScaleTick(value: "7500", coordinate: 125.0),
            scale.ScaleTick(value: "10000", coordinate: 50.0),
          ]
          axis.filter_ticks_by_interval(
            ticks: ticks,
            interval: axis.EquidistantPreserveStart,
            min_tick_gap: 5,
          )
          |> list.length
          |> expect.to_equal(expected: 5)
        },
      ),
    ]),
    // ----- Edge cases -----
    describe("edge cases", [
      it("single tick returns unchanged", fn() {
        let ticks = make_ticks(1, 50.0)
        axis.filter_ticks_by_interval(
          ticks: ticks,
          interval: axis.PreserveStart,
          min_tick_gap: 5,
        )
        |> list.length
        |> expect.to_equal(expected: 1)
      }),
      it("empty ticks returns empty", fn() {
        axis.filter_ticks_by_interval(
          ticks: [],
          interval: axis.PreserveEnd,
          min_tick_gap: 5,
        )
        |> list.length
        |> expect.to_equal(expected: 0)
      }),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// Test utility helpers
// ---------------------------------------------------------------------------

fn get_first_tick(ticks: List(scale.ScaleTick)) -> scale.ScaleTick {
  case ticks {
    [first, ..] -> first
    [] -> scale.ScaleTick(value: "", coordinate: -1.0)
  }
}

fn get_last_tick(ticks: List(scale.ScaleTick)) -> scale.ScaleTick {
  case ticks {
    [] -> scale.ScaleTick(value: "", coordinate: -1.0)
    [only] -> only
    [_, ..rest] -> get_last_tick(rest)
  }
}
