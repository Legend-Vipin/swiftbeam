#!/usr/bin/env python3
"""
SwiftBeam Git Pre-Commit Hook Installer (install_hooks.py)

Installs a Git pre-commit hook into .git/hooks/pre-commit that automatically runs `python3 tools/ci.py`
before every `git commit`.
"""

import os
import stat
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.resolve()
GIT_HOOKS_DIR = ROOT / ".git" / "hooks"
PRE_COMMIT_HOOK = GIT_HOOKS_DIR / "pre-commit"

HOOK_SCRIPT = """#!/bin/sh
# SwiftBeam Pre-Commit Hook
# Automatically runs Local CI checks before committing

echo "🔍 Running SwiftBeam Local CI before commit..."
python3 tools/ci.py --fast

if [ $? -ne 0 ]; then
    echo "❌ Local CI failed. Commit aborted."
    exit 1
fi
"""


def main():
    import argparse
    parser = argparse.ArgumentParser(description="SwiftBeam Git Hook Installer")
    parser.add_argument("--uninstall", action="store_true", help="Remove pre-commit hook")
    args = parser.parse_args()

    if args.uninstall:
        if PRE_COMMIT_HOOK.exists():
            PRE_COMMIT_HOOK.unlink()
            print("🗑️  Git pre-commit hook removed successfully.")
        else:
            print("ℹ️  No pre-commit hook found to remove.")
        return

    if not GIT_HOOKS_DIR.exists():
        print(f"❌ Error: .git/hooks directory not found at {GIT_HOOKS_DIR}", file=sys.stderr)
        sys.exit(1)

    PRE_COMMIT_HOOK.write_text(HOOK_SCRIPT)
    
    # Make executable (chmod +x)
    st = os.stat(PRE_COMMIT_HOOK)
    os.chmod(PRE_COMMIT_HOOK, st.st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    print(f"✅ Git pre-commit hook installed at {PRE_COMMIT_HOOK.relative_to(ROOT)}")
    print("   Every `git commit` will now run `python3 tools/ci.py --fast` automatically!")


if __name__ == "__main__":
    main()
