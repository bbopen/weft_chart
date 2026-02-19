//// Treemap series component.
////
//// Renders a squarified treemap visualization where hierarchical data is
//// shown as nested rectangles with areas proportional to values.  Implements
//// the Bruls-Huizing-van Wijk squarified treemap algorithm for optimal
//// aspect ratios, matching the recharts Treemap component.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element.{type Element}
import weft_chart/animation.{type AnimationConfig}
import weft_chart/internal/math
import weft_chart/internal/svg
import weft_chart/render
import weft_chart/shape
import weft_chart/tooltip

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A node in the treemap hierarchy.
///
/// Leaf nodes have an empty `children` list and carry their own `value`.
/// Branch nodes derive their value from the sum of their children.
pub type TreemapNode {
  TreemapNode(
    name: String,
    value: Float,
    children: List(TreemapNode),
    fill: String,
  )
}

/// Display mode for treemap rendering.
///
/// FlatTreemap renders all leaf nodes (current default behavior).
/// NestedTreemap renders only top-level groups and their direct children,
/// matching recharts Treemap `type` prop.
pub type TreemapDisplayType {
  /// Render all leaf nodes in a flat layout (default).
  FlatTreemap
  /// Render only depth-0 and depth-1 nodes in a nested layout.
  NestedTreemap
}

/// Configuration for a treemap visualization.
///
/// Controls layout algorithm parameters, visual styling, and label display.
pub type TreemapConfig(msg) {
  TreemapConfig(
    data: List(TreemapNode),
    data_key: String,
    name_key: String,
    aspect_ratio: Float,
    fill: String,
    stroke: String,
    stroke_width: Float,
    padding: Float,
    fills: List(String),
    show_label: Bool,
    legend_type: shape.LegendIconType,
    display_type: TreemapDisplayType,
    explicit_width: Option(Int),
    explicit_height: Option(Int),
    custom_shape: Option(fn(render.TreemapNodeProps) -> Element(msg)),
    css_class: String,
    animation: AnimationConfig,
    animation_update_active: Bool,
    on_click: Option(fn(TreemapNode) -> msg),
  )
}

// ---------------------------------------------------------------------------
// Internal types
// ---------------------------------------------------------------------------

type Rect {
  Rect(x: Float, y: Float, width: Float, height: Float)
}

type LayoutRect {
  LayoutRect(
    x: Float,
    y: Float,
    width: Float,
    height: Float,
    node: TreemapNode,
    depth: Int,
    sibling_index: Int,
  )
}

/// A node paired with its scaled area for the layout algorithm.
type AreaNode {
  AreaNode(node: TreemapNode, area: Float)
}

// ---------------------------------------------------------------------------
// Constructors
// ---------------------------------------------------------------------------

/// Create a treemap configuration with sensible defaults.
///
/// The default aspect ratio is the golden ratio (1.618), which produces
/// visually balanced rectangles.  Stroke defaults to white for clear
/// cell boundaries.
pub fn treemap_config(data_key data_key: String) -> TreemapConfig(msg) {
  TreemapConfig(
    data: [],
    data_key: data_key,
    name_key: "name",
    aspect_ratio: 1.618,
    fill: "#8884d8",
    stroke: "#fff",
    stroke_width: 1.0,
    padding: 0.0,
    fills: [
      "#1890FF", "#66B5FF", "#41D9C7", "#2FC25B", "#6EDB8F", "#9AE65C",
      "#FACC14", "#E6965C", "#57AD71", "#223273", "#738AE6", "#7564CC",
      "#8543E0", "#A877ED", "#5C8EE6", "#13C2C2", "#70E0E0", "#5CA3E6",
      "#3436C7", "#8082FF", "#DD81E6", "#F04864", "#FA7D92", "#D598D9",
    ],
    show_label: True,
    legend_type: shape.RectIcon,
    display_type: FlatTreemap,
    explicit_width: None,
    explicit_height: None,
    custom_shape: None,
    css_class: "",
    animation: animation.with_active(
      config: animation.line_default(),
      active: False,
    ),
    animation_update_active: True,
    on_click: None,
  )
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

/// Set the hierarchical data for the treemap.
pub fn treemap_data(
  config config: TreemapConfig(msg),
  data data: List(TreemapNode),
) -> TreemapConfig(msg) {
  TreemapConfig(..config, data: data)
}

/// Set the default fill color for treemap cells.
pub fn treemap_fill(
  config config: TreemapConfig(msg),
  fill fill: String,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, fill: fill)
}

/// Set the stroke color for cell borders.
pub fn treemap_stroke(
  config config: TreemapConfig(msg),
  stroke stroke: String,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, stroke: stroke)
}

/// Set the stroke width for cell borders.
pub fn treemap_stroke_width(
  config config: TreemapConfig(msg),
  width width: Float,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, stroke_width: width)
}

/// Set the target aspect ratio for the squarify algorithm.
///
/// Values closer to 1.0 produce more square cells.  The default
/// golden ratio (1.618) balances squareness with visual variety.
pub fn treemap_aspect_ratio(
  config config: TreemapConfig(msg),
  ratio ratio: Float,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, aspect_ratio: ratio)
}

/// Set the padding between treemap cells in pixels.
pub fn treemap_padding(
  config config: TreemapConfig(msg),
  padding padding: Float,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, padding: padding)
}

/// Set the color palette for cycling through cell fills.
///
/// When provided, cell colors cycle through this list by index.
/// Takes precedence over individual node fill colors.
pub fn treemap_fills(
  config config: TreemapConfig(msg),
  fills fills: List(String),
) -> TreemapConfig(msg) {
  TreemapConfig(..config, fills: fills)
}

/// Enable or disable text labels inside treemap cells.
pub fn treemap_show_label(
  config config: TreemapConfig(msg),
  show show: Bool,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, show_label: show)
}

/// Set the legend icon type for this treemap series.
pub fn treemap_legend_type(
  config config: TreemapConfig(msg),
  icon_type icon_type: shape.LegendIconType,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, legend_type: icon_type)
}

/// Set the display type for the treemap.
///
/// FlatTreemap renders all leaf nodes in a single flat layout (default).
/// NestedTreemap renders only the top two levels, with parent groups as
/// background rectangles and their direct children as foreground rectangles.
/// Matches recharts Treemap `type` prop.
pub fn treemap_display_type(
  config config: TreemapConfig(msg),
  display_type display_type: TreemapDisplayType,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, display_type: display_type)
}

/// Set an explicit width override for the treemap.
/// When provided, uses this value instead of the chart-level width.
pub fn treemap_explicit_width(
  config config: TreemapConfig(msg),
  width width: Int,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, explicit_width: Some(width))
}

/// Set an explicit height override for the treemap.
/// When provided, uses this value instead of the chart-level height.
pub fn treemap_explicit_height(
  config config: TreemapConfig(msg),
  height height: Int,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, explicit_height: Some(height))
}

/// Set a custom renderer for treemap cells.
/// When provided, each cell is rendered using this function instead
/// of the default rectangle.
/// Matches recharts Treemap `content` prop (element/function form).
pub fn treemap_custom_shape(
  config config: TreemapConfig(msg),
  renderer renderer: fn(render.TreemapNodeProps) -> Element(msg),
) -> TreemapConfig(msg) {
  TreemapConfig(..config, custom_shape: Some(renderer))
}

/// Set the CSS class applied to the treemap group element.
pub fn treemap_css_class(
  config config: TreemapConfig(msg),
  class class: String,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, css_class: class)
}

/// Set the animation configuration for treemap entry effects.
pub fn treemap_animation(
  config config: TreemapConfig(msg),
  animation anim: AnimationConfig,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, animation: anim)
}

/// Control whether re-render (update) animations are active.
///
/// Matches recharts `isUpdateAnimationActive` prop.  When False, update
/// animations are suppressed regardless of the `animation` config.
/// Defaults to True.
pub fn treemap_animation_update_active(
  config config: TreemapConfig(msg),
  active active: Bool,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, animation_update_active: active)
}

/// Set a click handler for treemap cells.
///
/// When provided, each cell becomes clickable and fires the given message
/// when the user clicks it.  In NestedTreemap mode, clicking a parent cell
/// is the signal for the application to drill into that node's children.
/// Matches recharts `onClick` prop on the Treemap component.
pub fn treemap_on_click(
  config config: TreemapConfig(msg),
  on_click on_click: fn(TreemapNode) -> msg,
) -> TreemapConfig(msg) {
  TreemapConfig(..config, on_click: Some(on_click))
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

/// Render a treemap visualization as an SVG group element.
///
/// In flat mode, flattens the hierarchical node data to leaf nodes, runs the
/// squarified layout algorithm to compute rectangle positions, and renders
/// each cell as an SVG rect with optional centered text labels.
///
/// In nested mode, renders only the top two levels: parent groups as
/// background rectangles and their direct children as foreground rectangles.
pub fn render_treemap(
  config config: TreemapConfig(msg),
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

  let layout_rects = case config.display_type {
    FlatTreemap -> compute_flat_layout(config:, w:, h:)
    NestedTreemap -> compute_nested_layout(config:, w:, h:)
  }

  case layout_rects {
    [] -> element.none()
    _ -> {
      // In NestedTreemap mode, only depth-0 cells are initially visible.
      // Children are not rendered until the application drills into a node
      // by updating the data passed to the chart (matching recharts behavior).
      let visible_rects = case config.display_type {
        FlatTreemap -> layout_rects
        NestedTreemap -> list.filter(layout_rects, fn(lr) { lr.depth == 0 })
      }

      let children =
        list.map(visible_rects, fn(lr) {
          render_cell(config: config, layout: lr, index: lr.sibling_index)
        })

      // Arrow polygons are rendered as a final overlay layer so they appear
      // on top of all child cells (which otherwise cover the parent background).
      let arrow_overlays =
        build_arrow_overlays(config: config, layout_rects: visible_rects)

      let class_attr = case config.css_class {
        "" -> "recharts-treemap"
        c -> "recharts-treemap " <> c
      }
      svg.g(
        attrs: [svg.attr("class", class_attr)],
        children: list.append(children, arrow_overlays),
      )
    }
  }
}

/// Build tooltip payloads for a treemap.
///
/// Returns one payload per leaf cell (cells whose node has no children),
/// with hit zones matching each cell's full dimensions.  Matches recharts
/// treemap tooltip behavior: label is empty, the single entry carries the
/// node name and effective value.
pub fn build_treemap_tooltip_payloads(
  config config: TreemapConfig(msg),
  width width: Int,
  height height: Int,
) -> List(tooltip.TooltipPayload) {
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

  let layout_rects = case config.display_type {
    FlatTreemap -> compute_flat_layout(config:, w:, h:)
    NestedTreemap -> compute_nested_layout(config:, w:, h:)
  }

  // FlatTreemap: only leaf cells get tooltip hit zones (matches recharts flat
  // mode which only attaches mouse events to leaf nodes).
  // NestedTreemap: depth-0 cells are the visible clickable cells; they all
  // get tooltip hit zones regardless of whether they have children.
  list.filter_map(layout_rects, fn(lr) {
    let include = case config.display_type {
      FlatTreemap -> lr.node.children == []
      NestedTreemap -> lr.depth == 0
    }
    case include {
      False -> Error(Nil)
      True ->
        Ok(tooltip.TooltipPayload(
          label: "",
          entries: [
            tooltip.TooltipEntry(
              name: lr.node.name,
              value: node_effective_value(lr.node),
              color: "",
              unit: "",
              hidden: False,
              entry_type: tooltip.VisibleEntry,
            ),
          ],
          x: lr.x +. lr.width /. 2.0,
          y: lr.y +. lr.height /. 2.0,
          active_dots: [],
          zone_width: lr.width,
          zone_height: lr.height,
        ))
    }
  })
}

/// Return the TreemapNode for each tooltip payload, in the same order as
/// `build_treemap_tooltip_payloads`.  Used by `chart.gleam` to attach click
/// handlers to the corresponding tooltip hit zones.
pub fn tooltip_payload_nodes(
  config config: TreemapConfig(msg),
  width width: Int,
  height height: Int,
) -> List(TreemapNode) {
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

  let layout_rects = case config.display_type {
    FlatTreemap -> compute_flat_layout(config:, w:, h:)
    NestedTreemap -> compute_nested_layout(config:, w:, h:)
  }

  list.filter_map(layout_rects, fn(lr) {
    let include = case config.display_type {
      FlatTreemap -> lr.node.children == []
      NestedTreemap -> lr.depth == 0
    }
    case include {
      False -> Error(Nil)
      True -> Ok(lr.node)
    }
  })
}

/// Compute flat layout: squarify top-level nodes hierarchically, then
/// squarify each group's children within the parent's bounding box.
fn compute_flat_layout(
  config config: TreemapConfig(msg),
  w w: Float,
  h h: Float,
) -> List(LayoutRect) {
  let top_nodes = compute_top_level_values(config.data)
  let total_value =
    list.fold(top_nodes, 0.0, fn(acc, node) { acc +. node.value })

  case total_value <=. 0.0 {
    True -> []
    False -> {
      let rect = Rect(x: 0.0, y: 0.0, width: w, height: h)
      let total_area = w *. h
      let area_nodes =
        list.map(top_nodes, fn(node) {
          let area = case node.value >. 0.0 {
            True -> node.value /. total_value *. total_area
            False -> 0.0
          }
          AreaNode(node: node, area: area)
        })

      let sorted =
        list.sort(area_nodes, fn(a, b) { float.compare(b.area, a.area) })

      let initial_size = float_min(rect.width, rect.height)
      let parent_rects =
        squarify(
          remaining: sorted,
          row: [],
          row_area: 0.0,
          size: initial_size,
          rect: rect,
          aspect_ratio: config.aspect_ratio,
        )

      list.flat_map(
        list.index_map(parent_rects, fn(pr, idx) {
          let indexed_pr = LayoutRect(..pr, sibling_index: idx)
          case pr.node.children {
            [] -> [indexed_pr]
            children -> {
              let child_total =
                list.fold(children, 0.0, fn(acc, c) {
                  acc +. node_effective_value(c)
                })
              case child_total <=. 0.0 {
                True -> [indexed_pr]
                False -> {
                  let child_area = pr.width *. pr.height
                  let child_rect =
                    Rect(x: pr.x, y: pr.y, width: pr.width, height: pr.height)
                  let child_area_nodes =
                    list.map(children, fn(c) {
                      let val = node_effective_value(c)
                      let area = case val >. 0.0 {
                        True -> val /. child_total *. child_area
                        False -> 0.0
                      }
                      AreaNode(node: c, area: area)
                    })
                  let child_sorted =
                    list.sort(child_area_nodes, fn(a, b) {
                      float.compare(b.area, a.area)
                    })
                  let child_size =
                    float_min(child_rect.width, child_rect.height)
                  let child_layouts =
                    squarify(
                      remaining: child_sorted,
                      row: [],
                      row_area: 0.0,
                      size: child_size,
                      rect: child_rect,
                      aspect_ratio: config.aspect_ratio,
                    )
                  let depth1_children =
                    list.index_map(child_layouts, fn(cl, ci) {
                      LayoutRect(..cl, depth: 1, sibling_index: ci)
                    })
                  [indexed_pr, ..depth1_children]
                }
              }
            }
          }
        }),
        fn(x) { x },
      )
    }
  }
}

/// Compute nested layout: squarify top-level nodes, then squarify children
/// within each parent's bounds.  Returns parent rects at depth 0 and child
/// rects at depth 1.
fn compute_nested_layout(
  config config: TreemapConfig(msg),
  w w: Float,
  h h: Float,
) -> List(LayoutRect) {
  // Compute effective value for each top-level node
  let top_nodes = compute_top_level_values(config.data)
  let total_value =
    list.fold(top_nodes, 0.0, fn(acc, node) { acc +. node.value })

  case total_value <=. 0.0 {
    True -> []
    False -> {
      let rect = Rect(x: 0.0, y: 0.0, width: w, height: h)
      let total_area = w *. h
      let area_nodes =
        list.map(top_nodes, fn(node) {
          let area = case node.value >. 0.0 {
            True -> node.value /. total_value *. total_area
            False -> 0.0
          }
          AreaNode(node: node, area: area)
        })

      let sorted =
        list.sort(area_nodes, fn(a, b) { float.compare(b.area, a.area) })

      let initial_size = float_min(rect.width, rect.height)
      let parent_rects =
        squarify(
          remaining: sorted,
          row: [],
          row_area: 0.0,
          size: initial_size,
          rect: rect,
          aspect_ratio: config.aspect_ratio,
        )

      // For each parent rect, if the original node has children,
      // squarify children within the parent bounds
      list.flat_map(
        list.index_map(parent_rects, fn(pr, idx) {
          LayoutRect(..pr, sibling_index: idx)
        }),
        fn(pr) {
          case pr.node.children {
            [] -> [pr]
            children -> {
              let child_total =
                list.fold(children, 0.0, fn(acc, c) {
                  acc +. node_effective_value(c)
                })
              case child_total <=. 0.0 {
                True -> [pr]
                False -> {
                  let child_area = pr.width *. pr.height
                  let child_rect =
                    Rect(x: pr.x, y: pr.y, width: pr.width, height: pr.height)
                  let child_area_nodes =
                    list.map(children, fn(c) {
                      let val = node_effective_value(c)
                      let area = case val >. 0.0 {
                        True -> val /. child_total *. child_area
                        False -> 0.0
                      }
                      AreaNode(node: c, area: area)
                    })
                  let child_sorted =
                    list.sort(child_area_nodes, fn(a, b) {
                      float.compare(b.area, a.area)
                    })
                  let child_size =
                    float_min(child_rect.width, child_rect.height)
                  let child_layouts =
                    squarify(
                      remaining: child_sorted,
                      row: [],
                      row_area: 0.0,
                      size: child_size,
                      rect: child_rect,
                      aspect_ratio: config.aspect_ratio,
                    )
                  // Set depth 1 for children
                  let depth1_children =
                    list.map(child_layouts, fn(cl) {
                      LayoutRect(..cl, depth: 1)
                    })
                  // Parent at depth 0, then children at depth 1
                  [pr, ..depth1_children]
                }
              }
            }
          }
        },
      )
    }
  }
}

// ---------------------------------------------------------------------------
// Squarified layout algorithm
// ---------------------------------------------------------------------------

/// Run the squarified treemap algorithm to position nodes within a rectangle.
///
/// Iteratively builds rows of nodes, checking whether adding the next node
/// improves the worst aspect ratio.  When it does not, the current row is
/// laid out and a new row begins in the remaining space.
fn squarify(
  remaining remaining: List(AreaNode),
  row row: List(AreaNode),
  row_area row_area: Float,
  size size: Float,
  rect rect: Rect,
  aspect_ratio aspect_ratio: Float,
) -> List(LayoutRect) {
  case remaining {
    [] -> {
      // Flush the final row
      case row {
        [] -> []
        _ -> {
          let #(positioned, _) =
            layout_row(row: row, row_area: row_area, rect: rect, is_flush: True)
          positioned
        }
      }
    }
    [next, ..rest] -> {
      case row {
        [] -> {
          // First node in a new row: always add it
          squarify(
            remaining: rest,
            row: [next],
            row_area: next.area,
            size: size,
            rect: rect,
            aspect_ratio: aspect_ratio,
          )
        }
        _ -> {
          let new_row_area = row_area +. next.area
          let current_score =
            worst_score(
              row: row,
              row_area: row_area,
              size: size,
              aspect_ratio: aspect_ratio,
            )
          let new_score =
            worst_score(
              row: [next, ..row],
              row_area: new_row_area,
              size: size,
              aspect_ratio: aspect_ratio,
            )

          case new_score <=. current_score {
            True -> {
              // Adding improves the ratio; continue with this row
              squarify(
                remaining: rest,
                row: [next, ..row],
                row_area: new_row_area,
                size: size,
                rect: rect,
                aspect_ratio: aspect_ratio,
              )
            }
            False -> {
              // Lay out current row and start fresh
              let #(positioned, new_rect) =
                layout_row(
                  row: row,
                  row_area: row_area,
                  rect: rect,
                  is_flush: False,
                )
              let new_size = float_min(new_rect.width, new_rect.height)
              let rest_positioned =
                squarify(
                  remaining: remaining,
                  row: [],
                  row_area: 0.0,
                  size: new_size,
                  rect: new_rect,
                  aspect_ratio: aspect_ratio,
                )
              list.append(positioned, rest_positioned)
            }
          }
        }
      }
    }
  }
}

/// Compute the worst aspect ratio score for a row of nodes.
///
/// Uses the Bruls et al. metric: for a row with total area S laid along
/// a side of length w, the worst ratio is
/// max(w^2 * max_area * r / S^2, S^2 / (w^2 * min_area * r))
/// where r is the target aspect ratio.
fn worst_score(
  row row: List(AreaNode),
  row_area row_area: Float,
  size size: Float,
  aspect_ratio aspect_ratio: Float,
) -> Float {
  case row {
    [] -> infinity()
    _ -> {
      let #(min_area, max_area) = row_min_max(row)
      let parent_area = size *. size
      let row_area_sq = row_area *. row_area

      case row_area_sq <=. 0.0 {
        True -> infinity()
        False -> {
          let score_a = parent_area *. max_area *. aspect_ratio /. row_area_sq
          let score_b =
            row_area_sq /. { parent_area *. min_area *. aspect_ratio }
          float_max(score_a, score_b)
        }
      }
    }
  }
}

/// Position items in a row within the rectangle.
///
/// Fills a strip along the shorter side of the rectangle.  If the current
/// orientation is horizontal (width <= height), items stack vertically
/// within a horizontal strip.  Otherwise, items stack horizontally within
/// a vertical strip.
fn layout_row(
  row row: List(AreaNode),
  row_area row_area: Float,
  rect rect: Rect,
  is_flush is_flush: Bool,
) -> #(List(LayoutRect), Rect) {
  case rect.width <=. rect.height {
    True ->
      horizontal_layout(
        row: list.reverse(row),
        row_area: row_area,
        rect: rect,
        is_flush: is_flush,
      )
    False ->
      vertical_layout(
        row: list.reverse(row),
        row_area: row_area,
        rect: rect,
        is_flush: is_flush,
      )
  }
}

/// Lay out a row horizontally: items fill a strip across the full width,
/// with the strip height determined by the row's total area / width.
fn horizontal_layout(
  row row: List(AreaNode),
  row_area row_area: Float,
  rect rect: Rect,
  is_flush is_flush: Bool,
) -> #(List(LayoutRect), Rect) {
  let row_height = case rect.width >. 0.0 {
    True -> int.to_float(float.round(row_area /. rect.width))
    False -> 0.0
  }
  let row_height = case is_flush || row_height >. rect.height {
    True -> rect.height
    False -> row_height
  }

  let positioned =
    layout_horizontal_items(
      items: row,
      row_height: row_height,
      rect: rect,
      cur_x: rect.x,
    )

  let new_rect =
    Rect(
      x: rect.x,
      y: rect.y +. row_height,
      width: rect.width,
      height: rect.height -. row_height,
    )

  #(positioned, new_rect)
}

fn layout_horizontal_items(
  items items: List(AreaNode),
  row_height row_height: Float,
  rect rect: Rect,
  cur_x cur_x: Float,
) -> List(LayoutRect) {
  case items {
    [] -> []
    [item] -> {
      // Last item gets remaining width to avoid rounding gaps
      let item_width = rect.x +. rect.width -. cur_x
      let item_width = float_max(item_width, 0.0)
      [
        LayoutRect(
          x: cur_x,
          y: rect.y,
          width: item_width,
          height: row_height,
          node: item.node,
          depth: 0,
          sibling_index: 0,
        ),
      ]
    }
    [item, ..rest] -> {
      let item_width = case row_height >. 0.0 {
        True -> {
          let w = int.to_float(float.round(item.area /. row_height))
          float_min(w, rect.x +. rect.width -. cur_x)
        }
        False -> 0.0
      }
      [
        LayoutRect(
          x: cur_x,
          y: rect.y,
          width: item_width,
          height: row_height,
          node: item.node,
          depth: 0,
          sibling_index: 0,
        ),
        ..layout_horizontal_items(
          items: rest,
          row_height: row_height,
          rect: rect,
          cur_x: cur_x +. item_width,
        )
      ]
    }
  }
}

/// Lay out a row vertically: items fill a strip down the full height,
/// with the strip width determined by the row's total area / height.
fn vertical_layout(
  row row: List(AreaNode),
  row_area row_area: Float,
  rect rect: Rect,
  is_flush is_flush: Bool,
) -> #(List(LayoutRect), Rect) {
  let row_width = case rect.height >. 0.0 {
    True -> int.to_float(float.round(row_area /. rect.height))
    False -> 0.0
  }
  let row_width = case is_flush || row_width >. rect.width {
    True -> rect.width
    False -> row_width
  }

  let positioned =
    layout_vertical_items(
      items: row,
      row_width: row_width,
      rect: rect,
      cur_y: rect.y,
    )

  let new_rect =
    Rect(
      x: rect.x +. row_width,
      y: rect.y,
      width: rect.width -. row_width,
      height: rect.height,
    )

  #(positioned, new_rect)
}

fn layout_vertical_items(
  items items: List(AreaNode),
  row_width row_width: Float,
  rect rect: Rect,
  cur_y cur_y: Float,
) -> List(LayoutRect) {
  case items {
    [] -> []
    [item] -> {
      // Last item gets remaining height to avoid rounding gaps
      let item_height = rect.y +. rect.height -. cur_y
      let item_height = float_max(item_height, 0.0)
      [
        LayoutRect(
          x: rect.x,
          y: cur_y,
          width: row_width,
          height: item_height,
          node: item.node,
          depth: 0,
          sibling_index: 0,
        ),
      ]
    }
    [item, ..rest] -> {
      let item_height = case row_width >. 0.0 {
        True -> {
          let h = int.to_float(float.round(item.area /. row_width))
          float_min(h, rect.y +. rect.height -. cur_y)
        }
        False -> 0.0
      }
      [
        LayoutRect(
          x: rect.x,
          y: cur_y,
          width: row_width,
          height: item_height,
          node: item.node,
          depth: 0,
          sibling_index: 0,
        ),
        ..layout_vertical_items(
          items: rest,
          row_width: row_width,
          rect: rect,
          cur_y: cur_y +. item_height,
        )
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Cell rendering
// ---------------------------------------------------------------------------

fn render_cell(
  config config: TreemapConfig(msg),
  layout layout: LayoutRect,
  index index: Int,
) -> Element(msg) {
  // Dispatch to custom_shape if provided.
  // Click handling is done on the tooltip zone rects (which sit on top
  // in SVG z-order) rather than here, so treemap cells are purely visual.
  case config.custom_shape {
    Some(renderer) ->
      renderer(render.TreemapNodeProps(
        x: layout.x,
        y: layout.y,
        width: layout.width,
        height: layout.height,
        depth: layout.depth,
        index: index,
        name: layout.node.name,
        value: layout.node.value,
      ))
    None -> render_cell_default(config: config, layout: layout)
  }
}

fn render_cell_default(
  config config: TreemapConfig(msg),
  layout layout: LayoutRect,
) -> Element(msg) {
  let fill_color = case config.display_type {
    FlatTreemap ->
      case layout.depth {
        0 ->
          resolve_fill(
            config: config,
            node: layout.node,
            index: layout.sibling_index,
          )
        _ -> "rgba(0,0,0,0)"
      }
    NestedTreemap ->
      resolve_fill(
        config: config,
        node: layout.node,
        index: layout.sibling_index,
      )
  }

  // Depth-0 rects in nested mode get reduced opacity as background
  let opacity_attrs = case layout.depth {
    0 -> []
    _ -> [svg.attr("opacity", "1")]
  }

  let depth_class = case layout.depth {
    0 -> "recharts-treemap-depth-0"
    _ -> "recharts-treemap-depth-1"
  }

  let rect_attrs =
    list.append(
      [
        svg.attr("fill", fill_color),
        svg.attr("stroke", config.stroke),
        svg.attr("stroke-width", math.fmt(config.stroke_width)),
        svg.attr("class", "recharts-treemap-rect " <> depth_class),
        svg.attr("role", "img"),
      ],
      opacity_attrs,
    )

  // Apply padding to compute the visual rect dimensions
  let p = config.padding
  let rect_x = layout.x +. p
  let rect_y = layout.y +. p
  let rect_w = float_max(0.0, layout.width -. 2.0 *. p)
  let rect_h = float_max(0.0, layout.height -. 2.0 *. p)

  // Both animation flags must be true for animation to fire
  let animation_active =
    config.animation.active && config.animation_update_active

  let rect_el = case animation_active {
    False ->
      svg.rect(
        x: math.fmt(rect_x),
        y: math.fmt(rect_y),
        width: math.fmt(rect_w),
        height: math.fmt(rect_h),
        attrs: rect_attrs,
      )
    True -> {
      // Center is unchanged by equal padding on both sides
      let cx = layout.x +. layout.width /. 2.0
      let cy = layout.y +. layout.height /. 2.0
      svg.rect_with_children(
        x: math.fmt(cx),
        y: math.fmt(cy),
        width: "0",
        height: "0",
        attrs: rect_attrs,
        children: [
          animation.animate_attribute(
            name: "x",
            from: cx,
            to: rect_x,
            config: config.animation,
          ),
          animation.animate_attribute(
            name: "y",
            from: cy,
            to: rect_y,
            config: config.animation,
          ),
          animation.animate_attribute(
            name: "width",
            from: 0.0,
            to: rect_w,
            config: config.animation,
          ),
          animation.animate_attribute(
            name: "height",
            from: 0.0,
            to: rect_h,
            config: config.animation,
          ),
        ],
      )
    }
  }

  // Label: suppress when text would overflow the cell (recharts text-fit guard)
  let label_elements = case config.show_label {
    False -> []
    True -> {
      let name_len = string.length(layout.node.name)
      let est_text_w = int.to_float(name_len) *. 8.0
      case
        rect_w >. 20.0
        && rect_h >. 20.0
        && est_text_w <. rect_w
        && 14.0 <. rect_h
      {
        False -> []
        True -> {
          let text_x = rect_x +. 8.0
          let text_y = rect_y +. rect_h /. 2.0 +. 7.0
          [
            svg.text(
              x: math.fmt(text_x),
              y: math.fmt(text_y),
              content: layout.node.name,
              attrs: [
                svg.attr("font-size", "14"),
                svg.attr("fill", "#000"),
                svg.attr("pointer-events", "none"),
                svg.attr("class", "recharts-treemap-label"),
              ],
            ),
          ]
        }
      }
    }
  }

  case label_elements {
    [] -> rect_el
    _ -> svg.g(attrs: [], children: [rect_el, ..label_elements])
  }
}

// Build the arrow polygon overlay elements for NestedTreemap parent cells.
//
// Arrows are collected separately and appended as the final layer in the
// treemap SVG group so they render on top of all child cells, which
// otherwise completely cover the parent background rect.
fn build_arrow_overlays(
  config config: TreemapConfig(msg),
  layout_rects layout_rects: List(LayoutRect),
) -> List(Element(msg)) {
  case config.display_type {
    FlatTreemap -> []
    NestedTreemap ->
      list.filter_map(layout_rects, fn(lr) {
        case lr.node.children {
          [] -> Error(Nil)
          [_, ..] ->
            case lr.width >. 10.0 && lr.height >. 10.0 {
              False -> Error(Nil)
              True -> {
                let x = lr.x
                let y = lr.y
                let h = lr.height
                let pts =
                  math.fmt(x +. 2.0)
                  <> ","
                  <> math.fmt(y +. h /. 2.0)
                  <> " "
                  <> math.fmt(x +. 6.0)
                  <> ","
                  <> math.fmt(y +. h /. 2.0 +. 3.0)
                  <> " "
                  <> math.fmt(x +. 2.0)
                  <> ","
                  <> math.fmt(y +. h /. 2.0 +. 6.0)
                Ok(svg.el("polygon", [svg.attr("points", pts)], []))
              }
            }
        }
      })
  }
}

/// Determine the fill color for a cell, checking node fill, fills palette,
/// and config default in that order.
fn resolve_fill(
  config config: TreemapConfig(msg),
  node node: TreemapNode,
  index index: Int,
) -> String {
  case node.fill {
    "" -> {
      case config.fills {
        [] -> config.fill
        fills -> cycle_fill(fills, index)
      }
    }
    fill -> fill
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Compute the effective value for a node: its own value if a leaf, or the
/// sum of its children's effective values if a branch.
fn node_effective_value(node: TreemapNode) -> Float {
  case node.children {
    [] -> node.value
    children ->
      list.fold(children, 0.0, fn(acc, c) { acc +. node_effective_value(c) })
  }
}

/// Compute top-level nodes with effective values derived from their children.
/// For leaf nodes, the value is preserved.  For branch nodes, the value is
/// set to the sum of all descendant leaf values.
fn compute_top_level_values(nodes: List(TreemapNode)) -> List(TreemapNode) {
  list.map(nodes, fn(node) {
    TreemapNode(..node, value: node_effective_value(node))
  })
}

/// Find the minimum and maximum area values in a row.
fn row_min_max(row: List(AreaNode)) -> #(Float, Float) {
  case row {
    [] -> #(0.0, 0.0)
    [first, ..rest] ->
      list.fold(rest, #(first.area, first.area), fn(acc, node) {
        let #(min_val, max_val) = acc
        let new_min = case node.area <. min_val {
          True -> node.area
          False -> min_val
        }
        let new_max = case node.area >. max_val {
          True -> node.area
          False -> max_val
        }
        #(new_min, new_max)
      })
  }
}

fn cycle_fill(fills: List(String), index: Int) -> String {
  let n = list.length(fills)
  case n == 0 {
    True -> "#808080"
    False -> {
      let target = index % n
      find_at(fills, target, 0, "#808080")
    }
  }
}

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

fn float_min(a: Float, b: Float) -> Float {
  case a <. b {
    True -> a
    False -> b
  }
}

fn float_max(a: Float, b: Float) -> Float {
  case a >. b {
    True -> a
    False -> b
  }
}

/// A large sentinel value used for "infinity" in ratio comparisons.
fn infinity() -> Float {
  1_000_000_000.0
}
