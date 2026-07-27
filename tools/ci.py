#!/usr/bin/env python3
"""
SwiftBeam Local CI Automation Tool Wrapper (ci.py)

Runs the Local CI pipeline for Rust core and Flutter mobile.

Usage:
  python3 tools/ci.py [--fix] [--rust-only] [--flutter-only] [--skip-tests] [--fast]
"""

import sys
from pathlib import Path

# Add tools directory to path
TOOLS_DIR = Path(__file__).parent.resolve()
sys.path.insert(0, str(TOOLS_DIR))

import ci_release

if __name__ == "__main__":
    # Inject 'ci' subcommand into sys.argv
    sys.argv.insert(1, "ci")
    ci_release.main()
