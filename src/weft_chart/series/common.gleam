//// Shared metadata for cartesian series.
////
//// Provides a common additive API for metadata that is duplicated
//// across area, line, and bar configurations.

import weft_chart/shape

/// Shared metadata applied by area, line, and bar series constructors.
pub type SeriesMeta {
  SeriesMeta(
    name: String,
    hide: Bool,
    tooltip_type: shape.TooltipType,
    unit: String,
    x_axis_id: String,
    y_axis_id: String,
    css_class: String,
  )
}

/// Create default shared series metadata.
pub fn series_meta() -> SeriesMeta {
  SeriesMeta(
    name: "",
    hide: False,
    tooltip_type: shape.DefaultTooltip,
    unit: "",
    x_axis_id: "0",
    y_axis_id: "0",
    css_class: "",
  )
}

/// Set the display name used in tooltip and legend.
pub fn series_name(meta meta: SeriesMeta, name name: String) -> SeriesMeta {
  SeriesMeta(..meta, name: name)
}

/// Hide the series while preserving domain/legend participation.
pub fn series_hide(meta meta: SeriesMeta, hide hide: Bool) -> SeriesMeta {
  SeriesMeta(..meta, hide: hide)
}

/// Set tooltip participation mode.
pub fn series_tooltip_type(
  meta meta: SeriesMeta,
  tooltip_type tooltip_type: shape.TooltipType,
) -> SeriesMeta {
  SeriesMeta(..meta, tooltip_type: tooltip_type)
}

/// Set the unit suffix for tooltip values.
pub fn series_unit(meta meta: SeriesMeta, unit unit: String) -> SeriesMeta {
  SeriesMeta(..meta, unit: unit)
}

/// Set the x-axis id the series binds to.
pub fn series_x_axis_id(meta meta: SeriesMeta, id id: String) -> SeriesMeta {
  SeriesMeta(..meta, x_axis_id: id)
}

/// Set the y-axis id the series binds to.
pub fn series_y_axis_id(meta meta: SeriesMeta, id id: String) -> SeriesMeta {
  SeriesMeta(..meta, y_axis_id: id)
}

/// Set the CSS class for the series group.
pub fn series_css_class(
  meta meta: SeriesMeta,
  class class: String,
) -> SeriesMeta {
  SeriesMeta(..meta, css_class: class)
}
