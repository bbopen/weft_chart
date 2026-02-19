//// Tests for domain calculation parity with recharts.

import startest.{describe, it}
import startest/expect
import weft_chart/scale

pub fn main() {
  startest.run(startest.default_config())
}

pub fn auto_domain_single_value_tests() {
  describe("auto_domain single value", [
    it("returns degenerate domain for single non-zero value", fn() {
      let #(min, max) = scale.auto_domain([5.0, 5.0, 5.0])
      min |> expect.to_equal(expected: 5.0)
      max |> expect.to_equal(expected: 5.0)
    }),
    it("returns #(0.0, 1.0) when all values are zero", fn() {
      let #(min, max) = scale.auto_domain([0.0, 0.0, 0.0])
      min |> expect.to_equal(expected: 0.0)
      max |> expect.to_equal(expected: 1.0)
    }),
    it("returns #(0.0, 1.0) for empty list", fn() {
      let #(min, max) = scale.auto_domain([])
      min |> expect.to_equal(expected: 0.0)
      max |> expect.to_equal(expected: 1.0)
    }),
    it("returns data min and max for distinct values", fn() {
      let #(min, max) = scale.auto_domain([20.0, 50.0, 100.0])
      min |> expect.to_equal(expected: 20.0)
      max |> expect.to_equal(expected: 100.0)
    }),
    it("returns degenerate domain for single negative value", fn() {
      let #(min, max) = scale.auto_domain([-3.0, -3.0])
      min |> expect.to_equal(expected: -3.0)
      max |> expect.to_equal(expected: -3.0)
    }),
  ])
}

pub fn auto_domain_from_zero_tests() {
  describe("auto_domain_from_zero", [
    it("starts domain at zero for positive values", fn() {
      let #(min, _max) = scale.auto_domain_from_zero([20.0, 50.0, 100.0])
      min |> expect.to_equal(expected: 0.0)
    }),
    it("returns #(0.0, 1.0) for empty list", fn() {
      let #(min, max) = scale.auto_domain_from_zero([])
      min |> expect.to_equal(expected: 0.0)
      max |> expect.to_equal(expected: 1.0)
    }),
  ])
}
