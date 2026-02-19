//// Tests for extended scale types, DataKey, DomainBound, color palette,
//// and percentage parsing.

import gleam/dict
import gleam/float
import gleam/list
import startest.{describe, it}
import startest/expect
import weft_chart/color
import weft_chart/scale

pub fn power_scale_tests() {
  describe("power_scale", [
    describe("power_apply", [
      it("maps domain midpoint to range midpoint for exponent 2", fn() {
        let s =
          scale.power(
            domain_min: 0.0,
            domain_max: 10.0,
            range_start: 0.0,
            range_end: 100.0,
            exponent: 2.0,
          )
        // value 5: 5^2 = 25, domain pow range [0, 100]
        // ratio = 25/100 = 0.25, pixel = 0 + 0.25 * 100 = 25
        scale.power_apply(s, 5.0)
        |> expect.to_equal(expected: 25.0)
      }),
      it("maps domain_max to range_end", fn() {
        let s =
          scale.power(
            domain_min: 0.0,
            domain_max: 10.0,
            range_start: 0.0,
            range_end: 100.0,
            exponent: 2.0,
          )
        scale.power_apply(s, 10.0)
        |> expect.to_equal(expected: 100.0)
      }),
      it("maps domain_min to range_start", fn() {
        let s =
          scale.power(
            domain_min: 0.0,
            domain_max: 10.0,
            range_start: 0.0,
            range_end: 100.0,
            exponent: 2.0,
          )
        scale.power_apply(s, 0.0)
        |> expect.to_equal(expected: 0.0)
      }),
      it("handles exponent 1 like linear", fn() {
        let s =
          scale.power(
            domain_min: 0.0,
            domain_max: 100.0,
            range_start: 0.0,
            range_end: 200.0,
            exponent: 1.0,
          )
        scale.power_apply(s, 50.0)
        |> expect.to_equal(expected: 100.0)
      }),
      it("handles exponent 0.5 like sqrt", fn() {
        let s =
          scale.power(
            domain_min: 0.0,
            domain_max: 100.0,
            range_start: 0.0,
            range_end: 100.0,
            exponent: 0.5,
          )
        // value 25: 25^0.5 = 5, domain pow range [0, 10]
        // ratio = 5/10 = 0.5, pixel = 50
        scale.power_apply(s, 25.0)
        |> expect.to_equal(expected: 50.0)
      }),
      it("returns midpoint for degenerate domain", fn() {
        let s =
          scale.power(
            domain_min: 5.0,
            domain_max: 5.0,
            range_start: 0.0,
            range_end: 100.0,
            exponent: 2.0,
          )
        scale.power_apply(s, 5.0)
        |> expect.to_equal(expected: 50.0)
      }),
    ]),
    describe("power_invert", [
      it("round-trips apply/invert", fn() {
        let s =
          scale.power(
            domain_min: 0.0,
            domain_max: 10.0,
            range_start: 0.0,
            range_end: 100.0,
            exponent: 2.0,
          )
        let pixel = scale.power_apply(s, 5.0)
        let result = scale.power_invert(s, pixel)
        // Should round-trip back to approximately 5.0
        let diff = float.absolute_value(result -. 5.0)
        { diff <. 0.01 }
        |> expect.to_be_true
      }),
      it("inverts domain endpoints", fn() {
        let s =
          scale.power(
            domain_min: 0.0,
            domain_max: 10.0,
            range_start: 0.0,
            range_end: 100.0,
            exponent: 2.0,
          )
        scale.power_invert(s, 0.0)
        |> expect.to_equal(expected: 0.0)
      }),
    ]),
    describe("ticks", [
      it("generates nice ticks for power scale", fn() {
        let s =
          scale.power(
            domain_min: 0.0,
            domain_max: 100.0,
            range_start: 0.0,
            range_end: 500.0,
            exponent: 2.0,
          )
        let t = scale.ticks(s, 5, True)
        // Should produce 5 tick marks
        list.length(t)
        |> expect.to_equal(expected: 5)
      }),
    ]),
  ])
}

pub fn time_scale_tests() {
  describe("time_scale", [
    describe("time_apply", [
      it("maps domain to range linearly", fn() {
        let s =
          scale.time(
            domain_min: 0.0,
            domain_max: 86_400_000.0,
            range_start: 0.0,
            range_end: 1000.0,
          )
        // Midpoint of day
        scale.time_apply(s, 43_200_000.0)
        |> expect.to_equal(expected: 500.0)
      }),
      it("maps domain_min to range_start", fn() {
        let s =
          scale.time(
            domain_min: 1_000_000.0,
            domain_max: 2_000_000.0,
            range_start: 100.0,
            range_end: 200.0,
          )
        scale.time_apply(s, 1_000_000.0)
        |> expect.to_equal(expected: 100.0)
      }),
      it("maps domain_max to range_end", fn() {
        let s =
          scale.time(
            domain_min: 1_000_000.0,
            domain_max: 2_000_000.0,
            range_start: 100.0,
            range_end: 200.0,
          )
        scale.time_apply(s, 2_000_000.0)
        |> expect.to_equal(expected: 200.0)
      }),
      it("returns midpoint for degenerate domain", fn() {
        let s =
          scale.time(
            domain_min: 1000.0,
            domain_max: 1000.0,
            range_start: 0.0,
            range_end: 100.0,
          )
        scale.time_apply(s, 1000.0)
        |> expect.to_equal(expected: 50.0)
      }),
    ]),
    describe("time_invert", [
      it("round-trips apply/invert", fn() {
        let s =
          scale.time(
            domain_min: 0.0,
            domain_max: 86_400_000.0,
            range_start: 0.0,
            range_end: 1000.0,
          )
        let pixel = scale.time_apply(s, 43_200_000.0)
        scale.time_invert(s, pixel)
        |> expect.to_equal(expected: 43_200_000.0)
      }),
    ]),
    describe("time_ticks", [
      it("generates ticks for a one-day range", fn() {
        let t = scale.time_ticks(0.0, 86_400_000.0, 5)
        // Should produce multiple ticks spanning the day
        let len = list.length(t)
        { len >= 2 }
        |> expect.to_be_true
      }),
      it("generates single tick for zero span", fn() {
        scale.time_ticks(1000.0, 1000.0, 5)
        |> expect.to_equal(expected: [1000.0])
      }),
      it("generates ticks for a one-hour range", fn() {
        let t = scale.time_ticks(0.0, 3_600_000.0, 5)
        let len = list.length(t)
        { len >= 2 }
        |> expect.to_be_true
      }),
    ]),
    describe("ticks integration", [
      it("produces ScaleTick values via ticks function", fn() {
        let s =
          scale.time(
            domain_min: 0.0,
            domain_max: 86_400_000.0,
            range_start: 0.0,
            range_end: 1000.0,
          )
        let t = scale.ticks(s, 5, True)
        let len = list.length(t)
        { len >= 2 }
        |> expect.to_be_true
      }),
    ]),
  ])
}

pub fn ordinal_scale_tests() {
  describe("ordinal_scale", [
    describe("ordinal_apply", [
      it("returns mapped value for known category", fn() {
        let mapping =
          dict.from_list([
            #("small", 10.0),
            #("medium", 20.0),
            #("large", 30.0),
          ])
        let s = scale.ordinal(mapping: mapping, default_value: 0.0)
        scale.ordinal_apply(s, "medium")
        |> expect.to_equal(expected: 20.0)
      }),
      it("returns default for unknown category", fn() {
        let mapping = dict.from_list([#("a", 1.0)])
        let s = scale.ordinal(mapping: mapping, default_value: -1.0)
        scale.ordinal_apply(s, "unknown")
        |> expect.to_equal(expected: -1.0)
      }),
      it("returns default for empty mapping", fn() {
        let s = scale.ordinal(mapping: dict.new(), default_value: 42.0)
        scale.ordinal_apply(s, "anything")
        |> expect.to_equal(expected: 42.0)
      }),
    ]),
    describe("ticks", [
      it("produces one tick per mapped category", fn() {
        let mapping =
          dict.from_list([
            #("a", 10.0),
            #("b", 20.0),
            #("c", 30.0),
          ])
        let s = scale.ordinal(mapping: mapping, default_value: 0.0)
        let t = scale.ticks(s, 5, True)
        list.length(t)
        |> expect.to_equal(expected: 3)
      }),
    ]),
    describe("apply", [
      it("returns default_value via unified apply", fn() {
        let mapping = dict.from_list([#("x", 50.0)])
        let s = scale.ordinal(mapping: mapping, default_value: 99.0)
        scale.apply(s, 0.0)
        |> expect.to_equal(expected: 99.0)
      }),
    ]),
  ])
}

pub fn data_key_tests() {
  describe("data_key", [
    describe("resolve_data_key", [
      it("resolves StringKey from dictionary", fn() {
        let data = dict.from_list([#("value", 42.0), #("other", 10.0)])
        scale.resolve_data_key(key: scale.StringKey(key: "value"), data: data)
        |> expect.to_equal(expected: Ok(42.0))
      }),
      it("returns Error for missing StringKey", fn() {
        let data = dict.from_list([#("value", 42.0)])
        scale.resolve_data_key(key: scale.StringKey(key: "missing"), data: data)
        |> expect.to_be_error
      }),
      it("resolves FnKey by calling extractor", fn() {
        let data = dict.from_list([#("a", 10.0), #("b", 20.0)])
        let extractor = fn(d: dict.Dict(String, Float)) {
          case dict.get(d, "a"), dict.get(d, "b") {
            Ok(a), Ok(b) -> a +. b
            _, _ -> 0.0
          }
        }
        scale.resolve_data_key(
          key: scale.FnKey(extractor: extractor),
          data: data,
        )
        |> expect.to_equal(expected: Ok(30.0))
      }),
    ]),
  ])
}

pub fn domain_bound_tests() {
  describe("domain_bound", [
    describe("resolve_domain_bound", [
      it("resolves Fixed to the given value", fn() {
        scale.resolve_domain_bound(
          bound: scale.Fixed(value: 42.0),
          data_min: 0.0,
          data_max: 100.0,
        )
        |> expect.to_equal(expected: 42.0)
      }),
      it("resolves DataMin to data_min", fn() {
        scale.resolve_domain_bound(
          bound: scale.DataMin,
          data_min: 5.0,
          data_max: 95.0,
        )
        |> expect.to_equal(expected: 5.0)
      }),
      it("resolves DataMax to data_max", fn() {
        scale.resolve_domain_bound(
          bound: scale.DataMax,
          data_min: 5.0,
          data_max: 95.0,
        )
        |> expect.to_equal(expected: 95.0)
      }),
      it("resolves DataMinOffset to data_min minus offset", fn() {
        scale.resolve_domain_bound(
          bound: scale.DataMinOffset(offset: 10.0),
          data_min: 50.0,
          data_max: 100.0,
        )
        |> expect.to_equal(expected: 40.0)
      }),
      it("resolves DataMaxOffset to data_max plus offset", fn() {
        scale.resolve_domain_bound(
          bound: scale.DataMaxOffset(offset: 25.0),
          data_min: 0.0,
          data_max: 100.0,
        )
        |> expect.to_equal(expected: 125.0)
      }),
      it(
        "resolves DomainFn by applying transform to data_min and data_max",
        fn() {
          let transform = fn(dmin: Float, _dmax: Float) { dmin *. 2.0 }
          scale.resolve_domain_bound(
            bound: scale.DomainFn(transform: transform),
            data_min: 15.0,
            data_max: 100.0,
          )
          |> expect.to_equal(expected: 30.0)
        },
      ),
    ]),
  ])
}

pub fn color_palette_tests() {
  describe("color", [
    describe("recharts_palette", [
      it("has 26 colors", fn() {
        list.length(color.recharts_palette)
        |> expect.to_equal(expected: 26)
      }),
      it("first color is #0088FE", fn() {
        case color.recharts_palette {
          [first, ..] -> first |> expect.to_equal(expected: "#0088FE")
          [] -> expect.to_be_true(False)
        }
      }),
    ]),
    describe("cycle_color", [
      it("returns first color at index 0", fn() {
        color.cycle_color(palette: color.recharts_palette, index: 0)
        |> expect.to_equal(expected: "#0088FE")
      }),
      it("returns second color at index 1", fn() {
        color.cycle_color(palette: color.recharts_palette, index: 1)
        |> expect.to_equal(expected: "#00C49F")
      }),
      it("wraps around at palette length", fn() {
        color.cycle_color(palette: color.recharts_palette, index: 26)
        |> expect.to_equal(expected: "#0088FE")
      }),
      it("wraps around at twice palette length", fn() {
        color.cycle_color(palette: color.recharts_palette, index: 52)
        |> expect.to_equal(expected: "#0088FE")
      }),
      it("wraps correctly for index 27", fn() {
        color.cycle_color(palette: color.recharts_palette, index: 27)
        |> expect.to_equal(expected: "#00C49F")
      }),
      it("returns fallback for empty palette", fn() {
        color.cycle_color(palette: [], index: 0)
        |> expect.to_equal(expected: "#000000")
      }),
      it("works with custom palette", fn() {
        color.cycle_color(palette: ["red", "green", "blue"], index: 4)
        |> expect.to_equal(expected: "green")
      }),
    ]),
  ])
}

pub fn resolve_percent_tests() {
  describe("resolve_percent", [
    it("parses 50% of 200 as 100", fn() {
      scale.resolve_percent(value: "50%", total: 200.0)
      |> expect.to_equal(expected: Ok(100.0))
    }),
    it("parses 100% of 50 as 50", fn() {
      scale.resolve_percent(value: "100%", total: 50.0)
      |> expect.to_equal(expected: Ok(50.0))
    }),
    it("parses 0% of anything as 0", fn() {
      scale.resolve_percent(value: "0%", total: 1000.0)
      |> expect.to_equal(expected: Ok(0.0))
    }),
    it("parses 25.5% as a decimal percentage", fn() {
      scale.resolve_percent(value: "25.5%", total: 100.0)
      |> expect.to_equal(expected: Ok(25.5))
    }),
    it("returns InvalidPercentage for string without %", fn() {
      scale.resolve_percent(value: "50", total: 100.0)
      |> expect.to_equal(expected: Error(scale.InvalidPercentage(input: "50")))
    }),
    it("returns InvalidPercentage for empty string", fn() {
      scale.resolve_percent(value: "", total: 100.0)
      |> expect.to_equal(expected: Error(scale.InvalidPercentage(input: "")))
    }),
    it("returns PercentageParseError for non-numeric percentage", fn() {
      scale.resolve_percent(value: "abc%", total: 100.0)
      |> expect.to_equal(
        expected: Error(scale.PercentageParseError(input: "abc%")),
      )
    }),
    it("parses negative percentage", fn() {
      scale.resolve_percent(value: "-10%", total: 200.0)
      |> expect.to_equal(expected: Ok(-20.0))
    }),
  ])
}

pub fn reversed_category_scale_tests() {
  describe("reversed category scales", [
    it("band_apply keeps reversed category positions inside range", fn() {
      let s =
        scale.band(
          categories: ["A", "B", "C"],
          range_start: 300.0,
          range_end: 0.0,
          padding_inner: 0.0,
          padding_outer: 0.0,
        )
      let #(a_start, a_bw) = scale.band_apply(s, "A")
      let #(b_start, _b_bw) = scale.band_apply(s, "B")
      let #(c_start, _c_bw) = scale.band_apply(s, "C")
      { a_start <=. 300.0 && a_start >=. 0.0 } |> expect.to_be_true
      { b_start <=. 300.0 && b_start >=. 0.0 } |> expect.to_be_true
      { c_start <=. 300.0 && c_start >=. 0.0 } |> expect.to_be_true
      { a_start +. a_bw <=. 300.0 } |> expect.to_be_true
      // Reversed order: A should start to the right of C.
      { a_start >. c_start } |> expect.to_be_true
    }),
    it("point_apply returns descending coordinates for reversed range", fn() {
      let s =
        scale.point(
          categories: ["A", "B", "C"],
          range_start: 300.0,
          range_end: 0.0,
          padding: 0.0,
        )
      scale.point_apply(s, "A") |> expect.to_equal(expected: 300.0)
      scale.point_apply(s, "B") |> expect.to_equal(expected: 150.0)
      scale.point_apply(s, "C") |> expect.to_equal(expected: 0.0)
    }),
  ])
}
