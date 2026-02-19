//// Accessibility configuration for weft_chart visualizations.
////
//// Provides keyboard navigation helpers, ARIA attributes, and screen reader
//// support.  The `A11yConfig` type controls which accessibility features are
//// applied to the outer SVG element of a chart, matching the recharts
//// `accessibilityLayer` prop behavior.

import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import weft_chart/internal/svg

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for chart accessibility features.
/// When enabled, sets tabindex, role, aria-label, and event handlers on
/// the chart SVG element.  Matches recharts accessibilityLayer behavior.
pub type A11yConfig(msg) {
  A11yConfig(
    enabled: Bool,
    tab_index: Int,
    role: String,
    description: Option(String),
    live_region_content: Option(String),
    on_focus: Option(fn() -> msg),
    on_blur: Option(fn() -> msg),
    on_key_down: Option(fn(String) -> msg),
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a default accessibility configuration.
/// Enabled with tab_index 0, role "application", no description or handlers.
/// Matches recharts accessibilityLayer defaults.
pub fn default() -> A11yConfig(msg) {
  A11yConfig(
    enabled: True,
    tab_index: 0,
    role: "application",
    description: None,
    live_region_content: None,
    on_focus: None,
    on_blur: None,
    on_key_down: None,
  )
}

/// Create a disabled accessibility configuration.
/// All features are off; no attributes or handlers are applied to the SVG.
pub fn disabled() -> A11yConfig(msg) {
  A11yConfig(
    enabled: False,
    tab_index: -1,
    role: "img",
    description: None,
    live_region_content: None,
    on_focus: None,
    on_blur: None,
    on_key_down: None,
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the tab index for keyboard focus.
/// Default is 0 (focusable in normal tab order).
pub fn with_tab_index(
  config config: A11yConfig(msg),
  tab_index tab_index: Int,
) -> A11yConfig(msg) {
  A11yConfig(..config, tab_index: tab_index)
}

/// Set the ARIA role attribute.
/// Default is "application" when accessibility is enabled.
pub fn with_role(
  config config: A11yConfig(msg),
  role role: String,
) -> A11yConfig(msg) {
  A11yConfig(..config, role: role)
}

/// Set the accessible description (rendered as aria-label on the SVG).
pub fn with_description(
  config config: A11yConfig(msg),
  description description: String,
) -> A11yConfig(msg) {
  A11yConfig(..config, description: Some(description))
}

/// Set the content for the ARIA live region.
/// When set, a screen-reader-only region announces this text.
pub fn with_live_region_content(
  config config: A11yConfig(msg),
  content content: String,
) -> A11yConfig(msg) {
  A11yConfig(..config, live_region_content: Some(content))
}

/// Set a focus handler for the chart SVG element.
/// Called when the chart receives keyboard focus.
pub fn with_on_focus(
  config config: A11yConfig(msg),
  handler handler: fn() -> msg,
) -> A11yConfig(msg) {
  A11yConfig(..config, on_focus: Some(handler))
}

/// Set a blur handler for the chart SVG element.
/// Called when the chart loses keyboard focus.
pub fn with_on_blur(
  config config: A11yConfig(msg),
  handler handler: fn() -> msg,
) -> A11yConfig(msg) {
  A11yConfig(..config, on_blur: Some(handler))
}

/// Set a keydown handler for the chart SVG element.
/// The handler receives the key name string (e.g. "ArrowRight").
pub fn with_on_key_down(
  config config: A11yConfig(msg),
  handler handler: fn(String) -> msg,
) -> A11yConfig(msg) {
  A11yConfig(..config, on_key_down: Some(handler))
}

// ---------------------------------------------------------------------------
// Keyboard navigation helpers
// ---------------------------------------------------------------------------

/// Compute the next index, wrapping around to the beginning.
/// Returns (current + 1) % total for circular navigation.
pub fn next_index(current current: Int, total total: Int) -> Int {
  case total <= 0 {
    True -> 0
    False -> { current + 1 } % total
  }
}

/// Compute the previous index, wrapping around to the end.
/// Returns (current - 1 + total) % total for circular navigation.
pub fn prev_index(current current: Int, total total: Int) -> Int {
  case total <= 0 {
    True -> 0
    False -> { current - 1 + total } % total
  }
}

/// Handle arrow key presses for data point navigation.
/// Returns Some(new_index) for arrow keys, None for unrecognized keys.
/// ArrowRight and ArrowDown advance forward; ArrowLeft and ArrowUp go back.
pub fn handle_arrow_key(
  key key: String,
  current_index current_index: Int,
  total_items total_items: Int,
) -> Option(Int) {
  case key {
    "ArrowRight" | "ArrowDown" ->
      Some(next_index(current: current_index, total: total_items))
    "ArrowLeft" | "ArrowUp" ->
      Some(prev_index(current: current_index, total: total_items))
    _ -> None
  }
}

// ---------------------------------------------------------------------------
// ARIA live region
// ---------------------------------------------------------------------------

/// Render a screen-reader-only ARIA live region inside an SVG.
/// Uses a foreignObject containing a visually-hidden div with aria-live="polite"
/// so screen readers announce content changes without visual disruption.
pub fn live_region(content content: String) -> Element(msg) {
  svg.el(
    tag: "foreignObject",
    attrs: [
      svg.attr("x", "0"),
      svg.attr("y", "0"),
      svg.attr("width", "1"),
      svg.attr("height", "1"),
      svg.attr("aria-hidden", "true"),
    ],
    children: [
      svg.xhtml(
        tag: "div",
        attrs: [
          svg.attr("aria-live", "polite"),
          svg.attr("role", "status"),
          svg.attr(
            "style",
            "position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0)",
          ),
        ],
        children: [element.text(content)],
      ),
    ],
  )
}
