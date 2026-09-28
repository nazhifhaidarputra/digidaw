#!/usr/bin/env python3
"""
Bump the project release version across Flutter pubspec.yaml files and Rust workspace crates.

Usage:
  ./scripts/version_bumper.py 1.2.3
  ./scripts/version_bumper.py 1.0.0-beta.2 --target rust
  ./scripts/version_bumper.py 2.0.0 --target flutter --include-cargokit
  ./scripts/version_bumper.py 1.0.0 --dry-run
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Repo root = parent of scripts/
REPO_ROOT = Path(__file__).resolve().parent.parent

PUBSPEC_DEFAULT = [
    REPO_ROOT / "pubspec.yaml",
    REPO_ROOT / "rust_builder" / "pubspec.yaml",
]

PUBSPEC_CARGOKIT_BUILD_TOOL = REPO_ROOT / "rust_builder" / "cargokit" / "build_tool" / "pubspec.yaml"

# Rust package versions are declared either in the workspace or in a member's [package] table.
RUST_WORKSPACE_MANIFEST = REPO_ROOT / "rust" / "Cargo.toml"
RUST_CRATE_MANIFESTS = sorted(REPO_ROOT.glob("rust/karbeat-*/Cargo.toml"))
RUST_LOCKFILE = REPO_ROOT / "rust" / "Cargo.lock"

PUBSPEC_VERSION_LINE = re.compile(r"^version:\s*.+$", re.MULTILINE)
TOML_SECTION_LINE = re.compile(r"^\s*\[([^]]+)]\s*$", re.MULTILINE)
TOML_VERSION_LINE = re.compile(
    r'^(?P<indent>\s*)version\s*=\s*"[^"]+"(?P<suffix>\s*(?:#.*)?)$',
    re.MULTILINE,
)
TOML_WORKSPACE_VERSION_LINE = re.compile(
    r"^\s*version\.workspace\s*=\s*true\s*(?:#.*)?$",
    re.MULTILINE,
)
CARGO_PACKAGE_BLOCK = re.compile(
    r"^\[\[package]]\s*$.*?(?=^\[\[package]]\s*$|\Z)",
    re.MULTILINE | re.DOTALL,
)
CARGO_PACKAGE_NAME = re.compile(r'^name\s*=\s*"([^"]+)"\s*$', re.MULTILINE)
SEMVER = re.compile(
    r"^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)


def bump_pubspec(text: str, new_version: str) -> str:
    if not PUBSPEC_VERSION_LINE.search(text):
        raise ValueError("no top-level version: line found")
    return PUBSPEC_VERSION_LINE.sub(f"version: {new_version}", text, count=1)


def bump_toml_section_version(
    text: str,
    section: str,
    new_version: str,
    *,
    allow_workspace_version: bool = False,
) -> str:
    sections = list(TOML_SECTION_LINE.finditer(text))
    section_match = next((match for match in sections if match.group(1) == section), None)
    if section_match is None:
        raise ValueError(f"no [{section}] section found")

    section_end = next(
        (match.start() for match in sections if match.start() > section_match.start()),
        len(text),
    )
    body_start = section_match.end()
    body = text[body_start:section_end]
    version_match = TOML_VERSION_LINE.search(body)
    if version_match is not None:
        replacement = (
            f'{version_match.group("indent")}version = "{new_version}"'
            f'{version_match.group("suffix")}'
        )
        start = body_start + version_match.start()
        end = body_start + version_match.end()
        return text[:start] + replacement + text[end:]

    if allow_workspace_version and TOML_WORKSPACE_VERSION_LINE.search(body):
        return text
    raise ValueError(f'no version = "..." line found in [{section}]')


def bump_rust_package_version(text: str, new_version: str) -> str:
    return bump_toml_section_version(
        text,
        "package",
        new_version,
        allow_workspace_version=True,
    )


def bump_rust_workspace_version(text: str, new_version: str) -> str:
    return bump_toml_section_version(text, "workspace.package", new_version)


def rust_package_name(text: str) -> str:
    sections = list(TOML_SECTION_LINE.finditer(text))
    package_match = next((match for match in sections if match.group(1) == "package"), None)
    if package_match is None:
        raise ValueError("no [package] section found")
    section_end = next(
        (match.start() for match in sections if match.start() > package_match.start()),
        len(text),
    )
    name_match = CARGO_PACKAGE_NAME.search(text[package_match.end() : section_end])
    if name_match is None:
        raise ValueError('no name = "..." line found in [package]')
    return name_match.group(1)


def bump_cargo_lock(text: str, new_version: str, package_names: set[str]) -> str:
    found: set[str] = set()

    def bump_package(match: re.Match[str]) -> str:
        block = match.group(0)
        name_match = CARGO_PACKAGE_NAME.search(block)
        if name_match is None or name_match.group(1) not in package_names:
            return block
        if re.search(r"^source\s*=", block, re.MULTILINE):
            return block
        found.add(name_match.group(1))
        return TOML_VERSION_LINE.sub(
            lambda version_match: (
                f'{version_match.group("indent")}version = "{new_version}"'
                f'{version_match.group("suffix")}'
            ),
            block,
            count=1,
        )

    updated = CARGO_PACKAGE_BLOCK.sub(bump_package, text)
    missing = package_names - found
    if missing:
        raise ValueError(f"workspace packages missing from lockfile: {', '.join(sorted(missing))}")
    return updated


def process_file(path: Path, new_version: str, kind: str, dry_run: bool) -> bool:
    text = path.read_text(encoding="utf-8")
    if kind == "pubspec":
        new_text = bump_pubspec(text, new_version)
    elif kind == "rust-package":
        new_text = bump_rust_package_version(text, new_version)
    elif kind == "rust-workspace":
        new_text = bump_rust_workspace_version(text, new_version)
    else:
        raise ValueError(kind)

    if new_text == text:
        return False
    rel = path.relative_to(REPO_ROOT)
    if dry_run:
        print(f"[dry-run] would update {rel}")
    else:
        path.write_text(new_text, encoding="utf-8", newline="\n")
        print(f"updated {rel}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Set the same release version on pubspec.yaml files and Rust crate manifests.",
    )
    parser.add_argument(
        "version",
        help='Release version (e.g. "1.2.3" or "1.0.0-alpha.2").',
    )
    parser.add_argument(
        "--target",
        "-t",
        choices=("all", "flutter", "rust"),
        default="all",
        help="Only bump Flutter pubspec files, only Rust crates, or both (default: all).",
    )
    parser.add_argument(
        "--include-cargokit",
        action="store_true",
        help=f"Also bump {PUBSPEC_CARGOKIT_BUILD_TOOL.relative_to(REPO_ROOT)} (vendored Cargokit build_tool).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print paths that would change without writing files.",
    )
    args = parser.parse_args()
    new_v = args.version.strip()
    if not SEMVER.fullmatch(new_v):
        print(
            "error: version must be a valid SemVer version such as 1.2.3, "
            "1.0.0-beta.2, or 1.2.3+4",
            file=sys.stderr,
        )
        return 2

    pubspec_paths = list(PUBSPEC_DEFAULT)
    if args.include_cargokit:
        pubspec_paths.append(PUBSPEC_CARGOKIT_BUILD_TOOL)

    changed = 0
    errors: list[str] = []

    if args.target in ("all", "flutter"):
        for p in pubspec_paths:
            if not p.is_file():
                errors.append(f"missing file: {p.relative_to(REPO_ROOT)}")
                continue
            try:
                if process_file(p, new_v, "pubspec", args.dry_run):
                    changed += 1
            except ValueError as e:
                errors.append(f"{p.relative_to(REPO_ROOT)}: {e}")

    if args.target in ("all", "rust"):
        package_names: set[str] = set()
        if not RUST_WORKSPACE_MANIFEST.is_file():
            errors.append(f"missing file: {RUST_WORKSPACE_MANIFEST.relative_to(REPO_ROOT)}")
        else:
            try:
                if process_file(
                    RUST_WORKSPACE_MANIFEST,
                    new_v,
                    "rust-workspace",
                    args.dry_run,
                ):
                    changed += 1
            except ValueError as e:
                errors.append(f"{RUST_WORKSPACE_MANIFEST.relative_to(REPO_ROOT)}: {e}")

        if not RUST_CRATE_MANIFESTS:
            errors.append("no Rust manifests matched rust/karbeat-*/Cargo.toml")
        for p in RUST_CRATE_MANIFESTS:
            try:
                package_names.add(rust_package_name(p.read_text(encoding="utf-8")))
                if process_file(p, new_v, "rust-package", args.dry_run):
                    changed += 1
            except ValueError as e:
                errors.append(f"{p.relative_to(REPO_ROOT)}: {e}")

        if not RUST_LOCKFILE.is_file():
            errors.append(f"missing file: {RUST_LOCKFILE.relative_to(REPO_ROOT)}")
        elif package_names:
            try:
                lock_text = RUST_LOCKFILE.read_text(encoding="utf-8")
                new_lock_text = bump_cargo_lock(lock_text, new_v, package_names)
                if new_lock_text != lock_text:
                    changed += 1
                    if args.dry_run:
                        print(f"[dry-run] would update {RUST_LOCKFILE.relative_to(REPO_ROOT)}")
                    else:
                        RUST_LOCKFILE.write_text(
                            new_lock_text,
                            encoding="utf-8",
                            newline="\n",
                        )
                        print(f"updated {RUST_LOCKFILE.relative_to(REPO_ROOT)}")
            except ValueError as e:
                errors.append(f"{RUST_LOCKFILE.relative_to(REPO_ROOT)}: {e}")

    for msg in errors:
        print(f"error: {msg}", file=sys.stderr)

    if errors:
        return 1
    if changed == 0 and not args.dry_run:
        print("nothing to change (versions already match)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
