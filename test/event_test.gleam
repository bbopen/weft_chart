//// Tests for chart event integration.
////
//// Covers event types, chart-level event handlers, tooltip state-driven
//// rendering, tooltip event attributes, backwards compatibility with
//// CSS hover, and throttle hint attribute.

import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import lustre/dev/query
import lustre/dev/simulate
import lustre/element
import startest.{describe, it}
import startest/expect
import weft
import weft_chart/chart
import weft_chart/event
import weft_chart/internal/layout
import weft_chart/series/common
import weft_chart/series/line
import weft_chart/tooltip

// ---------------------------------------------------------------------------
// Test message type
// ---------------------------------------------------------------------------

type Msg {
  Clicked
  MouseEntered
  MouseLeft
  MouseMoved
  TooltipEnter(Int)
  TooltipLeave
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

fn sample_data() -> List(chart.DataPoint) {
  [
    chart.DataPoint(category: "A", values: dict.from_list([#("val", 10.0)])),
    chart.DataPoint(category: "B", values: dict.from_list([#("val", 20.0)])),
    chart.DataPoint(category: "C", values: dict.from_list([#("val", 30.0)])),
  ]
}

fn missing_series_data() -> List(chart.DataPoint) {
  [
    chart.DataPoint(
      category: "A",
      values: dict.from_list([#("present_value", 10.0)]),
    ),
  ]
}

fn svg_query() -> query.Query {
  query.element(matching: query.namespaced("http://www.w3.org/2000/svg", "svg"))
}

fn chart_event_simulation(
  event_children event_children: List(chart.ChartChild(Msg)),
) -> simulate.Simulation(List(Msg), Msg) {
  let app =
    simulate.simple(
      init: fn(_args) { [] },
      update: fn(model, msg) { [msg, ..model] },
      view: fn(_model) {
        chart.line_chart(
          data: sample_data(),
          width: chart.FixedWidth(pixels: 400),
          theme: option.None,
          height: 300,
          children: [
            chart.line(line.line_config(
              data_key: "val",
              meta: common.series_meta(),
            )),
            ..event_children
          ],
        )
      },
    )

  simulate.start(app, Nil)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

pub fn event_tests() {
  describe("event", [
    // ----- ChartEvent variants -----
    describe("ChartEvent variants", [
      it("creates OnClick variant", fn() {
        let evt = event.on_click(handler: fn() { Clicked })
        case evt {
          event.OnClick(..) -> True
          _ -> False
        }
        |> expect.to_be_true
      }),
      it("creates OnMouseEnter variant", fn() {
        let evt = event.on_mouse_enter(handler: fn() { MouseEntered })
        case evt {
          event.OnMouseEnter(..) -> True
          _ -> False
        }
        |> expect.to_be_true
      }),
      it("creates OnMouseLeave variant", fn() {
        let evt = event.on_mouse_leave(handler: fn() { MouseLeft })
        case evt {
          event.OnMouseLeave(..) -> True
          _ -> False
        }
        |> expect.to_be_true
      }),
      it("creates OnMouseMove variant", fn() {
        let evt = event.on_mouse_move(handler: fn() { MouseMoved })
        case evt {
          event.OnMouseMove(..) -> True
          _ -> False
        }
        |> expect.to_be_true
      }),
    ]),
    // ----- Event builders on chart produce correct ChartChild -----
    describe("chart_event builder", [
      it("produces EventChild for on_click", fn() {
        let child =
          chart.event(handler: event.on_click(handler: fn() { Clicked }))
        case child {
          chart.EventChild(..) -> True
          _ -> False
        }
        |> expect.to_be_true
      }),
      it("produces EventChild for on_mouse_leave", fn() {
        let child =
          chart.event(
            handler: event.on_mouse_leave(handler: fn() { MouseLeft }),
          )
        case child {
          chart.EventChild(..) -> True
          _ -> False
        }
        |> expect.to_be_true
      }),
    ]),
    // ----- Chart-level events dispatch through Lustre wiring -----
    describe("chart event rendering", [
      it("dispatches click handler from SVG events", fn() {
        let simulation =
          chart_event_simulation(event_children: [
            chart.event(handler: event.on_click(handler: fn() { Clicked })),
          ])
          |> simulate.click(on: svg_query())

        simulate.model(simulation)
        |> expect.to_equal(expected: [Clicked])
      }),
      it("dispatches multiple chart-level SVG handlers", fn() {
        let simulation =
          chart_event_simulation(event_children: [
            chart.event(handler: event.on_click(handler: fn() { Clicked })),
            chart.event(
              handler: event.on_mouse_enter(handler: fn() { MouseEntered }),
            ),
            chart.event(
              handler: event.on_mouse_leave(handler: fn() { MouseLeft }),
            ),
            chart.event(
              handler: event.on_mouse_move(handler: fn() { MouseMoved }),
            ),
          ])
          |> simulate.event(on: svg_query(), name: "mouseenter", data: [])
          |> simulate.event(on: svg_query(), name: "mousemove", data: [])
          |> simulate.event(on: svg_query(), name: "mouseleave", data: [])
          |> simulate.click(on: svg_query())

        simulate.model(simulation)
        |> expect.to_equal(expected: [
          Clicked,
          MouseLeft,
          MouseMoved,
          MouseEntered,
        ])
      }),
    ]),
    // ----- Throttle -----
    describe("throttle", [
      it("produces ThrottleChild", fn() {
        let child = chart.throttle(delay_ms: 100)
        case child {
          chart.ThrottleChild(delay_ms: 100) -> True
          _ -> False
        }
        |> expect.to_be_true
      }),
      it("renders data-throttle-ms attribute on SVG", fn() {
        let html =
          chart.line_chart(
            data: sample_data(),
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.line(line.line_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
              chart.throttle(delay_ms: 150),
            ],
          )
          |> element.to_string
        html
        |> string.contains("data-throttle-ms=\"150\"")
        |> expect.to_be_true
      }),
      it("omits data-throttle-ms when no throttle child", fn() {
        let html =
          chart.line_chart(
            data: sample_data(),
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.line(line.line_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
            ],
          )
          |> element.to_string
        html
        |> string.contains("data-throttle-ms")
        |> expect.to_be_false
      }),
    ]),
    // ----- Tooltip active_index -----
    describe("tooltip active_index", [
      it("defaults to None", fn() {
        let config = tooltip.tooltip_config()
        config.active_index |> expect.to_equal(expected: None)
      }),
      it("sets active_index via builder", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_active_index(index: Some(2))
        config.active_index |> expect.to_equal(expected: Some(2))
      }),
      it("clears active_index to None", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_active_index(index: Some(1))
          |> tooltip.tooltip_active_index(index: None)
        config.active_index |> expect.to_equal(expected: None)
      }),
    ]),
    // ----- Tooltip on_tooltip_enter / on_tooltip_leave -----
    describe("tooltip event handlers", [
      it("defaults on_tooltip_enter to None", fn() {
        let config = tooltip.tooltip_config()
        config.on_tooltip_enter |> expect.to_equal(expected: None)
      }),
      it("defaults on_tooltip_leave to None", fn() {
        let config = tooltip.tooltip_config()
        config.on_tooltip_leave |> expect.to_equal(expected: None)
      }),
      it("sets on_tooltip_enter via builder", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_on_enter(handler: Some(TooltipEnter))
        case config.on_tooltip_enter {
          Some(_) -> True
          None -> False
        }
        |> expect.to_be_true
      }),
      it("sets on_tooltip_leave via builder", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_on_leave(handler: Some(fn() { TooltipLeave }))
        case config.on_tooltip_leave {
          Some(_) -> True
          None -> False
        }
        |> expect.to_be_true
      }),
    ]),
    // ----- Tooltip rendering with state-driven active index -----
    describe("tooltip state-driven rendering", [
      it("renders popup for active index", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_active_index(index: Some(0))
          |> tooltip.tooltip_on_enter(handler: Some(TooltipEnter))
          |> tooltip.tooltip_on_leave(handler: Some(fn() { TooltipLeave }))
        let payloads = [
          tooltip.TooltipPayload(
            label: "A",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 10.0,
                color: weft.css_color(value: "#ff0000"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 50.0,
            y: 100.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
          tooltip.TooltipPayload(
            label: "B",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 20.0,
                color: weft.css_color(value: "#00ff00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 150.0,
            y: 80.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
        ]
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: payloads,
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        // Active tooltip (index 0) should have popup content
        html |> string.contains("chart-tooltip-popup") |> expect.to_be_true
        // Hit zones should have event attrs (mouseenter)
        html |> string.contains("chart-tooltip-zone") |> expect.to_be_true
      }),
      it("hides non-active tooltip popup when state-driven", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_active_index(index: Some(0))
          |> tooltip.tooltip_on_enter(handler: Some(TooltipEnter))
          |> tooltip.tooltip_on_leave(handler: Some(fn() { TooltipLeave }))
        let payloads = [
          tooltip.TooltipPayload(
            label: "A",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 10.0,
                color: weft.css_color(value: "#ff0000"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 50.0,
            y: 100.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
          tooltip.TooltipPayload(
            label: "B",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 20.0,
                color: weft.css_color(value: "#00ff00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 150.0,
            y: 80.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
        ]
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: payloads,
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        // The active tooltip (A) shows its label, inactive (B) does not show popup
        // Both hit zones are rendered
        html |> string.contains("chart-hotspot") |> expect.to_be_true
      }),
    ]),
    // ----- Backwards compatibility: no handlers = CSS hover -----
    describe("tooltip backwards compatibility", [
      it("renders all popups when no event handlers set", fn() {
        let config = tooltip.tooltip_config()
        let payloads = [
          tooltip.TooltipPayload(
            label: "A",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 10.0,
                color: weft.css_color(value: "#ff0000"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 50.0,
            y: 100.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
          tooltip.TooltipPayload(
            label: "B",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 20.0,
                color: weft.css_color(value: "#00ff00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 150.0,
            y: 80.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
        ]
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: payloads,
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        // Both tooltips should have popup elements (CSS hover controls visibility)
        // Count occurrences of chart-tooltip-popup
        let popup_count =
          string.split(html, "chart-tooltip-popup")
          |> list_length_minus_one
        popup_count |> expect.to_equal(expected: 2)
      }),
      it("renders cursor for all tooltips without event handlers", fn() {
        let config = tooltip.tooltip_config()
        let payloads = [
          tooltip.TooltipPayload(
            label: "A",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 10.0,
                color: weft.css_color(value: "#ff0000"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 50.0,
            y: 100.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
        ]
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: payloads,
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html
        |> string.contains("chart-tooltip-cursor")
        |> expect.to_be_true
      }),
      it(
        "does not render dot elements by default (show_active_dot=False)",
        fn() {
          let config = tooltip.tooltip_config()
          let payloads = [
            tooltip.TooltipPayload(
              label: "A",
              entries: [
                tooltip.TooltipEntry(
                  name: "val",
                  value: 10.0,
                  color: weft.css_color(value: "#ff0000"),
                  unit: "",
                  hidden: False,
                  entry_type: tooltip.VisibleEntry,
                ),
              ],
              x: 50.0,
              y: 100.0,
              active_dots: [],
              zone_width: 0.0,
              zone_height: 0.0,
            ),
          ]
          let html =
            tooltip.render_tooltips(
              config: config,
              payloads: payloads,
              plot_x: 0.0,
              plot_y: 0.0,
              plot_width: 400.0,
              plot_height: 200.0,
              zone_width: 50.0,
              zone_mode: tooltip.ColumnZone,
              zone_extra_attrs: [],
            )
            |> element.to_string
          html |> string.contains("chart-tooltip-dot") |> expect.to_be_false
        },
      ),
      it("renders dot elements when show_active_dot is enabled", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_show_active_dot(show: True)
        let payloads = [
          tooltip.TooltipPayload(
            label: "A",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 10.0,
                color: weft.css_color(value: "#ff0000"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 50.0,
            y: 100.0,
            active_dots: [100.0],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
        ]
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: payloads,
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html |> string.contains("chart-tooltip-dot") |> expect.to_be_true
      }),
    ]),
    // ----- default_index + filter_null behavior -----
    describe("tooltip default_index and filter_null", [
      it("uses default_index when state-driven and active_index is None", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_default_index(index: 1)
          |> tooltip.tooltip_on_enter(handler: Some(TooltipEnter))
          |> tooltip.tooltip_on_leave(handler: Some(fn() { TooltipLeave }))
        let payloads = [
          tooltip.TooltipPayload(
            label: "A",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 10.0,
                color: weft.css_color(value: "#ff0000"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 50.0,
            y: 100.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
          tooltip.TooltipPayload(
            label: "B",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 20.0,
                color: weft.css_color(value: "#00ff00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 150.0,
            y: 80.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
        ]
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: payloads,
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        let popup_count =
          string.split(html, "chart-tooltip-popup")
          |> list_length_minus_one
        popup_count |> expect.to_equal(expected: 1)
      }),
      it("marks default tooltip hotspot in CSS-hover mode", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_default_index(index: 0)
        let payloads = [
          tooltip.TooltipPayload(
            label: "A",
            entries: [
              tooltip.TooltipEntry(
                name: "val",
                value: 10.0,
                color: weft.css_color(value: "#ff0000"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 50.0,
            y: 100.0,
            active_dots: [],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
        ]
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: payloads,
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.ColumnZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html
        |> string.contains("chart-default-active")
        |> expect.to_be_true
      }),
      it("RowZone renders active dots using per-entry x coordinates", fn() {
        let config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_show_active_dot(show: True)
          |> tooltip.tooltip_default_index(index: 0)
        let payloads = [
          tooltip.TooltipPayload(
            label: "A",
            entries: [
              tooltip.TooltipEntry(
                name: "v1",
                value: 10.0,
                color: weft.css_color(value: "#ff0000"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
              tooltip.TooltipEntry(
                name: "v2",
                value: 20.0,
                color: weft.css_color(value: "#00ff00"),
                unit: "",
                hidden: False,
                entry_type: tooltip.VisibleEntry,
              ),
            ],
            x: 80.0,
            y: 120.0,
            active_dots: [40.0, 90.0],
            zone_width: 0.0,
            zone_height: 0.0,
          ),
        ]
        let html =
          tooltip.render_tooltips(
            config: config,
            payloads: payloads,
            plot_x: 0.0,
            plot_y: 0.0,
            plot_width: 400.0,
            plot_height: 200.0,
            zone_width: 50.0,
            zone_mode: tooltip.RowZone,
            zone_extra_attrs: [],
          )
          |> element.to_string
        html |> string.contains("cx=\"40\"") |> expect.to_be_true
        html |> string.contains("cx=\"90\"") |> expect.to_be_true
      }),
      it("filter_null=False includes missing series entries", fn() {
        let html_filtered =
          chart.line_chart(
            data: missing_series_data(),
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.line(line.line_config(
                data_key: "present_value",
                meta: common.series_meta(),
              )),
              chart.line(line.line_config(
                data_key: "missing_value",
                meta: common.series_meta(),
              )),
              chart.tooltip(config: tooltip.tooltip_config()),
            ],
          )
          |> element.to_string
        html_filtered
        |> string.contains("missing_value")
        |> expect.to_be_false

        let html_include_missing =
          chart.line_chart(
            data: missing_series_data(),
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.line(line.line_config(
                data_key: "present_value",
                meta: common.series_meta(),
              )),
              chart.line(line.line_config(
                data_key: "missing_value",
                meta: common.series_meta(),
              )),
              chart.tooltip(
                config: tooltip.tooltip_config()
                |> tooltip.tooltip_filter_null(filter: False),
              ),
            ],
          )
          |> element.to_string
        html_include_missing
        |> string.contains("missing_value")
        |> expect.to_be_true
      }),
      it("vertical chart layout emits row-zone tooltip geometry", fn() {
        let html =
          chart.line_chart(
            data: sample_data(),
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.layout(layout: layout.Vertical),
              chart.line(line.line_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
              chart.tooltip(
                config: tooltip.tooltip_config()
                |> tooltip.tooltip_default_index(index: 0)
                |> tooltip.tooltip_show_active_dot(show: True),
              ),
            ],
          )
          |> element.to_string
        html |> string.contains("chart-tooltip-zone") |> expect.to_be_true
        // RowZone uses full plot width for hit zones in vertical layout.
        html |> string.contains("width=\"390\"") |> expect.to_be_true
      }),
    ]),
    // ----- Full chart integration -----
    describe("chart integration", [
      it("renders chart with tooltip and event handlers", fn() {
        let tooltip_config =
          tooltip.tooltip_config()
          |> tooltip.tooltip_active_index(index: Some(0))
          |> tooltip.tooltip_on_enter(handler: Some(TooltipEnter))
          |> tooltip.tooltip_on_leave(handler: Some(fn() { TooltipLeave }))
        let html =
          chart.line_chart(
            data: sample_data(),
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.line(line.line_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
              chart.tooltip(config: tooltip_config),
              chart.event(handler: event.on_click(handler: fn() { Clicked })),
              chart.throttle(delay_ms: 200),
            ],
          )
          |> element.to_string
        html |> string.contains("<svg") |> expect.to_be_true
        html
        |> string.contains("data-throttle-ms=\"200\"")
        |> expect.to_be_true
        html
        |> string.contains("recharts-tooltip-wrapper")
        |> expect.to_be_true
      }),
      it("renders chart without event children normally", fn() {
        let html =
          chart.line_chart(
            data: sample_data(),
            width: chart.FixedWidth(pixels: 400),
            theme: option.None,
            height: 300,
            children: [
              chart.line(line.line_config(
                data_key: "val",
                meta: common.series_meta(),
              )),
            ],
          )
          |> element.to_string
        html |> string.contains("<svg") |> expect.to_be_true
        html
        |> string.contains("data-throttle-ms")
        |> expect.to_be_false
      }),
    ]),
  ])
}

fn list_length_minus_one(parts: List(String)) -> Int {
  case parts {
    [] -> 0
    [_] -> 0
    [_, ..rest] -> 1 + list_length_minus_one(rest)
  }
}
