//// Custom render callback prop types.
////
//// These record types carry layout and styling data to user-provided
//// render functions.  Each type mirrors the props object that recharts
//// passes to its corresponding custom renderer.

import weft

/// Data passed to a custom tick render function.
///
/// Contains the computed position, value, and styling information
/// for a single axis tick mark.
pub type TickProps {
  TickProps(
    x: Float,
    y: Float,
    index: Int,
    value: String,
    text_anchor: String,
    vertical_anchor: String,
    fill: weft.Color,
    visible_ticks_count: Int,
  )
}

/// Data passed to a custom dot render function.
///
/// Used by Line, Scatter, and Radar series when a custom dot
/// renderer is provided.
pub type DotProps {
  DotProps(
    cx: Float,
    cy: Float,
    r: Float,
    index: Int,
    value: Float,
    data_key: String,
    fill: weft.Color,
    stroke: weft.Color,
  )
}

/// Data passed to a custom label render function.
///
/// Contains position, dimensions, and value for rendering a data
/// label on any series type.
pub type LabelProps {
  LabelProps(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    index: Int,
    value: String,
    offset: Float,
    position: String,
    fill: weft.Color,
  )
}

/// Data passed to a custom pie label render function.
///
/// Extends the standard label props with pie-specific geometry:
/// percent of total, midpoint angle, and middle radius.  Matches
/// the recharts PieLabelRenderProps interface.
pub type PieLabelProps {
  PieLabelProps(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    index: Int,
    value: String,
    offset: Float,
    position: String,
    fill: weft.Color,
    percent: Float,
    mid_angle: Float,
    middle_radius: Float,
  )
}

/// Data passed to a custom pie label line render function.
///
/// Contains the geometry needed to draw a line from a pie sector
/// to its external label.
pub type LabelLineProps {
  LabelLineProps(
    cx: Float,
    cy: Float,
    inner_radius: Float,
    outer_radius: Float,
    mid_angle: Float,
    start_x: Float,
    start_y: Float,
    end_x: Float,
    end_y: Float,
    index: Int,
    fill: weft.Color,
    stroke: weft.Color,
  )
}

/// Data passed to a custom bar shape render function.
///
/// Contains all the geometry and styling needed to render a single
/// bar in a bar chart.
pub type BarShapeProps {
  BarShapeProps(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    index: Int,
    value: Float,
    data_key: String,
    fill: weft.Color,
    stroke: weft.Color,
    radius: Float,
  )
}

/// Data passed to a custom sector render function.
///
/// Contains the geometry needed to render a pie or radial bar sector.
/// Used by Pie `active_shape`/`inactive_shape` and RadialBar
/// `custom_shape`/`active_shape` callbacks.
pub type SectorProps {
  SectorProps(
    cx: Float,
    cy: Float,
    inner_radius: Float,
    outer_radius: Float,
    start_angle: Float,
    end_angle: Float,
    index: Int,
    fill: weft.Color,
    stroke: weft.Color,
  )
}

/// Data passed to a custom trapezoid render function.
///
/// Contains the geometry needed to render a funnel segment as a
/// trapezoid.  Used by Funnel `custom_shape` and `active_shape`
/// callbacks.
pub type TrapezoidProps {
  TrapezoidProps(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    upper_width: Float,
    lower_width: Float,
    index: Int,
  )
}

/// Data passed to a custom treemap node render function.
///
/// Contains the geometry and metadata for rendering a single treemap
/// cell.  Used by Treemap `custom_shape` callback.
pub type TreemapNodeProps {
  TreemapNodeProps(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    depth: Int,
    index: Int,
    name: String,
    value: Float,
  )
}
