//// Low-level SVG shape primitives.
////
//// Public shape rendering functions used by series components and
//// available for custom chart rendering.  Matches the recharts
//// shape components (Dot, Rectangle, Sector, Polygon, Symbols).

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/element.{type Element}
import weft_chart/internal/math
import weft_chart/internal/polar
import weft_chart/internal/svg

// ---------------------------------------------------------------------------
// Dot (recharts Dot component)
// ---------------------------------------------------------------------------

/// Configuration for a series dot, matching recharts Dot props.
pub type DotConfig {
  DotConfig(
    /// When True, include a `clip-path` attribute referencing the chart's
    /// clip region.  Default: True (matching recharts).
    clip_dot: Bool,
  )
}

/// Create a default `DotConfig` with clip_dot enabled.
pub fn default_dot_config() -> DotConfig {
  DotConfig(clip_dot: True)
}

/// Set the `clip_dot` flag on a `DotConfig`.
pub fn dot_clip_dot(
  config _config: DotConfig,
  clip_dot clip_dot: Bool,
) -> DotConfig {
  DotConfig(clip_dot: clip_dot)
}

/// Render a circle dot at the given center with radius and fill.
pub fn dot(
  cx cx: Float,
  cy cy: Float,
  r r: Float,
  fill fill: String,
) -> Element(msg) {
  svg.circle(cx: math.fmt(cx), cy: math.fmt(cy), r: math.fmt(r), attrs: [
    svg.attr("fill", fill),
  ])
}

/// Render a circle dot with stroke.
pub fn dot_with_stroke(
  cx cx: Float,
  cy cy: Float,
  r r: Float,
  fill fill: String,
  stroke stroke: String,
  stroke_width stroke_width: Float,
) -> Element(msg) {
  svg.circle(cx: math.fmt(cx), cy: math.fmt(cy), r: math.fmt(r), attrs: [
    svg.attr("fill", fill),
    svg.attr("stroke", stroke),
    svg.attr("stroke-width", math.fmt(stroke_width)),
  ])
}

/// Render a circle dot using a `DotConfig`.
///
/// When `clip_dot` is True, the circle includes a `clip-path` attribute
/// pointing to the given clip path id.  When False, dots may render
/// outside the chart area.
pub fn dot_with_config(
  cx cx: Float,
  cy cy: Float,
  r r: Float,
  fill fill: String,
  config config: DotConfig,
  clip_path_id clip_path_id: String,
) -> Element(msg) {
  let base_attrs = [svg.attr("fill", fill)]
  let attrs = case config.clip_dot {
    True -> [
      svg.attr("clip-path", "url(#" <> clip_path_id <> ")"),
      ..base_attrs
    ]
    False -> base_attrs
  }
  svg.circle(cx: math.fmt(cx), cy: math.fmt(cy), r: math.fmt(r), attrs: attrs)
}

// ---------------------------------------------------------------------------
// Rectangle (recharts Rectangle component)
// ---------------------------------------------------------------------------

/// Render a rectangle with optional uniform rounded corners.
/// When radius > 0, uses SVG arc (A) commands matching recharts
/// getRectanglePath for exact parity.
pub fn rectangle(
  x x: Float,
  y y: Float,
  width width: Float,
  height height: Float,
  radius radius: Float,
  fill fill: String,
) -> Element(msg) {
  case radius >. 0.0 {
    True ->
      rectangle_with_corners(
        x: x,
        y: y,
        width: width,
        height: height,
        top_left: radius,
        top_right: radius,
        bottom_right: radius,
        bottom_left: radius,
        fill: fill,
      )
    False ->
      svg.rect(
        x: math.fmt(x),
        y: math.fmt(y),
        width: math.fmt(width),
        height: math.fmt(height),
        attrs: [svg.attr("fill", fill)],
      )
  }
}

/// Render a rectangle with per-corner radius using SVG path.
/// Direct port of recharts Rectangle getRectanglePath, using SVG
/// arc (A) commands for corners with xSign/ySign for negative
/// width/height support.  Radius order: [tl, tr, br, bl].
pub fn rectangle_with_corners(
  x x: Float,
  y y: Float,
  width width: Float,
  height height: Float,
  top_left top_left: Float,
  top_right top_right: Float,
  bottom_right bottom_right: Float,
  bottom_left bottom_left: Float,
  fill fill: String,
) -> Element(msg) {
  let has_radius =
    top_left >. 0.0
    || top_right >. 0.0
    || bottom_right >. 0.0
    || bottom_left >. 0.0
  case has_radius {
    False ->
      rectangle(
        x: x,
        y: y,
        width: width,
        height: height,
        radius: 0.0,
        fill: fill,
      )
    True -> {
      // Matches: const maxRadius = Math.min(Math.abs(width) / 2, Math.abs(height) / 2)
      let max_r =
        math.list_min([math.abs(width) /. 2.0, math.abs(height) /. 2.0])
      let tl = math.clamp(top_left, 0.0, max_r)
      let tr = math.clamp(top_right, 0.0, max_r)
      let br = math.clamp(bottom_right, 0.0, max_r)
      let bl = math.clamp(bottom_left, 0.0, max_r)

      // Matches: const ySign = height >= 0 ? 1 : -1
      let ys = case height >=. 0.0 {
        True -> 1.0
        False -> -1.0
      }
      // Matches: const xSign = width >= 0 ? 1 : -1
      let xs = case width >=. 0.0 {
        True -> 1.0
        False -> -1.0
      }
      // Matches: const clockWise = (height >= 0 && width >= 0) || (height < 0 && width < 0) ? 1 : 0
      let cw = case
        { height >=. 0.0 && width >=. 0.0 } || { height <. 0.0 && width <. 0.0 }
      {
        True -> "1"
        False -> "0"
      }

      // Build path matching recharts getRectanglePath per-corner branch.
      // Arcs are conditionally emitted only when the corner radius > 0.
      //
      // M x,(y + ySign*tl)
      let d = "M" <> f(x) <> "," <> f(y +. ys *. tl)
      // Corner 0 (top-left): A tl,tl,0,0,cw,(x + xSign*tl),y
      let d = case tl >. 0.0 {
        True ->
          d
          <> "A "
          <> f(tl)
          <> ","
          <> f(tl)
          <> ",0,0,"
          <> cw
          <> ","
          <> f(x +. xs *. tl)
          <> ","
          <> f(y)
        False -> d
      }
      // L (x + width - xSign*tr),y
      let d = d <> "L " <> f(x +. width -. xs *. tr) <> "," <> f(y)
      // Corner 1 (top-right): A tr,tr,0,0,cw,(x + width),(y + ySign*tr)
      let d = case tr >. 0.0 {
        True ->
          d
          <> "A "
          <> f(tr)
          <> ","
          <> f(tr)
          <> ",0,0,"
          <> cw
          <> ","
          <> f(x +. width)
          <> ","
          <> f(y +. ys *. tr)
        False -> d
      }
      // L (x + width),(y + height - ySign*br)
      let d = d <> "L " <> f(x +. width) <> "," <> f(y +. height -. ys *. br)
      // Corner 2 (bottom-right): A br,br,0,0,cw,(x + width - xSign*br),(y + height)
      let d = case br >. 0.0 {
        True ->
          d
          <> "A "
          <> f(br)
          <> ","
          <> f(br)
          <> ",0,0,"
          <> cw
          <> ","
          <> f(x +. width -. xs *. br)
          <> ","
          <> f(y +. height)
        False -> d
      }
      // L (x + xSign*bl),(y + height)
      let d = d <> "L " <> f(x +. xs *. bl) <> "," <> f(y +. height)
      // Corner 3 (bottom-left): A bl,bl,0,0,cw,x,(y + height - ySign*bl)
      let d = case bl >. 0.0 {
        True ->
          d
          <> "A "
          <> f(bl)
          <> ","
          <> f(bl)
          <> ",0,0,"
          <> cw
          <> ","
          <> f(x)
          <> ","
          <> f(y +. height -. ys *. bl)
        False -> d
      }
      let d = d <> "Z"

      svg.path(d: d, attrs: [svg.attr("fill", fill)])
    }
  }
}

// ---------------------------------------------------------------------------
// Sector (recharts Sector component — pie/donut segments)
// ---------------------------------------------------------------------------

/// Render a pie/donut sector as an SVG arc path.
///
/// When `corner_radius` > 0 and the sector is not a full 360,
/// rounded corners are drawn at each radius transition matching
/// recharts Sector `cornerRadius` behavior.
pub fn sector(
  cx cx: Float,
  cy cy: Float,
  inner_radius inner_radius: Float,
  outer_radius outer_radius: Float,
  start_angle start_angle: Float,
  end_angle end_angle: Float,
  corner_radius corner_radius: Float,
  fill fill: String,
) -> Element(msg) {
  let delta_radius = outer_radius -. inner_radius
  let cr = math.clamp(corner_radius, 0.0, delta_radius /. 2.0)
  let d = case cr >. 0.0 && math.abs(start_angle -. end_angle) <. 360.0 {
    True ->
      polar.sector_path_with_corners(
        cx: cx,
        cy: cy,
        inner_radius: inner_radius,
        outer_radius: outer_radius,
        corner_radius: cr,
        force_corner_radius: False,
        corner_is_external: False,
        start_angle: start_angle,
        end_angle: end_angle,
      )
    False ->
      polar.sector_path(
        cx: cx,
        cy: cy,
        inner_radius: inner_radius,
        outer_radius: outer_radius,
        start_angle: start_angle,
        end_angle: end_angle,
      )
  }
  svg.path(d: d, attrs: [svg.attr("fill", fill)])
}

/// Render a pie/donut sector with explicit stroke and stroke width.
///
/// Same as `sector` but adds stroke and stroke-width attributes to the
/// rendered SVG path.  Used by pie series when blend_stroke is active or
/// custom stroke styling is needed.
pub fn sector_with_stroke(
  cx cx: Float,
  cy cy: Float,
  inner_radius inner_radius: Float,
  outer_radius outer_radius: Float,
  start_angle start_angle: Float,
  end_angle end_angle: Float,
  corner_radius corner_radius: Float,
  fill fill: String,
  stroke stroke: String,
  stroke_width stroke_width: Float,
) -> Element(msg) {
  let delta_radius = outer_radius -. inner_radius
  let cr = math.clamp(corner_radius, 0.0, delta_radius /. 2.0)
  let d = case cr >. 0.0 && math.abs(start_angle -. end_angle) <. 360.0 {
    True ->
      polar.sector_path_with_corners(
        cx: cx,
        cy: cy,
        inner_radius: inner_radius,
        outer_radius: outer_radius,
        corner_radius: cr,
        force_corner_radius: False,
        corner_is_external: False,
        start_angle: start_angle,
        end_angle: end_angle,
      )
    False ->
      polar.sector_path(
        cx: cx,
        cy: cy,
        inner_radius: inner_radius,
        outer_radius: outer_radius,
        start_angle: start_angle,
        end_angle: end_angle,
      )
  }
  svg.path(d: d, attrs: [
    svg.attr("fill", fill),
    svg.attr("stroke", stroke),
    svg.attr("stroke-width", f(stroke_width)),
  ])
}

// ---------------------------------------------------------------------------
// Polygon (recharts Polygon component — radar charts)
// ---------------------------------------------------------------------------

/// Render a closed polygon from a list of vertex points.
pub fn polygon(
  points points: List(#(Float, Float)),
  fill fill: String,
  stroke stroke: String,
) -> Element(msg) {
  let d = case points {
    [] -> ""
    [#(x0, y0), ..rest] -> {
      let start = "M" <> f(x0) <> "," <> f(y0)
      let segments =
        list.fold(rest, start, fn(acc, pt) {
          acc <> "L" <> f(pt.0) <> "," <> f(pt.1)
        })
      segments <> "Z"
    }
  }
  svg.path(d: d, attrs: [
    svg.attr("fill", fill),
    svg.attr("stroke", stroke),
  ])
}

/// Render a polygon with fill opacity and stroke width.
pub fn polygon_styled(
  points points: List(#(Float, Float)),
  fill fill: String,
  fill_opacity fill_opacity: Float,
  stroke stroke: String,
  stroke_width stroke_width: Float,
) -> Element(msg) {
  let d = case points {
    [] -> ""
    [#(x0, y0), ..rest] -> {
      let start = "M" <> f(x0) <> "," <> f(y0)
      let segments =
        list.fold(rest, start, fn(acc, pt) {
          acc <> "L" <> f(pt.0) <> "," <> f(pt.1)
        })
      segments <> "Z"
    }
  }
  svg.path(d: d, attrs: [
    svg.attr("fill", fill),
    svg.attr("fill-opacity", float.to_string(fill_opacity)),
    svg.attr("stroke", stroke),
    svg.attr("stroke-width", float.to_string(stroke_width)),
  ])
}

/// Generate a polygon SVG path string from a list of points.
///
/// When `connect_nulls` is False (default), NaN-like points break the path
/// into separate sub-paths using `M` moveto commands.  When True, invalid
/// points are filtered out and the remaining points are connected.
///
/// When `base_line_points` is `Some`, generates a range path: the outer
/// points traced forward, then the baseline points traced in reverse,
/// forming a closed shape.  Matches recharts Polygon `getRangePath`.
pub fn polygon_path(
  points points: List(#(Float, Float)),
  connect_nulls connect_nulls: Bool,
  base_line_points base_line_points: Option(List(#(Float, Float))),
) -> String {
  case base_line_points {
    Some(baseline) -> range_polygon_path(points, baseline, connect_nulls)
    None -> single_polygon_path(points, connect_nulls)
  }
}

/// Render a polygon with `connect_nulls` and optional baseline support.
///
/// Extends the basic `polygon` renderer with recharts Polygon parity:
/// `connect_nulls` controls whether null/invalid points break the path,
/// and `base_line_points` enables range (area-between) rendering.
pub fn polygon_with_options(
  points points: List(#(Float, Float)),
  connect_nulls connect_nulls: Bool,
  base_line_points base_line_points: Option(List(#(Float, Float))),
  fill fill: String,
  stroke stroke: String,
) -> Element(msg) {
  let d =
    polygon_path(
      points: points,
      connect_nulls: connect_nulls,
      base_line_points: base_line_points,
    )
  svg.path(d: d, attrs: [
    svg.attr("fill", fill),
    svg.attr("stroke", stroke),
  ])
}

// ---------------------------------------------------------------------------
// Symbol rendering (recharts Symbols component)
// ---------------------------------------------------------------------------

/// Symbol shapes for data point markers, matching recharts symbol types.
pub type SymbolType {
  /// Circle marker.
  CircleSymbol
  /// Cross/plus marker.
  CrossSymbol
  /// Diamond (rotated square) marker.
  DiamondSymbol
  /// Axis-aligned square marker.
  SquareSymbol
  /// Five-pointed star marker.
  StarSymbol
  /// Equilateral triangle marker (pointing up).
  TriangleSymbol
  /// Y-shape (3 arms at 120-degree intervals) marker.
  WyeSymbol
}

/// How the `size` parameter is interpreted for symbol rendering.
pub type SymbolSizeType {
  /// Interpret `size` as pixel area.
  AreaSize
  /// Interpret `size` as diameter.
  DiameterSize
}

/// Generate an SVG path `d` attribute for a symbol centered at `(cx, cy)`.
///
/// The `size` parameter is interpreted according to `size_type`:
/// - `AreaSize`: `size` is the symbol area in square pixels
/// - `DiameterSize`: `size` is the symbol diameter in pixels
///
/// Returns a path string suitable for use as an SVG `<path d="...">` attribute.
pub fn symbol_path(
  symbol_type symbol_type: SymbolType,
  cx cx: Float,
  cy cy: Float,
  size size: Float,
  size_type size_type: SymbolSizeType,
) -> String {
  case symbol_type {
    CircleSymbol -> circle_symbol_path(cx, cy, size, size_type)
    CrossSymbol -> cross_symbol_path(cx, cy, size, size_type)
    DiamondSymbol -> diamond_symbol_path(cx, cy, size, size_type)
    SquareSymbol -> square_symbol_path(cx, cy, size, size_type)
    StarSymbol -> star_symbol_path(cx, cy, size, size_type)
    TriangleSymbol -> triangle_symbol_path(cx, cy, size, size_type)
    WyeSymbol -> wye_symbol_path(cx, cy, size, size_type)
  }
}

// ---------------------------------------------------------------------------
// Legend symbols (d3 symbols used for legend icons)
// ---------------------------------------------------------------------------

/// Legend icon shape types matching recharts legend types.
pub type LegendIconType {
  /// Small circle symbol.
  CircleIcon
  /// Cross/plus symbol.
  CrossIcon
  /// Diamond symbol.
  DiamondIcon
  /// Plain horizontal line.
  PlainLineIcon
  /// Curved line (default for line/area series).
  LineIcon
  /// Filled rectangle (default for bar series).
  RectIcon
  /// Filled square.
  SquareIcon
  /// Five-pointed star.
  StarIcon
  /// Triangle symbol.
  TriangleIcon
  /// Wye (Y-shape) symbol.
  WyeIcon
  /// Suppresses this series from the legend entirely.
  NoneIcon
}

// ---------------------------------------------------------------------------
// Tooltip type (shared across series)
// ---------------------------------------------------------------------------

/// Whether a series appears in the tooltip.
pub type TooltipType {
  /// Include in tooltip (default).
  DefaultTooltip
  /// Exclude from tooltip.
  NoTooltip
}

/// Render a legend icon at the given position and size.
pub fn legend_icon(
  icon_type icon_type: LegendIconType,
  x x: Float,
  y y: Float,
  size size: Float,
  color color: String,
) -> Element(msg) {
  case icon_type {
    NoneIcon -> element.none()
    CircleIcon ->
      svg.circle(
        cx: f(x +. size /. 2.0),
        cy: f(y +. size /. 2.0),
        r: f(size /. 2.0),
        attrs: [svg.attr("fill", color)],
      )
    RectIcon ->
      svg.rect(x: f(x), y: f(y), width: f(size), height: f(size), attrs: [
        svg.attr("fill", color),
      ])
    SquareIcon ->
      svg.rect(x: f(x), y: f(y), width: f(size), height: f(size), attrs: [
        svg.attr("fill", color),
      ])
    PlainLineIcon ->
      svg.line(
        x1: f(x),
        y1: f(y +. size /. 2.0),
        x2: f(x +. size),
        y2: f(y +. size /. 2.0),
        attrs: [
          svg.attr("stroke", color),
          svg.attr("stroke-width", "4"),
          svg.attr("fill", "none"),
        ],
      )
    LineIcon -> {
      let mid_y = y +. size /. 2.0
      let sixth = size /. 6.0
      let third = size /. 3.0
      let d =
        "M"
        <> f(x)
        <> ","
        <> f(mid_y)
        <> "h"
        <> f(third)
        <> "A"
        <> f(sixth)
        <> ","
        <> f(sixth)
        <> ",0,1,1,"
        <> f(x +. 2.0 *. third)
        <> ","
        <> f(mid_y)
        <> "H"
        <> f(x +. size)
        <> "M"
        <> f(x +. 2.0 *. third)
        <> ","
        <> f(mid_y)
        <> "A"
        <> f(sixth)
        <> ","
        <> f(sixth)
        <> ",0,1,1,"
        <> f(x +. third)
        <> ","
        <> f(mid_y)
      svg.path(d: d, attrs: [
        svg.attr("stroke", color),
        svg.attr("stroke-width", "4"),
        svg.attr("fill", "none"),
      ])
    }
    DiamondIcon -> {
      let cx = x +. size /. 2.0
      let cy = y +. size /. 2.0
      let half = size /. 2.0
      let d =
        "M"
        <> f(cx)
        <> ","
        <> f(cy -. half)
        <> "L"
        <> f(cx +. half)
        <> ","
        <> f(cy)
        <> "L"
        <> f(cx)
        <> ","
        <> f(cy +. half)
        <> "L"
        <> f(cx -. half)
        <> ","
        <> f(cy)
        <> "Z"
      svg.path(d: d, attrs: [svg.attr("fill", color)])
    }
    TriangleIcon -> {
      let cx = x +. size /. 2.0
      let d =
        "M"
        <> f(cx)
        <> ","
        <> f(y)
        <> "L"
        <> f(x +. size)
        <> ","
        <> f(y +. size)
        <> "L"
        <> f(x)
        <> ","
        <> f(y +. size)
        <> "Z"
      svg.path(d: d, attrs: [svg.attr("fill", color)])
    }
    CrossIcon -> {
      let cx = x +. size /. 2.0
      let cy = y +. size /. 2.0
      let arm = size /. 6.0
      let half = size /. 2.0
      let d =
        "M"
        <> f(cx -. arm)
        <> ","
        <> f(cy -. half)
        <> "L"
        <> f(cx +. arm)
        <> ","
        <> f(cy -. half)
        <> "L"
        <> f(cx +. arm)
        <> ","
        <> f(cy -. arm)
        <> "L"
        <> f(cx +. half)
        <> ","
        <> f(cy -. arm)
        <> "L"
        <> f(cx +. half)
        <> ","
        <> f(cy +. arm)
        <> "L"
        <> f(cx +. arm)
        <> ","
        <> f(cy +. arm)
        <> "L"
        <> f(cx +. arm)
        <> ","
        <> f(cy +. half)
        <> "L"
        <> f(cx -. arm)
        <> ","
        <> f(cy +. half)
        <> "L"
        <> f(cx -. arm)
        <> ","
        <> f(cy +. arm)
        <> "L"
        <> f(cx -. half)
        <> ","
        <> f(cy +. arm)
        <> "L"
        <> f(cx -. half)
        <> ","
        <> f(cy -. arm)
        <> "L"
        <> f(cx -. arm)
        <> ","
        <> f(cy -. arm)
        <> "Z"
      svg.path(d: d, attrs: [svg.attr("fill", color)])
    }
    StarIcon -> {
      // 5-pointed star
      let cx = x +. size /. 2.0
      let cy = y +. size /. 2.0
      let outer = size /. 2.0
      let inner = outer *. 0.4
      let star_points =
        int.range(from: 0, to: 10, with: [], run: fn(acc, i) { [i, ..acc] })
        |> list.reverse
        |> list.map(fn(i) {
          let angle = float.multiply(int_to_float(i), 36.0) -. 90.0
          let r = case i % 2 == 0 {
            True -> outer
            False -> inner
          }
          let rad = math.to_radians(angle)
          #(cx +. r *. math.cos(rad), cy +. r *. math.sin(rad))
        })
      let d = case star_points {
        [] -> ""
        [#(sx, sy), ..srest] -> {
          let start = "M" <> f(sx) <> "," <> f(sy)
          list.fold(srest, start, fn(sacc, spt) {
            sacc <> "L" <> f(spt.0) <> "," <> f(spt.1)
          })
          <> "Z"
        }
      }
      svg.path(d: d, attrs: [svg.attr("fill", color)])
    }
    WyeIcon -> {
      // Y-shape symbol
      let cx = x +. size /. 2.0
      let cy = y +. size /. 2.0
      let arm = size *. 0.4
      let half_w = size *. 0.12
      let d =
        "M"
        <> f(cx -. half_w)
        <> ","
        <> f(cy)
        <> "L"
        <> f(cx -. arm)
        <> ","
        <> f(cy -. arm)
        <> "L"
        <> f(cx -. arm +. half_w *. 2.0)
        <> ","
        <> f(cy -. arm)
        <> "L"
        <> f(cx)
        <> ","
        <> f(cy -. half_w)
        <> "L"
        <> f(cx +. arm -. half_w *. 2.0)
        <> ","
        <> f(cy -. arm)
        <> "L"
        <> f(cx +. arm)
        <> ","
        <> f(cy -. arm)
        <> "L"
        <> f(cx +. half_w)
        <> ","
        <> f(cy)
        <> "L"
        <> f(cx +. half_w)
        <> ","
        <> f(cy +. arm)
        <> "L"
        <> f(cx -. half_w)
        <> ","
        <> f(cy +. arm)
        <> "Z"
      svg.path(d: d, attrs: [svg.attr("fill", color)])
    }
  }
}

// ---------------------------------------------------------------------------
// Cross (recharts Cross component)
// ---------------------------------------------------------------------------

/// Render a cross (plus/crosshair) shape at a given position.
///
/// Matches the recharts Cross component: draws a vertical line from
/// `(x, top)` to `(x, top + height)` and a horizontal line from
/// `(left, y)` to `(left + width, y)`.  The SVG path uses relative
/// `v` and `h` commands matching the recharts path formula.
pub fn cross(
  x x: Float,
  y y: Float,
  top top: Float,
  left left: Float,
  width width: Float,
  height height: Float,
  stroke stroke: String,
  stroke_width stroke_width: Float,
) -> Element(msg) {
  let d =
    "M"
    <> f(x)
    <> ","
    <> f(top)
    <> "v"
    <> f(height)
    <> "M"
    <> f(left)
    <> ","
    <> f(y)
    <> "h"
    <> f(width)

  svg.path(d: d, attrs: [
    svg.attr("stroke", stroke),
    svg.attr("stroke-width", f(stroke_width)),
    svg.attr("fill", "none"),
    svg.attr("class", "recharts-cross"),
  ])
}

// ---------------------------------------------------------------------------
// Trapezoid (recharts Trapezoid component — funnel segments)
// ---------------------------------------------------------------------------

/// Render a trapezoid shape used by FunnelChart segments.
///
/// The trapezoid has two horizontal parallel edges (top and bottom) of
/// potentially different widths, centered within a bounding box.
/// - `x`: left edge of the bounding box
/// - `y`: top edge of the bounding box
/// - `upper_width`: width of the top edge
/// - `lower_width`: width of the bottom edge
/// - `height`: height of the trapezoid
/// - `fill`: fill color
///
/// Both edges are centered horizontally within the bounding box
/// whose width is `max(upper_width, lower_width)`.
pub fn trapezoid(
  x x: Float,
  y y: Float,
  upper_width upper_width: Float,
  lower_width lower_width: Float,
  height height: Float,
  fill fill: String,
) -> Element(msg) {
  let max_w = case upper_width >. lower_width {
    True -> upper_width
    False -> lower_width
  }
  let center_x = x +. max_w /. 2.0

  // Four corners: top-left, top-right, bottom-right, bottom-left
  let tl_x = center_x -. upper_width /. 2.0
  let tr_x = center_x +. upper_width /. 2.0
  let bl_x = center_x -. lower_width /. 2.0
  let br_x = center_x +. lower_width /. 2.0
  let bottom_y = y +. height

  let d =
    "M"
    <> f(tl_x)
    <> ","
    <> f(y)
    <> "L"
    <> f(tr_x)
    <> ","
    <> f(y)
    <> "L"
    <> f(br_x)
    <> ","
    <> f(bottom_y)
    <> "L"
    <> f(bl_x)
    <> ","
    <> f(bottom_y)
    <> "Z"

  svg.path(d: d, attrs: [
    svg.attr("fill", fill),
    svg.attr("class", "recharts-trapezoid"),
  ])
}

/// Render a trapezoid shape with stroke styling.
///
/// Same as `trapezoid` but adds stroke and stroke-width attributes.
/// Used by funnel series for segment borders.
pub fn trapezoid_with_stroke(
  x x: Float,
  y y: Float,
  upper_width upper_width: Float,
  lower_width lower_width: Float,
  height height: Float,
  fill fill: String,
  stroke stroke: String,
  stroke_width stroke_width: Float,
) -> Element(msg) {
  let max_w = case upper_width >. lower_width {
    True -> upper_width
    False -> lower_width
  }
  let center_x = x +. max_w /. 2.0

  let tl_x = center_x -. upper_width /. 2.0
  let tr_x = center_x +. upper_width /. 2.0
  let bl_x = center_x -. lower_width /. 2.0
  let br_x = center_x +. lower_width /. 2.0
  let bottom_y = y +. height

  let d =
    "M"
    <> f(tl_x)
    <> ","
    <> f(y)
    <> "L"
    <> f(tr_x)
    <> ","
    <> f(y)
    <> "L"
    <> f(br_x)
    <> ","
    <> f(bottom_y)
    <> "L"
    <> f(bl_x)
    <> ","
    <> f(bottom_y)
    <> "Z"

  svg.path(d: d, attrs: [
    svg.attr("fill", fill),
    svg.attr("stroke", stroke),
    svg.attr("stroke-width", f(stroke_width)),
    svg.attr("class", "recharts-trapezoid"),
  ])
}

// ---------------------------------------------------------------------------
// Polygon path helpers (matching recharts Polygon.tsx)
// ---------------------------------------------------------------------------

/// Build a single polygon path, handling invalid (NaN-like) points by
/// breaking into sub-paths.  Matches recharts `getSinglePolygonPath`.
fn single_polygon_path(
  points: List(#(Float, Float)),
  connect_nulls: Bool,
) -> String {
  case points {
    [] -> ""
    _ -> {
      let segments = parse_polygon_points(points)
      let merged = case connect_nulls {
        True -> [list.flatten(segments)]
        False -> segments
      }
      let path_str =
        merged
        |> list.map(fn(seg) { segment_to_path(seg) })
        |> string.join("")
      case list.length(merged) == 1 {
        True -> path_str <> "Z"
        False -> path_str
      }
    }
  }
}

/// Build a range polygon path: outer path forward + baseline reversed.
/// Matches recharts `getRangePath`.
fn range_polygon_path(
  points: List(#(Float, Float)),
  baseline: List(#(Float, Float)),
  connect_nulls: Bool,
) -> String {
  let outer = single_polygon_path(points, connect_nulls)
  let trimmed = case string.ends_with(outer, "Z") {
    True -> string.drop_end(outer, 1)
    False -> outer
  }
  let baseline_path = single_polygon_path(list.reverse(baseline), connect_nulls)
  // Skip the first character (M) of baseline path and join with L
  let baseline_suffix = case string.length(baseline_path) > 1 {
    True -> string.drop_start(baseline_path, 1)
    False -> ""
  }
  trimmed <> "L" <> baseline_suffix
}

/// Parse points into segments, splitting on invalid points.
/// Appends the first valid point to close each segment.
/// Matches recharts `getParsedPoints`.
fn parse_polygon_points(
  points: List(#(Float, Float)),
) -> List(List(#(Float, Float))) {
  let #(segments, current) =
    list.fold(points, #([], []), fn(state, pt) {
      let #(segs, cur) = state
      case is_valid_point(pt) {
        True -> #(segs, [pt, ..cur])
        False ->
          case cur {
            [] -> #(segs, [])
            _ -> #([list.reverse(cur), ..segs], [])
          }
      }
    })
  // Finalize the last segment
  let all_segments = case current {
    [] -> segments
    _ -> [list.reverse(current), ..segments]
  }
  let result = list.reverse(all_segments)
  // Append first valid point to close each segment
  let first_valid = case points {
    [pt, ..] ->
      case is_valid_point(pt) {
        True -> Some(pt)
        False -> None
      }
    _ -> None
  }
  case first_valid {
    Some(pt) -> list.map(result, fn(seg) { list.append(seg, [pt]) })
    None -> result
  }
}

fn is_valid_point(point: #(Float, Float)) -> Bool {
  // A point is valid if both coordinates are finite numbers.
  // In Gleam, Float values are always valid numbers (no NaN/Infinity),
  // so all points are valid by default. This function exists for
  // API compatibility with recharts' isValidatePoint.
  let #(_x, _y) = point
  True
}

fn segment_to_path(points: List(#(Float, Float))) -> String {
  case points {
    [] -> ""
    [#(x0, y0), ..rest] ->
      list.fold(rest, "M" <> f(x0) <> "," <> f(y0), fn(acc, pt) {
        acc <> "L" <> f(pt.0) <> "," <> f(pt.1)
      })
  }
}

// ---------------------------------------------------------------------------
// Symbol path generators
// ---------------------------------------------------------------------------

fn circle_symbol_path(
  cx: Float,
  cy: Float,
  size: Float,
  size_type: SymbolSizeType,
) -> String {
  let r = case size_type {
    AreaSize -> math.sqrt(size /. math.pi)
    DiameterSize -> size /. 2.0
  }
  "M"
  <> f(cx -. r)
  <> ","
  <> f(cy)
  <> "A"
  <> f(r)
  <> ","
  <> f(r)
  <> ",0,1,0,"
  <> f(cx +. r)
  <> ","
  <> f(cy)
  <> "A"
  <> f(r)
  <> ","
  <> f(r)
  <> ",0,1,0,"
  <> f(cx -. r)
  <> ","
  <> f(cy)
}

fn cross_symbol_path(
  cx: Float,
  cy: Float,
  size: Float,
  size_type: SymbolSizeType,
) -> String {
  // Cross: plus shape with arms extending r from center, arm width = r/3*2
  // For AreaSize: area = (5/9)*d^2, so d = sqrt(9*size/5)
  // For DiameterSize: d = size
  let d = case size_type {
    AreaSize -> math.sqrt(9.0 *. size /. 5.0)
    DiameterSize -> size
  }
  let half = d /. 2.0
  let arm = d /. 6.0
  "M"
  <> f(cx -. arm)
  <> ","
  <> f(cy -. half)
  <> "L"
  <> f(cx +. arm)
  <> ","
  <> f(cy -. half)
  <> "L"
  <> f(cx +. arm)
  <> ","
  <> f(cy -. arm)
  <> "L"
  <> f(cx +. half)
  <> ","
  <> f(cy -. arm)
  <> "L"
  <> f(cx +. half)
  <> ","
  <> f(cy +. arm)
  <> "L"
  <> f(cx +. arm)
  <> ","
  <> f(cy +. arm)
  <> "L"
  <> f(cx +. arm)
  <> ","
  <> f(cy +. half)
  <> "L"
  <> f(cx -. arm)
  <> ","
  <> f(cy +. half)
  <> "L"
  <> f(cx -. arm)
  <> ","
  <> f(cy +. arm)
  <> "L"
  <> f(cx -. half)
  <> ","
  <> f(cy +. arm)
  <> "L"
  <> f(cx -. half)
  <> ","
  <> f(cy -. arm)
  <> "L"
  <> f(cx -. arm)
  <> ","
  <> f(cy -. arm)
  <> "Z"
}

fn diamond_symbol_path(
  cx: Float,
  cy: Float,
  size: Float,
  size_type: SymbolSizeType,
) -> String {
  // Diamond: rotated square, 4 points at cardinal directions
  // For AreaSize: area = d^2/(2*sqrt(3)), so d = sqrt(2*sqrt(3)*size)
  // For DiameterSize: d = size
  let d = case size_type {
    AreaSize -> math.sqrt(2.0 *. math.sqrt(3.0) *. size)
    DiameterSize -> size
  }
  let half = d /. 2.0
  "M"
  <> f(cx)
  <> ","
  <> f(cy -. half)
  <> "L"
  <> f(cx +. half)
  <> ","
  <> f(cy)
  <> "L"
  <> f(cx)
  <> ","
  <> f(cy +. half)
  <> "L"
  <> f(cx -. half)
  <> ","
  <> f(cy)
  <> "Z"
}

fn square_symbol_path(
  cx: Float,
  cy: Float,
  size: Float,
  size_type: SymbolSizeType,
) -> String {
  // Square: axis-aligned, centered on point
  // For AreaSize: area = d^2, so d = sqrt(size)
  // For DiameterSize: d = size
  let d = case size_type {
    AreaSize -> math.sqrt(size)
    DiameterSize -> size
  }
  let half = d /. 2.0
  "M"
  <> f(cx -. half)
  <> ","
  <> f(cy -. half)
  <> "L"
  <> f(cx +. half)
  <> ","
  <> f(cy -. half)
  <> "L"
  <> f(cx +. half)
  <> ","
  <> f(cy +. half)
  <> "L"
  <> f(cx -. half)
  <> ","
  <> f(cy +. half)
  <> "Z"
}

fn star_symbol_path(
  cx: Float,
  cy: Float,
  size: Float,
  size_type: SymbolSizeType,
) -> String {
  // 5-pointed star, inner radius = outer * 0.382
  // For AreaSize: use recharts formula
  //   angle = 18 * RADIAN
  //   area = 1.25 * d^2 * (tan(angle) - tan(2*angle) * tan(angle)^2)
  //   so d = sqrt(size / (1.25 * (tan(a) - tan(2a)*tan(a)^2)))
  // For DiameterSize: d = size
  let d = case size_type {
    AreaSize -> {
      let angle = math.to_radians(18.0)
      let tan_a = math.sin(angle) /. math.cos(angle)
      let tan_2a = math.sin(2.0 *. angle) /. math.cos(2.0 *. angle)
      let factor = 1.25 *. { tan_a -. tan_2a *. tan_a *. tan_a }
      case factor >. 0.0 {
        True -> math.sqrt(size /. factor)
        False -> math.sqrt(size)
      }
    }
    DiameterSize -> size
  }
  let outer = d /. 2.0
  let inner = outer *. 0.382
  let star_points =
    int.range(from: 0, to: 10, with: [], run: fn(acc, i) { [i, ..acc] })
    |> list.reverse
    |> list.map(fn(i) {
      let angle = int.to_float(i) *. 36.0 -. 90.0
      let r = case i % 2 == 0 {
        True -> outer
        False -> inner
      }
      let rad = math.to_radians(angle)
      #(cx +. r *. math.cos(rad), cy +. r *. math.sin(rad))
    })
  case star_points {
    [] -> ""
    [#(sx, sy), ..srest] -> {
      let start = "M" <> f(sx) <> "," <> f(sy)
      list.fold(srest, start, fn(sacc, spt) {
        sacc <> "L" <> f(spt.0) <> "," <> f(spt.1)
      })
      <> "Z"
    }
  }
}

fn triangle_symbol_path(
  cx: Float,
  cy: Float,
  size: Float,
  size_type: SymbolSizeType,
) -> String {
  // Equilateral triangle pointing up
  // For AreaSize: area = sqrt(3)/4 * d^2, so d = sqrt(4*size/sqrt(3))
  // For DiameterSize: d = size
  let d = case size_type {
    AreaSize -> math.sqrt(4.0 *. size /. math.sqrt(3.0))
    DiameterSize -> size
  }
  let half = d /. 2.0
  // Height of equilateral triangle = d * sqrt(3) / 2
  let h = d *. math.sqrt(3.0) /. 2.0
  // Center the triangle vertically: top at cy - 2h/3, bottom at cy + h/3
  let top_y = cy -. h *. 2.0 /. 3.0
  let bottom_y = cy +. h /. 3.0
  "M"
  <> f(cx)
  <> ","
  <> f(top_y)
  <> "L"
  <> f(cx +. half)
  <> ","
  <> f(bottom_y)
  <> "L"
  <> f(cx -. half)
  <> ","
  <> f(bottom_y)
  <> "Z"
}

fn wye_symbol_path(
  cx: Float,
  cy: Float,
  size: Float,
  size_type: SymbolSizeType,
) -> String {
  // Y-shape symbol: 3 arms at 120-degree intervals
  // For AreaSize: area = ((21-10*sqrt(3))/8) * d^2
  //   so d = sqrt(8*size / (21-10*sqrt(3)))
  // For DiameterSize: d = size
  let d = case size_type {
    AreaSize -> {
      let factor = { 21.0 -. 10.0 *. math.sqrt(3.0) } /. 8.0
      case factor >. 0.0 {
        True -> math.sqrt(size /. factor)
        False -> math.sqrt(size)
      }
    }
    DiameterSize -> size
  }
  let arm = d *. 0.4
  let half_w = d *. 0.12
  "M"
  <> f(cx -. half_w)
  <> ","
  <> f(cy)
  <> "L"
  <> f(cx -. arm)
  <> ","
  <> f(cy -. arm)
  <> "L"
  <> f(cx -. arm +. half_w *. 2.0)
  <> ","
  <> f(cy -. arm)
  <> "L"
  <> f(cx)
  <> ","
  <> f(cy -. half_w)
  <> "L"
  <> f(cx +. arm -. half_w *. 2.0)
  <> ","
  <> f(cy -. arm)
  <> "L"
  <> f(cx +. arm)
  <> ","
  <> f(cy -. arm)
  <> "L"
  <> f(cx +. half_w)
  <> ","
  <> f(cy)
  <> "L"
  <> f(cx +. half_w)
  <> ","
  <> f(cy +. arm)
  <> "L"
  <> f(cx -. half_w)
  <> ","
  <> f(cy +. arm)
  <> "Z"
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn f(value: Float) -> String {
  math.fmt(value)
}

fn int_to_float(i: Int) -> Float {
  case i {
    0 -> 0.0
    1 -> 1.0
    2 -> 2.0
    3 -> 3.0
    4 -> 4.0
    5 -> 5.0
    6 -> 6.0
    7 -> 7.0
    8 -> 8.0
    9 -> 9.0
    _ -> {
      let base = int_to_float(i / 10) *. 10.0
      let rem = int_to_float(i % 10)
      base +. rem
    }
  }
}
