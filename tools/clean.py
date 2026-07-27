#!/usr/bin/env python3
"""
SwiftBeam Workspace Cleanup Utility (swiftbeam-tooling)
Purges all generated build artifacts, caches, compiled binaries, temporary files, and distribution packages.
"""

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.resolve()
MOBILE_DIR = ROOT / "apps" / "mobile"
CORE_DIR = ROOT / "core"
DIST_DIR = ROOT / "dist"


def remove_path(path: Path):
    """Safely remove a file or directory path."""
    if not path.exists():
        return
    try:
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path, ignore_errors=True)
            print(f"  🗑️  Removed directory: {path.relative_to(ROOT)}")
        else:
            path.unlink(missing_ok=True)
            print(f"  🗑️  Removed file: {path.relative_to(ROOT)}")
    except Exception as e:
        print(f"  ⚠️  Failed to remove {path}: {e}")


def clean_flutter():
    """Clean Flutter build cache and ephemeral artifacts."""
    print("🧹 Cleaning Flutter workspace...")
    try:
        subprocess.run(["flutter", "clean"], cwd=MOBILE_DIR, check=False)
        print("✅ Flutter clean executed.")
    except Exception as e:
        print(f"⚠️ Flutter clean error: {e}")

    # Explicitly clean any lingering build and cache folders
    extra_paths = [
        MOBILE_DIR / "build",
        MOBILE_DIR / ".dart_tool",
        MOBILE_DIR / ".flutter-plugins-dependencies",
        MOBILE_DIR / "build_log.txt",
        MOBILE_DIR / "lib" / "src" / "rust",
        MOBILE_DIR / "android" / ".gradle",
        MOBILE_DIR / "linux" / "flutter" / "ephemeral",
        MOBILE_DIR / "windows" / "flutter" / "ephemeral",
    ]
    for p in extra_paths:
        remove_path(p)


def clean_rust():
    """Clean Rust target directories."""
    print("🧹 Cleaning Rust workspace...")
    if CORE_DIR.exists():
        try:
            subprocess.run(["cargo", "clean"], cwd=CORE_DIR, check=False)
            print("✅ Cargo clean executed in core/.")
        except Exception as e:
            print(f"⚠️ Cargo clean error: {e}")

    extra_rust_targets = [
        CORE_DIR / "target",
        MOBILE_DIR / "rust" / "target",
        MOBILE_DIR / "rust_builder" / "target",
        MOBILE_DIR / "rust_builder" / "cargokit" / "target",
    ]
    for p in extra_rust_targets:
        remove_path(p)


def clean_python_caches():
    """Recursively remove Python __pycache__ directories and .pyc files."""
    print("🧹 Cleaning Python caches...")
    for p in ROOT.rglob("__pycache__"):
        remove_path(p)
    for p in ROOT.rglob("*.pyc"):
        remove_path(p)


def clean_dist():
    """Clean release packages distribution directory."""
    print("🧹 Cleaning release dist directory...")
    remove_path(DIST_DIR)


def main():
    print("🚀 SwiftBeam Complete Workspace Cleanup\n")
    clean_flutter()
    clean_rust()
    clean_python_caches()
    clean_dist()
    print("\n✨ Workspace cleanup completed successfully!")


if __name__ == "__main__":
    main()
