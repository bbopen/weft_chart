# weft_chart

[![Package Version](https://img.shields.io/hexpm/v/weft_chart)](https://hex.pm/packages/weft_chart)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/weft_chart/)

SVG chart rendering for weft_lustre — area charts with natural cubic spline interpolation and gradient fills.

## Installation

```sh
gleam add weft_chart
```

## Usage

See [SPEC.md](SPEC.md) for the complete technical specification.

## Preferred API Path (Additive v2)

The library now includes additive v2 config helpers for axis and shared series metadata:

- `axis.x_axis_base_config` / `axis.y_axis_base_config`
- `chart.x_axis_v2` / `chart.y_axis_v2`
- `series/common.series_meta`
- `line.line_config_v2`, `area.area_config_v2`, `bar.bar_config_v2`

Legacy APIs remain fully supported in this cycle (`x_axis_config`, `y_axis_config`, `line_config`, `area_config`, `bar_config`) and are kept as compatibility paths.
