//// Tests for active state, css_class, and animate_new_values in
//// Cartesian series (Bar, Line, Area, Scatter).

import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/internal/layout
import weft_chart/render
import weft_chart/scale
import weft_chart/series/area
import weft_chart/series/bar
import weft_chart/series/line
import weft_chart/series/scatter

pub fn main() {
  startest.run(startest.default_config())
}

// ---------------------------------------------------------------------------
// Bar active state tests
// ---------------------------------------------------------------------------

pub fn bar_active_state_tests() {
  describe("bar active state", [
    it("defaults active_bar to None", fn() {
      let config = bar.bar_config(data_key: "v")
      config.active_bar |> expect.to_equal(expected: None)
    }),
    it("defaults active_index to None", fn() {
      let config = bar.bar_config(data_key: "v")
      config.active_index |> expect.to_equal(expected: None)
    }),
    it("defaults css_class to empty string", fn() {
      let config = bar.bar_config(data_key: "v")
      config.css_class |> expect.to_equal(expected: "")
    }),
    it("bar_active_index sets the active index", fn() {
      let config =
        bar.bar_config(data_key: "v")
        |> bar.bar_active_index(index: 2)
      config.active_index |> expect.to_equal(expected: Some(2))
    }),
    it("bar_active_bar sets the active bar renderer", fn() {
      let renderer = fn(_props: render.BarShapeProps) { element.none() }
      let config =
        bar.bar_config(data_key: "v")
        |> bar.bar_active_bar(renderer: renderer)
      { config.active_bar != None } |> expect.to_be_true
    }),
    it("bar_css_class sets the CSS class", fn() {
      let config =
        bar.bar_config(data_key: "v")
        |> bar.bar_css_class(class: "my-bars")
      config.css_class |> expect.to_equal(expected: "my-bars")
    }),
    it("css_class appears in SVG output", fn() {
      let config =
        bar.bar_config(data_key: "v")
        |> bar.bar_css_class(class: "custom-bar")
      let data = [dict.from_list([#("v", 10.0)])]
      let x_scale =
        scale.band(
          categories: ["A"],
          range_start: 0.0,
          range_end: 400.0,
          padding_inner: 0.0,
          padding_outer: 0.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        bar.render_bars(
          config: config,
          data: data,
          categories: ["A"],
          x_scale: x_scale,
          y_scale: y_scale,
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html
      |> string.contains("custom-bar")
      |> expect.to_be_true
    }),
    it("active_index=Some(0) uses active_bar renderer", fn() {
      let renderer = fn(_props: render.BarShapeProps) {
        element.text("ACTIVE_BAR_MARKER")
      }
      let config =
        bar.bar_config(data_key: "v")
        |> bar.bar_active_index(index: 0)
        |> bar.bar_active_bar(renderer: renderer)
      let data = [dict.from_list([#("v", 10.0)])]
      let x_scale =
        scale.band(
          categories: ["A"],
          range_start: 0.0,
          range_end: 400.0,
          padding_inner: 0.0,
          padding_outer: 0.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 100.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        bar.render_bars(
          config: config,
          data: data,
          categories: ["A"],
          x_scale: x_scale,
          y_scale: y_scale,
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html
      |> string.contains("ACTIVE_BAR_MARKER")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Line active state tests
// ---------------------------------------------------------------------------

pub fn line_active_state_tests() {
  describe("line active state", [
    it("defaults active_dot to None", fn() {
      let config = line.line_config(data_key: "v")
      config.active_dot |> expect.to_equal(expected: None)
    }),
    it("defaults active_index to None", fn() {
      let config = line.line_config(data_key: "v")
      config.active_index |> expect.to_equal(expected: None)
    }),
    it("defaults css_class to empty string", fn() {
      let config = line.line_config(data_key: "v")
      config.css_class |> expect.to_equal(expected: "")
    }),
    it("defaults animate_new_values to True", fn() {
      let config = line.line_config(data_key: "v")
      config.animate_new_values |> expect.to_be_true
    }),
    it("line_active_index sets the active index", fn() {
      let config =
        line.line_config(data_key: "v")
        |> line.line_active_index(index: 3)
      config.active_index |> expect.to_equal(expected: Some(3))
    }),
    it("line_active_dot sets the active dot renderer", fn() {
      let renderer = fn(_props: render.DotProps) { element.none() }
      let config =
        line.line_config(data_key: "v")
        |> line.line_active_dot(renderer: renderer)
      { config.active_dot != None } |> expect.to_be_true
    }),
    it("line_css_class sets the CSS class", fn() {
      let config =
        line.line_config(data_key: "v")
        |> line.line_css_class(class: "my-line")
      config.css_class |> expect.to_equal(expected: "my-line")
    }),
    it("line_animate_new_values sets the flag", fn() {
      let config =
        line.line_config(data_key: "v")
        |> line.line_animate_new_values(animate: True)
      config.animate_new_values |> expect.to_be_true
    }),
    it("css_class appears in SVG output", fn() {
      let config =
        line.line_config(data_key: "v")
        |> line.line_css_class(class: "custom-line")
      let data = [
        dict.from_list([#("v", 10.0)]),
        dict.from_list([#("v", 20.0)]),
      ]
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
      let html =
        line.render_line(
          config: config,
          data: data,
          categories: ["A", "B"],
          x_scale: x_scale,
          y_scale: y_scale,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html
      |> string.contains("custom-line")
      |> expect.to_be_true
    }),
    it("active_index=Some(0) uses active_dot renderer", fn() {
      let renderer = fn(_props: render.DotProps) {
        element.text("ACTIVE_DOT_MARKER")
      }
      let config =
        line.line_config(data_key: "v")
        |> line.line_active_index(index: 0)
        |> line.line_active_dot(renderer: renderer)
      let data = [
        dict.from_list([#("v", 10.0)]),
        dict.from_list([#("v", 20.0)]),
      ]
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
      let html =
        line.render_line(
          config: config,
          data: data,
          categories: ["A", "B"],
          x_scale: x_scale,
          y_scale: y_scale,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html
      |> string.contains("ACTIVE_DOT_MARKER")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Area active state tests
// ---------------------------------------------------------------------------

pub fn area_active_state_tests() {
  describe("area active state", [
    it("defaults active_dot to None", fn() {
      let config = area.area_config(data_key: "v")
      config.active_dot |> expect.to_equal(expected: None)
    }),
    it("defaults active_index to None", fn() {
      let config = area.area_config(data_key: "v")
      config.active_index |> expect.to_equal(expected: None)
    }),
    it("defaults css_class to empty string", fn() {
      let config = area.area_config(data_key: "v")
      config.css_class |> expect.to_equal(expected: "")
    }),
    it("defaults animate_new_values to True", fn() {
      let config = area.area_config(data_key: "v")
      config.animate_new_values |> expect.to_be_true
    }),
    it("area_active_index sets the active index", fn() {
      let config =
        area.area_config(data_key: "v")
        |> area.area_active_index(index: 1)
      config.active_index |> expect.to_equal(expected: Some(1))
    }),
    it("area_active_dot sets the active dot renderer", fn() {
      let renderer = fn(_props: render.DotProps) { element.none() }
      let config =
        area.area_config(data_key: "v")
        |> area.area_active_dot(renderer: renderer)
      { config.active_dot != None } |> expect.to_be_true
    }),
    it("area_css_class sets the CSS class", fn() {
      let config =
        area.area_config(data_key: "v")
        |> area.area_css_class(class: "my-area")
      config.css_class |> expect.to_equal(expected: "my-area")
    }),
    it("area_animate_new_values sets the flag", fn() {
      let config =
        area.area_config(data_key: "v")
        |> area.area_animate_new_values(animate: True)
      config.animate_new_values |> expect.to_be_true
    }),
    it("css_class appears in SVG output", fn() {
      let config =
        area.area_config(data_key: "v")
        |> area.area_css_class(class: "custom-area")
        |> area.dot(True)
      let data = [
        dict.from_list([#("v", 10.0)]),
        dict.from_list([#("v", 20.0)]),
      ]
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
      let html =
        area.render_area(
          config: config,
          data: data,
          categories: ["A", "B"],
          x_scale: x_scale,
          y_scale: y_scale,
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html
      |> string.contains("custom-area")
      |> expect.to_be_true
    }),
    it("active_index=Some(1) uses active_dot renderer", fn() {
      let renderer = fn(_props: render.DotProps) {
        element.text("ACTIVE_AREA_DOT")
      }
      let config =
        area.area_config(data_key: "v")
        |> area.area_active_index(index: 1)
        |> area.area_active_dot(renderer: renderer)
        |> area.dot(True)
      let data = [
        dict.from_list([#("v", 10.0)]),
        dict.from_list([#("v", 20.0)]),
      ]
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
      let html =
        area.render_area(
          config: config,
          data: data,
          categories: ["A", "B"],
          x_scale: x_scale,
          y_scale: y_scale,
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html
      |> string.contains("ACTIVE_AREA_DOT")
      |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Scatter active state tests
// ---------------------------------------------------------------------------

pub fn scatter_active_state_tests() {
  describe("scatter active state", [
    it("defaults active_shape to None", fn() {
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      config.active_shape |> expect.to_equal(expected: None)
    }),
    it("defaults active_index to None", fn() {
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      config.active_index |> expect.to_equal(expected: None)
    }),
    it("defaults css_class to empty string", fn() {
      let config = scatter.scatter_config(x_data_key: "x", y_data_key: "y")
      config.css_class |> expect.to_equal(expected: "")
    }),
    it("scatter_active_index sets the active index", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_active_index(index: 0)
      config.active_index |> expect.to_equal(expected: Some(0))
    }),
    it("scatter_active_shape sets the active shape renderer", fn() {
      let renderer = fn(_props: render.DotProps) { element.none() }
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_active_shape(renderer: renderer)
      { config.active_shape != None } |> expect.to_be_true
    }),
    it("scatter_css_class sets the CSS class", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_css_class(class: "my-scatter")
      config.css_class |> expect.to_equal(expected: "my-scatter")
    }),
    it("css_class appears in SVG output", fn() {
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_css_class(class: "custom-scatter")
      let data = [dict.from_list([#("x", 1.0), #("y", 2.0)])]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 10.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 10.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      html
      |> string.contains("custom-scatter")
      |> expect.to_be_true
    }),
    it("active_index=Some(0) uses active_shape renderer", fn() {
      let renderer = fn(_props: render.DotProps) {
        element.text("ACTIVE_SCATTER_MARKER")
      }
      let config =
        scatter.scatter_config(x_data_key: "x", y_data_key: "y")
        |> scatter.scatter_active_index(index: 0)
        |> scatter.scatter_active_shape(renderer: renderer)
      let data = [dict.from_list([#("x", 1.0), #("y", 2.0)])]
      let x_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 10.0,
          range_start: 0.0,
          range_end: 400.0,
        )
      let y_scale =
        scale.linear(
          domain_min: 0.0,
          domain_max: 10.0,
          range_start: 300.0,
          range_end: 0.0,
        )
      let html =
        scatter.render_scatter(
          config: config,
          data: data,
          x_scale: x_scale,
          y_scale: y_scale,
        )
        |> element.to_string
      html
      |> string.contains("ACTIVE_SCATTER_MARKER")
      |> expect.to_be_true
    }),
  ])
}
