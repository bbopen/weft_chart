//// Tests for easing functions.

import gleam/float
import startest.{describe, it}
import startest/expect
import weft_chart/easing.{
  BackIn, BackInOut, BackOut, BounceIn, BounceInOut, BounceOut, CircleIn,
  CircleInOut, CircleOut, CubicBezier, CubicIn, CubicInOut, CubicOut,
  CustomEasing, Ease, EaseIn, EaseInOut, EaseOut, ElasticIn, ElasticInOut,
  ElasticOut, ExpIn, ExpInOut, ExpOut, Linear, QuadIn, QuadInOut, QuadOut, SinIn,
  SinInOut, SinOut, Spring,
}

pub fn main() {
  startest.run(startest.default_config())
}

fn approx_equal(actual: Float, expected: Float, tolerance: Float) -> Bool {
  float.absolute_value(actual -. expected) <. tolerance
}

pub fn linear_tests() {
  describe("apply/Linear", [
    it("returns 0.0 at t=0", fn() {
      easing.apply(easing: Linear, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("returns 0.5 at t=0.5", fn() {
      easing.apply(easing: Linear, t: 0.5)
      |> approx_equal(0.5, 0.001)
      |> expect.to_be_true
    }),
    it("returns 1.0 at t=1", fn() {
      easing.apply(easing: Linear, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
  ])
}

pub fn quad_tests() {
  describe("apply/Quad", [
    it("QuadIn returns 0.0 at t=0", fn() {
      easing.apply(easing: QuadIn, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("QuadIn returns 0.25 at t=0.5", fn() {
      easing.apply(easing: QuadIn, t: 0.5)
      |> approx_equal(0.25, 0.001)
      |> expect.to_be_true
    }),
    it("QuadIn returns 1.0 at t=1", fn() {
      easing.apply(easing: QuadIn, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("QuadOut returns 0.0 at t=0", fn() {
      easing.apply(easing: QuadOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("QuadOut returns 0.75 at t=0.5", fn() {
      easing.apply(easing: QuadOut, t: 0.5)
      |> approx_equal(0.75, 0.001)
      |> expect.to_be_true
    }),
    it("QuadOut returns 1.0 at t=1", fn() {
      easing.apply(easing: QuadOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("QuadInOut returns 0.0 at t=0", fn() {
      easing.apply(easing: QuadInOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("QuadInOut returns 0.5 at t=0.5", fn() {
      easing.apply(easing: QuadInOut, t: 0.5)
      |> approx_equal(0.5, 0.001)
      |> expect.to_be_true
    }),
    it("QuadInOut returns 1.0 at t=1", fn() {
      easing.apply(easing: QuadInOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
  ])
}

pub fn cubic_tests() {
  describe("apply/Cubic", [
    it("CubicIn returns 0.0 at t=0", fn() {
      easing.apply(easing: CubicIn, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("CubicIn returns 0.125 at t=0.5", fn() {
      easing.apply(easing: CubicIn, t: 0.5)
      |> approx_equal(0.125, 0.001)
      |> expect.to_be_true
    }),
    it("CubicIn returns 1.0 at t=1", fn() {
      easing.apply(easing: CubicIn, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("CubicOut returns 0.0 at t=0", fn() {
      easing.apply(easing: CubicOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("CubicOut returns 1.0 at t=1", fn() {
      easing.apply(easing: CubicOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("CubicInOut returns 0.0 at t=0", fn() {
      easing.apply(easing: CubicInOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("CubicInOut returns 0.5 at t=0.5", fn() {
      easing.apply(easing: CubicInOut, t: 0.5)
      |> approx_equal(0.5, 0.001)
      |> expect.to_be_true
    }),
    it("CubicInOut returns 1.0 at t=1", fn() {
      easing.apply(easing: CubicInOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
  ])
}

pub fn sin_tests() {
  describe("apply/Sin", [
    it("SinIn returns 0.0 at t=0", fn() {
      easing.apply(easing: SinIn, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("SinIn returns ~0.293 at t=0.5", fn() {
      easing.apply(easing: SinIn, t: 0.5)
      |> approx_equal(0.293, 0.01)
      |> expect.to_be_true
    }),
    it("SinIn returns 1.0 at t=1", fn() {
      easing.apply(easing: SinIn, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("SinOut returns 0.0 at t=0", fn() {
      easing.apply(easing: SinOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("SinOut returns 1.0 at t=1", fn() {
      easing.apply(easing: SinOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("SinInOut returns 0.0 at t=0", fn() {
      easing.apply(easing: SinInOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("SinInOut returns 0.5 at t=0.5", fn() {
      easing.apply(easing: SinInOut, t: 0.5)
      |> approx_equal(0.5, 0.001)
      |> expect.to_be_true
    }),
    it("SinInOut returns 1.0 at t=1", fn() {
      easing.apply(easing: SinInOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
  ])
}

pub fn exp_tests() {
  describe("apply/Exp", [
    it("ExpIn returns ~0.0 at t=0", fn() {
      easing.apply(easing: ExpIn, t: 0.0)
      |> approx_equal(0.0, 0.002)
      |> expect.to_be_true
    }),
    it("ExpIn returns 1.0 at t=1", fn() {
      easing.apply(easing: ExpIn, t: 1.0)
      |> approx_equal(1.0, 0.002)
      |> expect.to_be_true
    }),
    it("ExpOut returns 0.0 at t=0", fn() {
      easing.apply(easing: ExpOut, t: 0.0)
      |> approx_equal(0.0, 0.002)
      |> expect.to_be_true
    }),
    it("ExpOut returns 1.0 at t=1", fn() {
      easing.apply(easing: ExpOut, t: 1.0)
      |> approx_equal(1.0, 0.002)
      |> expect.to_be_true
    }),
    it("ExpInOut returns ~0.0 at t=0", fn() {
      easing.apply(easing: ExpInOut, t: 0.0)
      |> approx_equal(0.0, 0.002)
      |> expect.to_be_true
    }),
    it("ExpInOut returns 0.5 at t=0.5", fn() {
      easing.apply(easing: ExpInOut, t: 0.5)
      |> approx_equal(0.5, 0.002)
      |> expect.to_be_true
    }),
    it("ExpInOut returns 1.0 at t=1", fn() {
      easing.apply(easing: ExpInOut, t: 1.0)
      |> approx_equal(1.0, 0.002)
      |> expect.to_be_true
    }),
  ])
}

pub fn circle_tests() {
  describe("apply/Circle", [
    it("CircleIn returns 0.0 at t=0", fn() {
      easing.apply(easing: CircleIn, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("CircleIn returns 1.0 at t=1", fn() {
      easing.apply(easing: CircleIn, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("CircleOut returns 0.0 at t=0", fn() {
      easing.apply(easing: CircleOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("CircleOut returns 1.0 at t=1", fn() {
      easing.apply(easing: CircleOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("CircleInOut returns 0.0 at t=0", fn() {
      easing.apply(easing: CircleInOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("CircleInOut returns 0.5 at t=0.5", fn() {
      easing.apply(easing: CircleInOut, t: 0.5)
      |> approx_equal(0.5, 0.001)
      |> expect.to_be_true
    }),
    it("CircleInOut returns 1.0 at t=1", fn() {
      easing.apply(easing: CircleInOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
  ])
}

pub fn bounce_tests() {
  describe("apply/Bounce", [
    it("BounceOut returns 0.0 at t=0", fn() {
      easing.apply(easing: BounceOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("BounceOut returns ~0.765 at t=0.5", fn() {
      easing.apply(easing: BounceOut, t: 0.5)
      |> approx_equal(0.765, 0.02)
      |> expect.to_be_true
    }),
    it("BounceOut returns 1.0 at t=1", fn() {
      easing.apply(easing: BounceOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("BounceIn returns 0.0 at t=0", fn() {
      easing.apply(easing: BounceIn, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("BounceIn returns 1.0 at t=1", fn() {
      easing.apply(easing: BounceIn, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("BounceInOut returns 0.0 at t=0", fn() {
      easing.apply(easing: BounceInOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("BounceInOut returns 0.5 at t=0.5", fn() {
      easing.apply(easing: BounceInOut, t: 0.5)
      |> approx_equal(0.5, 0.001)
      |> expect.to_be_true
    }),
    it("BounceInOut returns 1.0 at t=1", fn() {
      easing.apply(easing: BounceInOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
  ])
}

pub fn back_tests() {
  describe("apply/Back", [
    it("BackIn returns 0.0 at t=0", fn() {
      easing.apply(easing: BackIn, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("BackIn overshoots below 0 at t=0.25", fn() {
      let val = easing.apply(easing: BackIn, t: 0.25)
      { val <. 0.0 } |> expect.to_be_true
    }),
    it("BackIn returns 1.0 at t=1", fn() {
      easing.apply(easing: BackIn, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("BackOut returns 0.0 at t=0", fn() {
      easing.apply(easing: BackOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("BackOut overshoots above 1 at t=0.75", fn() {
      let val = easing.apply(easing: BackOut, t: 0.75)
      { val >. 1.0 } |> expect.to_be_true
    }),
    it("BackOut returns 1.0 at t=1", fn() {
      easing.apply(easing: BackOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("BackInOut returns 0.0 at t=0", fn() {
      easing.apply(easing: BackInOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("BackInOut returns 1.0 at t=1", fn() {
      easing.apply(easing: BackInOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
  ])
}

pub fn elastic_tests() {
  describe("apply/Elastic", [
    it("ElasticIn returns ~0.0 at t=0", fn() {
      easing.apply(easing: ElasticIn, t: 0.0)
      |> approx_equal(0.0, 0.01)
      |> expect.to_be_true
    }),
    it("ElasticIn returns 1.0 at t=1", fn() {
      easing.apply(easing: ElasticIn, t: 1.0)
      |> approx_equal(1.0, 0.01)
      |> expect.to_be_true
    }),
    it("ElasticOut returns 0.0 at t=0", fn() {
      easing.apply(easing: ElasticOut, t: 0.0)
      |> approx_equal(0.0, 0.01)
      |> expect.to_be_true
    }),
    it("ElasticOut oscillates past 1.0", fn() {
      let val = easing.apply(easing: ElasticOut, t: 0.2)
      { val >. 1.0 } |> expect.to_be_true
    }),
    it("ElasticOut returns 1.0 at t=1", fn() {
      easing.apply(easing: ElasticOut, t: 1.0)
      |> approx_equal(1.0, 0.01)
      |> expect.to_be_true
    }),
    it("ElasticInOut returns ~0.0 at t=0", fn() {
      easing.apply(easing: ElasticInOut, t: 0.0)
      |> approx_equal(0.0, 0.01)
      |> expect.to_be_true
    }),
    it("ElasticInOut returns 1.0 at t=1", fn() {
      easing.apply(easing: ElasticInOut, t: 1.0)
      |> approx_equal(1.0, 0.01)
      |> expect.to_be_true
    }),
  ])
}

pub fn spring_tests() {
  describe("apply/Spring", [
    it("converges to 1.0 at t=1", fn() {
      easing.apply(easing: Spring(stiffness: 100.0, damping: 10.0), t: 1.0)
      |> approx_equal(1.0, 0.01)
      |> expect.to_be_true
    }),
    it("starts near 0.0 at t=0", fn() {
      easing.apply(easing: Spring(stiffness: 100.0, damping: 10.0), t: 0.0)
      |> approx_equal(0.0, 0.1)
      |> expect.to_be_true
    }),
  ])
}

pub fn cubic_bezier_tests() {
  describe("apply/CubicBezier", [
    it("matches Ease at t=0.5", fn() {
      let ease_val = easing.apply(easing: Ease, t: 0.5)
      let bezier_val =
        easing.apply(
          easing: CubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1.0),
          t: 0.5,
        )
      approx_equal(ease_val, bezier_val, 0.001) |> expect.to_be_true
    }),
    it("returns 0.0 at t=0", fn() {
      easing.apply(
        easing: CubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1.0),
        t: 0.0,
      )
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("returns 1.0 at t=1", fn() {
      easing.apply(
        easing: CubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1.0),
        t: 1.0,
      )
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
  ])
}

pub fn custom_easing_tests() {
  describe("apply/CustomEasing", [
    it("applies the user function", fn() {
      let square = fn(t: Float) -> Float { t *. t }
      easing.apply(easing: CustomEasing(apply: square), t: 0.5)
      |> approx_equal(0.25, 0.001)
      |> expect.to_be_true
    }),
  ])
}

pub fn css_native_tests() {
  describe("is_css_native", [
    it("returns True for Linear", fn() {
      easing.is_css_native(easing: Linear) |> expect.to_be_true
    }),
    it("returns True for Ease", fn() {
      easing.is_css_native(easing: Ease) |> expect.to_be_true
    }),
    it("returns True for EaseIn", fn() {
      easing.is_css_native(easing: EaseIn) |> expect.to_be_true
    }),
    it("returns True for EaseOut", fn() {
      easing.is_css_native(easing: EaseOut) |> expect.to_be_true
    }),
    it("returns True for EaseInOut", fn() {
      easing.is_css_native(easing: EaseInOut) |> expect.to_be_true
    }),
    it("returns False for QuadIn", fn() {
      easing.is_css_native(easing: QuadIn) |> expect.to_be_false
    }),
    it("returns False for BounceOut", fn() {
      easing.is_css_native(easing: BounceOut) |> expect.to_be_false
    }),
    it("returns False for ElasticIn", fn() {
      easing.is_css_native(easing: ElasticIn) |> expect.to_be_false
    }),
    it("returns False for Spring", fn() {
      easing.is_css_native(easing: Spring(stiffness: 100.0, damping: 10.0))
      |> expect.to_be_false
    }),
  ])
}

pub fn to_cubic_bezier_tests() {
  describe("to_cubic_bezier", [
    it("returns Ok for Linear", fn() {
      easing.to_cubic_bezier(easing: Linear)
      |> expect.to_equal(expected: Ok(#(0.0, 0.0, 1.0, 1.0)))
    }),
    it("returns Ok for Ease", fn() {
      easing.to_cubic_bezier(easing: Ease)
      |> expect.to_equal(expected: Ok(#(0.25, 0.1, 0.25, 1.0)))
    }),
    it("returns Ok for EaseIn", fn() {
      easing.to_cubic_bezier(easing: EaseIn)
      |> expect.to_equal(expected: Ok(#(0.42, 0.0, 1.0, 1.0)))
    }),
    it("returns Ok for EaseOut", fn() {
      easing.to_cubic_bezier(easing: EaseOut)
      |> expect.to_equal(expected: Ok(#(0.0, 0.0, 0.58, 1.0)))
    }),
    it("returns Ok for EaseInOut", fn() {
      easing.to_cubic_bezier(easing: EaseInOut)
      |> expect.to_equal(expected: Ok(#(0.42, 0.0, 0.58, 1.0)))
    }),
    it("returns Error for QuadIn", fn() {
      easing.to_cubic_bezier(easing: QuadIn)
      |> expect.to_be_error
    }),
    it("returns Error for BounceOut", fn() {
      easing.to_cubic_bezier(easing: BounceOut)
      |> expect.to_be_error
    }),
    it("returns Error for BackIn", fn() {
      easing.to_cubic_bezier(easing: BackIn)
      |> expect.to_be_error
    }),
  ])
}

pub fn css_ease_variants_tests() {
  describe("apply/CSS ease variants", [
    it("Ease returns 0.0 at t=0", fn() {
      easing.apply(easing: Ease, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("Ease returns 1.0 at t=1", fn() {
      easing.apply(easing: Ease, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("EaseIn returns 0.0 at t=0", fn() {
      easing.apply(easing: EaseIn, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("EaseIn returns 1.0 at t=1", fn() {
      easing.apply(easing: EaseIn, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("EaseOut returns 0.0 at t=0", fn() {
      easing.apply(easing: EaseOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("EaseOut returns 1.0 at t=1", fn() {
      easing.apply(easing: EaseOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
    it("EaseInOut returns 0.0 at t=0", fn() {
      easing.apply(easing: EaseInOut, t: 0.0)
      |> approx_equal(0.0, 0.001)
      |> expect.to_be_true
    }),
    it("EaseInOut returns 1.0 at t=1", fn() {
      easing.apply(easing: EaseInOut, t: 1.0)
      |> approx_equal(1.0, 0.001)
      |> expect.to_be_true
    }),
  ])
}

pub fn easing_cubic_bezier_values_tests() {
  describe("easing cubic-bezier control points", [
    it("EaseOut uses cubic-bezier(0.0, 0.0, 0.58, 1.0)", fn() {
      easing.to_cubic_bezier(easing: EaseOut)
      |> expect.to_equal(expected: Ok(#(0.0, 0.0, 0.58, 1.0)))
    }),
    it("EaseInOut uses cubic-bezier(0.42, 0.0, 0.58, 1.0)", fn() {
      easing.to_cubic_bezier(easing: EaseInOut)
      |> expect.to_equal(expected: Ok(#(0.42, 0.0, 0.58, 1.0)))
    }),
    it("EaseOut differs from EaseInOut", fn() {
      let ease_out = easing.to_cubic_bezier(easing: EaseOut)
      let ease_in_out = easing.to_cubic_bezier(easing: EaseInOut)
      { ease_out != ease_in_out } |> expect.to_be_true
    }),
  ])
}

pub fn spring_config_tests() {
  describe("spring configuration", [
    it("spring_default creates Spring with stiffness=170.0 damping=26.0", fn() {
      let spring = easing.spring_default()
      spring
      |> expect.to_equal(expected: Spring(stiffness: 170.0, damping: 26.0))
    }),
    it("with_stiffness modifies Spring stiffness", fn() {
      let spring =
        easing.spring_default()
        |> easing.with_stiffness(stiffness: 300.0)
      spring
      |> expect.to_equal(expected: Spring(stiffness: 300.0, damping: 26.0))
    }),
    it("with_damping modifies Spring damping", fn() {
      let spring =
        easing.spring_default()
        |> easing.with_damping(damping: 50.0)
      spring
      |> expect.to_equal(expected: Spring(stiffness: 170.0, damping: 50.0))
    }),
    it("with_stiffness is no-op on non-Spring easing", fn() {
      let result =
        Linear
        |> easing.with_stiffness(stiffness: 300.0)
      result |> expect.to_equal(expected: Linear)
    }),
    it("with_damping is no-op on non-Spring easing", fn() {
      let result =
        BounceOut
        |> easing.with_damping(damping: 50.0)
      result |> expect.to_equal(expected: BounceOut)
    }),
    it("different stiffness/damping produce different curves at t=0.2", fn() {
      let default_val = easing.apply(easing: easing.spring_default(), t: 0.2)
      let stiff_val =
        easing.apply(easing: Spring(stiffness: 300.0, damping: 10.0), t: 0.2)
      let soft_val =
        easing.apply(easing: Spring(stiffness: 50.0, damping: 30.0), t: 0.2)
      // All three configurations should yield different progress values
      { not_approx_equal(default_val, stiff_val, 0.01) }
      |> expect.to_be_true
      { not_approx_equal(default_val, soft_val, 0.01) }
      |> expect.to_be_true
    }),
  ])
}

fn not_approx_equal(a: Float, b: Float, tolerance: Float) -> Bool {
  float.absolute_value(a -. b) >=. tolerance
}
