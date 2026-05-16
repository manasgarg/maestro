#!/usr/bin/env python3
"""Validate every line of .maestro/tasks.jsonl against tasks.schema.json.

Exits non-zero on the first invalid line. Empty file is valid.
"""
import json
import pathlib
import sys

import jsonschema

REPO = pathlib.Path(__file__).resolve().parents[2]
SCHEMA = json.loads((REPO / ".maestro/schemas/tasks.schema.json").read_text())
TASKS = REPO / ".maestro/tasks.jsonl"


def main() -> int:
    if not TASKS.exists():
        print(f"OK: {TASKS} does not exist (no tasks yet).")
        return 0
    text = TASKS.read_text()
    if not text.strip():
        print(f"OK: {TASKS} is empty.")
        return 0
    validator = jsonschema.Draft202012Validator(SCHEMA)
    errors = 0
    for lineno, raw in enumerate(text.splitlines(), start=1):
        if not raw.strip():
            print(f"FAIL: {TASKS}:{lineno}: blank line not allowed")
            errors += 1
            continue
        try:
            row = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"FAIL: {TASKS}:{lineno}: invalid JSON: {e}")
            errors += 1
            continue
        for err in sorted(validator.iter_errors(row), key=lambda e: e.path):
            path = "/".join(str(p) for p in err.absolute_path) or "<root>"
            print(f"FAIL: {TASKS}:{lineno}: {path}: {err.message}")
            errors += 1
    if errors:
        print(f"\n{errors} validation error(s) in {TASKS}.")
        return 1
    print(f"OK: all rows in {TASKS} validate.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
