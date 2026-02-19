//// Typed context records for cartesian chart rendering.
////
//// Keeps render-time cartesian state grouped for helper boundaries.

import gleam/dict.{type Dict}
import weft_chart/internal/layout

/// Shared cartesian render context for plot and dataset state.
pub type CartesianContext {
  CartesianContext(
    plot: layout.PlotArea,
    categories: List(String),
    values: List(Dict(String, Float)),
    chart_layout: layout.LayoutDirection,
    clip_path_id: String,
  )
}

/// Construct a cartesian render context.
pub fn cartesian_context(
  plot plot: layout.PlotArea,
  categories categories: List(String),
  values values: List(Dict(String, Float)),
  chart_layout chart_layout: layout.LayoutDirection,
  clip_path_id clip_path_id: String,
) -> CartesianContext {
  CartesianContext(
    plot: plot,
    categories: categories,
    values: values,
    chart_layout: chart_layout,
    clip_path_id: clip_path_id,
  )
}
