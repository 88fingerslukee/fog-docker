#!/usr/bin/env python3
"""Extract a FOG define() constant from a PHP source file.

Tolerates single/double quotes and varying whitespace around define().
Exits 0 and prints the value on success; exits 1 if the constant is missing.
"""

from __future__ import annotations

import re
import sys


def extract(source: str, name: str) -> str | None:
    escaped = re.escape(name)
    string_pat = re.compile(
        rf"define\s*\(\s*['\"]{escaped}['\"]\s*,\s*['\"]([^'\"]*)['\"]",
        re.MULTILINE,
    )
    match = string_pat.search(source)
    if match:
        return match.group(1)

    numeric_pat = re.compile(
        rf"define\s*\(\s*['\"]{escaped}['\"]\s*,\s*([0-9]+)",
        re.MULTILINE,
    )
    match = numeric_pat.search(source)
    if match:
        return match.group(1)

    return None


def main() -> int:
    if len(sys.argv) != 3:
        print(
            f"Usage: {sys.argv[0]} <php-file> <CONSTANT_NAME>",
            file=sys.stderr,
        )
        return 2

    path, name = sys.argv[1], sys.argv[2]
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            source = handle.read()
    except OSError as exc:
        print(f"ERROR: cannot read {path}: {exc}", file=sys.stderr)
        return 1

    value = extract(source, name)
    if value is None:
        return 1

    print(value)
    return 0


if __name__ == "__main__":
    sys.exit(main())
