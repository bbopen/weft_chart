#!/usr/bin/env python3
"""Validate Hex package constraints against published releases.

Usage:
  check_hex_constraints.py --require "weft|>= 0.1.0 and < 1.0.0" [--require ...]
"""

from __future__ import annotations

import argparse
import functools
import json
import re
import sys
import urllib.error
import urllib.request
from collections.abc import Iterable
from dataclasses import dataclass


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


SEMVER_RE = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$",
)


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


def parse_prerelease(prerelease: str) -> tuple[tuple[int, int | str], ...]:
    parts: list[tuple[int, int | str]] = []
    for token in prerelease.split("."):
        if token == "":
            raise ValueError(f"invalid prerelease segment in version: {prerelease!r}")

        if token.isdigit():
            if len(token) > 1 and token.startswith("0"):
                raise ValueError(f"numeric prerelease segment has leading zeros: {token!r}")
            parts.append((0, int(token)))
        else:
            parts.append((1, token))

    return tuple(parts)


def parse_version(
    version: str,
) -> tuple[tuple[int, int, int], tuple[tuple[int, int | str], ...] | None]:
    match = SEMVER_RE.fullmatch(version)
    if match is None:
        raise ValueError(f"invalid semver version: {version!r}")

    core = (int(match.group(1)), int(match.group(2)), int(match.group(3)))
    prerelease = match.group(4)
    if prerelease is None:
        return core, None

    return core, parse_prerelease(prerelease)


def compare_versions(left: str, right: str) -> int:
    left_core, left_pre = parse_version(left)
    right_core, right_pre = parse_version(right)

    if left_core < right_core:
        return -1
    if left_core > right_core:
        return 1

    if left_pre is None and right_pre is None:
        return 0
    if left_pre is None:
        # Stable release is newer than prerelease for the same core.
        return 1
    if right_pre is None:
        return -1

    for left_identifier, right_identifier in zip(left_pre, right_pre):
        if left_identifier == right_identifier:
            continue

        left_kind, left_value = left_identifier
        right_kind, right_value = right_identifier

        if left_kind != right_kind:
            # Numeric prerelease segments have lower precedence than non-numeric.
            return -1 if left_kind < right_kind else 1

        if left_value < right_value:
            return -1
        return 1

    if len(left_pre) < len(right_pre):
        return -1
    if len(left_pre) > len(right_pre):
        return 1
    return 0


def parse_constraints(constraint: str) -> list[tuple[str, str]]:
    terms = [
        term.strip()
        for term in re.split(r"\s+and\s+", constraint, flags=re.IGNORECASE)
        if term.strip()
    ]
    parsed: list[tuple[str, str]] = []
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
    return max(versions, key=functools.cmp_to_key(compare_versions))


def fetch_versions(package: str) -> tuple[str, list[str]]:
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

    try:
        results = [evaluate(requirement) for requirement in requirements]
    except ValueError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 2

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
