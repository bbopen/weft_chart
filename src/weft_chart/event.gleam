//// Chart event types and handlers for interactive weft_chart visualizations.
////
//// Provides typed event data and handler variants for chart-level
//// interactions such as click, mouse enter, mouse leave, and mouse
//// move.  Matches the recharts generateCategoricalChart event system
//// where chart interactions deliver the active data index, data key,
//// and chart-relative coordinates.

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Data payload delivered with chart interaction events.
/// Contains the index of the active data point, the data key under
/// the cursor, and chart-relative coordinates.
pub type ChartEventData {
  ChartEventData(
    active_index: Int,
    active_data_key: String,
    chart_x: Float,
    chart_y: Float,
  )
}

/// Chart-level event handler variants.
/// Each variant wraps a handler function that receives event data
/// and produces a Lustre message.
pub type ChartEvent(msg) {
  /// Fires when the chart area is clicked.
  OnClick(handler: fn(ChartEventData) -> msg)
  /// Fires when the mouse enters the chart area.
  OnMouseEnter(handler: fn(ChartEventData) -> msg)
  /// Fires when the mouse leaves the chart area.
  OnMouseLeave(handler: fn() -> msg)
  /// Fires when the mouse moves within the chart area.
  OnMouseMove(handler: fn(ChartEventData) -> msg)
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a chart event data payload.
pub fn chart_event_data(
  active_index active_index: Int,
  active_data_key active_data_key: String,
  chart_x chart_x: Float,
  chart_y chart_y: Float,
) -> ChartEventData {
  ChartEventData(
    active_index: active_index,
    active_data_key: active_data_key,
    chart_x: chart_x,
    chart_y: chart_y,
  )
}

/// Create an on-click chart event handler.
pub fn on_click(handler handler: fn(ChartEventData) -> msg) -> ChartEvent(msg) {
  OnClick(handler: handler)
}

/// Create an on-mouse-enter chart event handler.
pub fn on_mouse_enter(
  handler handler: fn(ChartEventData) -> msg,
) -> ChartEvent(msg) {
  OnMouseEnter(handler: handler)
}

/// Create an on-mouse-leave chart event handler.
pub fn on_mouse_leave(handler handler: fn() -> msg) -> ChartEvent(msg) {
  OnMouseLeave(handler: handler)
}

/// Create an on-mouse-move chart event handler.
pub fn on_mouse_move(
  handler handler: fn(ChartEventData) -> msg,
) -> ChartEvent(msg) {
  OnMouseMove(handler: handler)
}
