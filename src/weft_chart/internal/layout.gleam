//// Chart layout computation.
////
//// Determines the usable plot area within a chart by subtracting
//// margins and axis space from the total dimensions.

import gleam/int
import weft_chart/scale

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Chart layout direction matching recharts `layout` prop.
pub type LayoutDirection {
  /// Categories on X-axis, values on Y-axis (default).
  Horizontal
  /// Categories on Y-axis, values on X-axis.
  Vertical
}

/// Margin specification for a chart.
pub type Margin {
  Margin(top: Int, right: Int, bottom: Int, left: Int)
}

/// Computed layout rectangle — the area where series are drawn.
pub type PlotArea {
  PlotArea(x: Float, y: Float, width: Float, height: Float)
}

// ---------------------------------------------------------------------------
// Defaults
// ---------------------------------------------------------------------------

/// Default chart margin matching Recharts defaults.
pub fn default_margin() -> Margin {
  Margin(top: 5, right: 5, bottom: 5, left: 5)
}

/// Default chart width when not responsive.
pub const default_width = 500

/// Default chart height when not responsive.
pub const default_height = 300

// ---------------------------------------------------------------------------
// Computation
// ---------------------------------------------------------------------------

/// Compute the plot area from total dimensions and margins.
pub fn plot_area(
  width width: Int,
  height height: Int,
  margin margin: Margin,
) -> PlotArea {
  let x = int.to_float(margin.left)
  let y = int.to_float(margin.top)
  let w = int.to_float(width - margin.left - margin.right)
  let h = int.to_float(height - margin.top - margin.bottom)
  PlotArea(
    x: x,
    y: y,
    width: case w <. 0.0 {
      True -> 0.0
      False -> w
    },
    height: case h <. 0.0 {
      True -> 0.0
      False -> h
    },
  )
}

/// Build a category scale that adapts to chart layout direction.
///
/// Horizontal layout maps categories along the horizontal span.
/// Vertical layout maps categories along the vertical span.
pub fn category_scale(
  direction direction: LayoutDirection,
  categories categories: List(String),
  use_band use_band: Bool,
  horizontal_start horizontal_start: Float,
  horizontal_end horizontal_end: Float,
  vertical_start vertical_start: Float,
  vertical_end vertical_end: Float,
) -> scale.Scale {
  let #(range_start, range_end) = case direction {
    Horizontal -> #(horizontal_start, horizontal_end)
    Vertical -> #(vertical_start, vertical_end)
  }

  case use_band {
    True ->
      scale.band(
        categories: categories,
        range_start: range_start,
        range_end: range_end,
        padding_inner: 0.1,
        padding_outer: 0.1,
      )
    False ->
      scale.point(
        categories: categories,
        range_start: range_start,
        range_end: range_end,
        padding: 0.0,
      )
  }
}

/// Build a linear value scale that adapts to chart layout direction.
///
/// Horizontal layout maps values along the vertical span.
/// Vertical layout maps values along the horizontal span.
pub fn value_scale(
  direction direction: LayoutDirection,
  domain_min domain_min: Float,
  domain_max domain_max: Float,
  horizontal_start horizontal_start: Float,
  horizontal_end horizontal_end: Float,
  vertical_start vertical_start: Float,
  vertical_end vertical_end: Float,
) -> scale.Scale {
  let #(range_start, range_end) = case direction {
    Horizontal -> #(vertical_start, vertical_end)
    Vertical -> #(horizontal_start, horizontal_end)
  }

  scale.linear(
    domain_min: domain_min,
    domain_max: domain_max,
    range_start: range_start,
    range_end: range_end,
  )
}
