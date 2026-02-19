//// Tests for render callback prop types.

import startest.{describe, it}
import startest/expect
import weft_chart/render

pub fn main() {
  startest.run(startest.default_config())
}

pub fn tick_props_tests() {
  describe("TickProps", [
    it("constructs with all fields accessible", fn() {
      let props =
        render.TickProps(
          x: 100.0,
          y: 200.0,
          index: 2,
          value: "Jan",
          text_anchor: "middle",
          vertical_anchor: "end",
          fill: "#333",
          visible_ticks_count: 5,
        )
      props.x |> expect.to_equal(expected: 100.0)
      props.y |> expect.to_equal(expected: 200.0)
      props.index |> expect.to_equal(expected: 2)
      props.value |> expect.to_equal(expected: "Jan")
      props.text_anchor |> expect.to_equal(expected: "middle")
      props.visible_ticks_count |> expect.to_equal(expected: 5)
    }),
  ])
}

pub fn dot_props_tests() {
  describe("DotProps", [
    it("constructs with all fields accessible", fn() {
      let props =
        render.DotProps(
          cx: 150.0,
          cy: 75.0,
          r: 4.0,
          index: 1,
          value: 186.0,
          data_key: "revenue",
          fill: "#fff",
          stroke: "#8884d8",
        )
      props.cx |> expect.to_equal(expected: 150.0)
      props.value |> expect.to_equal(expected: 186.0)
      props.data_key |> expect.to_equal(expected: "revenue")
    }),
  ])
}

pub fn label_props_tests() {
  describe("LabelProps", [
    it("constructs with all fields accessible", fn() {
      let props =
        render.LabelProps(
          x: 50.0,
          y: 60.0,
          width: 30.0,
          height: 100.0,
          index: 0,
          value: "186",
          offset: 10.0,
          position: "top",
          fill: "currentColor",
        )
      props.x |> expect.to_equal(expected: 50.0)
      props.position |> expect.to_equal(expected: "top")
      props.value |> expect.to_equal(expected: "186")
    }),
  ])
}

pub fn pie_label_props_tests() {
  describe("PieLabelProps", [
    it(
      "constructs with all fields including percent, mid_angle, middle_radius",
      fn() {
        let props =
          render.PieLabelProps(
            x: 50.0,
            y: 60.0,
            width: 0.0,
            height: 0.0,
            index: 0,
            value: "A (25.0)",
            offset: 20.0,
            position: "right",
            fill: "currentColor",
            percent: 0.25,
            mid_angle: 45.0,
            middle_radius: 40.0,
          )
        props.percent |> expect.to_equal(expected: 0.25)
        props.mid_angle |> expect.to_equal(expected: 45.0)
        props.middle_radius |> expect.to_equal(expected: 40.0)
        props.value |> expect.to_equal(expected: "A (25.0)")
      },
    ),
  ])
}

pub fn label_line_props_tests() {
  describe("LabelLineProps", [
    it("constructs with all fields accessible", fn() {
      let props =
        render.LabelLineProps(
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 80.0,
          mid_angle: 45.0,
          start_x: 256.57,
          start_y: 143.43,
          end_x: 270.71,
          end_y: 129.29,
          index: 0,
          fill: "#2563eb",
          stroke: "#2563eb",
        )
      props.mid_angle |> expect.to_equal(expected: 45.0)
      props.outer_radius |> expect.to_equal(expected: 80.0)
      props.start_x |> expect.to_equal(expected: 256.57)
      props.stroke |> expect.to_equal(expected: "#2563eb")
    }),
  ])
}

pub fn bar_shape_props_tests() {
  describe("BarShapeProps", [
    it("constructs with all fields accessible", fn() {
      let props =
        render.BarShapeProps(
          x: 10.0,
          y: 50.0,
          width: 20.0,
          height: 150.0,
          index: 3,
          value: 305.0,
          data_key: "revenue",
          fill: "#8884d8",
          stroke: "",
          radius: 4.0,
        )
      props.width |> expect.to_equal(expected: 20.0)
      props.height |> expect.to_equal(expected: 150.0)
      props.value |> expect.to_equal(expected: 305.0)
      props.radius |> expect.to_equal(expected: 4.0)
    }),
  ])
}
