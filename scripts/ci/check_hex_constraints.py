#!/usr/bin/env python3
"""Validate Hex package constraints against published releases.

Usage:
  check_hex_constraints.py --require "weft|>= 0.1.0 and < 1.0.0" [--require ...]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Iterable, List, Tuple


@dataclass
class Requirement:
    package: str
    constraint: str


@dataclass
class CheckResult:
    package: str
    constraint: str
    state: str
    detail: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require", action="append", default=[])
    return parser.parse_args()


def parse_requirement(raw: str) -> Requirement:
    if "|" not in raw:
        raise ValueError(f"invalid requirement: {raw!r}")
    package, constraint = raw.split("|", 1)
    package = package.strip()
    constraint = constraint.strip()
    if not package or not constraint:
        raise ValueError(f"invalid requirement: {raw!r}")
    return Requirement(package=package, constraint=constraint)


def parse_version(version: str) -> Tuple[Tuple[int, ...], bool]:
    core, _, _pre = version.partition("-")
    parts: List[int] = []
    for token in core.split("."):
        match = re.match(r"^(\d+)", token)
        parts.append(int(match.group(1)) if match else 0)
    return tuple(parts), bool(_pre)


def compare_versions(left: str, right: str) -> int:
    left_nums, left_pre = parse_version(left)
    right_nums, right_pre = parse_version(right)

    width = max(len(left_nums), len(right_nums))
    left_padded = left_nums + (0,) * (width - len(left_nums))
    right_padded = right_nums + (0,) * (width - len(right_nums))

    if left_padded < right_padded:
        return -1
    if left_padded > right_padded:
        return 1

    if left_pre == right_pre:
        return 0
    # Stable release is considered newer than prerelease for the same core.
    return -1 if left_pre else 1


def parse_constraints(constraint: str) -> List[Tuple[str, str]]:
    terms = [term.strip() for term in constraint.split("and") if term.strip()]
    parsed: List[Tuple[str, str]] = []
    for term in terms:
        match = re.match(r"^(>=|<=|>|<|==|=)\s*([A-Za-z0-9.+-]+)$", term)
        if not match:
            raise ValueError(f"unsupported constraint term: {term!r}")
        op, version = match.groups()
        parsed.append((op, version))
    if not parsed:
        raise ValueError(f"empty constraint: {constraint!r}")
    return parsed


def satisfies(version: str, constraint: str) -> bool:
    parsed = parse_constraints(constraint)
    for op, expected in parsed:
        cmp = compare_versions(version, expected)
        if op == ">=" and cmp < 0:
            return False
        if op == ">" and cmp <= 0:
            return False
        if op == "<=" and cmp > 0:
            return False
        if op == "<" and cmp >= 0:
            return False
        if op in {"=", "=="} and cmp != 0:
            return False
    return True


def max_version(versions: Iterable[str]) -> str:
    versions = list(versions)
    if not versions:
        return ""
    return max(versions, key=lambda version: parse_version(version))


def fetch_versions(package: str) -> Tuple[str, List[str]]:
    url = f"https://hex.pm/api/packages/{package}"
    try:
        with urllib.request.urlopen(url, timeout=15) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return "missing", []
        return "network", []
    except (TimeoutError, urllib.error.URLError):
        return "network", []

    releases = payload.get("releases") or []
    versions = [release.get("version", "") for release in releases if release.get("version")]
    return "ok", versions


def evaluate(requirement: Requirement) -> CheckResult:
    status, versions = fetch_versions(requirement.package)
    if status == "missing":
        return CheckResult(
            package=requirement.package,
            constraint=requirement.constraint,
            state="missing",
            detail="package is not published on Hex",
        )
    if status == "network":
        return CheckResult(
            package=requirement.package,
            constraint=requirement.constraint,
            state="network",
            detail="could not query Hex API",
        )

    matches = [version for version in versions if satisfies(version, requirement.constraint)]
    if matches:
        selected = max_version(matches)
        return CheckResult(
            package=requirement.package,
            constraint=requirement.constraint,
            state="ok",
            detail=f"matched release {selected}",
        )

    latest = max_version(versions)
    latest_note = latest if latest else "none"
    return CheckResult(
        package=requirement.package,
        constraint=requirement.constraint,
        state="unsatisfied",
        detail=f"no matching release (latest available: {latest_note})",
    )


def main() -> int:
    args = parse_args()

    if not args.require:
        print("FAIL: at least one --require argument is required", file=sys.stderr)
        return 2

    try:
        requirements = [parse_requirement(raw) for raw in args.require]
    except ValueError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 2

    results = [evaluate(requirement) for requirement in requirements]

    has_network = False
    has_unsatisfied = False

    for result in results:
        line = (
            f"{result.state.upper()}: {result.package} "
            f"[{result.constraint}] -> {result.detail}"
        )
        print(line)
        if result.state == "network":
            has_network = True
        if result.state in {"missing", "unsatisfied"}:
            has_unsatisfied = True

    if has_network:
        return 20
    if has_unsatisfied:
        return 10
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
