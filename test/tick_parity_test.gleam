//// Tests for tick generation parity with recharts-scale.
////
//// Each test verifies that weft_chart/scale.nice_ticks produces the same
//// tick values as the corresponding recharts-scale getNiceTickValues call.
//// Test vectors are generated from recharts-scale v0.4.5.

import gleam/list
import startest.{describe, it}
import startest/expect
import weft_chart/scale

pub fn tick_parity_tests() {
  describe("nice_ticks parity with recharts-scale", [
    describe("getNiceTickValues", [
      it("basic: [0, 7] count=5 -> [0, 2, 4, 6, 8]", fn() {
        scale.nice_ticks(0.0, 7.0, 5, True)
        |> expect.to_equal(expected: [0.0, 2.0, 4.0, 6.0, 8.0])
      }),
      it("round_numbers: [0, 100] count=5 -> [0, 25, 50, 75, 100]", fn() {
        scale.nice_ticks(0.0, 100.0, 5, True)
        |> expect.to_equal(expected: [0.0, 25.0, 50.0, 75.0, 100.0])
      }),
      it("zero_crossing: [-10, 10] count=5 -> [-10, -5, 0, 5, 10]", fn() {
        scale.nice_ticks(-10.0, 10.0, 5, True)
        |> expect.to_equal(expected: [-10.0, -5.0, 0.0, 5.0, 10.0])
      }),
      it("single_value: [5, 5] count=5 -> [3, 4, 5, 6, 7]", fn() {
        scale.nice_ticks(5.0, 5.0, 5, True)
        |> expect.to_equal(expected: [3.0, 4.0, 5.0, 6.0, 7.0])
      }),
      it("small_decimals: [0, 0.7] count=5 -> [0, 0.2, 0.4, 0.6, 0.8]", fn() {
        scale.nice_ticks(0.0, 0.7, 5, True)
        |> expect.to_equal(expected: [0.0, 0.2, 0.4, 0.6000000000000001, 0.8])
      }),
      it(
        "integer_only: [0, 7] count=5 allowDecimals=false -> [0, 2, 4, 6, 8]",
        fn() {
          scale.nice_ticks(0.0, 7.0, 5, False)
          |> expect.to_equal(expected: [0.0, 2.0, 4.0, 6.0, 8.0])
        },
      ),
      it(
        "large_range: [100, 10000] count=5 -> [0, 2500, 5000, 7500, 10000]",
        fn() {
          scale.nice_ticks(100.0, 10_000.0, 5, True)
          |> expect.to_equal(expected: [0.0, 2500.0, 5000.0, 7500.0, 10_000.0])
        },
      ),
      it("few_ticks: [0, 1] count=3 -> [0, 0.5, 1]", fn() {
        scale.nice_ticks(0.0, 1.0, 3, True)
        |> expect.to_equal(expected: [0.0, 0.5, 1.0])
      }),
      it("zero_domain: [0, 0] count=5 -> [0, 1, 2, 3, 4]", fn() {
        scale.nice_ticks(0.0, 0.0, 5, True)
        |> expect.to_equal(expected: [0.0, 1.0, 2.0, 3.0, 4.0])
      }),
      it("all_negative: [-100, -10] count=5 -> [-100, -75, -50, -25, 0]", fn() {
        scale.nice_ticks(-100.0, -10.0, 5, True)
        |> expect.to_equal(expected: [-100.0, -75.0, -50.0, -25.0, 0.0])
      }),
      it("non_round: [3, 97] count=5 -> [0, 25, 50, 75, 100]", fn() {
        scale.nice_ticks(3.0, 97.0, 5, True)
        |> expect.to_equal(expected: [0.0, 25.0, 50.0, 75.0, 100.0])
      }),
      it(
        "y_axis_typical: [0, 9200] count=5 -> [0, 2500, 5000, 7500, 10000]",
        fn() {
          scale.nice_ticks(0.0, 9200.0, 5, True)
          |> expect.to_equal(expected: [0.0, 2500.0, 5000.0, 7500.0, 10_000.0])
        },
      ),
      it("user_data_range: [1260, 2760] count=5 -> covers data range", fn() {
        let ticks = scale.nice_ticks(1260.0, 2760.0, 5, True)
        let first = case ticks {
          [f, ..] -> f
          [] -> 99_999.0
        }
        let last = case list.last(ticks) {
          Ok(l) -> l
          Error(_) -> -1.0
        }
        // First tick should be at or below data min
        { first <=. 1260.0 } |> expect.to_be_true
        // Last tick should be at or above data max
        { last >=. 2760.0 } |> expect.to_be_true
        // Should produce exactly 5 ticks
        list.length(ticks) |> expect.to_equal(expected: 5)
      }),
    ]),
    describe("getTickValuesFixedDomain", [
      it("fixed_basic: [0, 100] count=5 -> [0, 25, 50, 75, 100]", fn() {
        scale.nice_ticks_fixed(0.0, 100.0, 5, True)
        |> expect.to_equal(expected: [0.0, 25.0, 50.0, 75.0, 100.0])
      }),
      it(
        "fixed_zero_crossing: [-50, 50] count=5 -> [-50, -25, 0, 25, 50]",
        fn() {
          scale.nice_ticks_fixed(-50.0, 50.0, 5, True)
          |> expect.to_equal(expected: [-50.0, -25.0, 0.0, 25.0, 50.0])
        },
      ),
      it(
        "fixed_integer_only: [0, 7] count=5 allowDecimals=false -> [0, 2, 4, 7]",
        fn() {
          scale.nice_ticks_fixed(0.0, 7.0, 5, False)
          |> expect.to_equal(expected: [0.0, 2.0, 4.0, 7.0])
        },
      ),
      it("fixed_mid_range: [10, 90] count=5 -> [10, 30, 50, 70, 90]", fn() {
        scale.nice_ticks_fixed(10.0, 90.0, 5, True)
        |> expect.to_equal(expected: [10.0, 30.0, 50.0, 70.0, 90.0])
      }),
    ]),
  ])
}
