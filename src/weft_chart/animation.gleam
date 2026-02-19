//// SVG SMIL animation builders.
////
//// Generates `<animate>` elements that produce smooth entry animations
//// on chart series.  For CSS-native easings (linear, ease, ease-in,
//// ease-out, ease-in-out), emits `calcMode="spline"` with `keySplines`.
//// For complex easings, pre-computes baked keyframes sampled from the
//// easing function.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import weft_chart/easing.{type Easing}
import weft_chart/internal/layout.{type LayoutDirection, Horizontal}
import weft_chart/internal/math
import weft_chart/internal/svg

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Configuration for series entry animation.
pub type AnimationConfig {
  AnimationConfig(
    active: Bool,
    duration: Int,
    delay: Int,
    easing: Easing,
    fill_mode: FillMode,
    animate_new_values: Bool,
    on_animation_start: Option(String),
    on_animation_end: Option(String),
    animation_id: Option(String),
  )
}

/// How the animation holds its final value.
pub type FillMode {
  /// Hold the final animated value (default).
  Freeze
  /// Revert to the initial value after animation.
  Remove
}

// ---------------------------------------------------------------------------
// Default constructors
// ---------------------------------------------------------------------------

/// Bar animation defaults: 400ms, Ease easing, no delay.
pub fn bar_default() -> AnimationConfig {
  AnimationConfig(
    active: True,
    duration: 400,
    delay: 0,
    easing: easing.Ease,
    fill_mode: Freeze,
    animate_new_values: False,
    on_animation_start: None,
    on_animation_end: None,
    animation_id: None,
  )
}

/// Scatter animation defaults: 400ms, Linear easing, no delay.
pub fn scatter_default() -> AnimationConfig {
  AnimationConfig(
    active: True,
    duration: 400,
    delay: 0,
    easing: easing.Linear,
    fill_mode: Freeze,
    animate_new_values: False,
    on_animation_start: None,
    on_animation_end: None,
    animation_id: None,
  )
}

/// Line/Area/Radar/RadialBar defaults: 1500ms, Ease easing, no delay.
pub fn line_default() -> AnimationConfig {
  AnimationConfig(
    active: True,
    duration: 1500,
    delay: 0,
    easing: easing.Ease,
    fill_mode: Freeze,
    animate_new_values: False,
    on_animation_start: None,
    on_animation_end: None,
    animation_id: None,
  )
}

/// Pie/Funnel defaults: 1500ms, Ease easing, 400ms delay.
pub fn pie_default() -> AnimationConfig {
  AnimationConfig(
    active: True,
    duration: 1500,
    delay: 400,
    easing: easing.Ease,
    fill_mode: Freeze,
    animate_new_values: False,
    on_animation_start: None,
    on_animation_end: None,
    animation_id: None,
  )
}

// ---------------------------------------------------------------------------
// Builder functions
// ---------------------------------------------------------------------------

/// Set whether animation is active.
pub fn with_active(
  config config: AnimationConfig,
  active active: Bool,
) -> AnimationConfig {
  AnimationConfig(..config, active: active)
}

/// Set animation duration in milliseconds.
pub fn with_duration(
  config config: AnimationConfig,
  duration duration: Int,
) -> AnimationConfig {
  AnimationConfig(..config, duration: duration)
}

/// Set animation delay in milliseconds.
pub fn with_delay(
  config config: AnimationConfig,
  delay delay: Int,
) -> AnimationConfig {
  AnimationConfig(..config, delay: delay)
}

/// Set the easing function.
pub fn with_easing(
  config config: AnimationConfig,
  easing easing: Easing,
) -> AnimationConfig {
  AnimationConfig(..config, easing: easing)
}

/// Set the fill mode.
pub fn with_fill_mode(
  config config: AnimationConfig,
  fill_mode fill_mode: FillMode,
) -> AnimationConfig {
  AnimationConfig(..config, fill_mode: fill_mode)
}

/// Set whether to re-trigger animation when data updates.
///
/// When True, the generated SMIL `<animate>` element includes
/// `restart="always"` so the animation replays on DOM updates.
pub fn with_animate_new_values(
  config config: AnimationConfig,
  animate_new_values animate_new_values: Bool,
) -> AnimationConfig {
  AnimationConfig(..config, animate_new_values: animate_new_values)
}

/// Set the SMIL `onbegin` event attribute value for the `<animate>` element.
///
/// When Some, the string is emitted as the `onbegin` attribute, which fires
/// when the SMIL animation starts.
pub fn with_on_animation_start(
  config config: AnimationConfig,
  handler handler: Option(String),
) -> AnimationConfig {
  AnimationConfig(..config, on_animation_start: handler)
}

/// Set the SMIL `onend` event attribute value for the `<animate>` element.
///
/// When Some, the string is emitted as the `onend` attribute, which fires
/// when the SMIL animation completes.
pub fn with_on_animation_end(
  config config: AnimationConfig,
  handler handler: Option(String),
) -> AnimationConfig {
  AnimationConfig(..config, on_animation_end: handler)
}

/// Set the `id` attribute on the generated `<animate>` element.
///
/// When Some, applies the given string as the element's `id`, allowing
/// external CSS or JavaScript to target specific animations.
pub fn with_animation_id(
  config config: AnimationConfig,
  animation_id animation_id: Option(String),
) -> AnimationConfig {
  AnimationConfig(..config, animation_id: animation_id)
}

// ---------------------------------------------------------------------------
// SMIL builder functions
// ---------------------------------------------------------------------------

/// Animate a single numeric SVG attribute from one value to another.
///
/// For CSS-native easings, emits `calcMode="spline"` with `keySplines`.
/// For complex easings, bakes N keyframes via the easing function.
pub fn animate_attribute(
  name name: String,
  from from: Float,
  to to: Float,
  config config: AnimationConfig,
) -> Element(msg) {
  let timing = smil_timing_attrs(config)
  let attrs = case easing.is_css_native(easing: config.easing) {
    True -> {
      case easing.to_cubic_bezier(easing: config.easing) {
        Ok(#(x1, y1, x2, y2)) -> {
          let spline =
            math.fmt(x1)
            <> " "
            <> math.fmt(y1)
            <> " "
            <> math.fmt(x2)
            <> " "
            <> math.fmt(y2)
          [
            svg.attr("attributeName", name),
            svg.attr("from", math.fmt(from)),
            svg.attr("to", math.fmt(to)),
            svg.attr("calcMode", "spline"),
            svg.attr("keyTimes", "0;1"),
            svg.attr("keySplines", spline),
            ..timing
          ]
        }
        Error(_) -> [
          svg.attr("attributeName", name),
          svg.attr("from", math.fmt(from)),
          svg.attr("to", math.fmt(to)),
          ..timing
        ]
      }
    }
    False -> {
      let #(key_times, values) =
        bake_numeric(config.easing, from, to, baked_steps)
      [
        svg.attr("attributeName", name),
        svg.attr("values", values),
        svg.attr("keyTimes", key_times),
        svg.attr("calcMode", "linear"),
        ..timing
      ]
    }
  }
  svg.el(tag: "animate", attrs: attrs, children: [])
}

/// Animate an SVG path `d` attribute through baked keyframes.
///
/// The `path_at_progress` function maps progress `[0,1]` to a path d string.
/// Used for pie sectors, radar polygons, and other shape morphs.
pub fn animate_path(
  path_at_progress path_at_progress: fn(Float) -> String,
  config config: AnimationConfig,
  steps steps: Int,
) -> Element(msg) {
  let timing = smil_timing_attrs(config)
  let #(key_times, values) = bake_path(config.easing, path_at_progress, steps)
  let attrs = [
    svg.attr("attributeName", "d"),
    svg.attr("values", values),
    svg.attr("keyTimes", key_times),
    svg.attr("calcMode", "linear"),
    ..timing
  ]
  svg.el(tag: "animate", attrs: attrs, children: [])
}

/// Animate stroke-dashoffset for a line reveal effect.
///
/// Sets initial dashoffset equal to path_length, animates to 0.
pub fn animate_stroke_reveal(
  path_length path_length: Float,
  config config: AnimationConfig,
) -> Element(msg) {
  animate_attribute(
    name: "stroke-dashoffset",
    from: path_length,
    to: 0.0,
    config: config,
  )
}

/// Generate a clipPath with an animated rectangle for area reveal.
///
/// Returns a `<clipPath>` element containing a `<rect>` with `<animate>`
/// children that grow from zero to full dimensions.
pub fn animate_clip_rect(
  clip_id clip_id: String,
  x x: Float,
  y y: Float,
  width width: Float,
  height height: Float,
  config config: AnimationConfig,
  direction direction: LayoutDirection,
) -> Element(msg) {
  let anim = case direction {
    Horizontal ->
      animate_attribute(name: "width", from: 0.0, to: width, config: config)
    layout.Vertical ->
      animate_attribute(name: "height", from: 0.0, to: height, config: config)
  }
  svg.clip_path(id: clip_id, children: [
    svg.rect_with_children(
      x: math.fmt(x),
      y: math.fmt(y),
      width: math.fmt(width),
      height: math.fmt(height),
      attrs: [],
      children: [anim],
    ),
  ])
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Number of baked keyframe steps for complex easings.
///
/// Set to 60 for smoother elastic and bounce animation curves.
const baked_steps = 60

/// Bake numeric keyframes: sample easing at N steps.
/// Returns (key_times_string, values_string) for SMIL attributes.
fn bake_numeric(
  easing_fn: Easing,
  from: Float,
  to: Float,
  steps: Int,
) -> #(String, String) {
  let steps_float = int.to_float(steps)
  let pairs =
    int.range(from: 0, to: steps + 1, with: [], run: fn(acc, i) {
      let t = int.to_float(i) /. steps_float
      let progress = easing.apply(easing: easing_fn, t: t)
      let value = from +. { to -. from } *. progress
      [#(fmt_key_time(t), math.fmt(value)), ..acc]
    })
    |> list.reverse
  let key_times =
    pairs
    |> list.map(fn(pair) { pair.0 })
    |> string.join(";")
  let values =
    pairs
    |> list.map(fn(pair) { pair.1 })
    |> string.join(";")
  #(key_times, values)
}

/// Bake path keyframes.
fn bake_path(
  easing_fn: Easing,
  path_fn: fn(Float) -> String,
  steps: Int,
) -> #(String, String) {
  let steps_float = int.to_float(steps)
  let pairs =
    int.range(from: 0, to: steps + 1, with: [], run: fn(acc, i) {
      let t = int.to_float(i) /. steps_float
      let progress = easing.apply(easing: easing_fn, t: t)
      [#(fmt_key_time(t), path_fn(progress)), ..acc]
    })
    |> list.reverse
  let key_times =
    pairs
    |> list.map(fn(pair) { pair.0 })
    |> string.join(";")
  let values =
    pairs
    |> list.map(fn(pair) { pair.1 })
    |> string.join(";")
  #(key_times, values)
}

/// Format a float for keyTimes (needs more precision than math.fmt).
fn fmt_key_time(t: Float) -> String {
  let rounded = float.round(t *. 10_000.0)
  let whole = rounded / 10_000
  let frac = case rounded < 0 {
    True -> { 0 - rounded } % 10_000
    False -> rounded % 10_000
  }
  case frac == 0 {
    True -> int.to_string(whole)
    False -> {
      let frac_str = int.to_string(frac)
      let padded = case frac < 10 {
        True -> "000" <> frac_str
        False ->
          case frac < 100 {
            True -> "00" <> frac_str
            False ->
              case frac < 1000 {
                True -> "0" <> frac_str
                False -> frac_str
              }
          }
      }
      int.to_string(whole) <> "." <> padded
    }
  }
}

/// Format fill mode as SMIL attribute value.
fn fill_mode_to_string(mode: FillMode) -> String {
  case mode {
    Freeze -> "freeze"
    Remove -> "remove"
  }
}

/// Build the common SMIL timing attributes list.
fn smil_timing_attrs(config: AnimationConfig) -> List(Attribute(msg)) {
  let dur = int.to_string(config.duration) <> "ms"
  let fill = fill_mode_to_string(config.fill_mode)
  let base = [svg.attr("dur", dur), svg.attr("fill", fill)]
  let base = case config.delay > 0 {
    True -> [svg.attr("begin", int.to_string(config.delay) <> "ms"), ..base]
    False -> base
  }
  let base = case config.animate_new_values {
    True -> [svg.attr("restart", "always"), ..base]
    False -> base
  }
  let base = case config.on_animation_start {
    Some(handler) -> [svg.attr("onbegin", handler), ..base]
    None -> base
  }
  let base = case config.on_animation_end {
    Some(handler) -> [svg.attr("onend", handler), ..base]
    None -> base
  }
  let base = case config.animation_id {
    Some(id) -> [svg.attr("id", id), ..base]
    None -> base
  }
  base
}
