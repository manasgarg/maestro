#!/usr/bin/env python3
"""Validate that every .maestro/evidence/<dir>/ has the artifacts required by DESIGN.md principle 8.

Required for every evidence directory:
  - verify.sh
  - runbook.md
  - test-catches-it.log

Required additionally if the directory contains a marker file `NON_ATOMIC`:
  - pre-mortem.md
  - counterfactual.md
  - bug-hunter.log

Directories under .maestro/evidence/ that contain only legacy artifacts
(predating principle 8) may opt out by including a file named `LEGACY`
with a one-line justification. Legacy directories are warned but not failed.

Exits non-zero if any required artifact is missing in a non-legacy directory.
"""
from __future__ import annotations

import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
ROOT = REPO / ".maestro/evidence"

REQUIRED = ["verify.sh", "runbook.md", "test-catches-it.log"]
NON_ATOMIC_EXTRA = ["pre-mortem.md", "counterfactual.md", "bug-hunter.log"]


def main() -> int:
    if not ROOT.exists():
        print(f"OK: {ROOT} does not exist (no evidence yet).")
        return 0
    failures = 0
    checked = 0
    for d in sorted(p for p in ROOT.iterdir() if p.is_dir()):
        checked += 1
        legacy = (d / "LEGACY").exists()
        if legacy:
            note = (d / "LEGACY").read_text().strip().splitlines()
            first = note[0] if note else "(no justification)"
            print(f"WARN: {d.relative_to(REPO)}: LEGACY ({first})")
            continue
        missing = [name for name in REQUIRED if not (d / name).exists()]
        if (d / "NON_ATOMIC").exists():
            missing += [n for n in NON_ATOMIC_EXTRA if not (d / n).exists()]
        if missing:
            for m in missing:
                print(f"FAIL: {d.relative_to(REPO)}: missing {m}")
                failures += 1
        else:
            print(f"OK:   {d.relative_to(REPO)}")
    if failures:
        print(f"\n{failures} missing artifact(s) across {checked} evidence director(ies).")
        return 1
    print(f"\nOK: {checked} evidence director(ies) validated.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
