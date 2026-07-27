#!/usr/bin/env python3
"""
SwiftBeam Local Release Automation Tool Wrapper (release.py)

Runs the Release packaging pipeline (CI pre-checks -> versioning -> APK build -> multi-platform build -> changelog & manifest).

Usage:
  python3 tools/release.py [--version X.Y.Z] [--bump patch|minor|major] [--target linux|macos|windows|ios|universal|all] [--tag] [--push] [--skip-ci]
"""

import sys
from pathlib import Path

# Add tools directory to path
TOOLS_DIR = Path(__file__).parent.resolve()
sys.path.insert(0, str(TOOLS_DIR))

import ci_release

if __name__ == "__main__":
    # Inject 'release' subcommand into sys.argv
    sys.argv.insert(1, "release")
    ci_release.main()
