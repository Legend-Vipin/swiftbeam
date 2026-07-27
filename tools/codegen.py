#!/usr/bin/env python3
"""
SwiftBeam FFI Codegen Helper (swiftbeam-tooling)
Runs flutter_rust_bridge_codegen generate to bridge Rust and Flutter APIs using apps/mobile/flutter_rust_bridge.yaml.
"""

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.resolve()
MOBILE_DIR = ROOT / "apps" / "mobile"
MOBILE_FFI_DIR = MOBILE_DIR / "lib" / "core" / "ffi"
OBSOLETE_SRC_RUST = MOBILE_DIR / "lib" / "src" / "rust"


def main():
    print("⚡  Running flutter_rust_bridge_codegen...")
    try:
        # Run codegen from apps/mobile where flutter_rust_bridge.yaml is defined
        subprocess.run(
            ["flutter_rust_bridge_codegen", "generate"],
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
