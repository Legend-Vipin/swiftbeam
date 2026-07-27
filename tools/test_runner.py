#!/usr/bin/env python3
"""
SwiftBeam Test Runner (swiftbeam-tooling)
Orchestrates Rust unit/integration tests and Flutter widget/unit tests.
Generates structured JSON reports in tools/reports/test_report.json.
"""

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).parent.parent.resolve()
CORE_DIR = ROOT / "core"
MOBILE_DIR = ROOT / "apps" / "mobile"
REPORTS_DIR = ROOT / "tools" / "reports"


def run_rust_tests() -> dict:
    print("🔬  Running Rust tests (cargo test --workspace)...")
    start = time.time()
    proc = subprocess.run(
        ["cargo", "test", "--workspace"],
        cwd=CORE_DIR,
        capture_output=True,
        text=True,
    )
    duration = time.time() - start
    success = proc.returncode == 0
    if success:
        print(f"✅  Rust tests passed in {duration:.2f}s")
    else:
        print(f"❌  Rust tests failed!\n{proc.stderr}", file=sys.stderr)

    return {
        "suite": "rust",
        "success": success,
        "duration_seconds": round(duration, 2),
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


def run_flutter_tests() -> dict:
    print("📱  Running Flutter tests (flutter test)...")
    start = time.time()
    proc = subprocess.run(
        ["flutter", "test"],
        cwd=MOBILE_DIR,
        capture_output=True,
        text=True,
    )
    duration = time.time() - start
    success = proc.returncode == 0
    if success:
        print(f"✅  Flutter tests passed in {duration:.2f}s")
    else:
        print(f"❌  Flutter tests failed!\n{proc.stderr}", file=sys.stderr)

    return {
        "suite": "flutter",
        "success": success,
        "duration_seconds": round(duration, 2),
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


def main():
    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    report_file = REPORTS_DIR / "test_report.json"

    rust_result = run_rust_tests()
    flutter_result = {"suite": "flutter", "success": False, "skipped": True}

    # Only run Flutter tests if Rust tests pass
    if rust_result["success"]:
        flutter_result = run_flutter_tests()

    overall_success = rust_result["success"] and flutter_result.get("success", False)

    report = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "overall_success": overall_success,
        "results": [rust_result, flutter_result],
    }

    report_file.write_text(json.dumps(report, indent=2))
    print(f"\n📊  Test report written to {report_file}")

    if not overall_success:
        sys.exit(1)


if __name__ == "__main__":
    main()
