//// Cartesian tooltip payload helpers.
////
//// Converts chart rows and series metadata into tooltip payloads with
//// layout-aware coordinates and active-dot positions.

import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import weft_chart/internal/layout
import weft_chart/scale
import weft_chart/tooltip

/// Tooltip metadata for one series.
pub type TooltipSeriesInfo {
  TooltipSeriesInfo(
    data_key: String,
    display_name: String,
    color: String,
    hidden: Bool,
    no_tooltip: Bool,
    unit: String,
  )
}

/// Tooltip input row.
pub type TooltipDatum {
  TooltipDatum(category: String, values: Dict(String, Float))
}

/// Construct tooltip metadata for one series.
pub fn tooltip_series_info(
  data_key data_key: String,
  display_name display_name: String,
  color color: String,
  hidden hidden: Bool,
  no_tooltip no_tooltip: Bool,
  unit unit: String,
) -> TooltipSeriesInfo {
  TooltipSeriesInfo(
    data_key: data_key,
    display_name: display_name,
    color: color,
    hidden: hidden,
    no_tooltip: no_tooltip,
    unit: unit,
  )
}

/// Construct one tooltip input row.
pub fn tooltip_datum(
  category category: String,
  values values: Dict(String, Float),
) -> TooltipDatum {
  TooltipDatum(category: category, values: values)
}

/// Build tooltip payloads for cartesian charts.
///
/// Horizontal layout maps category->x and value->y.
/// Vertical layout maps value->x and category->y.
pub fn build_payloads(
  data data: List(TooltipDatum),
  series_info series_info: List(TooltipSeriesInfo),
  x_scale x_scale: scale.Scale,
  y_scale y_scale: scale.Scale,
  chart_layout chart_layout: layout.LayoutDirection,
  include_hidden include_hidden: Bool,
  filter_null filter_null: Bool,
  y_unit y_unit: String,
) -> List(tooltip.TooltipPayload) {
  list.map(data, fn(datum) {
    let entries =
      list.filter_map(series_info, fn(info) {
        let effective_unit = case info.unit {
          "" -> y_unit
          value -> value
        }
        case info.no_tooltip {
          True -> skip()
          False ->
            case info.hidden && !include_hidden {
              True -> skip()
              False ->
                case dict.get(datum.values, info.data_key) {
                  Ok(value) ->
                    include(tooltip.TooltipEntry(
                      name: info.display_name,
                      value: value,
                      color: info.color,
                      unit: effective_unit,
                      hidden: info.hidden,
                      entry_type: tooltip.VisibleEntry,
                    ))
                  Error(_) ->
                    case filter_null {
                      True -> skip()
                      False ->
                        include(tooltip.TooltipEntry(
                          name: info.display_name,
                          value: 0.0,
                          color: info.color,
                          unit: effective_unit,
                          hidden: info.hidden,
                          entry_type: tooltip.VisibleEntry,
                        ))
                    }
                }
            }
        }
      })

    let #(x, y, active_positions) = case chart_layout {
      layout.Horizontal -> {
        let x = scale.point_apply(x_scale, datum.category)
        let active_ys =
          list.map(entries, fn(entry) { scale.apply(y_scale, entry.value) })
        #(x, average_or_zero(active_ys), active_ys)
      }
      layout.Vertical -> {
        let y = scale.point_apply(y_scale, datum.category)
        let active_xs =
          list.map(entries, fn(entry) { scale.apply(x_scale, entry.value) })
        #(average_or_zero(active_xs), y, active_xs)
      }
    }

    tooltip.TooltipPayload(
      label: datum.category,
      entries: entries,
      x: x,
      y: y,
      active_dots: active_positions,
      zone_width: 0.0,
      zone_height: 0.0,
    )
  })
}

fn average_or_zero(values: List(Float)) -> Float {
  case values {
    [] -> 0.0
    xs -> {
      let sum = list.fold(xs, 0.0, fn(acc, value) { acc +. value })
      sum /. int.to_float(list.length(xs))
    }
  }
}

fn include(value: a) -> Result(a, Nil) {
  Ok(value)
}

fn skip() -> Result(a, Nil) {
  Error(Nil)
}
