# weft_chart

[![Package Version](https://img.shields.io/hexpm/v/weft_chart)](https://hex.pm/packages/weft_chart)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/weft_chart/)

Type-safe SVG chart rendering for Lustre, written in pure Gleam.

`weft_chart` provides a compositional API for building cartesian and polar charts
that render deterministic SVG output across Erlang and JavaScript targets.

## Why `weft_chart`

- Pure Gleam implementation (no FFI)
- Cross-target support (Erlang + JavaScript)
- Compositional chart API via typed child elements
- Recharts-style chart/series primitives adapted to Gleam idioms
- Strong regression suite and explicit spec-driven architecture

## Supported Charts

- `chart.area_chart`
- `chart.bar_chart`
- `chart.line_chart`
- `chart.composed_chart`
- `chart.pie_chart`
- `chart.radar_chart`
- `chart.radial_bar_chart`
- `chart.scatter_chart`
- `chart.funnel_chart`
- `chart.treemap_chart`
- `chart.sunburst_chart`
- `chart.sankey_chart`

## Installation

```sh
gleam add weft_chart
```

## Quick Start

```gleam
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

chart.area_chart(data: data, width: 700, height: 320, children: [
  chart.margin(top: 10, right: 16, bottom: 10, left: 8),
  chart.cartesian_grid(
    grid.cartesian_grid_config()
    |> grid.grid_vertical(False),
  ),
  chart.x_axis(
    axis.x_axis_config()
    |> axis.axis_data_key("category")
    |> axis.axis_tick_line(False)
    |> axis.axis_axis_line(False),
  ),
  chart.y_axis(
    axis.y_axis_config()
    |> axis.axis_axis_line(False),
  ),
  chart.tooltip(tooltip.tooltip_config()),
  chart.area(
    area.area_config(
      data_key: "desktop",
      meta: common.series_meta(),
    )
    |> area.area_curve_type(curve.Natural)
    |> area.area_fill_opacity(0.3),
  ),
  chart.area(
    area.area_config(
      data_key: "mobile",
      meta: common.series_meta(),
    )
    |> area.area_curve_type(curve.Natural)
    |> area.area_fill_opacity(0.3),
  ),
])
```

## API Overview

- Axis API:
  - `axis.x_axis_config()` and `axis.y_axis_config()` return `axis.AxisBaseConfig(msg)`
  - configure via shared `axis.axis_*` builders
  - attach with `chart.x_axis(...)` and `chart.y_axis(...)`
- Cartesian series constructors:
  - `line.line_config(data_key:, meta:)`
  - `area.area_config(data_key:, meta:)`
  - `bar.bar_config(data_key:, meta:)`
  - shared metadata in `weft_chart/series/common`
- Normalized chart child names:
  - `chart.pie`, `chart.radar`, `chart.radial_bar`, `chart.scatter`
  - `chart.funnel`, `chart.treemap`, `chart.sunburst`, `chart.sankey`
  - `chart.tooltip`, `chart.legend`, `chart.brush`, `chart.reference_dot`
  - `chart.error_bar`, `chart.title`, `chart.desc`, `chart.event`, `chart.layout`

## Development

Run the full local verification chain:

```sh
bash scripts/grep-gates.sh
gleam format --check src test
gleam build --target erlang --warnings-as-errors
gleam build --target javascript --warnings-as-errors
gleam test
gleam docs build
```

## Documentation

- Full technical specification: [`SPEC.md`](SPEC.md)
- Generated docs: [`hexdocs.pm/weft_chart`](https://hexdocs.pm/weft_chart/)
