#!/usr/bin/env python3
"""Merge .circleci/continue_config.yml with `circleci orb pack` output as inline orbs.chiubaka.

Used in the setup workflow so the continued config does not reference
chiubaka/circleci-orb@dev:<< pipeline.git.revision >> before that dev label exists in the registry.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from ruamel.yaml import YAML


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[2],
        help="Repository root (default: ../../ from this script)",
    )
    parser.add_argument(
        "--src-dir",
        type=Path,
        default=None,
        help="Orb source directory passed to `circleci orb pack` (default: <root>/src)",
    )
    parser.add_argument(
        "--continue-path",
        type=Path,
        default=None,
        help="Input continuation config (default: <root>/.circleci/continue_config.yml)",
    )
    parser.add_argument(
        "--out-path",
        type=Path,
        default=None,
        help="Output path (default: <root>/.circleci/continue_merged.yml)",
    )
    args = parser.parse_args()

    root: Path = args.root
    src_dir = args.src_dir or (root / "src")
    continue_path = args.continue_path or (root / ".circleci" / "continue_config.yml")
    out_path = args.out_path or (root / ".circleci" / "continue_merged.yml")

    pack = subprocess.check_output(
        ["circleci", "orb", "pack", str(src_dir)],
        text=True,
        cwd=root,
    )

    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.indent(mapping=2, sequence=4, offset=2)

    orb = yaml.load(pack)
    if not isinstance(orb, dict):
        print("Packed orb root must be a mapping.", file=sys.stderr)
        return 1
    orb.pop("version", None)

    with continue_path.open() as f:
        base = yaml.load(f)

    if not isinstance(base, dict):
        print("Continuation config root must be a mapping.", file=sys.stderr)
        return 1

    orbs = base.setdefault("orbs", {})
    if not isinstance(orbs, dict):
        print("orbs: must be a mapping.", file=sys.stderr)
        return 1
    if "chiubaka" in orbs:
        print("Refusing to overwrite existing orbs.chiubaka.", file=sys.stderr)
        return 1
    orbs["chiubaka"] = orb

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w") as f:
        yaml.dump(base, f)

    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
