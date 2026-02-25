//// Chart event types and handlers for interactive weft_chart visualizations.
////
//// Provides handler variants for chart-level interactions such as click,
//// mouse enter, mouse leave, and mouse move.
////
//// Chart-level handlers are payloadless because this library intentionally
//// avoids browser FFI in public APIs for cross-target compatibility.

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Chart-level event handler variants.
/// Each variant wraps a handler function that produces a Lustre message.
/// Handlers should be pure message constructors.
pub type ChartEvent(msg) {
  /// Fires when the chart area is clicked.
  OnClick(handler: fn() -> msg)
  /// Fires when the mouse enters the chart area.
  OnMouseEnter(handler: fn() -> msg)
  /// Fires when the mouse leaves the chart area.
  OnMouseLeave(handler: fn() -> msg)
  /// Fires when the mouse moves within the chart area.
  OnMouseMove(handler: fn() -> msg)
}

/// Create an on-click chart event handler.
pub fn on_click(handler handler: fn() -> msg) -> ChartEvent(msg) {
  OnClick(handler: handler)
}

/// Create an on-mouse-enter chart event handler.
pub fn on_mouse_enter(handler handler: fn() -> msg) -> ChartEvent(msg) {
  OnMouseEnter(handler: handler)
}

/// Create an on-mouse-leave chart event handler.
pub fn on_mouse_leave(handler handler: fn() -> msg) -> ChartEvent(msg) {
  OnMouseLeave(handler: handler)
}

/// Create an on-mouse-move chart event handler.
pub fn on_mouse_move(handler handler: fn() -> msg) -> ChartEvent(msg) {
  OnMouseMove(handler: handler)
}
