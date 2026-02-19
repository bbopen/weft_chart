//// End-to-end integration tests for animation across chart series.
////
//// Renders full chart configurations with animation enabled and verifies
//// that SMIL animation elements appear correctly in the SVG output.

import gleam/dict
import gleam/list
import gleam/string
import lustre/element
import startest.{describe, it}
import startest/expect
import weft_chart/animation
import weft_chart/easing
import weft_chart/internal/layout
import weft_chart/scale
import weft_chart/series/bar
import weft_chart/series/line
import weft_chart/series/pie

pub fn main() {
  startest.run(startest.default_config())
}

pub fn animation_integration_tests() {
  describe("animation integration", [
    bar_chart_tests(),
    line_chart_tests(),
    pie_chart_tests(),
    easing_mode_tests(),
    timing_attribute_tests(),
    default_config_tests(),
    mixed_series_tests(),
  ])
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn sample_bar_data() -> List(dict.Dict(String, Float)) {
  [
    dict.from_list([#("value", 100.0)]),
    dict.from_list([#("value", 200.0)]),
    dict.from_list([#("value", 150.0)]),
  ]
}

fn sample_categories() -> List(String) {
  ["A", "B", "C"]
}

fn make_band_scale(categories: List(String)) -> scale.Scale {
  scale.band(
    categories: categories,
    range_start: 0.0,
    range_end: 400.0,
    padding_inner: 0.1,
    padding_outer: 0.1,
  )
}

fn make_y_scale() -> scale.Scale {
  scale.linear(
    domain_min: 0.0,
    domain_max: 300.0,
    range_start: 300.0,
    range_end: 0.0,
  )
}

fn make_point_scale(categories: List(String)) -> scale.Scale {
  scale.point(
    categories: categories,
    range_start: 0.0,
    range_end: 400.0,
    padding: 0.1,
  )
}

fn count_semicolons(s: String) -> Int {
  let parts = string.split(s, ";")
  list.length(parts) - 1
}

// ---------------------------------------------------------------------------
// Bar chart integration tests
// ---------------------------------------------------------------------------

fn bar_chart_tests() {
  describe("bar chart with animation", [
    it("produces animate elements in rendered output", fn() {
      let data = sample_bar_data()
      let categories = sample_categories()
      let config = bar.bar_config(data_key: "value")
      let html =
        bar.render_bars(
          config: config,
          data: data,
          categories: categories,
          x_scale: make_band_scale(categories),
          y_scale: make_y_scale(),
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("<animate") |> expect.to_be_true
    }),
    it("with animation disabled has zero animate elements", fn() {
      let data = sample_bar_data()
      let categories = sample_categories()
      let inactive_anim =
        animation.bar_default()
        |> animation.with_active(active: False)
      let config =
        bar.bar_config(data_key: "value")
        |> bar.bar_animation(anim: inactive_anim)
      let html =
        bar.render_bars(
          config: config,
          data: data,
          categories: categories,
          x_scale: make_band_scale(categories),
          y_scale: make_y_scale(),
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("<animate") |> expect.to_be_false
    }),
  ])
}

// ---------------------------------------------------------------------------
// Line chart integration tests
// ---------------------------------------------------------------------------

fn line_chart_tests() {
  describe("line chart with animation", [
    it("produces stroke-dashoffset animation in rendered output", fn() {
      let data = sample_bar_data()
      let categories = sample_categories()
      let config = line.line_config(data_key: "value")
      let html =
        line.render_line(
          config: config,
          data: data,
          categories: categories,
          x_scale: make_point_scale(categories),
          y_scale: make_y_scale(),
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("stroke-dashoffset") |> expect.to_be_true
      html |> string.contains("stroke-dasharray") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Pie chart integration tests
// ---------------------------------------------------------------------------

fn pie_chart_tests() {
  describe("pie chart with animation", [
    it("produces animate elements with baked path keyframes", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 200.0)]),
      ]
      let config = pie.pie_config(data_key: "value")
      let html =
        pie.render_pie(
          config: config,
          data: data,
          categories: ["A", "B"],
          width: 400.0,
          height: 400.0,
        )
        |> element.to_string
      html |> string.contains("animate") |> expect.to_be_true
    }),
    it("baked path keyframes contain at least 20 semicolons", fn() {
      let data = [
        dict.from_list([#("value", 100.0)]),
        dict.from_list([#("value", 200.0)]),
      ]
      let config = pie.pie_config(data_key: "value")
      let html =
        pie.render_pie(
          config: config,
          data: data,
          categories: ["A", "B"],
          width: 400.0,
          height: 400.0,
        )
        |> element.to_string
      // Baked with 30 steps produces 31 keyframes; combined keyTimes + values
      // attributes should yield many semicolons
      let semicolons = count_semicolons(html)
      { semicolons > 20 } |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Easing mode tests
// ---------------------------------------------------------------------------

fn easing_mode_tests() {
  describe("easing modes in rendered output", [
    it("CSS-native Ease easing produces calcMode spline", fn() {
      let config = bar.bar_config(data_key: "value")
      let data = [dict.from_list([#("value", 100.0)])]
      let categories = ["A"]
      let html =
        bar.render_bars(
          config: config,
          data: data,
          categories: categories,
          x_scale: make_band_scale(categories),
          y_scale: make_y_scale(),
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("calcMode") |> expect.to_be_true
      html |> string.contains("spline") |> expect.to_be_true
    }),
    it(
      "complex BounceOut easing produces baked keyTimes with many values",
      fn() {
        let bounce_anim =
          animation.bar_default()
          |> animation.with_easing(easing: easing.BounceOut)
        let config =
          bar.bar_config(data_key: "value")
          |> bar.bar_animation(anim: bounce_anim)
        let data = [dict.from_list([#("value", 100.0)])]
        let categories = ["A"]
        let html =
          bar.render_bars(
            config: config,
            data: data,
            categories: categories,
            x_scale: make_band_scale(categories),
            y_scale: make_y_scale(),
            baseline_y: 300.0,
            layout: layout.Horizontal,
          )
          |> element.to_string
        html |> string.contains("keyTimes") |> expect.to_be_true
        // Baked mode uses calcMode="linear" with many values
        html |> string.contains("values") |> expect.to_be_true
        // 30 steps -> 31 keyframes -> at least 30 semicolons in values attr
        let semicolons = count_semicolons(html)
        { semicolons > 20 } |> expect.to_be_true
      },
    ),
  ])
}

// ---------------------------------------------------------------------------
// Timing attribute tests
// ---------------------------------------------------------------------------

fn timing_attribute_tests() {
  describe("timing attributes in rendered output", [
    it("custom 500ms delay produces begin attribute with 500ms", fn() {
      let delayed_anim =
        animation.bar_default()
        |> animation.with_delay(delay: 500)
      let config =
        bar.bar_config(data_key: "value")
        |> bar.bar_animation(anim: delayed_anim)
      let data = [dict.from_list([#("value", 100.0)])]
      let categories = ["A"]
      let html =
        bar.render_bars(
          config: config,
          data: data,
          categories: categories,
          x_scale: make_band_scale(categories),
          y_scale: make_y_scale(),
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("begin") |> expect.to_be_true
      html |> string.contains("500ms") |> expect.to_be_true
    }),
    it("custom 2000ms duration produces dur attribute with 2000ms", fn() {
      let slow_anim =
        animation.bar_default()
        |> animation.with_duration(duration: 2000)
      let config =
        bar.bar_config(data_key: "value")
        |> bar.bar_animation(anim: slow_anim)
      let data = [dict.from_list([#("value", 100.0)])]
      let categories = ["A"]
      let html =
        bar.render_bars(
          config: config,
          data: data,
          categories: categories,
          x_scale: make_band_scale(categories),
          y_scale: make_y_scale(),
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("2000ms") |> expect.to_be_true
    }),
    it("default fill mode produces fill=freeze in output", fn() {
      let config = bar.bar_config(data_key: "value")
      let data = [dict.from_list([#("value", 100.0)])]
      let categories = ["A"]
      let html =
        bar.render_bars(
          config: config,
          data: data,
          categories: categories,
          x_scale: make_band_scale(categories),
          y_scale: make_y_scale(),
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      html |> string.contains("freeze") |> expect.to_be_true
    }),
  ])
}

// ---------------------------------------------------------------------------
// Default config validation tests
// ---------------------------------------------------------------------------

fn default_config_tests() {
  describe("default configs match recharts", [
    it("bar_default has duration=400", fn() {
      let config = animation.bar_default()
      config.duration |> expect.to_equal(expected: 400)
    }),
    it("line_default has duration=1500", fn() {
      let config = animation.line_default()
      config.duration |> expect.to_equal(expected: 1500)
    }),
    it("pie_default has delay=400", fn() {
      let config = animation.pie_default()
      config.delay |> expect.to_equal(expected: 400)
    }),
  ])
}

// ---------------------------------------------------------------------------
// Mixed series tests
// ---------------------------------------------------------------------------

fn mixed_series_tests() {
  describe("mixed chart types", [
    it("bar and line animation types coexist in combined output", fn() {
      let data = sample_bar_data()
      let categories = sample_categories()
      // Render bar series
      let bar_html =
        bar.render_bars(
          config: bar.bar_config(data_key: "value"),
          data: data,
          categories: categories,
          x_scale: make_band_scale(categories),
          y_scale: make_y_scale(),
          baseline_y: 300.0,
          layout: layout.Horizontal,
        )
        |> element.to_string
      // Render line series
      let line_html =
        line.render_line(
          config: line.line_config(data_key: "value"),
          data: data,
          categories: categories,
          x_scale: make_point_scale(categories),
          y_scale: make_y_scale(),
          layout: layout.Horizontal,
        )
        |> element.to_string
      // Combined output contains both animation techniques
      let combined = bar_html <> line_html
      // Bar uses <animate> for attribute animation
      combined |> string.contains("<animate") |> expect.to_be_true
      // Line uses stroke-dashoffset for reveal animation
      combined |> string.contains("stroke-dashoffset") |> expect.to_be_true
    }),
  ])
}
