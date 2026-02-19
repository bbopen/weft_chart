//// Tests for line/area series P1 parity improvements.
////
//// Covers Monotone/Bump curve aliases, animate_new_values and clip_dot
//// defaults, and Area custom_dot field.

import gleam/option.{None}
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/curve
import weft_chart/render
import weft_chart/series/area
import weft_chart/series/common
import weft_chart/series/line

pub fn monotone_curve_alias_tests() {
  describe("Monotone curve alias", [
    it("produces same path as MonotoneX", fn() {
      let points = [#(0.0, 0.0), #(1.0, 2.0), #(2.0, 1.0), #(3.0, 3.0)]
      let monotone_path = curve.path(curve_type: curve.Monotone, points: points)
      let monotone_x_path =
        curve.path(curve_type: curve.MonotoneX, points: points)
      monotone_path
      |> expect.to_equal(expected: monotone_x_path)
    }),
    it("produces same path as MonotoneX for two points", fn() {
      let points = [#(0.0, 0.0), #(5.0, 10.0)]
      let monotone_path = curve.path(curve_type: curve.Monotone, points: points)
      let monotone_x_path =
        curve.path(curve_type: curve.MonotoneX, points: points)
      monotone_path
      |> expect.to_equal(expected: monotone_x_path)
    }),
    it("produces empty string for empty points", fn() {
      curve.path(curve_type: curve.Monotone, points: [])
      |> expect.to_equal(expected: "")
    }),
  ])
}

pub fn bump_curve_alias_tests() {
  describe("Bump curve alias", [
    it("produces same path as BumpX", fn() {
      let points = [#(0.0, 0.0), #(1.0, 2.0), #(2.0, 1.0), #(3.0, 3.0)]
      let bump_path = curve.path(curve_type: curve.Bump, points: points)
      let bump_x_path = curve.path(curve_type: curve.BumpX, points: points)
      bump_path
      |> expect.to_equal(expected: bump_x_path)
    }),
    it("produces same path as BumpX for two points", fn() {
      let points = [#(0.0, 0.0), #(5.0, 10.0)]
      let bump_path = curve.path(curve_type: curve.Bump, points: points)
      let bump_x_path = curve.path(curve_type: curve.BumpX, points: points)
      bump_path
      |> expect.to_equal(expected: bump_x_path)
    }),
    it("produces empty string for empty points", fn() {
      curve.path(curve_type: curve.Bump, points: [])
      |> expect.to_equal(expected: "")
    }),
  ])
}

pub fn line_animate_new_values_default_tests() {
  describe("line animate_new_values default", [
    it("defaults to True matching recharts", fn() {
      let config =
        line.line_config(data_key: "value", meta: common.series_meta())
      config.animate_new_values
      |> expect.to_be_true
    }),
    it("can be set to False via builder", fn() {
      let config =
        line.line_config(data_key: "value", meta: common.series_meta())
        |> line.line_animate_new_values(animate: False)
      config.animate_new_values
      |> expect.to_be_false
    }),
  ])
}

pub fn line_clip_dot_default_tests() {
  describe("line clip_dot default", [
    it("defaults to True matching recharts", fn() {
      let config =
        line.line_config(data_key: "value", meta: common.series_meta())
      config.clip_dot
      |> expect.to_be_true
    }),
    it("can be set to False via builder", fn() {
      let config =
        line.line_config(data_key: "value", meta: common.series_meta())
        |> line.line_clip_dot(clip: False)
      config.clip_dot
      |> expect.to_be_false
    }),
  ])
}

pub fn area_custom_dot_tests() {
  describe("area custom_dot", [
    it("defaults to None", fn() {
      let config =
        area.area_config(data_key: "value", meta: common.series_meta())
      config.custom_dot
      |> expect.to_equal(expected: None)
    }),
    it("sets renderer via builder", fn() {
      let config =
        area.area_config(data_key: "value", meta: common.series_meta())
        |> area.area_custom_dot(renderer: fn(_props: render.DotProps) {
          element.none()
        })
      config.custom_dot
      |> option.is_some
      |> expect.to_be_true
    }),
  ])
}

pub fn area_animate_new_values_default_tests() {
  describe("area animate_new_values default", [
    it("defaults to True matching recharts", fn() {
      let config =
        area.area_config(data_key: "value", meta: common.series_meta())
      config.animate_new_values
      |> expect.to_be_true
    }),
    it("can be set to False via builder", fn() {
      let config =
        area.area_config(data_key: "value", meta: common.series_meta())
        |> area.area_animate_new_values(animate: False)
      config.animate_new_values
      |> expect.to_be_false
    }),
  ])
}

pub fn area_clip_dot_default_tests() {
  describe("area clip_dot default", [
    it("defaults to True matching recharts", fn() {
      let config =
        area.area_config(data_key: "value", meta: common.series_meta())
      config.clip_dot
      |> expect.to_be_true
    }),
    it("can be set to False via builder", fn() {
      let config =
        area.area_config(data_key: "value", meta: common.series_meta())
        |> area.area_clip_dot(clip: False)
      config.clip_dot
      |> expect.to_be_false
    }),
  ])
}
