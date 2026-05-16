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

# Files Maestro ships as a sensible default but the satellite may override
# with its own. Install writes these only if they don't already exist; if
# they do, the satellite's version wins. This is for files that fill in a
# Maestro convention but whose content is satellite-specific in real-world
# use (the canonical example is `tools/run_tests.sh` — Maestro's reusable
# CI workflow calls it, but many satellites have their own elaborate test
# runner they want to keep).
MAESTRO_DEFAULTS = (
    "tools/run_tests.sh",
)


def template_files(template_dir: Path) -> list[tuple[str, Path, str]]:
    """Return [(rel_path, abs_src_path, policy), ...] for files in the template.

    Order is MAESTRO_MANAGED then MAESTRO_DEFAULTS so the install plan is
    deterministic and managed files appear first. Raises FileNotFoundError
    if the template is missing an expected file. `policy` is "managed" or
    "default".
    """
    files: list[tuple[str, Path, str]] = []
    missing: list[str] = []
    for rel in MAESTRO_MANAGED:
        src = template_dir / rel
        if not src.is_file():
            missing.append(rel)
        else:
            files.append((rel, src, "managed"))
    for rel in MAESTRO_DEFAULTS:
        src = template_dir / rel
        if not src.is_file():
            missing.append(rel)
        else:
            files.append((rel, src, "default"))
    if missing:
        raise FileNotFoundError(
            f"template directory {template_dir} is missing expected file(s): "
            + ", ".join(missing)
        )
    return files


def classify(target: Path, rel_path: str, policy: str) -> str:
    """Return the action to take for a template file.

    For policy='managed': "replace" if the file exists in the satellite, else "write".
    For policy='default': "keep-existing" if the file exists (satellite wins),
                          else "write".
    """
    exists = (target / rel_path).exists()
    if policy == "managed":
        return "replace" if exists else "write"
    # policy == "default"
    return "keep-existing" if exists else "write"


def install(
    template_dir: Path,
    target: Path,
    version: str,
    dry_run: bool = False,
) -> list[tuple[str, str]]:
    """Install the scaffold. Returns [(action, rel_path), ...] for printing.

    action ∈ {"write", "replace", "keep-existing", "would-<one of those>"}.
    """
    files = template_files(template_dir)
    actions: list[tuple[str, str]] = []
    for rel, src, policy in files:
        action = classify(target, rel, policy)
        if dry_run:
            actions.append((f"would-{action}", rel))
            continue
        if action == "keep-existing":
            # Satellite already has its own copy of a default-policy file;
            # do not overwrite. The satellite's version wins.
            actions.append((action, rel))
            continue
        content = src.read_text(encoding="utf-8")
        content = content.replace(VERSION_PLACEHOLDER, version)
        dest = target / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content, encoding="utf-8")
        # Preserve executable bit from the template (matters for shell
        # scripts like tools/run_tests.sh).
        src_mode = src.stat().st_mode
        if src_mode & 0o111:
            dest.chmod(dest.stat().st_mode | 0o755)
        actions.append((action, rel))
    return actions


def is_mature(target: Path) -> list[str]:
    """Return the list of Maestro-managed paths that already exist in target.

    Only counts MAESTRO_MANAGED files — MAESTRO_DEFAULTS files (like
    tools/run_tests.sh) are explicitly *not* a sign of maturity, since
    Maestro defers to the satellite's version of those.
    """
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
