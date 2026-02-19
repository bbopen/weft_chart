//// Tests for SVG SMIL animation builders.

import gleam/float
import gleam/list
import gleam/option.{Some}
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/animation
import weft_chart/easing
import weft_chart/internal/layout

pub fn main() {
  startest.run(startest.default_config())
}

pub fn animation_tests() {
  describe("animation", [
    default_config_tests(),
    animate_attribute_tests(),
    animate_stroke_reveal_tests(),
    animate_clip_rect_tests(),
    animate_path_tests(),
    fill_mode_tests(),
    baked_steps_tests(),
    animate_new_values_tests(),
    animation_callback_tests(),
    animation_id_tests(),
  ])
}

fn default_config_tests() {
  describe("default configs", [
    it("bar_default has duration=400, active=True, easing=Ease", fn() {
      let config = animation.bar_default()
      config.duration |> expect.to_equal(expected: 400)
      config.active |> expect.to_be_true
      config.easing |> expect.to_equal(expected: easing.Ease)
    }),
    it("line_default has duration=1500", fn() {
      let config = animation.line_default()
      config.duration |> expect.to_equal(expected: 1500)
    }),
    it("pie_default has delay=400", fn() {
      let config = animation.pie_default()
      config.delay |> expect.to_equal(expected: 400)
    }),
    it("scatter_default has easing=Linear", fn() {
      let config = animation.scatter_default()
      config.easing |> expect.to_equal(expected: easing.Linear)
    }),
  ])
}

fn animate_attribute_tests() {
  describe("animate_attribute", [
    it("with CSS-native easing produces calcMode=spline", fn() {
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: animation.bar_default(),
        )
      let html = element.to_string(el)
      html |> string.contains("calcMode") |> expect.to_be_true
      html |> string.contains("spline") |> expect.to_be_true
      html |> string.contains("keySplines") |> expect.to_be_true
    }),
    it("with complex easing produces baked values and keyTimes", fn() {
      let config =
        animation.bar_default()
        |> animation.with_easing(easing: easing.BounceOut)
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: config,
        )
      let html = element.to_string(el)
      html |> string.contains("values") |> expect.to_be_true
      html |> string.contains("keyTimes") |> expect.to_be_true
      html |> string.contains("calcMode") |> expect.to_be_true
      html |> string.contains("linear") |> expect.to_be_true
    }),
    it("includes correct duration string", fn() {
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: animation.bar_default(),
        )
      let html = element.to_string(el)
      html |> string.contains("400ms") |> expect.to_be_true
    }),
    it("with delay produces begin attribute", fn() {
      let config =
        animation.bar_default()
        |> animation.with_delay(delay: 200)
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: config,
        )
      let html = element.to_string(el)
      html |> string.contains("begin") |> expect.to_be_true
      html |> string.contains("200ms") |> expect.to_be_true
    }),
    it("without delay omits begin attribute", fn() {
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: animation.bar_default(),
        )
      let html = element.to_string(el)
      html |> string.contains("begin") |> expect.to_be_false
    }),
  ])
}

fn animate_stroke_reveal_tests() {
  describe("animate_stroke_reveal", [
    it("produces stroke-dashoffset animation", fn() {
      let el =
        animation.animate_stroke_reveal(
          path_length: 500.0,
          config: animation.line_default(),
        )
      let html = element.to_string(el)
      html |> string.contains("stroke-dashoffset") |> expect.to_be_true
      html |> string.contains("500") |> expect.to_be_true
    }),
  ])
}

fn animate_clip_rect_tests() {
  describe("animate_clip_rect", [
    it("Horizontal produces width animation", fn() {
      let el =
        animation.animate_clip_rect(
          clip_id: "clip-1",
          x: 0.0,
          y: 0.0,
          width: 400.0,
          height: 300.0,
          config: animation.line_default(),
          direction: layout.Horizontal,
        )
      let html = element.to_string(el)
      html |> string.contains("clipPath") |> expect.to_be_true
      html |> string.contains("clip-1") |> expect.to_be_true
      html |> string.contains("width") |> expect.to_be_true
    }),
    it("Vertical produces height animation", fn() {
      let el =
        animation.animate_clip_rect(
          clip_id: "clip-2",
          x: 0.0,
          y: 0.0,
          width: 400.0,
          height: 300.0,
          config: animation.line_default(),
          direction: layout.Vertical,
        )
      let html = element.to_string(el)
      html |> string.contains("clipPath") |> expect.to_be_true
      html |> string.contains("height") |> expect.to_be_true
    }),
  ])
}

fn animate_path_tests() {
  describe("animate_path", [
    it("produces d-attribute animation with baked keyframes", fn() {
      let path_fn = fn(progress) {
        let x = 100.0 *. progress
        "M 0 0 L " <> { x |> float.to_string } <> " 0"
      }
      let el =
        animation.animate_path(
          path_at_progress: path_fn,
          config: animation.bar_default(),
          steps: 10,
        )
      let html = element.to_string(el)
      html |> string.contains("attributeName") |> expect.to_be_true
      html |> string.contains("values") |> expect.to_be_true
      html |> string.contains("keyTimes") |> expect.to_be_true
    }),
  ])
}

fn fill_mode_tests() {
  describe("FillMode", [
    it("Freeze produces fill=freeze", fn() {
      let config =
        animation.bar_default()
        |> animation.with_fill_mode(fill_mode: animation.Freeze)
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: config,
        )
      let html = element.to_string(el)
      html |> string.contains("freeze") |> expect.to_be_true
    }),
    it("Remove produces fill=remove", fn() {
      let config =
        animation.bar_default()
        |> animation.with_fill_mode(fill_mode: animation.Remove)
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: config,
        )
      let html = element.to_string(el)
      html |> string.contains("remove") |> expect.to_be_true
    }),
  ])
}

fn baked_steps_tests() {
  describe("60-step baking", [
    it("produces 61 keyframe values for complex easing", fn() {
      let config =
        animation.bar_default()
        |> animation.with_easing(easing: easing.BounceOut)
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: config,
        )
      let html = element.to_string(el)
      // Extract the values attribute content and count semicolons.
      // 61 keyframes joined by ";" means 60 semicolons in the values attr.
      let values_parts = case string.split(html, "values=\"") {
        [_, rest, ..] ->
          case string.split(rest, "\"") {
            [values_str, ..] -> values_str |> string.split(";") |> list.length
            _ -> 0
          }
        _ -> 0
      }
      values_parts |> expect.to_equal(expected: 61)
    }),
    it("produces 61 keyTimes entries for complex easing", fn() {
      let config =
        animation.bar_default()
        |> animation.with_easing(easing: easing.ElasticOut)
      let el =
        animation.animate_attribute(
          name: "height",
          from: 0.0,
          to: 200.0,
          config: config,
        )
      let html = element.to_string(el)
      let key_times_parts = case string.split(html, "keyTimes=\"") {
        [_, rest, ..] ->
          case string.split(rest, "\"") {
            [kt_str, ..] -> kt_str |> string.split(";") |> list.length
            _ -> 0
          }
        _ -> 0
      }
      key_times_parts |> expect.to_equal(expected: 61)
    }),
  ])
}

fn animate_new_values_tests() {
  describe("animate_new_values", [
    it("when True adds restart=always attribute", fn() {
      let config =
        animation.bar_default()
        |> animation.with_animate_new_values(animate_new_values: True)
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: config,
        )
      let html = element.to_string(el)
      html |> string.contains("restart") |> expect.to_be_true
      html |> string.contains("always") |> expect.to_be_true
    }),
    it("when False omits restart attribute", fn() {
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: animation.bar_default(),
        )
      let html = element.to_string(el)
      html |> string.contains("restart") |> expect.to_be_false
    }),
  ])
}

fn animation_callback_tests() {
  describe("animation callbacks", [
    it("on_animation_start generates onbegin attribute", fn() {
      let config =
        animation.bar_default()
        |> animation.with_on_animation_start(handler: Some("handleStart()"))
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: config,
        )
      let html = element.to_string(el)
      html |> string.contains("onbegin") |> expect.to_be_true
      html |> string.contains("handleStart()") |> expect.to_be_true
    }),
    it("on_animation_end generates onend attribute", fn() {
      let config =
        animation.bar_default()
        |> animation.with_on_animation_end(handler: Some("handleEnd()"))
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: config,
        )
      let html = element.to_string(el)
      html |> string.contains("onend") |> expect.to_be_true
      html |> string.contains("handleEnd()") |> expect.to_be_true
    }),
    it("None callbacks omit event attributes", fn() {
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: animation.bar_default(),
        )
      let html = element.to_string(el)
      html |> string.contains("onbegin") |> expect.to_be_false
      html |> string.contains("onend") |> expect.to_be_false
    }),
  ])
}

fn animation_id_tests() {
  describe("animation_id", [
    it("when Some adds id attribute to animate element", fn() {
      let config =
        animation.bar_default()
        |> animation.with_animation_id(animation_id: Some("bar-anim-1"))
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: config,
        )
      let html = element.to_string(el)
      html |> string.contains("id=\"bar-anim-1\"") |> expect.to_be_true
    }),
    it("when None omits id attribute", fn() {
      let el =
        animation.animate_attribute(
          name: "width",
          from: 0.0,
          to: 100.0,
          config: animation.bar_default(),
        )
      let html = element.to_string(el)
      // The default output should not contain an id attribute
      // (other attributes like attributeName exist but not a bare id)
      html |> string.contains("id=") |> expect.to_be_false
    }),
  ])
}
