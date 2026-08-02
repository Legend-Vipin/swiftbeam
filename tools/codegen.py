#!/usr/bin/env python3
"""
SwiftBeam FFI Codegen Helper (swiftbeam-tooling)
Runs flutter_rust_bridge_codegen generate to bridge Rust and Flutter APIs using apps/mobile/flutter_rust_bridge.yaml.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.resolve()
MOBILE_DIR = ROOT / "apps" / "mobile"
MOBILE_FFI_DIR = MOBILE_DIR / "lib" / "core" / "ffi"
OBSOLETE_SRC_RUST = MOBILE_DIR / "lib" / "src" / "rust"

# Ensure ~/.cargo/bin (or $CARGO_HOME/bin) is in PATH
CARGO_HOME = Path(os.environ.get("CARGO_HOME", Path.home() / ".cargo"))
CARGO_BIN = CARGO_HOME / "bin"
CARGO_BIN_STR = str(CARGO_BIN)

if CARGO_BIN_STR not in os.environ.get("PATH", ""):
    os.environ["PATH"] = f"{CARGO_BIN_STR}:{os.environ.get('PATH', '')}"


def get_codegen_bin_path() -> str:
    """Find executable path for flutter_rust_bridge_codegen."""
    which_path = shutil.which("flutter_rust_bridge_codegen")
    if which_path:
        return which_path

    frb_bin = CARGO_BIN / "flutter_rust_bridge_codegen"
    if frb_bin.exists():
        try:
            frb_bin.chmod(0o755)
        except Exception:
            pass
        return str(frb_bin)

    return "flutter_rust_bridge_codegen"


def ensure_codegen_installed():
    """Ensure flutter_rust_bridge_codegen is present and executable."""
    if CARGO_BIN.exists():
        for item in CARGO_BIN.iterdir():
            if item.is_file() and not os.access(item, os.X_OK):
                try:
                    item.chmod(item.stat().st_mode | 0o111)
                except Exception:
                    pass

    frb_bin = CARGO_BIN / "flutter_rust_bridge_codegen"
    if shutil.which("flutter_rust_bridge_codegen") is None and not frb_bin.exists():
        print("⚡ flutter_rust_bridge_codegen not found. Installing version 2.12.0 via cargo...")
        subprocess.run(
            ["cargo", "install", "flutter_rust_bridge_codegen", "--version", "2.12.0", "--force"],
            check=True,
        )


def main():
    print("⚡  Running flutter_rust_bridge_codegen...")
    try:
        ensure_codegen_installed()
        bin_path = get_codegen_bin_path()
        # Run codegen from apps/mobile where flutter_rust_bridge.yaml is defined
        subprocess.run(
            [bin_path, "generate"],
            cwd=MOBILE_DIR,
            check=True,
        )

        # Remove any obsolete generated bindings in lib/src/rust if created by default
        if OBSOLETE_SRC_RUST.exists():
            shutil.rmtree(OBSOLETE_SRC_RUST)

        # Verify target generated files exist
        frb_file = MOBILE_FFI_DIR / "frb_generated.dart"
        api_file = MOBILE_FFI_DIR / "api.dart"
        
        if frb_file.exists() and api_file.exists():
            print("✅  Codegen completed successfully!")
            print(f"📁  Verified output directory: {MOBILE_FFI_DIR}")
        else:
            print(f"⚠️  Warning: Missing expected codegen outputs in {MOBILE_FFI_DIR}", file=sys.stderr)

    except subprocess.CalledProcessError as e:
        print(f"❌  Codegen failed with exit code {e.returncode}", file=sys.stderr)
        sys.exit(e.returncode)
    except FileNotFoundError:
        print("❌  flutter_rust_bridge_codegen not found in PATH. Install with:", file=sys.stderr)
        print("    cargo install flutter_rust_bridge_codegen --version 2.12.0", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
