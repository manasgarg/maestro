#!/usr/bin/env python3
"""Install the Maestro satellite scaffold into a target repo.

The scaffold is a small set of files that turn another repo into a
"satellite" — it runs the same Maestro loop, but invokes Maestro's
reusable workflows in `manasgarg/maestro` at a pinned version. After
the install PR merges, filing a `maestro:direction` issue triggers
the loop end-to-end.

This script is invoked by the `Maestro Install` workflow that the
human copies into their satellite (`tools/maestro-install-workflow.yml`
in the Maestro repo). It can also be run locally against a checked-out
satellite directory.

Usage:
    python3 install_satellite.py --version <maestro-ref> --target <satellite-dir>
    python3 install_satellite.py --version v0.1.0     --target /path/to/satellite --dry-run

Behavior on a mature repo (one that already has Maestro-managed files,
or files in the same paths as Maestro's): the rollout is absolute per
issue #14's acceptance criterion 6 — the prior files are replaced
wholesale with the canonical pinned-Maestro versions. Salvageable
process knowledge from the prior files should be extracted FIRST via
the `/maestro-intake` slash command, which captures it into learnings
that survive the replacement. The install plan (printed to stdout)
enumerates every file that will be replaced so the human can audit
the PR diff before merging.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

VERSION_PLACEHOLDER = "__MAESTRO_VERSION__"

# Files Maestro takes responsibility for in a satellite. Anything outside
# this set is left untouched. If a file at one of these paths already
# exists in the satellite, the install replaces it (mature-repo case).
MAESTRO_MANAGED = (
    ".github/workflows/maestro-implement.yml",
    ".github/workflows/maestro-review.yml",
    ".github/workflows/maestro-ci.yml",
    ".github/workflows/maestro-learn.yml",
    ".github/pull_request_template.md",
    ".github/ISSUE_TEMPLATE/maestro-direction.md",
    ".maestro/version",
)


def template_files(template_dir: Path) -> list[tuple[str, Path]]:
    """Return [(rel_path, abs_src_path), ...] for files in the template.

    Order matches MAESTRO_MANAGED so the install plan is deterministic.
    Raises FileNotFoundError if the template is missing an expected file.
    """
    files = []
    missing = []
    for rel in MAESTRO_MANAGED:
        src = template_dir / rel
        if not src.is_file():
            missing.append(rel)
        else:
            files.append((rel, src))
    if missing:
        raise FileNotFoundError(
            f"template directory {template_dir} is missing expected file(s): "
            + ", ".join(missing)
        )
    return files


def classify(target: Path, rel_path: str) -> str:
    """Return 'replace' if the file exists in the satellite, else 'write'."""
    return "replace" if (target / rel_path).exists() else "write"


def install(
    template_dir: Path,
    target: Path,
    version: str,
    dry_run: bool = False,
) -> list[tuple[str, str]]:
    """Install the scaffold. Returns [(action, rel_path), ...] for printing.

    action ∈ {"write", "replace", "would-write", "would-replace"}.
    """
    files = template_files(template_dir)
    actions: list[tuple[str, str]] = []
    for rel, src in files:
        action = classify(target, rel)
        if dry_run:
            actions.append((f"would-{action}", rel))
            continue
        content = src.read_text(encoding="utf-8")
        content = content.replace(VERSION_PLACEHOLDER, version)
        dest = target / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8")
        actions.append((action, rel))
    return actions


def is_mature(target: Path) -> list[str]:
    """Return the list of Maestro-managed paths that already exist in target."""
    return [rel for rel in MAESTRO_MANAGED if (target / rel).exists()]


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--version",
        required=True,
        help="Maestro git ref to pin (e.g. v0.1.0, main, or a sha)",
    )
    parser.add_argument(
        "--target",
        required=True,
        type=Path,
        help="Satellite repo directory (where the scaffold gets written)",
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=Path(__file__).parent / "satellite-template",
        help="Template directory (default: tools/satellite-template/ next to this script)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the install plan without writing anything",
    )
    args = parser.parse_args()

    if not args.source.is_dir():
        print(f"ERROR: template directory not found: {args.source}", file=sys.stderr)
        return 1
    if not args.target.is_dir():
        print(f"ERROR: target directory not found: {args.target}", file=sys.stderr)
        return 1

    pre_existing = is_mature(args.target)
    if pre_existing:
        print(
            f"Mature repo detected — {len(pre_existing)} Maestro-managed file(s) "
            f"already present and will be replaced wholesale (rollout is absolute "
            f"per issue #14 AC 6):"
        )
        for rel in pre_existing:
            print(f"  EXISTING  {rel}")
        print(
            "If this repo has informal process conventions you want to keep, run "
            "`/maestro-intake` in a Claude Code session in this repo BEFORE merging "
            "the install PR. It extracts those conventions into learnings (and "
            "candidate Maestro improvements) that survive the replacement."
        )
        print()

    actions = install(args.source, args.target, args.version, dry_run=args.dry_run)
    print("Install plan:" if args.dry_run else "Installed:")
    for action, rel in actions:
        print(f"  {action.upper():14}  {rel}")
    print()
    print(
        f"{'Would install' if args.dry_run else 'Installed'} {len(actions)} file(s) "
        f"into {args.target}. Maestro version pinned: {args.version}."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
