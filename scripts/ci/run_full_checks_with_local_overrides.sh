#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

say() { printf '%s\n' "$*" >&2; }
fail() {
  say "FAIL: $*"
  exit 1
}

[[ -d "../weft" ]] || fail "required sibling repo missing: ../weft"

backup_file="$(mktemp)"
cp gleam.toml "$backup_file"
restore() {
  cp "$backup_file" gleam.toml
  rm -f "$backup_file"
}
trap restore EXIT

python3 - "gleam.toml" <<'PY'
import re
import sys
from pathlib import Path

file_path = Path(sys.argv[1])
text = file_path.read_text()

pattern = r"^weft\s*=\s*.*$"
replacement = 'weft = { path = "../weft" }'

if not re.search(pattern, text, flags=re.MULTILINE):
    raise SystemExit("missing dependency line for weft")

text = re.sub(pattern, replacement, text, flags=re.MULTILINE)
file_path.write_text(text)
PY

say "CI mode: local dependency overrides (weft path)"
bash scripts/check.sh
