#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="cross"

say() { printf '%s\n' "$*" >&2; }
fail() { say "FAIL: $*"; exit 1; }

have_rg() { command -v rg >/dev/null 2>&1; }

search_has_match_fixed() {
  local pattern="$1"
  shift

  if have_rg; then
    rg -n -F --glob '*.gleam' -- "$pattern" "$@" >/dev/null 2>&1
  else
    grep -RIn -F --include='*.gleam' -- "$pattern" "$@" >/dev/null 2>&1
  fi
}

search_print_matches_fixed() {
  local pattern="$1"
  shift

  if have_rg; then
    rg -n -F --glob '*.gleam' -- "$pattern" "$@" || true
  else
    grep -RIn -F --include='*.gleam' -- "$pattern" "$@" || true
  fi
}

search_has_match_regex() {
  local pattern="$1"
  shift

  if have_rg; then
    rg -n --glob '*.gleam' -- "$pattern" "$@" >/dev/null 2>&1
  else
    grep -RIn -E --include='*.gleam' -- "$pattern" "$@" >/dev/null 2>&1
  fi
}

search_print_matches_regex() {
  local pattern="$1"
  shift

  if have_rg; then
    rg -n --glob '*.gleam' -- "$pattern" "$@" || true
  else
    grep -RIn -E --include='*.gleam' -- "$pattern" "$@" || true
  fi
}

search_has_match_fixed_any() {
  local pattern="$1"
  shift

  if have_rg; then
    rg -n -F -- "$pattern" "$@" >/dev/null 2>&1
  else
    grep -RIn -F -- "$pattern" "$@" >/dev/null 2>&1
  fi
}

search_print_matches_fixed_any() {
  local pattern="$1"
  shift

  if have_rg; then
    rg -n -F -- "$pattern" "$@" || true
  else
    grep -RIn -F -- "$pattern" "$@" || true
  fi
}

list_files_with_match() {
  local pattern="$1"
  shift

  if have_rg; then
    rg -l -F --glob '*.gleam' -- "$pattern" "$@" 2>/dev/null || true
  else
    grep -RIl -F --include='*.gleam' -- "$pattern" "$@" 2>/dev/null || true
  fi
}

check_no_match() {
  local description="$1"
  local pattern="$2" # fixed string
  shift 2

  if search_has_match_fixed "$pattern" "$@"; then
    say ""
    say "Found forbidden pattern: $description"
    search_print_matches_fixed "$pattern" "$@"
    fail "$description"
  fi
}

check_no_match_regex() {
  local description="$1"
  local pattern="$2" # regex
  shift 2

  if search_has_match_regex "$pattern" "$@"; then
    say ""
    say "Found forbidden pattern: $description"
    search_print_matches_regex "$pattern" "$@"
    fail "$description"
  fi
}

check_no_match_any() {
  local description="$1"
  local pattern="$2" # fixed string
  shift 2

  if search_has_match_fixed_any "$pattern" "$@"; then
    say ""
    say "Found forbidden pattern: $description"
    search_print_matches_fixed_any "$pattern" "$@"
    fail "$description"
  fi
}

check_toml_no_target() {
  local toml="$ROOT_DIR/gleam.toml"
  [[ -f "$toml" ]] || return 0

  if command -v rg >/dev/null 2>&1; then
    if rg -n '^target\\s*=' "$toml" >/dev/null 2>&1; then
      rg -n '^target\\s*=' "$toml" || true
      fail "cross-target libs must not set target in gleam.toml"
    fi
  else
    if grep -nE '^target[[:space:]]*=' "$toml" >/dev/null 2>&1; then
      grep -nE '^target[[:space:]]*=' "$toml" || true
      fail "cross-target libs must not set target in gleam.toml"
    fi
  fi
}

src_dir="$ROOT_DIR/src"
test_dir="$ROOT_DIR/test"

[[ -d "$src_dir" ]] || fail "missing src/ directory"

search_dirs=("$src_dir")
if [[ -d "$test_dir" ]]; then
  search_dirs+=("$test_dir")
fi

docs_files=()
[[ -f "$ROOT_DIR/README.md" ]] && docs_files+=("$ROOT_DIR/README.md")
[[ -f "$ROOT_DIR/SPEC.md" ]] && docs_files+=("$ROOT_DIR/SPEC.md")

check_no_match_regex "todo keyword in src/ (ship no todo)" '(^|[^[:alnum:]_])todo([^[:alnum:]_]|$)' "$src_dir"
check_no_match_regex "panic keyword in src/ (ship no panic)" '(^|[^[:alnum:]_])panic([^[:alnum:]_]|$)' "$src_dir"

check_no_match "dynamic.unsafe_coerce (breaks type safety)" "dynamic.unsafe_coerce" "${search_dirs[@]}"
check_no_match "@deprecated (avoid in initial releases)" "@deprecated" "$src_dir"

removed_api_symbols=(
  "chart.x_axis_v2("
  "chart.y_axis_v2("
  "axis.x_axis_base_config("
  "axis.y_axis_base_config("
  "line.line_config_v2("
  "area.area_config_v2("
  "bar.bar_config_v2("
  "chart.pie_series("
  "chart.radar_series("
  "chart.radial_bar_series("
  "chart.scatter_series("
  "chart.funnel_series("
  "chart.treemap_series("
  "chart.sunburst_series("
  "chart.sankey_series("
  "chart.chart_tooltip("
  "chart.chart_legend("
  "chart.chart_brush("
  "chart.chart_reference_dot("
  "chart.chart_error_bar("
  "chart.chart_title("
  "chart.chart_desc("
  "chart.chart_event("
  "chart.chart_layout("
  "axis.x_data_key("
  "axis.x_type("
  "axis.x_orientation("
  "axis.x_tick_line("
  "axis.x_axis_line("
  "axis.x_tick_margin("
  "axis.x_tick_count("
  "axis.x_tick_formatter("
  "axis.x_padding("
  "axis.x_padding_mode("
  "axis.x_hide("
  "axis.x_reversed("
  "axis.x_mirror("
  "axis.x_tick_size("
  "axis.x_allow_decimals("
  "axis.x_angle("
  "axis.x_min_tick_gap("
  "axis.x_numeric_ticks("
  "axis.x_category_ticks("
  "axis.x_label("
  "axis.x_interval("
  "axis.x_allow_data_overflow("
  "axis.x_domain("
  "axis.x_unit("
  "axis.x_scale_type("
  "axis.x_height("
  "axis.x_name("
  "axis.x_allow_duplicated_category("
  "axis.x_axis_line_stroke("
  "axis.x_axis_line_stroke_width("
  "axis.x_tick_line_stroke("
  "axis.x_tick_line_stroke_width("
  "axis.x_axis_line_stroke_dasharray("
  "axis.x_tick_line_stroke_dasharray("
  "axis.x_axis_id("
  "axis.x_custom_tick("
  "axis.x_include_hidden("
  "axis.y_data_key("
  "axis.y_type("
  "axis.y_orientation("
  "axis.y_tick_line("
  "axis.y_axis_line("
  "axis.y_tick_count("
  "axis.y_tick_formatter("
  "axis.y_domain("
  "axis.y_hide("
  "axis.y_reversed("
  "axis.y_mirror("
  "axis.y_tick_size("
  "axis.y_allow_decimals("
  "axis.y_tick_margin("
  "axis.y_numeric_ticks("
  "axis.y_category_ticks("
  "axis.y_padding_top("
  "axis.y_padding_bottom("
  "axis.y_min_tick_gap("
  "axis.y_angle("
  "axis.y_label("
  "axis.y_interval("
  "axis.y_allow_data_overflow("
  "axis.y_unit("
  "axis.y_scale_type("
  "axis.y_width("
  "axis.y_name("
  "axis.y_allow_duplicated_category("
  "axis.y_axis_line_stroke("
  "axis.y_axis_line_stroke_width("
  "axis.y_tick_line_stroke("
  "axis.y_tick_line_stroke_width("
  "axis.y_axis_line_stroke_dasharray("
  "axis.y_tick_line_stroke_dasharray("
  "axis.y_axis_id("
  "axis.y_custom_tick("
  "axis.y_include_hidden("
  "area.curve_type("
  "area.fill("
  "area.fill_opacity("
  "area.stroke("
  "area.stroke_width("
  "area.stack_id("
  "area.connect_nulls("
  "area.dot("
  "area.dot_radius("
  "area.base_value("
  "area.legend_type("
  "area.gradient_fill("
  "line.line_name("
  "line.line_hide("
  "line.line_tooltip_type("
  "line.line_unit("
  "line.line_x_axis_id("
  "line.line_y_axis_id("
  "line.line_css_class("
  "area.area_name("
  "area.hide("
  "area.area_tooltip_type("
  "area.area_unit("
  "area.area_x_axis_id("
  "area.area_y_axis_id("
  "area.area_css_class("
  "bar.bar_name("
  "bar.bar_hide("
  "bar.bar_tooltip_type("
  "bar.bar_unit("
  "bar.bar_x_axis_id("
  "bar.bar_y_axis_id("
  "bar.bar_css_class("
)

for symbol in "${removed_api_symbols[@]}"; do
  check_no_match "removed API symbol in Gleam sources: $symbol" "$symbol" "${search_dirs[@]}"
  if [[ ${#docs_files[@]} -gt 0 ]]; then
    check_no_match_any "removed API symbol in docs: $symbol" "$symbol" "${docs_files[@]}"
  fi
done

external_files="$(list_files_with_match "@external" "${search_dirs[@]}")"

if [[ "$TARGET" == "cross" ]]; then
  if [[ -n "$external_files" ]]; then
    say ""
    say "Cross-target libs must not use @external. Found in:"
    say "$external_files"
    fail "@external is forbidden in cross-target libs"
  fi

  check_no_match "import gleam/erlang (cross-target forbidden)" "import gleam/erlang" "${search_dirs[@]}"
  check_no_match "import gleam/javascript (cross-target forbidden)" "import gleam/javascript" "${search_dirs[@]}"
  check_toml_no_target
else
  # Erlang-target libs may use FFI, but it must be isolated to clearly-named modules.
  if [[ -n "$external_files" ]]; then
    bad_files=""
    while IFS= read -r f; do
      case "$f" in
        */ffi.gleam|*/ffi_*.gleam|*/*_ffi.gleam|*/ffi/*.gleam) ;;
        *) bad_files="${bad_files}${bad_files:+$'\n'}${f}" ;;
      esac
    done <<< "$external_files"

    if [[ -n "$bad_files" ]]; then
      say ""
      say "@external must be isolated to FFI modules:"
      say "  allowed: src/**/ffi.gleam, src/**/ffi_*.gleam, src/**/*_ffi.gleam, src/**/ffi/*.gleam"
      say "Move FFI declarations into a dedicated module and wrap them with typed functions."
      say ""
      say "Disallowed @external usage found in:"
      say "$bad_files"
      fail "@external isolation gate failed"
    fi
  fi
fi

check_module_doc() {
  local f="$1"
  local first

  first="$(awk '
    /^[[:space:]]*$/ { next }
    {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      print NR ":" line
      exit
    }
  ' "$f")"

  if [[ -z "$first" ]]; then
    fail "empty Gleam source file: $f"
  fi

  if [[ "${first#*:}" != "////"* ]]; then
    say ""
    say "Missing module doc comment (////) at top of file:"
    say "  $f"
    say "  first non-empty line: $first"
    fail "module doc gate failed"
  fi
}

check_pub_docs() {
  local f="$1"

  if ! awk -v file="$f" '
    function ltrim(s) { sub(/^[[:space:]]+/, "", s); return s }
    function is_attr(s) { return s ~ /^@/ }
    function is_pub_def(s) { return s ~ /^pub[[:space:]]+(fn|type|const|opaque[[:space:]]+type)/ }

    /^[[:space:]]*$/ { buf_len = 0; next }
    {
      line = ltrim($0)

      if (is_pub_def(line)) {
        j = buf_len
        while (j >= 1 && is_attr(buf[j])) { j-- }
        if (j < 1 || buf[j] !~ /^\/\/\/($|[[:space:]])/) {
          printf("%s:%d: public item missing /// doc comment\n", file, NR) > "/dev/stderr"
          exit 1
        }
      }

      buf_len++
      buf[buf_len] = line
    }
  ' "$f"; then
    fail "public doc gate failed"
  fi
}

while IFS= read -r -d '' f; do
  check_module_doc "$f"
  check_pub_docs "$f"
done < <(find "$src_dir" -type f -name '*.gleam' -print0)

say "OK: grep gates passed"
