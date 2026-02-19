//// Tests for accessibility features.
////
//// Covers A11yConfig defaults, builder functions, disabled config,
//// keyboard navigation helpers, live_region rendering, brush keyboard
//// handling, and chart AccessibilityChild attribute rendering.

import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/a11y
import weft_chart/brush
import weft_chart/chart

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

fn simple_data() -> List(chart.DataPoint) {
  [
    chart.DataPoint(category: "A", values: dict.from_list([#("val", 10.0)])),
    chart.DataPoint(category: "B", values: dict.from_list([#("val", 20.0)])),
    chart.DataPoint(category: "C", values: dict.from_list([#("val", 30.0)])),
  ]
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

pub fn a11y_tests() {
  describe("a11y", [
    // ----- A11yConfig defaults -----
    describe("default", [
      it("creates enabled config with tab_index 0", fn() {
        let config = a11y.default()
        config.enabled |> expect.to_be_true
        config.tab_index |> expect.to_equal(expected: 0)
      }),
      it("sets role to application", fn() {
        let config = a11y.default()
        config.role |> expect.to_equal(expected: "application")
      }),
      it("has no description by default", fn() {
        let config = a11y.default()
        config.description |> expect.to_equal(expected: None)
      }),
      it("has no live_region_content by default", fn() {
        let config = a11y.default()
        config.live_region_content |> expect.to_equal(expected: None)
      }),
      it("has no on_focus handler by default", fn() {
        let config: a11y.A11yConfig(String) = a11y.default()
        config.on_focus |> expect.to_equal(expected: None)
      }),
      it("has no on_blur handler by default", fn() {
        let config: a11y.A11yConfig(String) = a11y.default()
        config.on_blur |> expect.to_equal(expected: None)
      }),
      it("has no on_key_down handler by default", fn() {
        let config: a11y.A11yConfig(String) = a11y.default()
        config.on_key_down |> expect.to_equal(expected: None)
      }),
    ]),
    // ----- disabled -----
    describe("disabled", [
      it("creates config with enabled=False", fn() {
        let config = a11y.disabled()
        config.enabled |> expect.to_be_false
      }),
      it("sets tab_index to -1", fn() {
        let config = a11y.disabled()
        config.tab_index |> expect.to_equal(expected: -1)
      }),
      it("sets role to img", fn() {
        let config = a11y.disabled()
        config.role |> expect.to_equal(expected: "img")
      }),
    ]),
    // ----- Builder functions -----
    describe("with_tab_index", [
      it("sets the tab index", fn() {
        let config =
          a11y.default()
          |> a11y.with_tab_index(config: _, tab_index: 5)
        config.tab_index |> expect.to_equal(expected: 5)
      }),
    ]),
    describe("with_role", [
      it("sets the role", fn() {
        let config =
          a11y.default()
          |> a11y.with_role(config: _, role: "region")
        config.role |> expect.to_equal(expected: "region")
      }),
    ]),
    describe("with_description", [
      it("sets the description to Some", fn() {
        let config =
          a11y.default()
          |> a11y.with_description(config: _, description: "Sales data chart")
        config.description
        |> expect.to_equal(expected: Some("Sales data chart"))
      }),
    ]),
    describe("with_live_region_content", [
      it("sets the live region content", fn() {
        let config =
          a11y.default()
          |> a11y.with_live_region_content(config: _, content: "Point A: 100")
        config.live_region_content
        |> expect.to_equal(expected: Some("Point A: 100"))
      }),
    ]),
    describe("with_on_focus", [
      it("sets the focus handler to Some", fn() {
        let config =
          a11y.default()
          |> a11y.with_on_focus(config: _, handler: fn() { "focused" })
        option.is_some(config.on_focus) |> expect.to_be_true
      }),
    ]),
    describe("with_on_blur", [
      it("sets the blur handler to Some", fn() {
        let config =
          a11y.default()
          |> a11y.with_on_blur(config: _, handler: fn() { "blurred" })
        option.is_some(config.on_blur) |> expect.to_be_true
      }),
    ]),
    describe("with_on_key_down", [
      it("sets the keydown handler to Some", fn() {
        let config =
          a11y.default()
          |> a11y.with_on_key_down(config: _, handler: fn(k) { k })
        option.is_some(config.on_key_down) |> expect.to_be_true
      }),
    ]),
    // ----- Keyboard navigation helpers -----
    describe("next_index", [
      it("advances by one", fn() {
        a11y.next_index(current: 2, total: 5)
        |> expect.to_equal(expected: 3)
      }),
      it("wraps around to zero", fn() {
        a11y.next_index(current: 4, total: 5)
        |> expect.to_equal(expected: 0)
      }),
      it("returns 0 for zero total", fn() {
        a11y.next_index(current: 0, total: 0)
        |> expect.to_equal(expected: 0)
      }),
      it("returns 0 for negative total", fn() {
        a11y.next_index(current: 3, total: -1)
        |> expect.to_equal(expected: 0)
      }),
    ]),
    describe("prev_index", [
      it("goes back by one", fn() {
        a11y.prev_index(current: 3, total: 5)
        |> expect.to_equal(expected: 2)
      }),
      it("wraps around to end", fn() {
        a11y.prev_index(current: 0, total: 5)
        |> expect.to_equal(expected: 4)
      }),
      it("returns 0 for zero total", fn() {
        a11y.prev_index(current: 0, total: 0)
        |> expect.to_equal(expected: 0)
      }),
    ]),
    describe("handle_arrow_key", [
      it("returns next for ArrowRight", fn() {
        a11y.handle_arrow_key(
          key: "ArrowRight",
          current_index: 2,
          total_items: 5,
        )
        |> expect.to_equal(expected: Some(3))
      }),
      it("returns next for ArrowDown", fn() {
        a11y.handle_arrow_key(
          key: "ArrowDown",
          current_index: 2,
          total_items: 5,
        )
        |> expect.to_equal(expected: Some(3))
      }),
      it("returns prev for ArrowLeft", fn() {
        a11y.handle_arrow_key(
          key: "ArrowLeft",
          current_index: 2,
          total_items: 5,
        )
        |> expect.to_equal(expected: Some(1))
      }),
      it("returns prev for ArrowUp", fn() {
        a11y.handle_arrow_key(key: "ArrowUp", current_index: 2, total_items: 5)
        |> expect.to_equal(expected: Some(1))
      }),
      it("returns None for unrecognized key", fn() {
        a11y.handle_arrow_key(key: "Enter", current_index: 2, total_items: 5)
        |> expect.to_equal(expected: None)
      }),
      it("wraps ArrowRight from last item", fn() {
        a11y.handle_arrow_key(
          key: "ArrowRight",
          current_index: 4,
          total_items: 5,
        )
        |> expect.to_equal(expected: Some(0))
      }),
      it("wraps ArrowLeft from first item", fn() {
        a11y.handle_arrow_key(
          key: "ArrowLeft",
          current_index: 0,
          total_items: 5,
        )
        |> expect.to_equal(expected: Some(4))
      }),
    ]),
    // ----- live_region -----
    describe("live_region", [
      it("renders foreignObject with aria-live div", fn() {
        let html =
          a11y.live_region(content: "Point B: 200")
          |> element.to_string
        html |> string.contains("foreignObject") |> expect.to_be_true
      }),
      it("includes aria-live=polite attribute", fn() {
        let html =
          a11y.live_region(content: "Test content")
          |> element.to_string
        html |> string.contains("aria-live") |> expect.to_be_true
      }),
      it("includes role=status attribute", fn() {
        let html =
          a11y.live_region(content: "Test content")
          |> element.to_string
        html |> string.contains("role=\"status\"") |> expect.to_be_true
      }),
      it("includes the content text", fn() {
        let html =
          a11y.live_region(content: "Sales: $500")
          |> element.to_string
        html |> string.contains("Sales: $500") |> expect.to_be_true
      }),
      it("includes visually-hidden style", fn() {
        let html =
          a11y.live_region(content: "hidden text")
          |> element.to_string
        html |> string.contains("clip:rect(0,0,0,0)") |> expect.to_be_true
      }),
    ]),
    // ----- Brush keyboard handling -----
    describe("handle_brush_key", [
      it("shifts range right with ArrowRight", fn() {
        brush.handle_brush_key(
          key: "ArrowRight",
          start: 2,
          end_: 5,
          data_length: 10,
        )
        |> expect.to_equal(expected: Some(#(3, 6)))
      }),
      it("shifts range left with ArrowLeft", fn() {
        brush.handle_brush_key(
          key: "ArrowLeft",
          start: 2,
          end_: 5,
          data_length: 10,
        )
        |> expect.to_equal(expected: Some(#(1, 4)))
      }),
      it("expands range with Shift+ArrowRight", fn() {
        brush.handle_brush_key(
          key: "Shift+ArrowRight",
          start: 2,
          end_: 5,
          data_length: 10,
        )
        |> expect.to_equal(expected: Some(#(2, 6)))
      }),
      it("shrinks range with Shift+ArrowLeft", fn() {
        brush.handle_brush_key(
          key: "Shift+ArrowLeft",
          start: 2,
          end_: 5,
          data_length: 10,
        )
        |> expect.to_equal(expected: Some(#(2, 4)))
      }),
      it("returns None at right boundary for ArrowRight", fn() {
        brush.handle_brush_key(
          key: "ArrowRight",
          start: 7,
          end_: 9,
          data_length: 10,
        )
        |> expect.to_equal(expected: None)
      }),
      it("returns None at left boundary for ArrowLeft", fn() {
        brush.handle_brush_key(
          key: "ArrowLeft",
          start: 0,
          end_: 3,
          data_length: 10,
        )
        |> expect.to_equal(expected: None)
      }),
      it("returns None for Shift+ArrowLeft when range is minimum", fn() {
        brush.handle_brush_key(
          key: "Shift+ArrowLeft",
          start: 2,
          end_: 3,
          data_length: 10,
        )
        |> expect.to_equal(expected: None)
      }),
      it("returns None at right boundary for Shift+ArrowRight", fn() {
        brush.handle_brush_key(
          key: "Shift+ArrowRight",
          start: 2,
          end_: 9,
          data_length: 10,
        )
        |> expect.to_equal(expected: None)
      }),
      it("returns None for unrecognized key", fn() {
        brush.handle_brush_key(key: "Enter", start: 2, end_: 5, data_length: 10)
        |> expect.to_equal(expected: None)
      }),
    ]),
    // ----- Chart with AccessibilityChild -----
    describe("chart accessibility integration", [
      it("renders tabindex attribute when a11y is enabled", fn() {
        let html =
          chart.line_chart(
            data: simple_data(),
            width: 400,
            height: 300,
            children: [
              chart.accessibility(config: a11y.default()),
            ],
          )
          |> element.to_string
        html |> string.contains("tabindex=\"0\"") |> expect.to_be_true
      }),
      it("renders role=application when a11y is enabled", fn() {
        let html =
          chart.line_chart(
            data: simple_data(),
            width: 400,
            height: 300,
            children: [
              chart.accessibility(config: a11y.default()),
            ],
          )
          |> element.to_string
        html |> string.contains("role=\"application\"") |> expect.to_be_true
      }),
      it("renders aria-label when description is set", fn() {
        let config =
          a11y.default()
          |> a11y.with_description(config: _, description: "Revenue chart")
        let html =
          chart.line_chart(
            data: simple_data(),
            width: 400,
            height: 300,
            children: [
              chart.accessibility(config: config),
            ],
          )
          |> element.to_string
        html
        |> string.contains("aria-label=\"Revenue chart\"")
        |> expect.to_be_true
      }),
      it("renders custom tab_index", fn() {
        let config =
          a11y.default()
          |> a11y.with_tab_index(config: _, tab_index: 3)
        let html =
          chart.line_chart(
            data: simple_data(),
            width: 400,
            height: 300,
            children: [
              chart.accessibility(config: config),
            ],
          )
          |> element.to_string
        html |> string.contains("tabindex=\"3\"") |> expect.to_be_true
      }),
      it("overrides RoleChild with a11y role", fn() {
        let html =
          chart.line_chart(
            data: simple_data(),
            width: 400,
            height: 300,
            children: [
              chart.role(role: "img"),
              chart.accessibility(
                config: a11y.default()
                |> a11y.with_role(config: _, role: "region"),
              ),
            ],
          )
          |> element.to_string
        html |> string.contains("role=\"region\"") |> expect.to_be_true
      }),
      it("does not render a11y attrs when disabled", fn() {
        let html =
          chart.line_chart(
            data: simple_data(),
            width: 400,
            height: 300,
            children: [
              chart.accessibility(config: a11y.disabled()),
            ],
          )
          |> element.to_string
        // Should have default role "img" (not "application")
        html |> string.contains("role=\"img\"") |> expect.to_be_true
        // Should not have tabindex
        html |> string.contains("tabindex") |> expect.to_be_false
      }),
      it("renders live region when content is set", fn() {
        let config =
          a11y.default()
          |> a11y.with_live_region_content(
            config: _,
            content: "Active: Point A",
          )
        let html =
          chart.line_chart(
            data: simple_data(),
            width: 400,
            height: 300,
            children: [
              chart.accessibility(config: config),
            ],
          )
          |> element.to_string
        html |> string.contains("foreignObject") |> expect.to_be_true
        html |> string.contains("Active: Point A") |> expect.to_be_true
      }),
      it("does not render live region when content is None", fn() {
        let html =
          chart.line_chart(
            data: simple_data(),
            width: 400,
            height: 300,
            children: [
              chart.accessibility(config: a11y.default()),
            ],
          )
          |> element.to_string
        html |> string.contains("foreignObject") |> expect.to_be_false
      }),
    ]),
  ])
}
