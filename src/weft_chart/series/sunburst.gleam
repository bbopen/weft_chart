//// Sunburst chart series component.
////
//// Renders a hierarchical tree as concentric ring sectors.  Each level
//// of the hierarchy occupies a ring, and each node's angular span is
//// proportional to its value relative to the root total.  Supports
//// configurable radii, start/end angles, ring padding, per-node fill
//// colors, and optional text labels.  Matches the recharts
//// SunburstChart component.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/element.{type Element}
import weft_chart/animation.{type AnimationConfig}
import weft_chart/internal/math
import weft_chart/internal/polar
import weft_chart/internal/svg
import weft_chart/shape

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A node in the sunburst hierarchy.
///
/// Each node carries a name, a numeric value, an optional fill color,
/// and a list of children.  Leaf nodes have an empty children list.
/// The value of a parent should equal the sum of its children's values
/// for the angular layout to be visually consistent.
pub type SunburstNode {
  SunburstNode(
    name: String,
    value: Float,
    fill: String,
    children: List(SunburstNode),
  )
}

/// Configuration for a sunburst chart.
///
/// Controls geometry (center, radii, angles), visual style (fill,
/// stroke, ring padding), and optional label rendering.
pub type SunburstConfig {
  SunburstConfig(
    data: SunburstNode,
    cx: Float,
    cy: Float,
    inner_radius: Float,
    outer_radius: Float,
    start_angle: Float,
    end_angle: Float,
    fill: String,
    stroke: String,
    stroke_width: Float,
    ring_padding: Float,
    show_label: Bool,
    fills: List(String),
    legend_type: shape.LegendIconType,
    explicit_width: Option(Int),
    explicit_height: Option(Int),
    css_class: String,
    animation: AnimationConfig,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a sunburst configuration with default settings.
///
/// Defaults match recharts SunburstChart: full 360-degree sweep,
/// inner_radius of 50 (donut hole), outer_radius auto-computed from chart
/// dimensions (0 = sentinel), dark gray fill, labels visible.
pub fn sunburst_config() -> SunburstConfig {
  SunburstConfig(
    data: SunburstNode(name: "", value: 0.0, fill: "", children: []),
    cx: 0.0,
    cy: 0.0,
    inner_radius: 50.0,
    outer_radius: 0.0,
    start_angle: 0.0,
    end_angle: 360.0,
    fill: "#333",
    stroke: "#fff",
    stroke_width: 1.0,
    ring_padding: 2.0,
    show_label: True,
    fills: [],
    legend_type: shape.RectIcon,
    explicit_width: None,
    explicit_height: None,
    css_class: "",
    animation: animation.pie_default(),
  )
}

/// Create a sunburst node with children.
pub fn sunburst_node(
  name name: String,
  value value: Float,
  fill fill: String,
  children children: List(SunburstNode),
) -> SunburstNode {
  SunburstNode(name: name, value: value, fill: fill, children: children)
}

/// Create a sunburst leaf node (no children).
pub fn sunburst_leaf(
  name name: String,
  value value: Float,
  fill fill: String,
) -> SunburstNode {
  SunburstNode(name: name, value: value, fill: fill, children: [])
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the hierarchical data tree.
pub fn sunburst_data(
  config config: SunburstConfig,
  data data: SunburstNode,
) -> SunburstConfig {
  SunburstConfig(..config, data: data)
}

/// Set the center x-coordinate (0 = auto-center from width).
pub fn sunburst_cx(
  config config: SunburstConfig,
  cx cx: Float,
) -> SunburstConfig {
  SunburstConfig(..config, cx: cx)
}

/// Set the center y-coordinate (0 = auto-center from height).
pub fn sunburst_cy(
  config config: SunburstConfig,
  cy cy: Float,
) -> SunburstConfig {
  SunburstConfig(..config, cy: cy)
}

/// Set the inner radius (0 for no central hole).
pub fn sunburst_inner_radius(
  config config: SunburstConfig,
  radius radius: Float,
) -> SunburstConfig {
  SunburstConfig(..config, inner_radius: radius)
}

/// Set the outer radius.
pub fn sunburst_outer_radius(
  config config: SunburstConfig,
  radius radius: Float,
) -> SunburstConfig {
  SunburstConfig(..config, outer_radius: radius)
}

/// Set the start angle in degrees.
pub fn sunburst_start_angle(
  config config: SunburstConfig,
  angle angle: Float,
) -> SunburstConfig {
  SunburstConfig(..config, start_angle: angle)
}

/// Set the end angle in degrees.
pub fn sunburst_end_angle(
  config config: SunburstConfig,
  angle angle: Float,
) -> SunburstConfig {
  SunburstConfig(..config, end_angle: angle)
}

/// Set the default fill color for nodes without an explicit fill.
pub fn sunburst_fill(
  config config: SunburstConfig,
  fill fill: String,
) -> SunburstConfig {
  SunburstConfig(..config, fill: fill)
}

/// Set the stroke color between sectors.
pub fn sunburst_stroke(
  config config: SunburstConfig,
  stroke stroke: String,
) -> SunburstConfig {
  SunburstConfig(..config, stroke: stroke)
}

/// Set the stroke width between sectors.
pub fn sunburst_stroke_width(
  config config: SunburstConfig,
  width width: Float,
) -> SunburstConfig {
  SunburstConfig(..config, stroke_width: width)
}

/// Set the radial padding between concentric rings.
pub fn sunburst_ring_padding(
  config config: SunburstConfig,
  padding padding: Float,
) -> SunburstConfig {
  SunburstConfig(..config, ring_padding: padding)
}

/// Show or hide value labels on sectors.
pub fn sunburst_label(
  config config: SunburstConfig,
  show show: Bool,
) -> SunburstConfig {
  SunburstConfig(..config, show_label: show)
}

/// Set the fill colors cycled across nodes at each depth level.
///
/// When a node has no explicit fill and this list is non-empty,
/// colors are assigned by cycling through this list based on the
/// node's index among its siblings.
pub fn sunburst_fills(
  config config: SunburstConfig,
  fills fills: List(String),
) -> SunburstConfig {
  SunburstConfig(..config, fills: fills)
}

/// Set the legend icon type for this series.
pub fn sunburst_legend_type(
  config config: SunburstConfig,
  icon_type icon_type: shape.LegendIconType,
) -> SunburstConfig {
  SunburstConfig(..config, legend_type: icon_type)
}

/// Set an explicit width override for the sunburst.
/// When provided, uses this value instead of the chart-level width.
pub fn sunburst_explicit_width(
  config config: SunburstConfig,
  width width: Int,
) -> SunburstConfig {
  SunburstConfig(..config, explicit_width: Some(width))
}

/// Set an explicit height override for the sunburst.
/// When provided, uses this value instead of the chart-level height.
pub fn sunburst_explicit_height(
  config config: SunburstConfig,
  height height: Int,
) -> SunburstConfig {
  SunburstConfig(..config, explicit_height: Some(height))
}

/// Set the CSS class applied to the sunburst group element.
pub fn sunburst_css_class(
  config config: SunburstConfig,
  class class: String,
) -> SunburstConfig {
  SunburstConfig(..config, css_class: class)
}

/// Set the animation configuration for sunburst entry effects.
pub fn sunburst_animation(
  config config: SunburstConfig,
  anim anim: AnimationConfig,
) -> SunburstConfig {
  SunburstConfig(..config, animation: anim)
}

// ---------------------------------------------------------------------------
// Sector info (for tooltip payloads)
// ---------------------------------------------------------------------------

/// Centroid position and metadata for a rendered sunburst sector.
///
/// Used by chart containers to build tooltip payloads via `PointZone`
/// hit detection — the same pattern as `PieSectorInfo`.
pub type SunburstSectorInfo {
  SunburstSectorInfo(
    centroid_x: Float,
    centroid_y: Float,
    value: Float,
    fill: String,
    name: String,
    outer_radius: Float,
  )
}

/// Compute centroid positions and metadata for every rendered sector.
///
/// Returns one `SunburstSectorInfo` per non-root node.  Used by
/// `render_sunburst_chart` to build tooltip payloads.
pub fn sunburst_sector_infos(
  config config: SunburstConfig,
  width width: Int,
  height height: Int,
) -> List(SunburstSectorInfo) {
  let effective_width = case config.explicit_width {
    Some(w) -> w
    None -> width
  }
  let effective_height = case config.explicit_height {
    Some(h) -> h
    None -> height
  }
  let w = int.to_float(effective_width)
  let h = int.to_float(effective_height)

  let cx = case config.cx <=. 0.0 {
    True -> w /. 2.0
    False -> config.cx
  }
  let cy = case config.cy <=. 0.0 {
    True -> h /. 2.0
    False -> config.cy
  }

  let root = config.data
  let root_value = root.value

  case root_value <=. 0.0 {
    True -> []
    False -> {
      let outer_radius = case config.outer_radius <=. 0.0 {
        True -> float.min(w, h) /. 2.0
        False -> config.outer_radius
      }
      let inner_radius = config.inner_radius
      let max_depth = get_max_depth(root)
      let ring_thickness = case max_depth == 0 {
        True -> 0.0
        False ->
          float.max(
            { outer_radius -. inner_radius } /. int.to_float(max_depth),
            0.0,
          )
      }
      let angle_range = config.end_angle -. config.start_angle

      collect_sector_infos(
        nodes: root.children,
        depth: 0,
        initial_angle: config.start_angle,
        parent_color: "",
        sibling_offset: 0,
        cx: cx,
        cy: cy,
        inner_radius: inner_radius,
        ring_thickness: ring_thickness,
        ring_padding: config.ring_padding,
        root_value: root_value,
        angle_range: angle_range,
        default_fill: config.fill,
        fills: config.fills,
        outer_radius: outer_radius,
        acc: [],
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a sunburst chart as an SVG group element.
///
/// Computes concentric ring layout from the hierarchy, then renders
/// each node as an arc sector.  Center coordinates default to the
/// middle of the given width/height when config cx/cy are zero.
pub fn render_sunburst(
  config config: SunburstConfig,
  width width: Int,
  height height: Int,
) -> Element(msg) {
  let effective_width = case config.explicit_width {
    Some(w) -> w
    None -> width
  }
  let effective_height = case config.explicit_height {
    Some(h) -> h
    None -> height
  }
  let w = int.to_float(effective_width)
  let h = int.to_float(effective_height)

  let cx = case config.cx <=. 0.0 {
    True -> w /. 2.0
    False -> config.cx
  }
  let cy = case config.cy <=. 0.0 {
    True -> h /. 2.0
    False -> config.cy
  }

  let root = config.data
  let root_value = root.value

  // Empty or zero-value root produces no output
  case root_value <=. 0.0 {
    True -> {
      let class_attr = case config.css_class {
        "" -> "recharts-sunburst"
        c -> "recharts-sunburst " <> c
      }
      svg.g(attrs: [svg.attr("class", class_attr)], children: [])
    }
    False -> {
      let outer_radius = case config.outer_radius <=. 0.0 {
        True -> float.min(w, h) /. 2.0
        False -> config.outer_radius
      }
      let inner_radius = config.inner_radius

      let max_depth = get_max_depth(root)
      let ring_thickness = case max_depth == 0 {
        True -> 0.0
        False ->
          float.max(
            { outer_radius -. inner_radius } /. int.to_float(max_depth),
            0.0,
          )
      }

      let angle_range = config.end_angle -. config.start_angle

      let sectors =
        draw_arcs(
          nodes: root.children,
          depth: 0,
          initial_angle: config.start_angle,
          parent_color: "",
          sibling_offset: 0,
          cx: cx,
          cy: cy,
          inner_radius: inner_radius,
          ring_thickness: ring_thickness,
          ring_padding: config.ring_padding,
          root_value: root_value,
          angle_range: angle_range,
          default_fill: config.fill,
          fills: config.fills,
          stroke: config.stroke,
          stroke_width: config.stroke_width,
          show_label: config.show_label,
          anim: config.animation,
          acc: [],
        )

      let class_attr = case config.css_class {
        "" -> "recharts-sunburst"
        c -> "recharts-sunburst " <> c
      }
      svg.g(
        attrs: [svg.attr("class", class_attr)],
        children: list.reverse(sectors),
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Internal: recursive arc drawing
// ---------------------------------------------------------------------------

/// Recursively draw arc sectors for a list of sibling nodes.
///
/// Each node gets an angular span proportional to its value relative
/// to the root total.  Children are drawn one ring further out.
fn draw_arcs(
  nodes nodes: List(SunburstNode),
  depth depth: Int,
  initial_angle initial_angle: Float,
  parent_color parent_color: String,
  sibling_offset sibling_offset: Int,
  cx cx: Float,
  cy cy: Float,
  inner_radius inner_radius: Float,
  ring_thickness ring_thickness: Float,
  ring_padding ring_padding: Float,
  root_value root_value: Float,
  angle_range angle_range: Float,
  default_fill default_fill: String,
  fills fills: List(String),
  stroke stroke: String,
  stroke_width stroke_width: Float,
  show_label show_label: Bool,
  anim anim: AnimationConfig,
  acc acc: List(Element(msg)),
) -> List(Element(msg)) {
  case nodes {
    [] -> acc
    [node, ..rest] -> {
      // Compute arc length for this node
      let arc_length = case root_value <=. 0.0 {
        True -> 0.0
        False -> node.value /. root_value *. angle_range
      }

      let sa = initial_angle
      let ea = initial_angle +. arc_length

      // Compute ring radii for this depth
      let inner_r =
        inner_radius
        +. int.to_float(depth)
        *. { ring_thickness +. ring_padding }
      let outer_r = inner_r +. ring_thickness

      // Resolve fill: node.fill > cycle fills > parent color > default
      let fill_color =
        resolve_fill(
          node_fill: node.fill,
          parent_color: parent_color,
          fills: fills,
          index: sibling_offset,
          default: default_fill,
        )

      // Render the sector arc.
      // recharts uses cos(-RADIAN*angle), so angle=0=East, increasing=CCW.
      // weft_chart uses angle=0=North, increasing=CW.
      // Transform: polar_angle = 90 - recharts_angle → maps 0→90(East), flips to CCW.
      let polar_sa = 90.0 -. sa
      let polar_ea = 90.0 -. ea
      let sector_d =
        polar.sector_path(
          cx: cx,
          cy: cy,
          inner_radius: inner_r,
          outer_radius: outer_r,
          start_angle: polar_sa,
          end_angle: polar_ea,
        )
      let sector_el = case anim.active {
        False ->
          svg.path(d: sector_d, attrs: [
            svg.attr("fill", fill_color),
            svg.attr("stroke", stroke),
            svg.attr("stroke-width", fmt(stroke_width)),
          ])
        True -> {
          let path_fn = fn(progress) {
            let animated_end = polar_sa +. progress *. { polar_ea -. polar_sa }
            polar.sector_path(
              cx: cx,
              cy: cy,
              inner_radius: inner_r,
              outer_radius: outer_r,
              start_angle: polar_sa,
              end_angle: animated_end,
            )
          }
          let initial_d =
            polar.sector_path(
              cx: cx,
              cy: cy,
              inner_radius: inner_r,
              outer_radius: outer_r,
              start_angle: polar_sa,
              end_angle: polar_sa -. 0.001,
            )
          let animate_el =
            animation.animate_path(
              path_at_progress: path_fn,
              config: anim,
              steps: 30,
            )
          svg.path_with_children(
            d: initial_d,
            attrs: [
              svg.attr("fill", fill_color),
              svg.attr("stroke", stroke),
              svg.attr("stroke-width", fmt(stroke_width)),
            ],
            children: [animate_el],
          )
        }
      }

      // Optional label at arc midpoint
      let label_el = case show_label {
        False -> []
        True -> {
          let polar_mid = 90.0 -. { sa +. ea } /. 2.0
          let mid_r = { inner_r +. outer_r } /. 2.0
          let #(tx, ty) =
            polar.to_cartesian(
              cx: cx,
              cy: cy,
              radius: mid_r,
              angle_degrees: polar_mid,
            )
          [
            svg.text(
              x: fmt(tx),
              y: fmt(ty),
              content: float.to_string(node.value),
              attrs: [
                svg.attr("text-anchor", "middle"),
                svg.attr("dominant-baseline", "central"),
                svg.attr("font-size", "0.75rem"),
                svg.attr("font-weight", "bold"),
                svg.attr("fill", "black"),
                svg.attr("stroke", "#FFF"),
                svg.attr("paint-order", "stroke fill"),
                svg.attr("pointer-events", "none"),
              ],
            ),
          ]
        }
      }

      let group_el =
        svg.g(attrs: [svg.attr("aria-label", node.name)], children: [
          sector_el,
          ..label_el
        ])

      // Accumulate this node's element
      let acc1 = [group_el, ..acc]

      // Recurse into children (one ring deeper, starting at same angle)
      let acc2 =
        draw_arcs(
          nodes: node.children,
          depth: depth + 1,
          initial_angle: sa,
          parent_color: fill_color,
          sibling_offset: 0,
          cx: cx,
          cy: cy,
          inner_radius: inner_radius,
          ring_thickness: ring_thickness,
          ring_padding: ring_padding,
          root_value: root_value,
          angle_range: angle_range,
          default_fill: default_fill,
          fills: fills,
          stroke: stroke,
          stroke_width: stroke_width,
          show_label: show_label,
          anim: anim,
          acc: acc1,
        )

      // Continue to next sibling, advancing the angle
      draw_arcs(
        nodes: rest,
        depth: depth,
        initial_angle: ea,
        parent_color: parent_color,
        sibling_offset: sibling_offset + 1,
        cx: cx,
        cy: cy,
        inner_radius: inner_radius,
        ring_thickness: ring_thickness,
        ring_padding: ring_padding,
        root_value: root_value,
        angle_range: angle_range,
        default_fill: default_fill,
        fills: fills,
        stroke: stroke,
        stroke_width: stroke_width,
        show_label: show_label,
        anim: anim,
        acc: acc2,
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Internal: recursive sector info collection
// ---------------------------------------------------------------------------

/// Recursively collect sector centroid info for tooltip payloads.
fn collect_sector_infos(
  nodes nodes: List(SunburstNode),
  depth depth: Int,
  initial_angle initial_angle: Float,
  parent_color parent_color: String,
  sibling_offset sibling_offset: Int,
  cx cx: Float,
  cy cy: Float,
  inner_radius inner_radius: Float,
  ring_thickness ring_thickness: Float,
  ring_padding ring_padding: Float,
  root_value root_value: Float,
  angle_range angle_range: Float,
  default_fill default_fill: String,
  fills fills: List(String),
  outer_radius outer_radius: Float,
  acc acc: List(SunburstSectorInfo),
) -> List(SunburstSectorInfo) {
  case nodes {
    [] -> acc
    [node, ..rest] -> {
      let arc_length = case root_value <=. 0.0 {
        True -> 0.0
        False -> node.value /. root_value *. angle_range
      }
      let sa = initial_angle
      let ea = sa +. arc_length

      let inner_r =
        inner_radius
        +. int.to_float(depth)
        *. { ring_thickness +. ring_padding }
      let outer_r = inner_r +. ring_thickness

      let fill_color =
        resolve_fill(
          node_fill: node.fill,
          parent_color: parent_color,
          fills: fills,
          index: sibling_offset,
          default: default_fill,
        )

      let mid_angle = { sa +. ea } /. 2.0
      let polar_mid = 90.0 -. mid_angle
      let mid_r = { inner_r +. outer_r } /. 2.0
      let #(cx_pt, cy_pt) =
        polar.to_cartesian(
          cx: cx,
          cy: cy,
          radius: mid_r,
          angle_degrees: polar_mid,
        )

      let info =
        SunburstSectorInfo(
          centroid_x: cx_pt,
          centroid_y: cy_pt,
          value: node.value,
          fill: fill_color,
          name: node.name,
          outer_radius: outer_radius,
        )

      let acc1 = [info, ..acc]

      let acc2 =
        collect_sector_infos(
          nodes: node.children,
          depth: depth + 1,
          initial_angle: sa,
          parent_color: fill_color,
          sibling_offset: 0,
          cx: cx,
          cy: cy,
          inner_radius: inner_radius,
          ring_thickness: ring_thickness,
          ring_padding: ring_padding,
          root_value: root_value,
          angle_range: angle_range,
          default_fill: default_fill,
          fills: fills,
          outer_radius: outer_radius,
          acc: acc1,
        )

      collect_sector_infos(
        nodes: rest,
        depth: depth,
        initial_angle: ea,
        parent_color: parent_color,
        sibling_offset: sibling_offset + 1,
        cx: cx,
        cy: cy,
        inner_radius: inner_radius,
        ring_thickness: ring_thickness,
        ring_padding: ring_padding,
        root_value: root_value,
        angle_range: angle_range,
        default_fill: default_fill,
        fills: fills,
        outer_radius: outer_radius,
        acc: acc2,
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Internal: tree depth computation
// ---------------------------------------------------------------------------

/// Compute the maximum depth of a sunburst tree.
///
/// A leaf node has depth 1.  The root's depth is 1 + max child depth.
fn get_max_depth(node: SunburstNode) -> Int {
  case node.children {
    [] -> 1
    children -> {
      let child_depths = list.map(children, get_max_depth)
      1 + list_max_int(child_depths)
    }
  }
}

// ---------------------------------------------------------------------------
// Internal: helpers
// ---------------------------------------------------------------------------

/// Resolve the fill color for a node using priority chain:
/// node.fill > cycle through fills list > parent color > default.
fn resolve_fill(
  node_fill node_fill: String,
  parent_color parent_color: String,
  fills fills: List(String),
  index index: Int,
  default default: String,
) -> String {
  case node_fill {
    "" ->
      case fills {
        [] ->
          case parent_color {
            "" -> default
            _ -> parent_color
          }
        _ -> cycle_fill(fills, index)
      }
    _ -> node_fill
  }
}

/// Cycle through a list of fill colors by index.
fn cycle_fill(fills: List(String), index: Int) -> String {
  let n = list.length(fills)
  case n == 0 {
    True -> "currentColor"
    False -> {
      let target = index % n
      find_at(fills, target, 0, "currentColor")
    }
  }
}

/// Find the element at a given index in a list.
fn find_at(
  items: List(String),
  target: Int,
  current: Int,
  default: String,
) -> String {
  case items {
    [] -> default
    [first, ..rest] ->
      case current == target {
        True -> first
        False -> find_at(rest, target, current + 1, default)
      }
  }
}

/// Find the maximum value in a list of integers.
fn list_max_int(values: List(Int)) -> Int {
  case values {
    [] -> 0
    [first, ..rest] ->
      list.fold(rest, first, fn(acc, v) {
        case v > acc {
          True -> v
          False -> acc
        }
      })
  }
}

/// Format a float for SVG attributes.
fn fmt(value: Float) -> String {
  math.fmt(value)
}
