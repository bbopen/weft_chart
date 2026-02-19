//// Tests for reference elements, grid generators, polar axis props,
//// error bar css_class, and brush component.

import gleam/dict
import gleam/float
import gleam/int
import gleam/option.{None, Some}
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/brush
import weft_chart/error_bar
import weft_chart/grid
import weft_chart/internal/svg
import weft_chart/polar_axis
import weft_chart/reference
import weft_chart/scale

pub fn main() {
  startest.run(startest.default_config())
}

// ---------------------------------------------------------------------------
// ReferenceLine custom shape tests
// ---------------------------------------------------------------------------

pub fn reference_line_custom_shape_tests() {
  describe("reference_line_custom_shape", [
    it("default config has no custom shape", fn() {
      let config = reference.horizontal_line(value: 50.0)
      config.custom_shape |> expect.to_equal(expected: None)
    }),
    it("builder sets custom shape to Some", fn() {
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_custom_shape(renderer: fn(_props) { element.none() })
      let _ = config.custom_shape |> expect.to_be_some
      Nil
    }),
    it("custom shape renderer receives correct props", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_custom_shape(renderer: fn(props) {
          svg.el(
            tag: "line",
            attrs: [
              svg.attr("class", "custom-ref-line"),
              svg.attr("data-x1", float.to_string(props.x1)),
              svg.attr("data-stroke", props.stroke),
            ],
            children: [],
          )
        })
      let html =
        reference.render_reference_line(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html |> string.contains("custom-ref-line") |> expect.to_be_true
    }),
    it("custom shape replaces default line element", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        reference.horizontal_line(value: 50.0)
        |> reference.line_custom_shape(renderer: fn(_props) {
          svg.el(
            tag: "path",
            attrs: [svg.attr("class", "my-custom-line")],
            children: [],
          )
        })
      let html =
        reference.render_reference_line(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html |> string.contains("my-custom-line") |> expect.to_be_true
      // The wrapper group should still have the recharts class
      html
      |> string.contains("recharts-reference-line")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// ReferenceArea custom shape tests
// ---------------------------------------------------------------------------

pub fn reference_area_custom_shape_tests() {
  describe("reference_area_custom_shape", [
    it("default config has no custom shape", fn() {
      let config = reference.horizontal_area(value1: 20.0, value2: 80.0)
      config.custom_shape |> expect.to_equal(expected: None)
    }),
    it("builder sets custom shape to Some", fn() {
      let config =
        reference.horizontal_area(value1: 20.0, value2: 80.0)
        |> reference.area_custom_shape(renderer: fn(_props) { element.none() })
      let _ = config.custom_shape |> expect.to_be_some
      Nil
    }),
    it("custom shape renders in output", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        reference.horizontal_area(value1: 20.0, value2: 80.0)
        |> reference.area_custom_shape(renderer: fn(_props) {
          svg.el(
            tag: "ellipse",
            attrs: [svg.attr("class", "custom-ref-area")],
            children: [],
          )
        })
      let html =
        reference.render_reference_area(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html |> string.contains("custom-ref-area") |> expect.to_be_true
      html
      |> string.contains("recharts-reference-area")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// ReferenceDot custom shape tests
// ---------------------------------------------------------------------------

pub fn reference_dot_custom_shape_tests() {
  describe("reference_dot_custom_shape", [
    it("default config has no custom shape", fn() {
      let config = reference.reference_dot(x: 50.0, y: 50.0)
      config.custom_shape |> expect.to_equal(expected: None)
    }),
    it("builder sets custom shape to Some", fn() {
      let config =
        reference.reference_dot(x: 50.0, y: 50.0)
        |> reference.dot_custom_shape(renderer: fn(_props) { element.none() })
      let _ = config.custom_shape |> expect.to_be_some
      Nil
    }),
    it("custom shape renders in output", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        reference.reference_dot(x: 50.0, y: 50.0)
        |> reference.dot_if_overflow(overflow: reference.Visible)
        |> reference.dot_custom_shape(renderer: fn(_props) {
          svg.el(
            tag: "rect",
            attrs: [svg.attr("class", "custom-ref-dot")],
            children: [],
          )
        })
      let html =
        reference.render_reference_dot(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
          clip_path_id: "clip",
        )
        |> element.to_string
      html |> string.contains("custom-ref-dot") |> expect.to_be_true
      html
      |> string.contains("recharts-reference-dot")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// PolarAngleAxis label_angle tests
// ---------------------------------------------------------------------------

pub fn polar_angle_axis_label_angle_tests() {
  describe("polar_angle_axis_label_angle", [
    it("default config has no label angle", fn() {
      let config = polar_axis.angle_axis_config()
      config.label_angle |> expect.to_equal(expected: None)
    }),
    it("builder sets label angle", fn() {
      let config =
        polar_axis.angle_axis_config()
        |> polar_axis.angle_label_angle(angle: 45.0)
      config.label_angle |> expect.to_equal(expected: Some(45.0))
    }),
    it("label_angle produces rotation transform in SVG", fn() {
      let config =
        polar_axis.angle_axis_config()
        |> polar_axis.angle_label_angle(angle: 30.0)
      let html =
        polar_axis.render_angle_axis(
          config: config,
          cx: 200.0,
          cy: 200.0,
          radius: 150.0,
          categories: ["A", "B"],
          angles: [0.0, 180.0],
        )
        |> element.to_string
      html |> string.contains("rotate(30.0") |> expect.to_be_true
    }),
    it("no rotation when label_angle is None", fn() {
      let config = polar_axis.angle_axis_config()
      let html =
        polar_axis.render_angle_axis(
          config: config,
          cx: 200.0,
          cy: 200.0,
          radius: 150.0,
          categories: ["A"],
          angles: [0.0],
        )
        |> element.to_string
      html |> string.contains("rotate(") |> expect.to_be_false
    }),
  ])
}

// ---------------------------------------------------------------------------
// PolarAngleAxis scale_type tests
// ---------------------------------------------------------------------------

pub fn polar_angle_axis_scale_type_tests() {
  describe("polar_angle_axis_scale_type", [
    it("default config has no scale type", fn() {
      let config = polar_axis.angle_axis_config()
      config.scale_type |> expect.to_equal(expected: None)
    }),
    it("builder sets scale type to LinearScale", fn() {
      let config =
        polar_axis.angle_axis_config()
        |> polar_axis.angle_scale_type(scale_type: polar_axis.LinearScale)
      config.scale_type
      |> expect.to_equal(expected: Some(polar_axis.LinearScale))
    }),
    it("builder sets scale type to BandScale", fn() {
      let config =
        polar_axis.angle_axis_config()
        |> polar_axis.angle_scale_type(scale_type: polar_axis.BandScale)
      config.scale_type
      |> expect.to_equal(expected: Some(polar_axis.BandScale))
    }),
    it("builder sets scale type to AutoScale", fn() {
      let config =
        polar_axis.angle_axis_config()
        |> polar_axis.angle_scale_type(scale_type: polar_axis.AutoScale)
      config.scale_type
      |> expect.to_equal(expected: Some(polar_axis.AutoScale))
    }),
  ])
}

// ---------------------------------------------------------------------------
// CartesianGrid custom generator tests
// ---------------------------------------------------------------------------

pub fn cartesian_grid_custom_generator_tests() {
  describe("cartesian_grid_custom_generator", [
    it("default config has no generators", fn() {
      let config = grid.cartesian_grid_config()
      config.horizontal_generator |> expect.to_equal(expected: None)
      config.vertical_generator |> expect.to_equal(expected: None)
    }),
    it("horizontal generator builder sets function", fn() {
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_horizontal_generator(generator: fn(_start, _end, _count) {
          [50.0, 100.0, 150.0]
        })
      let _ = config.horizontal_generator |> expect.to_be_some
      Nil
    }),
    it("vertical generator builder sets function", fn() {
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_vertical_generator(generator: fn(_start, _end, _count) {
          [100.0, 200.0, 300.0]
        })
      let _ = config.vertical_generator |> expect.to_be_some
      Nil
    }),
    it("horizontal generator positions used in rendering", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_horizontal_generator(generator: fn(_start, _end, _count) {
          [77.0, 177.0]
        })
      let html =
        grid.render_cartesian_grid(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
        )
        |> element.to_string
      // Custom positions 77 and 177 should appear in the SVG
      html |> string.contains("77") |> expect.to_be_true
      html |> string.contains("177") |> expect.to_be_true
    }),
    it("vertical generator positions used in rendering", fn() {
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let config =
        grid.cartesian_grid_config()
        |> grid.grid_vertical_generator(generator: fn(_start, _end, _count) {
          [111.0, 222.0]
        })
      let html =
        grid.render_cartesian_grid(
          config: config,
          x_scale: x_scale,
          y_scale: y_scale,
          plot_x: 0.0,
          plot_y: 0.0,
          plot_width: 400.0,
          plot_height: 300.0,
        )
        |> element.to_string
      html |> string.contains("111") |> expect.to_be_true
      html |> string.contains("222") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// ErrorBar css_class tests
// ---------------------------------------------------------------------------

pub fn error_bar_css_class_tests() {
  describe("error_bar_css_class", [
    it("default config has empty css_class", fn() {
      let config = error_bar.error_bar_config(data_key: "err")
      config.css_class |> expect.to_equal(expected: "")
    }),
    it("builder sets css_class", fn() {
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_css_class(css_class: "my-error-bars")
      config.css_class |> expect.to_equal(expected: "my-error-bars")
    }),
    it("css_class appears in rendered output", fn() {
      let x_scale =
        scale.point(
          categories: ["A", "B"],
          range_start: 0.0,
          range_end: 400.0,
          padding: 0.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let data = [
        dict.from_list([#("val", 50.0), #("err", 10.0)]),
        dict.from_list([#("val", 70.0), #("err", 5.0)]),
      ]
      let config =
        error_bar.error_bar_config(data_key: "err")
        |> error_bar.error_bar_css_class(css_class: "custom-error")
      let html =
        error_bar.render_error_bars(
          config: config,
          data: data,
          categories: ["A", "B"],
          x_scale: x_scale,
          y_scale: y_scale,
          series_data_key: "val",
        )
        |> element.to_string
      html |> string.contains("custom-error") |> expect.to_be_true
      html |> string.contains("recharts-errorBar") |> expect.to_be_true
    }),
    it("no extra class when css_class is empty", fn() {
      let config = error_bar.error_bar_config(data_key: "err")
      let x_scale =
        scale.point(
          categories: ["A"],
          range_start: 0.0,
          range_end: 400.0,
          padding: 0.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let data = [dict.from_list([#("val", 50.0), #("err", 10.0)])]
      let html =
        error_bar.render_error_bars(
          config: config,
          data: data,
          categories: ["A"],
          x_scale: x_scale,
          y_scale: y_scale,
          series_data_key: "val",
        )
        |> element.to_string
      // Should just have recharts-errorBar, not a trailing space
      html
      |> string.contains("recharts-errorBar\"")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Brush tests
// ---------------------------------------------------------------------------

pub fn brush_render_tests() {
  describe("brush_render", [
    it("renders expected SVG structure", fn() {
      let data = [
        dict.from_list([#("value", 10.0)]),
        dict.from_list([#("value", 30.0)]),
        dict.from_list([#("value", 20.0)]),
        dict.from_list([#("value", 40.0)]),
        dict.from_list([#("value", 25.0)]),
      ]
      let config =
        brush.new(start_index: 1, end_index: 3, data_key: "value", data: data)
      let html =
        brush.render(
          config: config,
          plot_x: 50.0,
          plot_width: 400.0,
          plot_bottom: 300.0,
        )
        |> element.to_string
      // Should contain the brush group
      html |> string.contains("recharts-brush") |> expect.to_be_true
      // Should contain traveller handles
      html
      |> string.contains("recharts-brush-traveller")
      |> expect.to_be_true
      // Should contain a path (mini preview area)
      html |> string.contains("<path") |> expect.to_be_true
    }),
    it("renders with correct dimensions", fn() {
      let data = [
        dict.from_list([#("v", 10.0)]),
        dict.from_list([#("v", 20.0)]),
        dict.from_list([#("v", 30.0)]),
      ]
      let config =
        brush.new(start_index: 0, end_index: 2, data_key: "v", data: data)
        |> brush.height(height: 50.0)
      let html =
        brush.render(
          config: config,
          plot_x: 100.0,
          plot_width: 300.0,
          plot_bottom: 400.0,
        )
        |> element.to_string
      // Background rect should use plot_bottom as y position
      html |> string.contains("400") |> expect.to_be_true
      // Height should be 50
      html |> string.contains("50") |> expect.to_be_true
    }),
    it("returns empty for empty data", fn() {
      let config =
        brush.new(start_index: 0, end_index: 0, data_key: "v", data: [])
      let html =
        brush.render(
          config: config,
          plot_x: 0.0,
          plot_width: 400.0,
          plot_bottom: 300.0,
        )
        |> element.to_string
      // element.none() renders as empty string
      html |> string.contains("recharts-brush") |> expect.to_be_false
    }),
    it("handles positioned at correct indices", fn() {
      let data = [
        dict.from_list([#("v", 10.0)]),
        dict.from_list([#("v", 20.0)]),
        dict.from_list([#("v", 30.0)]),
        dict.from_list([#("v", 40.0)]),
      ]
      let config =
        brush.new(start_index: 1, end_index: 2, data_key: "v", data: data)
      let html =
        brush.render(
          config: config,
          plot_x: 0.0,
          plot_width: 300.0,
          plot_bottom: 400.0,
        )
        |> element.to_string
      // With 4 data points and width 300, step = 100.0
      // start handle at index 1 = x 100, end handle at index 2 = x 200
      // Handle width is 5, so handle x = 100 - 2.5 = 97.5
      html |> string.contains("97.5") |> expect.to_be_true
    }),
  ])
}

pub fn brush_builder_tests() {
  describe("brush_builders", [
    it("new sets defaults", fn() {
      let data = [dict.from_list([#("v", 10.0)])]
      let config =
        brush.new(start_index: 0, end_index: 0, data_key: "v", data: data)
      config.height |> expect.to_equal(expected: 40.0)
      config.stroke |> expect.to_equal(expected: "#666")
      config.fill |> expect.to_equal(expected: "#fff")
    }),
    it("height builder changes height", fn() {
      let data = [dict.from_list([#("v", 10.0)])]
      let config =
        brush.new(start_index: 0, end_index: 0, data_key: "v", data: data)
        |> brush.height(height: 60.0)
      config.height |> expect.to_equal(expected: 60.0)
    }),
    it("stroke builder changes stroke", fn() {
      let data = [dict.from_list([#("v", 10.0)])]
      let config =
        brush.new(start_index: 0, end_index: 0, data_key: "v", data: data)
        |> brush.stroke(stroke: "#ff0000")
      config.stroke |> expect.to_equal(expected: "#ff0000")
    }),
    it("fill builder changes fill", fn() {
      let data = [dict.from_list([#("v", 10.0)])]
      let config =
        brush.new(start_index: 0, end_index: 0, data_key: "v", data: data)
        |> brush.fill(fill: "#00ff00")
      config.fill |> expect.to_equal(expected: "#00ff00")
    }),
  ])
}

// ---------------------------------------------------------------------------
// ReferenceLineProps / ReferenceAreaProps / ReferenceDotProps type tests
// ---------------------------------------------------------------------------

pub fn reference_props_type_tests() {
  describe("reference_props_types", [
    it("ReferenceLineProps constructs correctly", fn() {
      let props =
        reference.ReferenceLineProps(
          x1: 10.0,
          y1: 20.0,
          x2: 30.0,
          y2: 40.0,
          stroke: "#abc",
        )
      props.x1 |> expect.to_equal(expected: 10.0)
      props.stroke |> expect.to_equal(expected: "#abc")
    }),
    it("ReferenceAreaProps constructs correctly", fn() {
      let props =
        reference.ReferenceAreaProps(
          x: 5.0,
          y: 10.0,
          width: 100.0,
          height: 50.0,
          fill: "#def",
        )
      props.width |> expect.to_equal(expected: 100.0)
      props.fill |> expect.to_equal(expected: "#def")
    }),
    it("ReferenceDotProps constructs correctly", fn() {
      let props =
        reference.ReferenceDotProps(
          cx: 150.0,
          cy: 75.0,
          r: 8.0,
          fill: "#fff",
          stroke: "#000",
        )
      props.cx |> expect.to_equal(expected: 150.0)
      props.r |> expect.to_equal(expected: 8.0)
    }),
  ])
}

// ---------------------------------------------------------------------------
// PolarRadiusAxis verification tests
// ---------------------------------------------------------------------------

pub fn polar_radius_axis_tests() {
  describe("polar_radius_axis_props", [
    it("reversed builder sets reversed flag", fn() {
      let config =
        polar_axis.radius_axis_config()
        |> polar_axis.radius_reversed(reversed: True)
      config.reversed |> expect.to_equal(expected: True)
    }),
    it("domain builder sets custom domain", fn() {
      let config =
        polar_axis.radius_axis_config()
        |> polar_axis.radius_domain(min: 10.0, max: 90.0)
      config.domain_min |> expect.to_equal(expected: 10.0)
      config.domain_max |> expect.to_equal(expected: 90.0)
      config.has_custom_domain |> expect.to_equal(expected: True)
    }),
    it("angle builder sets angle", fn() {
      let config =
        polar_axis.radius_axis_config()
        |> polar_axis.radius_angle(angle: 45.0)
      config.angle |> expect.to_equal(expected: 45.0)
    }),
    it("tick_count builder sets count", fn() {
      let config =
        polar_axis.radius_axis_config()
        |> polar_axis.radius_tick_count(count: 10)
      config.tick_count |> expect.to_equal(expected: 10)
    }),
    it("orientation builder sets orientation", fn() {
      let config =
        polar_axis.radius_axis_config()
        |> polar_axis.radius_orientation(
          orientation: polar_axis.LeftOrientation,
        )
      config.orientation
      |> expect.to_equal(expected: polar_axis.LeftOrientation)
    }),
  ])
}

// ---------------------------------------------------------------------------
// PolarAxisType, tick_formatter, and new field tests
// ---------------------------------------------------------------------------

pub fn polar_axis_type_tests() {
  describe("polar_axis_type", [
    it("angle axis defaults to CategoryAxisType", fn() {
      let config = polar_axis.angle_axis_config()
      config.axis_type
      |> expect.to_equal(expected: polar_axis.CategoryAxisType)
    }),
    it("radius axis defaults to NumberAxisType", fn() {
      let config = polar_axis.radius_axis_config()
      config.axis_type
      |> expect.to_equal(expected: polar_axis.NumberAxisType)
    }),
    it("angle_axis_type builder sets type", fn() {
      let config =
        polar_axis.angle_axis_config()
        |> polar_axis.angle_axis_type(axis_type: polar_axis.NumberAxisType)
      config.axis_type
      |> expect.to_equal(expected: polar_axis.NumberAxisType)
    }),
    it("radius_axis_type builder sets type", fn() {
      let config =
        polar_axis.radius_axis_config()
        |> polar_axis.radius_axis_type(axis_type: polar_axis.CategoryAxisType)
      config.axis_type
      |> expect.to_equal(expected: polar_axis.CategoryAxisType)
    }),
  ])
}

pub fn polar_axis_allow_duplicated_category_tests() {
  describe("allow_duplicated_category", [
    it("angle axis defaults to True", fn() {
      let config = polar_axis.angle_axis_config()
      config.allow_duplicated_category |> expect.to_be_true
    }),
    it("radius axis defaults to True", fn() {
      let config = polar_axis.radius_axis_config()
      config.allow_duplicated_category |> expect.to_be_true
    }),
    it("angle builder sets allow_duplicated_category", fn() {
      let config =
        polar_axis.angle_axis_config()
        |> polar_axis.angle_allow_duplicated_category(allow: False)
      config.allow_duplicated_category |> expect.to_be_false
    }),
    it("radius builder sets allow_duplicated_category", fn() {
      let config =
        polar_axis.radius_axis_config()
        |> polar_axis.radius_allow_duplicated_category(allow: False)
      config.allow_duplicated_category |> expect.to_be_false
    }),
  ])
}

pub fn polar_radius_allow_data_overflow_tests() {
  describe("radius_allow_data_overflow", [
    it("defaults to False", fn() {
      let config = polar_axis.radius_axis_config()
      config.allow_data_overflow |> expect.to_be_false
    }),
    it("builder sets allow_data_overflow", fn() {
      let config =
        polar_axis.radius_axis_config()
        |> polar_axis.radius_allow_data_overflow(allow: True)
      config.allow_data_overflow |> expect.to_be_true
    }),
  ])
}

pub fn polar_angle_hide_tests() {
  describe("angle_hide", [
    it("defaults to False", fn() {
      let config = polar_axis.angle_axis_config()
      config.hide |> expect.to_be_false
    }),
    it("builder sets hide", fn() {
      let config =
        polar_axis.angle_axis_config()
        |> polar_axis.angle_hide(hide: True)
      config.hide |> expect.to_be_true
    }),
    it("hide True produces empty SVG", fn() {
      let config =
        polar_axis.angle_axis_config()
        |> polar_axis.angle_hide(hide: True)
      let html =
        polar_axis.render_angle_axis(
          config: config,
          cx: 200.0,
          cy: 200.0,
          radius: 150.0,
          categories: ["A", "B", "C"],
          angles: [90.0, 210.0, 330.0],
        )
        |> element.to_string
      // When hidden, render_angle_axis returns element.none() which is empty
      html |> string.length |> expect.to_equal(expected: 0)
    }),
  ])
}

pub fn polar_axis_tick_formatter_index_tests() {
  describe("tick_formatter_index", [
    it("angle tick_formatter receives index", fn() {
      let config =
        polar_axis.angle_axis_config()
        |> polar_axis.angle_tick_formatter(formatter: fn(val, idx) {
          val <> ":" <> int.to_string(idx)
        })
      let html =
        polar_axis.render_angle_axis(
          config: config,
          cx: 200.0,
          cy: 200.0,
          radius: 150.0,
          categories: ["A", "B"],
          angles: [90.0, 270.0],
        )
        |> element.to_string
      html |> string.contains("A:0") |> expect.to_be_true
      html |> string.contains("B:1") |> expect.to_be_true
    }),
    it("radius tick_formatter receives index", fn() {
      let config =
        polar_axis.radius_axis_config()
        |> polar_axis.radius_tick_formatter(formatter: fn(val, idx) {
          val <> "#" <> int.to_string(idx)
        })
      let html =
        polar_axis.render_radius_axis(
          config: config,
          cx: 200.0,
          cy: 200.0,
          inner_radius: 0.0,
          outer_radius: 150.0,
          domain_max: 100.0,
        )
        |> element.to_string
      // The 0-value tick is suppressed (at origin, matches recharts behavior).
      // Verify the first visible tick (original index 1) is rendered with its index.
      html |> string.contains("#1") |> expect.to_be_true
    }),
  ])
}
