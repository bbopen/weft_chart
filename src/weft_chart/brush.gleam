//// Brush component for range selection on charts.
////
//// Renders a brush indicator with a mini preview area, two handle
//// indicators, and a highlighted selected region overlay.
//// Supports keyboard interaction for accessible range adjustment.
//// Matches the recharts Brush component visual structure.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/event as lustre_event
import weft_chart/internal/math
import weft_chart/internal/svg

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for a brush component.
/// Generic over the Lustre message type to support event handlers.
pub type BrushConfig(msg) {
  BrushConfig(
    start_index: Int,
    end_index: Int,
    height: Float,
    stroke: String,
    fill: String,
    data_key: String,
    data: List(Dict(String, Float)),
    on_range_change: Option(fn(Int, Int) -> msg),
    on_key_down: Option(fn(String) -> msg),
    /// Width of the brush handle/traveller in pixels. Default 5.
    traveller_width: Float,
    /// Index snap granularity when dragging. Default 1.
    gap: Int,
    /// Called when a drag interaction completes with the final index range.
    on_drag_end: Option(fn(Int, Int) -> msg),
    /// Internal padding around the brush area in pixels. Default 2.
    brush_padding: Float,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a brush configuration with required parameters.
/// Defaults: height=40.0, stroke="#666", fill="#fff".
/// Matches recharts BrushDefaultProps.
pub fn new(
  start_index start_index: Int,
  end_index end_index: Int,
  data_key data_key: String,
  data data: List(Dict(String, Float)),
) -> BrushConfig(msg) {
  BrushConfig(
    start_index: start_index,
    end_index: end_index,
    height: 40.0,
    stroke: "#666",
    fill: "#fff",
    data_key: data_key,
    data: data,
    on_range_change: None,
    on_key_down: None,
    traveller_width: 5.0,
    gap: 1,
    on_drag_end: None,
    brush_padding: 2.0,
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the brush height in pixels.
/// Matches recharts Brush `height` prop (default: 40).
pub fn height(
  config config: BrushConfig(msg),
  height height: Float,
) -> BrushConfig(msg) {
  BrushConfig(..config, height: height)
}

/// Set the brush stroke color.
/// Matches recharts Brush `stroke` prop (default: "#666").
pub fn stroke(
  config config: BrushConfig(msg),
  stroke stroke: String,
) -> BrushConfig(msg) {
  BrushConfig(..config, stroke: stroke)
}

/// Set the brush fill color.
/// Matches recharts Brush `fill` prop (default: "#fff").
pub fn fill(
  config config: BrushConfig(msg),
  fill fill: String,
) -> BrushConfig(msg) {
  BrushConfig(..config, fill: fill)
}

/// Set a callback for when the brush range changes.
/// The handler receives the new start and end indices.
pub fn on_range_change(
  config config: BrushConfig(msg),
  handler handler: fn(Int, Int) -> msg,
) -> BrushConfig(msg) {
  BrushConfig(..config, on_range_change: Some(handler))
}

/// Set a keydown handler for the brush container.
/// When set, the brush becomes keyboard-focusable (tabindex=0).
/// The handler receives the key name string (e.g. "ArrowRight").
pub fn on_key_down(
  config config: BrushConfig(msg),
  handler handler: fn(String) -> msg,
) -> BrushConfig(msg) {
  BrushConfig(..config, on_key_down: Some(handler))
}

/// Set the width of the brush handle/traveller in pixels.
/// Matches recharts Brush `travellerWidth` prop (default: 5).
pub fn brush_traveller_width(
  config config: BrushConfig(msg),
  width w: Float,
) -> BrushConfig(msg) {
  BrushConfig(..config, traveller_width: w)
}

/// Set the index snap granularity when dragging.
/// Matches recharts Brush `gap` prop (default: 1).
pub fn brush_gap(
  config config: BrushConfig(msg),
  gap g: Int,
) -> BrushConfig(msg) {
  BrushConfig(..config, gap: g)
}

/// Set a callback for when a drag interaction completes.
/// The handler receives the final start and end indices.
/// Matches recharts Brush `onDragEnd` prop.
pub fn brush_on_drag_end(
  config config: BrushConfig(msg),
  callback c: fn(Int, Int) -> msg,
) -> BrushConfig(msg) {
  BrushConfig(..config, on_drag_end: Some(c))
}

/// Set the internal padding around the brush area in pixels.
/// Matches recharts Brush internal padding (default: 2).
pub fn brush_set_padding(
  config config: BrushConfig(msg),
  padding p: Float,
) -> BrushConfig(msg) {
  BrushConfig(..config, brush_padding: p)
}

// ---------------------------------------------------------------------------
// Keyboard helpers
// ---------------------------------------------------------------------------

/// Handle keyboard events for brush range adjustment.
/// ArrowRight shifts the range right by 1, ArrowLeft shifts left by 1.
/// Shift+ArrowRight expands the range (end + 1).
/// Shift+ArrowLeft shrinks the range from the right (end - 1).
/// Returns Some(#(start, end)) for recognized keys, None otherwise.
pub fn handle_brush_key(
  key key: String,
  start start: Int,
  end_ end_: Int,
  data_length data_length: Int,
) -> Option(#(Int, Int)) {
  case key {
    "ArrowRight" ->
      case end_ < data_length - 1 {
        True -> Some(#(start + 1, end_ + 1))
        False -> None
      }
    "ArrowLeft" ->
      case start > 0 {
        True -> Some(#(start - 1, end_ - 1))
        False -> None
      }
    "Shift+ArrowRight" ->
      case end_ < data_length - 1 {
        True -> Some(#(start, end_ + 1))
        False -> None
      }
    "Shift+ArrowLeft" ->
      case end_ > start + 1 {
        True -> Some(#(start, end_ - 1))
        False -> None
      }
    _ -> None
  }
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a brush component below the chart.
/// Draws a background rectangle, a mini area chart preview, handle
/// indicators at start/end positions, and a selected region overlay.
/// When on_key_down is set, adds tabindex and keydown event handler.
pub fn render(
  config config: BrushConfig(msg),
  plot_x plot_x: Float,
  plot_width plot_width: Float,
  plot_bottom plot_bottom: Float,
) -> Element(msg) {
  let data_len = list.length(config.data)
  case data_len {
    0 -> element.none()
    _ -> {
      let y = plot_bottom
      let w = plot_width
      let h = config.height

      // Background rectangle
      let bg =
        svg.rect(
          x: math.fmt(plot_x),
          y: math.fmt(y),
          width: math.fmt(w),
          height: math.fmt(h),
          attrs: [
            svg.attr("fill", "#fff"),
            svg.attr("stroke", config.stroke),
            svg.attr("stroke-width", "1"),
          ],
        )

      // Compute x positions for each data point
      let step = case data_len > 1 {
        True -> w /. int.to_float(data_len - 1)
        False -> w
      }

      // Extract values for the mini preview chart
      let values =
        list.map(config.data, fn(d) {
          case dict.get(d, config.data_key) {
            Ok(v) -> v
            Error(_) -> 0.0
          }
        })

      // Find min/max for y scaling
      let v_min =
        list.fold(values, 0.0, fn(acc, v) {
          case v <. acc {
            True -> v
            False -> acc
          }
        })
      let v_max =
        list.fold(values, 0.0, fn(acc, v) {
          case v >. acc {
            True -> v
            False -> acc
          }
        })
      let v_range = case v_max -. v_min >. 0.0 {
        True -> v_max -. v_min
        False -> 1.0
      }

      // Build area path for mini preview
      let area_path =
        build_area_path(
          values: values,
          plot_x: plot_x,
          y: y,
          step: step,
          height: h,
          v_min: v_min,
          v_range: v_range,
          padding: config.brush_padding,
        )

      let preview =
        svg.path(d: area_path, attrs: [
          svg.attr("fill", config.fill),
          svg.attr("fill-opacity", "0.2"),
          svg.attr("stroke", config.stroke),
          svg.attr("stroke-width", "1"),
        ])

      // Handle positions
      let handle_width = config.traveller_width
      let start_x =
        plot_x
        +. int.to_float(config.start_index)
        *. step
        -. handle_width
        /. 2.0
      let end_x =
        plot_x +. int.to_float(config.end_index) *. step -. handle_width /. 2.0

      // Selected region overlay
      let sel_x = plot_x +. int.to_float(config.start_index) *. step
      let sel_w = int.to_float(config.end_index - config.start_index) *. step
      let selection =
        svg.rect(
          x: math.fmt(sel_x),
          y: math.fmt(y),
          width: math.fmt(sel_w),
          height: math.fmt(h),
          attrs: [
            svg.attr("fill", config.stroke),
            svg.attr("fill-opacity", "0.1"),
            svg.attr("stroke", "none"),
          ],
        )

      // Start handle
      let start_handle = render_handle(start_x, y, handle_width, h, config)

      // End handle
      let end_handle = render_handle(end_x, y, handle_width, h, config)

      // Container attributes: class + optional keyboard support
      let base_g_attrs = [svg.attr("class", "recharts-brush")]
      let g_attrs = case config.on_key_down {
        None -> base_g_attrs
        Some(handler) ->
          list.append(base_g_attrs, [
            attribute.attribute("tabindex", "0"),
            lustre_event.on_keydown(handler),
          ])
      }

      svg.g(attrs: g_attrs, children: [
        bg,
        preview,
        selection,
        start_handle,
        end_handle,
      ])
    }
  }
}

/// Build an SVG area path for the mini preview chart.
fn build_area_path(
  values values: List(Float),
  plot_x plot_x: Float,
  y y: Float,
  step step: Float,
  height height: Float,
  v_min v_min: Float,
  v_range v_range: Float,
  padding padding: Float,
) -> String {
  let usable_h = height -. padding *. 2.0

  case values {
    [] -> ""
    [first_val, ..rest_vals] -> {
      let first_py =
        y
        +. height
        -. padding
        -. { { first_val -. v_min } /. v_range *. usable_h }
      let start = "M" <> math.fmt(plot_x) <> "," <> math.fmt(first_py)

      let #(line_path, _) =
        list.fold(rest_vals, #(start, 1), fn(state, v) {
          let #(acc, idx) = state
          let px = plot_x +. int.to_float(idx) *. step
          let py =
            y +. height -. padding -. { { v -. v_min } /. v_range *. usable_h }
          #(acc <> "L" <> math.fmt(px) <> "," <> math.fmt(py), idx + 1)
        })

      // Close the area by going to bottom-right, then bottom-left
      let last_x = plot_x +. int.to_float(list.length(rest_vals)) *. step
      let bottom_y = y +. height -. padding
      line_path
      <> "L"
      <> math.fmt(last_x)
      <> ","
      <> math.fmt(bottom_y)
      <> "L"
      <> math.fmt(plot_x)
      <> ","
      <> math.fmt(bottom_y)
      <> "Z"
    }
  }
}

/// Render a brush handle indicator.
fn render_handle(
  x: Float,
  y: Float,
  width: Float,
  height: Float,
  config: BrushConfig(msg),
) -> Element(msg) {
  let handle_rect =
    svg.rect(
      x: math.fmt(x),
      y: math.fmt(y),
      width: math.fmt(width),
      height: math.fmt(height),
      attrs: [
        svg.attr("fill", config.stroke),
        svg.attr("stroke", "none"),
        svg.attr("class", "recharts-brush-traveller"),
      ],
    )

  // Two small lines inside the handle for grip visual
  let line_y1 = y +. height /. 2.0 -. 1.0
  let line_y2 = y +. height /. 2.0 +. 1.0
  let line1 =
    svg.line(
      x1: math.fmt(x +. 1.0),
      y1: math.fmt(line_y1),
      x2: math.fmt(x +. width -. 1.0),
      y2: math.fmt(line_y1),
      attrs: [
        svg.attr("stroke", "#fff"),
        svg.attr("fill", "none"),
      ],
    )
  let line2 =
    svg.line(
      x1: math.fmt(x +. 1.0),
      y1: math.fmt(line_y2),
      x2: math.fmt(x +. width -. 1.0),
      y2: math.fmt(line_y2),
      attrs: [
        svg.attr("stroke", "#fff"),
        svg.attr("fill", "none"),
      ],
    )

  svg.g(attrs: [], children: [handle_rect, line1, line2])
}
