//// Sankey diagram series component.
////
//// Renders a Sankey flow diagram with nodes as rectangles and links as
//// curved bands showing flow between nodes.  The layout algorithm uses
//// iterative relaxation to position nodes vertically and computes
//// horizontal positions via BFS depth assignment.  Matches the recharts
//// Sankey component.

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import lustre/element.{type Element}
import weft_chart/animation.{type AnimationConfig}
import weft_chart/internal/math
import weft_chart/internal/svg
import weft_chart/shape

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A node in the Sankey diagram.
pub type SankeyNode {
  SankeyNode(name: String)
}

/// A link between two nodes in the Sankey diagram.
pub type SankeyLink {
  SankeyLink(source: Int, target: Int, value: Float)
}

/// Input data for a Sankey diagram.
pub type SankeyData {
  SankeyData(nodes: List(SankeyNode), links: List(SankeyLink))
}

/// Properties passed to a custom node renderer.
pub type SankeyNodeProps {
  SankeyNodeProps(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    index: Int,
    name: String,
    value: Float,
    fill: String,
  )
}

/// Properties passed to a custom link renderer.
pub type SankeyLinkProps {
  SankeyLinkProps(
    source_x: Float,
    source_y: Float,
    target_x: Float,
    target_y: Float,
    link_width: Float,
    index: Int,
    fill: String,
    fill_opacity: Float,
  )
}

/// Configuration for a Sankey diagram.
pub type SankeyConfig(msg) {
  SankeyConfig(
    data: SankeyData,
    node_width: Float,
    node_padding: Float,
    iterations: Int,
    link_stroke: String,
    link_stroke_opacity: Float,
    link_curvature: Float,
    node_fills: List(String),
    show_label: Bool,
    legend_type: shape.LegendIconType,
    margin_top: Float,
    margin_right: Float,
    margin_bottom: Float,
    margin_left: Float,
    explicit_width: Option(Int),
    explicit_height: Option(Int),
    sort_fn: Option(fn(SankeyNode, SankeyNode) -> order.Order),
    custom_node: Option(fn(SankeyNodeProps) -> Element(msg)),
    custom_link: Option(fn(SankeyLinkProps) -> Element(msg)),
    css_class: String,
    animation: AnimationConfig,
  )
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a Sankey configuration with default settings.
///
/// Defaults match recharts Sankey: node_width=10.0, node_padding=10.0,
/// iterations=32, link_stroke="#333", link_stroke_opacity=0.2,
/// link_curvature=0.5, node_fills=["#0088fe"], show_label=True,
/// margins=5.0, custom_node=None, custom_link=None.
pub fn sankey_config(data data: SankeyData) -> SankeyConfig(msg) {
  SankeyConfig(
    data: data,
    node_width: 10.0,
    node_padding: 10.0,
    iterations: 32,
    link_stroke: "#333",
    link_stroke_opacity: 0.2,
    link_curvature: 0.5,
    node_fills: ["#0088fe"],
    show_label: True,
    legend_type: shape.RectIcon,
    margin_top: 5.0,
    margin_right: 5.0,
    margin_bottom: 5.0,
    margin_left: 5.0,
    explicit_width: None,
    explicit_height: None,
    sort_fn: None,
    custom_node: None,
    custom_link: None,
    css_class: "",
    animation: animation.with_active(
      config: animation.line_default(),
      active: False,
    ),
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the node width in pixels.
pub fn sankey_node_width(
  config config: SankeyConfig(msg),
  width width: Float,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, node_width: width)
}

/// Set the vertical padding between nodes in pixels.
pub fn sankey_node_padding(
  config config: SankeyConfig(msg),
  padding padding: Float,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, node_padding: padding)
}

/// Set the number of layout relaxation iterations.
pub fn sankey_iterations(
  config config: SankeyConfig(msg),
  iterations iterations: Int,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, iterations: iterations)
}

/// Set the link stroke color.
pub fn sankey_link_stroke(
  config config: SankeyConfig(msg),
  stroke stroke: String,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, link_stroke: stroke)
}

/// Set the link stroke opacity (0.0 to 1.0).
pub fn sankey_link_stroke_opacity(
  config config: SankeyConfig(msg),
  opacity opacity: Float,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, link_stroke_opacity: opacity)
}

/// Set the fill colors for nodes (cycled if fewer than node count).
pub fn sankey_node_fills(
  config config: SankeyConfig(msg),
  fills fills: List(String),
) -> SankeyConfig(msg) {
  SankeyConfig(..config, node_fills: fills)
}

/// Set whether to show text labels beside nodes.
pub fn sankey_show_label(
  config config: SankeyConfig(msg),
  show show: Bool,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, show_label: show)
}

/// Set the legend icon type for this series.
pub fn sankey_legend_type(
  config config: SankeyConfig(msg),
  icon_type icon_type: shape.LegendIconType,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, legend_type: icon_type)
}

/// Set the top margin in pixels.
pub fn sankey_margin_top(
  config config: SankeyConfig(msg),
  margin margin: Float,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, margin_top: margin)
}

/// Set the right margin in pixels.
pub fn sankey_margin_right(
  config config: SankeyConfig(msg),
  margin margin: Float,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, margin_right: margin)
}

/// Set the bottom margin in pixels.
pub fn sankey_margin_bottom(
  config config: SankeyConfig(msg),
  margin margin: Float,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, margin_bottom: margin)
}

/// Set the left margin in pixels.
pub fn sankey_margin_left(
  config config: SankeyConfig(msg),
  margin margin: Float,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, margin_left: margin)
}

/// Set an explicit width override for the Sankey diagram.
/// When provided, uses this value instead of the chart-level width.
pub fn sankey_explicit_width(
  config config: SankeyConfig(msg),
  width width: Int,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, explicit_width: Some(width))
}

/// Set an explicit height override for the Sankey diagram.
/// When provided, uses this value instead of the chart-level height.
pub fn sankey_explicit_height(
  config config: SankeyConfig(msg),
  height height: Int,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, explicit_height: Some(height))
}

/// Set a custom sorting function for Sankey nodes.
/// When provided, nodes within each depth column are sorted using
/// this comparison function instead of the default value-based ordering.
pub fn sankey_sort_fn(
  config config: SankeyConfig(msg),
  sort sort: fn(SankeyNode, SankeyNode) -> order.Order,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, sort_fn: Some(sort))
}

/// Set the CSS class applied to the Sankey group element.
pub fn sankey_css_class(
  config config: SankeyConfig(msg),
  class class: String,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, css_class: class)
}

/// Set the animation configuration for Sankey entry effects.
pub fn sankey_animation(
  config config: SankeyConfig(msg),
  animation anim: AnimationConfig,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, animation: anim)
}

/// Set the link curvature for cubic bezier paths.
///
/// Controls how curved the links are between nodes.
/// 0.0 produces straight lines, 1.0 produces sharp curves.
/// Default is 0.5 (matching recharts).
pub fn sankey_link_curvature(
  config config: SankeyConfig(msg),
  curvature curvature: Float,
) -> SankeyConfig(msg) {
  SankeyConfig(..config, link_curvature: curvature)
}

/// Set a custom node render function.
///
/// When set, called for each node instead of the default rectangle.
pub fn sankey_custom_node(
  config config: SankeyConfig(msg),
  renderer renderer: fn(SankeyNodeProps) -> Element(msg),
) -> SankeyConfig(msg) {
  SankeyConfig(..config, custom_node: Some(renderer))
}

/// Set a custom link render function.
///
/// When set, called for each link instead of the default path.
pub fn sankey_custom_link(
  config config: SankeyConfig(msg),
  renderer renderer: fn(SankeyLinkProps) -> Element(msg),
) -> SankeyConfig(msg) {
  SankeyConfig(..config, custom_link: Some(renderer))
}

// ---------------------------------------------------------------------------
// Tooltip hit-zone info
// ---------------------------------------------------------------------------

/// Information about a Sankey node used to position tooltip hit zones.
///
/// Centroid coordinates are in SVG space (margin offsets included).
/// Zone dimensions equal the rendered node rectangle for per-node hit areas.
pub type SankeyHitInfo {
  SankeyHitInfo(
    centroid_x: Float,
    centroid_y: Float,
    name: String,
    value: Float,
    fill: String,
    node_width: Float,
    node_height: Float,
  )
}

/// Compute tooltip hit-zone information for every node in the Sankey layout.
///
/// Runs the same layout algorithm as `render_sankey`, then returns one
/// `SankeyHitInfo` per node with centroid coordinates (in SVG space,
/// including margin offsets) and node dimensions.  Used by the chart
/// container to build `PointZone` tooltip payloads.
pub fn sankey_hit_infos(
  config config: SankeyConfig(msg),
  width width: Int,
  height height: Int,
) -> List(SankeyHitInfo) {
  let effective_width = case config.explicit_width {
    Some(ew) -> ew
    None -> width
  }
  let effective_height = case config.explicit_height {
    Some(eh) -> eh
    None -> height
  }
  let w = int.to_float(effective_width)
  let h = int.to_float(effective_height)
  let content_w = w -. config.margin_left -. config.margin_right
  let content_h = h -. config.margin_top -. config.margin_bottom

  case content_w <=. 0.0 || content_h <=. 0.0 {
    True -> []
    False -> {
      let #(nodes, _links) =
        compute_layout(
          data: config.data,
          width: content_w,
          height: content_h,
          node_width: config.node_width,
          node_padding: config.node_padding,
          iterations: config.iterations,
          sort_fn: config.sort_fn,
        )

      let node_list =
        dict.values(nodes)
        |> list.sort(fn(a, b) { int.compare(a.index, b.index) })

      list.map(node_list, fn(node) {
        let fill = cycle_fill(config.node_fills, node.index)
        // Expand the hit zone width to cover the node rect + label area.
        // Nodes are only node_width (10px) wide by default — too narrow to
        // hover reliably.  Adding 50px covers a typical node label ("Name: 60")
        // placed to the right of the rect at node.x + node_width + 6.
        let zone_w = float.max(node.width +. 50.0, 50.0)
        SankeyHitInfo(
          centroid_x: config.margin_left +. node.x +. node.width /. 2.0,
          centroid_y: config.margin_top +. node.y +. node.height /. 2.0,
          name: node.name,
          value: node.value,
          fill: fill,
          node_width: zone_w,
          node_height: node.height,
        )
      })
    }
  }
}

/// Compute tooltip hit-zone information for every link in the Sankey layout.
///
/// Runs the same layout algorithm as `render_sankey`, then returns one
/// `SankeyHitInfo` per link positioned at the bezier path midpoint.
/// The `name` field uses `"source - target"` format to match recharts.
/// Zone dimensions span the full horizontal gap between columns.
pub fn sankey_link_hit_infos(
  config config: SankeyConfig(msg),
  width width: Int,
  height height: Int,
) -> List(SankeyHitInfo) {
  let effective_width = case config.explicit_width {
    Some(ew) -> ew
    None -> width
  }
  let effective_height = case config.explicit_height {
    Some(eh) -> eh
    None -> height
  }
  let w = int.to_float(effective_width)
  let h = int.to_float(effective_height)
  let content_w = w -. config.margin_left -. config.margin_right
  let content_h = h -. config.margin_top -. config.margin_bottom

  case content_w <=. 0.0 || content_h <=. 0.0 {
    True -> []
    False -> {
      let #(nodes, links) =
        compute_layout(
          data: config.data,
          width: content_w,
          height: content_h,
          node_width: config.node_width,
          node_padding: config.node_padding,
          iterations: config.iterations,
          sort_fn: config.sort_fn,
        )

      list.map(links, fn(link) {
        let source_node = dict_get_or_default(nodes, link.source)
        let target_node = dict_get_or_default(nodes, link.target)
        let source_x = source_node.x +. config.node_width
        let link_w = link.width
        let source_y = source_node.y +. link.source_y +. link_w /. 2.0
        let target_x = target_node.x
        let target_y = target_node.y +. link.target_y +. link_w /. 2.0

        // Bezier midpoint: midpoint between the two endpoints
        let mid_x = { source_x +. target_x } /. 2.0
        let mid_y = { source_y +. target_y } /. 2.0

        // Zone spans the full horizontal gap between the two columns
        // so hovering anywhere along the link path triggers the tooltip.
        let zone_w = float.max(target_x -. source_x, 40.0)
        // Zone height matches the link stroke width (at least 20px to hover)
        let zone_h = float.max(link_w, 20.0)

        SankeyHitInfo(
          centroid_x: config.margin_left +. mid_x,
          centroid_y: config.margin_top +. mid_y,
          name: source_node.name <> " - " <> target_node.name,
          value: link.value,
          fill: config.link_stroke,
          node_width: zone_w,
          node_height: zone_h,
        )
      })
    }
  }
}

// ---------------------------------------------------------------------------
// Internal types
// ---------------------------------------------------------------------------

type LayoutNode {
  LayoutNode(
    index: Int,
    name: String,
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    value: Float,
    depth: Int,
    source_links: List(Int),
    target_links: List(Int),
  )
}

type LayoutLink {
  LayoutLink(
    source: Int,
    target: Int,
    value: Float,
    width: Float,
    source_y: Float,
    target_y: Float,
  )
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a Sankey diagram given configuration, width, and height.
///
/// Runs the Sankey layout algorithm to position nodes and links, then
/// renders SVG rectangles for nodes and cubic bezier paths for links.
pub fn render_sankey(
  config config: SankeyConfig(msg),
  width width: Int,
  height height: Int,
) -> Element(msg) {
  let effective_width = case config.explicit_width {
    Some(ew) -> ew
    None -> width
  }
  let effective_height = case config.explicit_height {
    Some(eh) -> eh
    None -> height
  }
  let w = int.to_float(effective_width)
  let h = int.to_float(effective_height)
  let content_w = w -. config.margin_left -. config.margin_right
  let content_h = h -. config.margin_top -. config.margin_bottom

  case content_w <=. 0.0 || content_h <=. 0.0 {
    True -> element.none()
    False -> {
      let #(nodes, links) =
        compute_layout(
          data: config.data,
          width: content_w,
          height: content_h,
          node_width: config.node_width,
          node_padding: config.node_padding,
          iterations: config.iterations,
          sort_fn: config.sort_fn,
        )

      let link_els = render_links(links: links, nodes: nodes, config: config)

      let node_els = render_nodes(nodes: nodes, config: config)

      let class_attr = case config.css_class {
        "" -> "recharts-sankey"
        c -> "recharts-sankey " <> c
      }
      svg.g(
        attrs: [
          svg.attr("class", class_attr),
          svg.attr(
            "transform",
            "translate("
              <> math.fmt(config.margin_left)
              <> ","
              <> math.fmt(config.margin_top)
              <> ")",
          ),
        ],
        children: [link_els, node_els],
      )
    }
  }
}

fn render_links(
  links links: List(LayoutLink),
  nodes nodes: Dict(Int, LayoutNode),
  config config: SankeyConfig(msg),
) -> Element(msg) {
  let children =
    list.index_map(links, fn(link, i) {
      let source_node = dict_get_or_default(nodes, link.source)
      let target_node = dict_get_or_default(nodes, link.target)

      let source_x = source_node.x +. config.node_width
      // Use link midpoint Y (top edge + half width) to match recharts rendering:
      // recharts: sourceY = node.y + link.sy + link.dy/2
      let link_w = link.width
      let source_y = source_node.y +. link.source_y +. link_w /. 2.0
      let target_x = target_node.x
      let target_y = target_node.y +. link.target_y +. link_w /. 2.0

      case config.custom_link {
        Some(renderer) ->
          renderer(SankeyLinkProps(
            source_x: source_x,
            source_y: source_y,
            target_x: target_x,
            target_y: target_y,
            link_width: link_w,
            index: i,
            fill: config.link_stroke,
            fill_opacity: config.link_stroke_opacity,
          ))
        None -> {
          let curvature = config.link_curvature
          let dx = target_x -. source_x
          let source_ctrl_x = source_x +. dx *. curvature
          let target_ctrl_x = target_x -. dx *. curvature

          // Single cubic bezier with thick stroke — matches recharts renderLinkItem:
          // M{sx},{sy} C{ctrl1},{sy} {ctrl2},{ty} {tx},{ty}
          // fill="none" stroke=color strokeWidth=linkWidth strokeOpacity=opacity
          let d =
            "M"
            <> math.fmt(source_x)
            <> ","
            <> math.fmt(source_y)
            <> " C"
            <> math.fmt(source_ctrl_x)
            <> ","
            <> math.fmt(source_y)
            <> " "
            <> math.fmt(target_ctrl_x)
            <> ","
            <> math.fmt(target_y)
            <> " "
            <> math.fmt(target_x)
            <> ","
            <> math.fmt(target_y)

          let link_path_el =
            svg.path(d: d, attrs: [
              svg.attr("fill", "none"),
              svg.attr("stroke", config.link_stroke),
              svg.attr("stroke-width", math.fmt(link_w)),
              svg.attr("stroke-opacity", math.fmt(config.link_stroke_opacity)),
              svg.attr("class", "recharts-sankey-link"),
            ])
          case config.animation.active {
            False -> link_path_el
            True ->
              svg.g(attrs: [svg.attr("opacity", "0")], children: [
                link_path_el,
                animation.animate_attribute(
                  name: "opacity",
                  from: 0.0,
                  to: 1.0,
                  config: config.animation,
                ),
              ])
          }
        }
      }
    })

  svg.g(attrs: [svg.attr("class", "recharts-sankey-links")], children: children)
}

fn render_nodes(
  nodes nodes: Dict(Int, LayoutNode),
  config config: SankeyConfig(msg),
) -> Element(msg) {
  let node_list =
    dict.values(nodes)
    |> list.sort(fn(a, b) { int.compare(a.index, b.index) })

  let children =
    list.map(node_list, fn(node) {
      let fill = cycle_fill(config.node_fills, node.index)

      case config.custom_node {
        Some(renderer) ->
          renderer(SankeyNodeProps(
            x: node.x,
            y: node.y,
            width: node.width,
            height: node.height,
            index: node.index,
            name: node.name,
            value: node.value,
            fill: fill,
          ))
        None -> {
          let node_attrs = [
            svg.attr("fill", fill),
            svg.attr("fill-opacity", "0.8"),
            svg.attr("class", "recharts-sankey-node"),
          ]
          let rect_el = case config.animation.active {
            False ->
              svg.rect(
                x: math.fmt(node.x),
                y: math.fmt(node.y),
                width: math.fmt(node.width),
                height: math.fmt(node.height),
                attrs: node_attrs,
              )
            True ->
              svg.rect_with_children(
                x: math.fmt(node.x),
                y: math.fmt(node.y),
                width: "0",
                height: math.fmt(node.height),
                attrs: node_attrs,
                children: [
                  animation.animate_attribute(
                    name: "width",
                    from: 0.0,
                    to: node.width,
                    config: config.animation,
                  ),
                ],
              )
          }

          case config.show_label {
            False -> rect_el
            True -> {
              let label_x = node.x +. node.width +. 6.0
              let label_y = node.y +. node.height /. 2.0

              svg.g(attrs: [], children: [
                rect_el,
                svg.text(
                  x: math.fmt(label_x),
                  y: math.fmt(label_y),
                  content: node.name,
                  attrs: [
                    svg.attr("dominant-baseline", "central"),
                    svg.attr("font-size", "12"),
                    svg.attr("class", "recharts-sankey-node-label"),
                  ],
                ),
              ])
            }
          }
        }
      }
    })

  svg.g(attrs: [svg.attr("class", "recharts-sankey-nodes")], children: children)
}

// ---------------------------------------------------------------------------
// Layout algorithm
// ---------------------------------------------------------------------------

fn compute_layout(
  data data: SankeyData,
  width width: Float,
  height height: Float,
  node_width node_width: Float,
  node_padding node_padding: Float,
  iterations iterations: Int,
  sort_fn sort_fn: Option(fn(SankeyNode, SankeyNode) -> order.Order),
) -> #(Dict(Int, LayoutNode), List(LayoutLink)) {
  let input_links = data.links

  // Step 1: Build initial nodes with source/target link indices and values
  let nodes = build_initial_nodes(data.nodes, input_links)

  // Step 2: Compute depths via BFS from source nodes
  let nodes = compute_depths(nodes, input_links)

  // Step 3: Push leaf nodes (no outgoing links) to max depth
  let max_depth = dict_max_depth(nodes)
  let nodes = push_leaves_to_max_depth(nodes, max_depth)

  // Step 4: Position nodes horizontally
  let nodes = position_x(nodes, width, node_width, max_depth)

  // Step 5: Compute y ratio and initial vertical layout
  let #(nodes, layout_links) =
    initialize_vertical(
      nodes,
      input_links,
      data.nodes,
      height,
      node_padding,
      sort_fn,
    )

  // Step 6: Resolve initial collisions
  let nodes = resolve_all_collisions(nodes, height, node_padding, max_depth)

  // Step 7: Iterative relaxation
  let nodes =
    iterate_relaxation(
      nodes: nodes,
      input_links: input_links,
      height: height,
      node_padding: node_padding,
      max_depth: max_depth,
      iterations_remaining: iterations,
      alpha: 1.0,
    )

  // Step 8: Compute link vertical positions
  let final_links = compute_link_positions(nodes, layout_links)

  #(nodes, final_links)
}

fn build_initial_nodes(
  nodes: List(SankeyNode),
  links: List(SankeyLink),
) -> Dict(Int, LayoutNode) {
  list.index_map(nodes, fn(node, i) {
    let #(source_link_indices, target_link_indices) =
      find_links_for_node(links, i)

    let source_sum = sum_link_values_by_indices(links, source_link_indices)
    let target_sum = sum_link_values_by_indices(links, target_link_indices)

    let value = case source_sum >. target_sum {
      True -> source_sum
      False -> target_sum
    }

    #(
      i,
      LayoutNode(
        index: i,
        name: node.name,
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
        value: value,
        depth: 0,
        source_links: source_link_indices,
        target_links: target_link_indices,
      ),
    )
  })
  |> dict.from_list
}

fn find_links_for_node(
  links: List(SankeyLink),
  node_index: Int,
) -> #(List(Int), List(Int)) {
  find_links_for_node_loop(links, node_index, 0, [], [])
}

fn find_links_for_node_loop(
  links: List(SankeyLink),
  node_index: Int,
  link_index: Int,
  source_acc: List(Int),
  target_acc: List(Int),
) -> #(List(Int), List(Int)) {
  case links {
    [] -> #(list.reverse(source_acc), list.reverse(target_acc))
    [link, ..rest] -> {
      let new_source = case link.target == node_index {
        True -> [link_index, ..source_acc]
        False -> source_acc
      }
      let new_target = case link.source == node_index {
        True -> [link_index, ..target_acc]
        False -> target_acc
      }
      find_links_for_node_loop(
        rest,
        node_index,
        link_index + 1,
        new_source,
        new_target,
      )
    }
  }
}

fn sum_link_values_by_indices(
  links: List(SankeyLink),
  indices: List(Int),
) -> Float {
  list.fold(indices, 0.0, fn(acc, idx) { acc +. get_link_value_at(links, idx) })
}

fn get_link_value_at(links: List(SankeyLink), index: Int) -> Float {
  get_link_value_at_loop(links, index, 0)
}

fn get_link_value_at_loop(
  links: List(SankeyLink),
  target: Int,
  current: Int,
) -> Float {
  case links {
    [] -> 0.0
    [link, ..rest] ->
      case current == target {
        True -> link.value
        False -> get_link_value_at_loop(rest, target, current + 1)
      }
  }
}

// ---------------------------------------------------------------------------
// Depth computation (BFS from sources)
// ---------------------------------------------------------------------------

fn compute_depths(
  nodes: Dict(Int, LayoutNode),
  links: List(SankeyLink),
) -> Dict(Int, LayoutNode) {
  // Find source nodes (no incoming links)
  let source_indices =
    dict.fold(nodes, [], fn(acc, idx, node) {
      case list.is_empty(node.source_links) {
        True -> [idx, ..acc]
        False -> acc
      }
    })

  // BFS: propagate depths from sources
  propagate_depths(nodes, source_indices, links)
}

fn propagate_depths(
  nodes: Dict(Int, LayoutNode),
  queue: List(Int),
  links: List(SankeyLink),
) -> Dict(Int, LayoutNode) {
  case queue {
    [] -> nodes
    [node_idx, ..rest] -> {
      let node = dict_get_or_default(nodes, node_idx)
      let #(updated_nodes, new_queue) =
        update_target_depths(nodes, node, links, node.target_links, rest)
      propagate_depths(updated_nodes, new_queue, links)
    }
  }
}

fn update_target_depths(
  nodes: Dict(Int, LayoutNode),
  source_node: LayoutNode,
  links: List(SankeyLink),
  target_link_indices: List(Int),
  queue: List(Int),
) -> #(Dict(Int, LayoutNode), List(Int)) {
  case target_link_indices {
    [] -> #(nodes, queue)
    [link_idx, ..rest_links] -> {
      let link = get_sankey_link_at(links, link_idx)
      let target_idx = link.target
      let target_node = dict_get_or_default(nodes, target_idx)
      let new_depth = source_node.depth + 1
      case new_depth > target_node.depth {
        True -> {
          let updated =
            dict.insert(
              nodes,
              target_idx,
              LayoutNode(..target_node, depth: new_depth),
            )
          update_target_depths(updated, source_node, links, rest_links, [
            target_idx,
            ..queue
          ])
        }
        False ->
          update_target_depths(nodes, source_node, links, rest_links, queue)
      }
    }
  }
}

fn get_sankey_link_at(links: List(SankeyLink), index: Int) -> SankeyLink {
  get_sankey_link_at_loop(links, index, 0)
}

fn get_sankey_link_at_loop(
  links: List(SankeyLink),
  target: Int,
  current: Int,
) -> SankeyLink {
  case links {
    [] -> SankeyLink(source: 0, target: 0, value: 0.0)
    [link, ..rest] ->
      case current == target {
        True -> link
        False -> get_sankey_link_at_loop(rest, target, current + 1)
      }
  }
}

fn dict_max_depth(nodes: Dict(Int, LayoutNode)) -> Int {
  dict.fold(nodes, 0, fn(acc, _idx, node) {
    case node.depth > acc {
      True -> node.depth
      False -> acc
    }
  })
}

fn push_leaves_to_max_depth(
  nodes: Dict(Int, LayoutNode),
  max_depth: Int,
) -> Dict(Int, LayoutNode) {
  dict.map_values(nodes, fn(_idx, node) {
    case list.is_empty(node.target_links) {
      True -> LayoutNode(..node, depth: max_depth)
      False -> node
    }
  })
}

// ---------------------------------------------------------------------------
// Horizontal positioning
// ---------------------------------------------------------------------------

fn position_x(
  nodes: Dict(Int, LayoutNode),
  width: Float,
  node_width: Float,
  max_depth: Int,
) -> Dict(Int, LayoutNode) {
  let x_step = case max_depth >= 1 {
    True -> { width -. node_width } /. int.to_float(max_depth)
    False -> 0.0
  }

  dict.map_values(nodes, fn(_idx, node) {
    LayoutNode(..node, x: int.to_float(node.depth) *. x_step, width: node_width)
  })
}

// ---------------------------------------------------------------------------
// Vertical initialization
// ---------------------------------------------------------------------------

fn initialize_vertical(
  nodes: Dict(Int, LayoutNode),
  input_links: List(SankeyLink),
  input_nodes: List(SankeyNode),
  height: Float,
  node_padding: Float,
  sort_fn: Option(fn(SankeyNode, SankeyNode) -> order.Order),
) -> #(Dict(Int, LayoutNode), List(LayoutLink)) {
  // Group nodes by depth to compute y_ratio per column
  let depth_groups = group_by_depth(nodes)

  // Compute y_ratio: the minimum across all depth columns of
  // (available_height) / (sum of node values in column)
  // where available_height = height - (count - 1) * node_padding
  let y_ratio = compute_y_ratio(nodes, depth_groups, height, node_padding)

  // Set initial y positions (sequential within each column) and heights
  let nodes =
    dict.map_values(nodes, fn(_idx, node) {
      let position_in_column =
        get_position_in_depth(
          depth_groups,
          node.depth,
          node.index,
          input_nodes,
          sort_fn,
        )
      LayoutNode(
        ..node,
        y: int.to_float(position_in_column),
        height: node.value *. y_ratio,
      )
    })

  // Create layout links with widths proportional to value
  let layout_links =
    list.map(input_links, fn(link) {
      LayoutLink(
        source: link.source,
        target: link.target,
        value: link.value,
        width: link.value *. y_ratio,
        source_y: 0.0,
        target_y: 0.0,
      )
    })

  #(nodes, layout_links)
}

fn group_by_depth(nodes: Dict(Int, LayoutNode)) -> Dict(Int, List(Int)) {
  dict.fold(nodes, dict.new(), fn(acc, idx, node) {
    let existing = case dict.get(acc, node.depth) {
      Ok(lst) -> lst
      Error(_) -> []
    }
    dict.insert(acc, node.depth, [idx, ..existing])
  })
}

fn compute_y_ratio(
  nodes: Dict(Int, LayoutNode),
  depth_groups: Dict(Int, List(Int)),
  height: Float,
  node_padding: Float,
) -> Float {
  // For each depth column, compute:
  //   ratio = (height - (count - 1) * node_padding) / sum_of_values
  // Return the minimum ratio so all columns fit within height.
  let ratios =
    dict.fold(depth_groups, [], fn(acc, _depth, indices) {
      let count = list.length(indices)
      let value_sum =
        list.fold(indices, 0.0, fn(sum, idx) {
          let node = dict_get_or_default(nodes, idx)
          sum +. node.value
        })
      case value_sum >. 0.0 {
        True -> {
          let available = height -. int.to_float(count - 1) *. node_padding
          let safe_available = case available <. 0.0 {
            True -> 0.0
            False -> available
          }
          [safe_available /. value_sum, ..acc]
        }
        False -> acc
      }
    })

  case ratios {
    [] -> 1.0
    [first, ..rest] ->
      list.fold(rest, first, fn(acc, r) {
        case r <. acc {
          True -> r
          False -> acc
        }
      })
  }
}

fn get_position_in_depth(
  depth_groups: Dict(Int, List(Int)),
  depth: Int,
  node_index: Int,
  input_nodes: List(SankeyNode),
  sort_fn: Option(fn(SankeyNode, SankeyNode) -> order.Order),
) -> Int {
  case dict.get(depth_groups, depth) {
    Error(_) -> 0
    Ok(indices) -> {
      let sorted = case sort_fn {
        None -> list.sort(indices, int.compare)
        Some(cmp) ->
          list.sort(indices, fn(a, b) {
            let node_a = get_input_node_at(input_nodes, a)
            let node_b = get_input_node_at(input_nodes, b)
            cmp(node_a, node_b)
          })
      }
      find_position(sorted, node_index, 0)
    }
  }
}

fn get_input_node_at(nodes: List(SankeyNode), index: Int) -> SankeyNode {
  case list.drop(nodes, index) {
    [node, ..] -> node
    [] -> SankeyNode(name: "")
  }
}

fn find_position(items: List(Int), target: Int, pos: Int) -> Int {
  case items {
    [] -> pos
    [first, ..rest] ->
      case first == target {
        True -> pos
        False -> find_position(rest, target, pos + 1)
      }
  }
}

// ---------------------------------------------------------------------------
// Collision resolution
// ---------------------------------------------------------------------------

fn resolve_all_collisions(
  nodes: Dict(Int, LayoutNode),
  height: Float,
  node_padding: Float,
  max_depth: Int,
) -> Dict(Int, LayoutNode) {
  resolve_collisions_at_depth(nodes, 0, max_depth, height, node_padding)
}

fn resolve_collisions_at_depth(
  nodes: Dict(Int, LayoutNode),
  depth: Int,
  max_depth: Int,
  height: Float,
  node_padding: Float,
) -> Dict(Int, LayoutNode) {
  case depth > max_depth {
    True -> nodes
    False -> {
      let column_indices = get_nodes_at_depth(nodes, depth)
      let sorted_indices = sort_indices_by_y(nodes, column_indices)
      let nodes = push_down_overlaps(nodes, sorted_indices, node_padding)
      let nodes =
        push_up_from_bottom(nodes, sorted_indices, height, node_padding)
      resolve_collisions_at_depth(
        nodes,
        depth + 1,
        max_depth,
        height,
        node_padding,
      )
    }
  }
}

fn get_nodes_at_depth(nodes: Dict(Int, LayoutNode), depth: Int) -> List(Int) {
  dict.fold(nodes, [], fn(acc, idx, node) {
    case node.depth == depth {
      True -> [idx, ..acc]
      False -> acc
    }
  })
}

fn sort_indices_by_y(
  nodes: Dict(Int, LayoutNode),
  indices: List(Int),
) -> List(Int) {
  list.sort(indices, fn(a, b) {
    let node_a = dict_get_or_default(nodes, a)
    let node_b = dict_get_or_default(nodes, b)
    float.compare(node_a.y, node_b.y)
  })
}

fn push_down_overlaps(
  nodes: Dict(Int, LayoutNode),
  sorted_indices: List(Int),
  node_padding: Float,
) -> Dict(Int, LayoutNode) {
  push_down_loop(nodes, sorted_indices, 0.0, node_padding)
}

fn push_down_loop(
  nodes: Dict(Int, LayoutNode),
  indices: List(Int),
  y0: Float,
  node_padding: Float,
) -> Dict(Int, LayoutNode) {
  case indices {
    [] -> nodes
    [idx, ..rest] -> {
      let node = dict_get_or_default(nodes, idx)
      let dy = y0 -. node.y
      let new_node = case dy >. 0.0 {
        True -> LayoutNode(..node, y: node.y +. dy)
        False -> node
      }
      let updated = dict.insert(nodes, idx, new_node)
      let next_y0 = new_node.y +. new_node.height +. node_padding
      push_down_loop(updated, rest, next_y0, node_padding)
    }
  }
}

fn push_up_from_bottom(
  nodes: Dict(Int, LayoutNode),
  sorted_indices: List(Int),
  height: Float,
  node_padding: Float,
) -> Dict(Int, LayoutNode) {
  let reversed = list.reverse(sorted_indices)
  push_up_loop(nodes, reversed, height +. node_padding, node_padding)
}

fn push_up_loop(
  nodes: Dict(Int, LayoutNode),
  indices: List(Int),
  y0: Float,
  node_padding: Float,
) -> Dict(Int, LayoutNode) {
  case indices {
    [] -> nodes
    [idx, ..rest] -> {
      let node = dict_get_or_default(nodes, idx)
      let dy = node.y +. node.height +. node_padding -. y0
      case dy >. 0.0 {
        True -> {
          let new_node = LayoutNode(..node, y: node.y -. dy)
          let updated = dict.insert(nodes, idx, new_node)
          push_up_loop(updated, rest, new_node.y, node_padding)
        }
        False -> nodes
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Iterative relaxation
// ---------------------------------------------------------------------------

fn iterate_relaxation(
  nodes nodes: Dict(Int, LayoutNode),
  input_links input_links: List(SankeyLink),
  height height: Float,
  node_padding node_padding: Float,
  max_depth max_depth: Int,
  iterations_remaining iterations_remaining: Int,
  alpha alpha: Float,
) -> Dict(Int, LayoutNode) {
  case iterations_remaining <= 0 {
    True -> nodes
    False -> {
      let new_alpha = alpha *. 0.99

      // Relax right to left
      let nodes = relax_right_to_left(nodes, input_links, max_depth, new_alpha)
      let nodes = resolve_all_collisions(nodes, height, node_padding, max_depth)

      // Relax left to right
      let nodes = relax_left_to_right(nodes, input_links, max_depth, new_alpha)
      let nodes = resolve_all_collisions(nodes, height, node_padding, max_depth)

      iterate_relaxation(
        nodes: nodes,
        input_links: input_links,
        height: height,
        node_padding: node_padding,
        max_depth: max_depth,
        iterations_remaining: iterations_remaining - 1,
        alpha: new_alpha,
      )
    }
  }
}

fn relax_left_to_right(
  nodes: Dict(Int, LayoutNode),
  input_links: List(SankeyLink),
  max_depth: Int,
  alpha: Float,
) -> Dict(Int, LayoutNode) {
  relax_ltr_at_depth(nodes, input_links, 0, max_depth, alpha)
}

fn relax_ltr_at_depth(
  nodes: Dict(Int, LayoutNode),
  input_links: List(SankeyLink),
  depth: Int,
  max_depth: Int,
  alpha: Float,
) -> Dict(Int, LayoutNode) {
  case depth > max_depth {
    True -> nodes
    False -> {
      let indices = get_nodes_at_depth(nodes, depth)
      let nodes = relax_nodes_by_sources(nodes, input_links, indices, alpha)
      relax_ltr_at_depth(nodes, input_links, depth + 1, max_depth, alpha)
    }
  }
}

fn relax_nodes_by_sources(
  nodes: Dict(Int, LayoutNode),
  input_links: List(SankeyLink),
  indices: List(Int),
  alpha: Float,
) -> Dict(Int, LayoutNode) {
  case indices {
    [] -> nodes
    [idx, ..rest] -> {
      let node = dict_get_or_default(nodes, idx)
      case list.is_empty(node.source_links) {
        True -> relax_nodes_by_sources(nodes, input_links, rest, alpha)
        False -> {
          let source_sum =
            sum_link_values_by_indices(input_links, node.source_links)
          case source_sum >. 0.0 {
            True -> {
              let weighted_sum =
                weighted_source_sum(nodes, input_links, node.source_links)
              let target_y = weighted_sum /. source_sum
              let center = node.y +. node.height /. 2.0
              let new_y = node.y +. { target_y -. center } *. alpha
              let updated =
                dict.insert(nodes, idx, LayoutNode(..node, y: new_y))
              relax_nodes_by_sources(updated, input_links, rest, alpha)
            }
            False -> relax_nodes_by_sources(nodes, input_links, rest, alpha)
          }
        }
      }
    }
  }
}

fn weighted_source_sum(
  nodes: Dict(Int, LayoutNode),
  links: List(SankeyLink),
  link_indices: List(Int),
) -> Float {
  list.fold(link_indices, 0.0, fn(acc, link_idx) {
    let link = get_sankey_link_at(links, link_idx)
    let source_node = dict_get_or_default(nodes, link.source)
    let center = source_node.y +. source_node.height /. 2.0
    acc +. center *. link.value
  })
}

fn relax_right_to_left(
  nodes: Dict(Int, LayoutNode),
  input_links: List(SankeyLink),
  max_depth: Int,
  alpha: Float,
) -> Dict(Int, LayoutNode) {
  relax_rtl_at_depth(nodes, input_links, max_depth, alpha)
}

fn relax_rtl_at_depth(
  nodes: Dict(Int, LayoutNode),
  input_links: List(SankeyLink),
  depth: Int,
  alpha: Float,
) -> Dict(Int, LayoutNode) {
  case depth < 0 {
    True -> nodes
    False -> {
      let indices = get_nodes_at_depth(nodes, depth)
      let nodes = relax_nodes_by_targets(nodes, input_links, indices, alpha)
      relax_rtl_at_depth(nodes, input_links, depth - 1, alpha)
    }
  }
}

fn relax_nodes_by_targets(
  nodes: Dict(Int, LayoutNode),
  input_links: List(SankeyLink),
  indices: List(Int),
  alpha: Float,
) -> Dict(Int, LayoutNode) {
  case indices {
    [] -> nodes
    [idx, ..rest] -> {
      let node = dict_get_or_default(nodes, idx)
      case list.is_empty(node.target_links) {
        True -> relax_nodes_by_targets(nodes, input_links, rest, alpha)
        False -> {
          let target_sum =
            sum_link_values_by_indices(input_links, node.target_links)
          case target_sum >. 0.0 {
            True -> {
              let weighted_sum =
                weighted_target_sum(nodes, input_links, node.target_links)
              let target_y = weighted_sum /. target_sum
              let center = node.y +. node.height /. 2.0
              let new_y = node.y +. { target_y -. center } *. alpha
              let updated =
                dict.insert(nodes, idx, LayoutNode(..node, y: new_y))
              relax_nodes_by_targets(updated, input_links, rest, alpha)
            }
            False -> relax_nodes_by_targets(nodes, input_links, rest, alpha)
          }
        }
      }
    }
  }
}

fn weighted_target_sum(
  nodes: Dict(Int, LayoutNode),
  links: List(SankeyLink),
  link_indices: List(Int),
) -> Float {
  list.fold(link_indices, 0.0, fn(acc, link_idx) {
    let link = get_sankey_link_at(links, link_idx)
    let target_node = dict_get_or_default(nodes, link.target)
    let center = target_node.y +. target_node.height /. 2.0
    acc +. center *. link.value
  })
}

// ---------------------------------------------------------------------------
// Link position computation
// ---------------------------------------------------------------------------

fn compute_link_positions(
  nodes: Dict(Int, LayoutNode),
  links: List(LayoutLink),
) -> List(LayoutLink) {
  // For each node, compute the cumulative source_y and target_y offsets
  // by sorting outgoing/incoming links by target/source y position.
  let node_list = dict.values(nodes)

  // Build cumulative outgoing offsets: node_index -> (link_index -> sy)
  let outgoing_offsets =
    list.fold(node_list, dict.new(), fn(acc, node) {
      let sorted_target_links =
        sort_link_indices_by_target_y(nodes, links, node.target_links)
      let offsets = compute_cumulative_offsets(links, sorted_target_links, 0.0)
      dict.insert(acc, node.index, offsets)
    })

  // Build cumulative incoming offsets: node_index -> (link_index -> ty)
  let incoming_offsets =
    list.fold(node_list, dict.new(), fn(acc, node) {
      let sorted_source_links =
        sort_link_indices_by_source_y(nodes, links, node.source_links)
      let offsets = compute_cumulative_offsets(links, sorted_source_links, 0.0)
      dict.insert(acc, node.index, offsets)
    })

  // Apply offsets to links
  list.index_map(links, fn(link, i) {
    let sy = get_offset(outgoing_offsets, link.source, i)
    let ty = get_offset(incoming_offsets, link.target, i)
    LayoutLink(..link, source_y: sy, target_y: ty)
  })
}

fn sort_link_indices_by_target_y(
  nodes: Dict(Int, LayoutNode),
  links: List(LayoutLink),
  link_indices: List(Int),
) -> List(Int) {
  list.sort(link_indices, fn(a, b) {
    let link_a = get_layout_link_at(links, a)
    let link_b = get_layout_link_at(links, b)
    let node_a = dict_get_or_default(nodes, link_a.target)
    let node_b = dict_get_or_default(nodes, link_b.target)
    float.compare(node_a.y, node_b.y)
  })
}

fn sort_link_indices_by_source_y(
  nodes: Dict(Int, LayoutNode),
  links: List(LayoutLink),
  link_indices: List(Int),
) -> List(Int) {
  list.sort(link_indices, fn(a, b) {
    let link_a = get_layout_link_at(links, a)
    let link_b = get_layout_link_at(links, b)
    let node_a = dict_get_or_default(nodes, link_a.source)
    let node_b = dict_get_or_default(nodes, link_b.source)
    float.compare(node_a.y, node_b.y)
  })
}

fn compute_cumulative_offsets(
  links: List(LayoutLink),
  sorted_indices: List(Int),
  offset: Float,
) -> Dict(Int, Float) {
  case sorted_indices {
    [] -> dict.new()
    [idx, ..rest] -> {
      let link = get_layout_link_at(links, idx)
      let result = compute_cumulative_offsets(links, rest, offset +. link.width)
      dict.insert(result, idx, offset)
    }
  }
}

fn get_offset(
  offset_map: Dict(Int, Dict(Int, Float)),
  node_index: Int,
  link_index: Int,
) -> Float {
  case dict.get(offset_map, node_index) {
    Error(_) -> 0.0
    Ok(offsets) ->
      case dict.get(offsets, link_index) {
        Error(_) -> 0.0
        Ok(v) -> v
      }
  }
}

fn get_layout_link_at(links: List(LayoutLink), index: Int) -> LayoutLink {
  get_layout_link_at_loop(links, index, 0)
}

fn get_layout_link_at_loop(
  links: List(LayoutLink),
  target: Int,
  current: Int,
) -> LayoutLink {
  case links {
    [] ->
      LayoutLink(
        source: 0,
        target: 0,
        value: 0.0,
        width: 0.0,
        source_y: 0.0,
        target_y: 0.0,
      )
    [link, ..rest] ->
      case current == target {
        True -> link
        False -> get_layout_link_at_loop(rest, target, current + 1)
      }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn dict_get_or_default(nodes: Dict(Int, LayoutNode), index: Int) -> LayoutNode {
  case dict.get(nodes, index) {
    Ok(node) -> node
    Error(_) ->
      LayoutNode(
        index: 0,
        name: "",
        x: 0.0,
        y: 0.0,
        width: 0.0,
        height: 0.0,
        value: 0.0,
        depth: 0,
        source_links: [],
        target_links: [],
      )
  }
}

fn cycle_fill(fills: List(String), index: Int) -> String {
  let n = list.length(fills)
  case n == 0 {
    True -> "#808080"
    False -> {
      let target = index % n
      find_fill_at(fills, target, 0, "#808080")
    }
  }
}

fn find_fill_at(
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
        False -> find_fill_at(rest, target, current + 1, default)
      }
  }
}
