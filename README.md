# weft_chart

[![Package Version](https://img.shields.io/hexpm/v/weft_chart)](https://hex.pm/packages/weft_chart)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/weft_chart/)

SVG chart rendering for [Lustre](https://hexdocs.pm/lustre/) applications,
written in pure Gleam. It runs on both Erlang and JavaScript targets.

`weft_chart` gives you typed, composable chart primitives that produce
deterministic SVG output. The API follows Recharts conventions adapted to
Gleam idioms: you pick a chart container, add series and decoration children,
and get back a Lustre `Element(msg)`.

## Installation

Before the first Hex release, use local path dependencies from a checked-out
stack:

```toml
[dependencies]
weft = { path = "../weft" }
weft_chart = { path = "../weft_chart" }
```

After Hex publish, install with:

```toml
[dependencies]
weft_chart = ">= 0.2.0 and < 1.0.0"
```

`weft_chart` depends on [`weft`](https://github.com/bbopen/weft) and
[`lustre`](https://hexdocs.pm/lustre/).

## Chart types

Cartesian charts: `area_chart`, `bar_chart`, `line_chart`, `scatter_chart`,
`composed_chart` (mixed series on shared axes).

Polar charts: `pie_chart`, `radar_chart`, `radial_bar_chart`.

Hierarchical/flow charts: `treemap_chart`, `sunburst_chart`, `sankey_chart`,
`funnel_chart`.

## Quick start

```gleam
import gleam/option.{None}
import weft_chart.{data_point}
import weft_chart/axis
import weft_chart/chart
import weft_chart/curve
import weft_chart/grid
import weft_chart/series/area
import weft_chart/series/common
import weft_chart/tooltip

let data = [
  data_point("Jan", [#("desktop", 186.0), #("mobile", 80.0)]),
  data_point("Feb", [#("desktop", 305.0), #("mobile", 200.0)]),
  data_point("Mar", [#("desktop", 237.0), #("mobile", 120.0)]),
]

chart.area_chart(
  data: data,
  width: chart.FixedWidth(pixels: 700),
  height: 320,
  theme: None,
  children: [
    chart.cartesian_grid(
      grid.cartesian_grid_config()
      |> grid.grid_vertical(False),
    ),
    chart.x_axis(
      axis.x_axis_config()
      |> axis.axis_data_key("category")
      |> axis.axis_tick_line(False),
    ),
    chart.tooltip(tooltip.tooltip_config()),
    chart.area(
      area.area_config(data_key: "desktop", meta: common.series_meta())
      |> area.area_curve_type(curve.Natural)
      |> area.area_fill_opacity(0.3),
    ),
    chart.area(
      area.area_config(data_key: "mobile", meta: common.series_meta())
      |> area.area_curve_type(curve.Natural)
      |> area.area_fill_opacity(0.3),
    ),
  ],
)
```

## Notable features

Curves use natural cubic spline interpolation (`curve.Natural`), which
produces smooth lines without the wobble artifacts you get from Catmull-Rom.
Linear, step, and monotone-x interpolation are also available.

Area and bar series support gradient fills. Define gradient stops on the
series config and the chart renders an SVG `<linearGradient>` automatically.

Sizing is handled through `ChartWidth`: `FixedWidth(pixels: 700)` renders a
fixed-size SVG, while `FillWidth` adds a `viewBox` so the chart scales to
fill its container.

Tooltip styling uses CSS custom properties. You can pass
`chart.chart_theme_light()` or `chart.chart_theme_dark()` to the chart's
`theme` parameter, and it'll inject a scoped `<style>` block with the right
colors.

Stacking works by assigning matching `stack_id` values to series in the
same chart. The library handles offset calculation and rendering order.

## Development

```sh
bash scripts/check.sh
```

This runs grep gates, formatting, dual-target builds with warnings-as-errors,
tests, and doc generation.

Pre-publish note: this branch intentionally uses a Hex semver dependency on
`weft`. Until `weft` is published to Hex, dependency resolution in clean
environments is expected to fail. This is temporary and enforced by the stack
preflight gate so the failure mode is explicit.

## License

Apache-2.0
