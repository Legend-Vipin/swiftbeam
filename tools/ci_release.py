#!/usr/bin/env python3
"""
SwiftBeam Local CI & Release Automation Tool (ci_release.py)

Orchestrates local continuous integration checks and release packaging for the SwiftBeam monorepo.
Adheres to CorePy guidelines (Python 3.10+, pathlib.Path, subprocess.run).

Usage:
  # Run full Local CI pipeline:
  python3 tools/ci_release.py ci

  # Run CI auto-fixing formatting issues:
  python3 tools/ci_release.py ci --fix

  # Run CI for Rust only or Flutter only:
  python3 tools/ci_release.py ci --rust-only
  python3 tools/ci_release.py ci --flutter-only

  # Run Release pipeline (CI + version check + packaging + manifest):
  python3 tools/ci_release.py release

  # Run Release with version bump and git tag creation:
  python3 tools/ci_release.py release --bump patch --tag
"""

import argparse
import datetime
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

# Repository root directory setup
ROOT = Path(__file__).parent.parent.resolve()
CORE_DIR = ROOT / "core"
MOBILE_DIR = ROOT / "apps" / "mobile"
TOOLS_DIR = ROOT / "tools"
REPORTS_DIR = TOOLS_DIR / "reports"
DIST_DIR = ROOT / "dist"


class Colors:
    """Terminal ANSI styling constants."""
    ENABLED = sys.stdout.isatty() or os.environ.get("FORCE_COLOR") == "1"

    GREEN = "\033[92m" if ENABLED else ""
    RED = "\033[91m" if ENABLED else ""
    YELLOW = "\033[93m" if ENABLED else ""
    BLUE = "\033[94m" if ENABLED else ""
    CYAN = "\033[96m" if ENABLED else ""
    BOLD = "\033[1m" if ENABLED else ""
    RESET = "\033[0m" if ENABLED else ""


def print_banner(title: str, subtitle: str = ""):
    """Print a bold color header banner."""
    width = 68
    print(f"\n{Colors.CYAN}{Colors.BOLD}{'=' * width}{Colors.RESET}")
    print(f"{Colors.CYAN}{Colors.BOLD} 🚀 {title.center(width - 6)} 🚀 {Colors.RESET}")
    if subtitle:
        print(f"{Colors.BLUE}    {subtitle.center(width - 8)}    {Colors.RESET}")
    print(f"{Colors.CYAN}{Colors.BOLD}{'=' * width}{Colors.RESET}\n")


def print_stage_header(stage_num: int, total_stages: int, name: str):
    """Print header for an individual stage."""
    print(f"\n{Colors.BOLD}[Stage {stage_num}/{total_stages}] {Colors.CYAN}{name}{Colors.RESET}")
    print(f"{Colors.BLUE}{'-' * 50}{Colors.RESET}")


def run_command(cmd: list[str], cwd: Path = ROOT, check: bool = False, capture: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command adhering to CorePy guidelines."""
    env = os.environ.copy()
    cargo_home = Path(os.environ.get("CARGO_HOME", Path.home() / ".cargo"))
    cargo_bin = str(cargo_home / "bin")
    if cargo_bin not in env.get("PATH", ""):
        env["PATH"] = f"{cargo_bin}:{env.get('PATH', '')}"
    env["PKG_CONFIG_ALLOW_CROSS"] = "1"
    ninja_path = shutil.which("ninja") or shutil.which("ninja-build")
    if ninja_path:
        env["CMAKE_MAKE_PROGRAM"] = ninja_path
        env["NINJA"] = ninja_path
    try:
        return subprocess.run(
            cmd,
            cwd=cwd,
            check=check,
            capture_output=capture,
            text=True,
            env=env
        )
    except FileNotFoundError:
        return subprocess.CompletedProcess(
            args=cmd,
            returncode=127,
            stdout="",
            stderr=f"Command not found: {cmd[0]}"
        )


def get_app_version() -> str:
    """Extract version from apps/mobile/pubspec.yaml."""
    pubspec = (MOBILE_DIR / "pubspec.yaml").read_text()
    for line in pubspec.splitlines():
        if line.startswith("version:"):
            # version: 1.0.0+1 -> 1.0.0
            return line.split(":")[1].strip().split("+")[0]
    return "1.0.0"


def bump_version_string(version: str, bump_type: str) -> str:
    """Bump semantic version string."""
    clean_ver = version.lstrip("v")
    parts = list(map(int, clean_ver.split(".")))
    while len(parts) < 3:
        parts.append(0)

    if bump_type == "patch":
        parts[2] += 1
    elif bump_type == "minor":
        parts[1] += 1
        parts[2] = 0
    elif bump_type == "major":
        parts[0] += 1
        parts[1] = 0
        parts[2] = 0

    return f"{parts[0]}.{parts[1]}.{parts[2]}"


def set_app_version(new_version: str):
    """Update version string in apps/mobile/pubspec.yaml."""
    pubspec_path = MOBILE_DIR / "pubspec.yaml"
    content = pubspec_path.read_text()
    lines = content.splitlines()
    updated = False
    new_lines = []

    for line in lines:
        if line.startswith("version:"):
            # Keep build number if present
            if "+" in line:
                build_num = line.split("+")[1]
                new_lines.append(f"version: {new_version}+{build_num}")
            else:
                new_lines.append(f"version: {new_version}")
            updated = True
        else:
            new_lines.append(line)

    if updated:
        pubspec_path.write_text("\n".join(new_lines) + "\n")
        print(f"📝 Updated {pubspec_path.relative_to(ROOT)} version to {new_version}")


def get_git_commit_hash() -> str:
    """Get current short git commit hash."""
    res = run_command(["git", "rev-parse", "--short", "HEAD"])
    return res.stdout.strip() if res.returncode == 0 else "unknown"


def compute_sha256(filepath: Path) -> str:
    """Compute SHA256 checksum for a file."""
    hasher = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(8192):
            hasher.update(chunk)
    return hasher.hexdigest()


# ==============================================================================
# LOCAL CI PIPELINE
# ==============================================================================

def run_ci(args) -> bool:
    """Run the Local CI Pipeline across Rust core and Flutter mobile."""
    print_banner("SwiftBeam Local CI Pipeline", "Automated code quality, static analysis & testing")

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    report_path = REPORTS_DIR / "ci_report.json"

    # Define CI stages
    stages = []

    # Rust stages
    if not args.flutter_only:
        stages.extend([
            {
                "id": "ffi-codegen",
                "name": "FFI Bridge Codegen Verification",
                "action": lambda: run_command([sys.executable, str(TOOLS_DIR / "codegen.py")]),
                "fix_action": None,
                "category": "rust",
            },
            {
                "id": "rust-fmt",
                "name": "Rust Code Format Check (cargo fmt)",
                "action": lambda: run_command(["cargo", "fmt", "--all", "--", "--check"], cwd=CORE_DIR),
                "fix_action": lambda: run_command(["cargo", "fmt", "--all"], cwd=CORE_DIR),
                "category": "rust",
            },
            {
                "id": "rust-clippy",
                "name": "Rust Clippy Linter Check (cargo clippy)",
                "action": lambda: run_command(
                    ["cargo", "clippy", "--workspace", "--all-targets", "--all-features", "--", "-D", "warnings"],
                    cwd=CORE_DIR
                ),
                "fix_action": None,
                "category": "rust",
            },
        ])

        if not args.skip_tests and not args.fast:
            stages.append({
                "id": "rust-test",
                "name": "Rust Core Unit & Integration Tests (cargo test)",
                "action": lambda: run_command(["cargo", "test", "--workspace", "--all-features"], cwd=CORE_DIR),
                "fix_action": None,
                "category": "rust",
            })

    # Flutter stages
    if not args.rust_only:
        # Ensure dependencies are fetched and package_config.json is up-to-date
        run_command(["flutter", "pub", "get"], cwd=MOBILE_DIR)

        stages.extend([
            {
                "id": "flutter-fmt",
                "name": "Flutter / Dart Format Check (dart format)",
                "action": lambda: run_command(
                    ["dart", "format", "--output=none", "--set-exit-if-changed", "."],
                    cwd=MOBILE_DIR
                ),
                "fix_action": lambda: run_command(["dart", "format", "."], cwd=MOBILE_DIR),
                "category": "flutter",
            },
            {
                "id": "flutter-analyze",
                "name": "Flutter Static Analysis (flutter analyze)",
                "action": lambda: run_command(["flutter", "analyze"], cwd=MOBILE_DIR),
                "fix_action": None,
                "category": "flutter",
            },
        ])

        if not args.skip_tests and not args.fast:
            stages.append({
                "id": "flutter-test",
                "name": "Flutter Widget & Unit Tests (flutter test)",
                "action": lambda: run_command(["flutter", "test"], cwd=MOBILE_DIR),
                "fix_action": None,
                "category": "flutter",
            })

    total_stages = len(stages)
    results = []
    overall_success = True

    for idx, stage in enumerate(stages, 1):
        print_stage_header(idx, total_stages, stage["name"])
        start_time = time.time()

        # If --fix is set and fix action exists, run fix first
        if getattr(args, "fix", False) and stage["fix_action"]:
            print(f"🔧 Applying auto-fix for {stage['name']}...")
            stage["fix_action"]()

        proc = stage["action"]()
        duration = round(time.time() - start_time, 2)
        success = (proc.returncode == 0)

        if success:
            print(f"{Colors.GREEN}✅ PASSED{Colors.RESET} ({duration}s)")
        else:
            print(f"{Colors.RED}❌ FAILED{Colors.RESET} ({duration}s)")
            if proc.stderr:
                print(f"\n{Colors.RED}--- Error Output ---{Colors.RESET}\n{proc.stderr.strip()}")
            elif proc.stdout:
                print(f"\n{Colors.RED}--- Standard Output ---{Colors.RESET}\n{proc.stdout.strip()}")
            overall_success = False

        results.append({
            "id": stage["id"],
            "name": stage["name"],
            "category": stage["category"],
            "success": success,
            "duration_seconds": duration,
            "exit_code": proc.returncode,
            "stderr": proc.stderr,
        })

        # If stage fails and user didn't request --keep-going, we log and proceed to give full feedback
        # but overall_success remains False

    # Build final report
    report_data = {
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "commit": get_git_commit_hash(),
        "overall_success": overall_success,
        "total_stages": total_stages,
        "passed_stages": sum(1 for r in results if r["success"]),
        "failed_stages": sum(1 for r in results if not r["success"]),
        "stages": results
    }

    report_path.write_text(json.dumps(report_data, indent=2))

    # Print Summary Table
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'=' * 68}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.CYAN} 📊 LOCAL CI SUMMARY RESULT 📊 {Colors.RESET}".center(76))
    print(f"{Colors.BOLD}{Colors.CYAN}{'=' * 68}{Colors.RESET}\n")

    for r in results:
        status_str = f"{Colors.GREEN}PASS{Colors.RESET}" if r["success"] else f"{Colors.RED}FAIL{Colors.RESET}"
        print(f"  [{status_str}] {r['name']:<48} ({r['duration_seconds']}s)")

    print(f"\n📁 Detailed CI report written to: {Colors.BOLD}{report_path.relative_to(ROOT)}{Colors.RESET}")

    if overall_success:
        print(f"\n{Colors.GREEN}{Colors.BOLD}🎉 ALL LOCAL CI CHECKS PASSED SUCCESSFULLY! 🎉{Colors.RESET}\n")
    else:
        print(f"\n{Colors.RED}{Colors.BOLD}❌ LOCAL CI FAILED. Please resolve errors before committing or releasing.{Colors.RESET}\n")

    return overall_success


# ==============================================================================
# RELEASE PIPELINE
# ==============================================================================

def generate_changelog(version: str) -> str:
    """Generate markdown changelog from git history."""
    # Find last tag if any
    tag_proc = run_command(["git", "describe", "--abbrev=0", "--tags", "HEAD^"])
    last_tag = tag_proc.stdout.strip() if tag_proc.returncode == 0 else ""

    if last_tag:
        log_proc = run_command(["git", "log", "--pretty=format:- %s (%h)", f"{last_tag}..HEAD"])
        range_desc = f"Changes since `{last_tag}`"
    else:
        log_proc = run_command(["git", "log", "--pretty=format:- %s (%h)", "-n", "20"])
        range_desc = "Recent commits"

    commits = log_proc.stdout.strip() if log_proc.returncode == 0 else "- Initial release"
    if not commits:
        commits = "- Minor fixes and performance updates"

    today = datetime.date.today().isoformat()

    changelog_md = f"""# Release {version} ({today})

{range_desc}:

{commits}

---
*Built with SwiftBeam Local Release Tooling*
"""
    return changelog_md


def run_release(args) -> bool:
    """Run full Release Pipeline (CI -> Build APK -> Build Universal -> Changelog -> Manifest)."""
    print_banner("SwiftBeam Local Release Pipeline", "Automated release validation, building & packaging")

    # 1. Step 1: Pre-release CI Verification
    if not args.skip_ci:
        print(f"{Colors.BOLD}🔍 Step 1: Running Pre-release CI Checks...{Colors.RESET}")
        ci_ok = run_ci(args)
        if not ci_ok:
            print(f"\n{Colors.RED}{Colors.BOLD}⛔ Release aborted: Local CI failed. Fix errors or pass --skip-ci.{Colors.RESET}")
            return False
    else:
        print(f"{Colors.YELLOW}⚠️  Skipping Local CI pre-checks (--skip-ci specified).{Colors.RESET}")

    # 2. Step 2: Check Git Working Tree
    print(f"\n{Colors.BOLD}🧹 Step 2: Checking Git Working Directory...{Colors.RESET}")
    status_proc = run_command(["git", "status", "--porcelain"])
    dirty = bool(status_proc.stdout.strip())
    if dirty and not args.allow_dirty:
        print(f"{Colors.RED}❌ Working directory has uncommitted changes!{Colors.RESET}")
        print("Please commit or stash your changes before releasing, or pass --allow-dirty.")
        return False
    elif dirty:
        print(f"{Colors.YELLOW}⚠️  Working directory is dirty, but --allow-dirty was specified.{Colors.RESET}")
    else:
        print(f"{Colors.GREEN}✅ Git working directory is clean.{Colors.RESET}")

    # 3. Step 3: Handle Version & Tagging
    current_version = get_app_version()
    target_version = current_version

    if args.bump:
        target_version = bump_version_string(current_version, args.bump)
        print(f"📈 Bumping version: {current_version} -> {target_version}")
        set_app_version(target_version)
    elif args.version:
        target_version = args.version.lstrip("v")
        print(f"📌 Setting explicit version: {current_version} -> {target_version}")
        set_app_version(target_version)
    else:
        print(f"📦 Using current app version: v{target_version}")

    tag_name = f"v{target_version}"

    if args.tag or args.create_tag:
        print(f"🏷️  Creating local git tag `{tag_name}`...")
        tag_cmd = run_command(["git", "tag", "-a", tag_name, "-m", f"Release {tag_name}"])
        if tag_cmd.returncode == 0:
            print(f"{Colors.GREEN}✅ Git tag {tag_name} created successfully.{Colors.RESET}")
            if args.push:
                print(f"🌐 Pushing tag {tag_name} and commits to remote...")
                run_command(["git", "push", "origin", tag_name], check=True)
                run_command(["git", "push"], check=True)
                print(f"{Colors.GREEN}✅ Git tag pushed to remote.{Colors.RESET}")
        else:
            print(f"{Colors.YELLOW}⚠️  Git tag `{tag_name}` already exists or could not be created.{Colors.RESET}")

    # 4. Step 4: Build Release Artifacts
    DIST_DIR.mkdir(parents=True, exist_ok=True)
    print(f"\n{Colors.BOLD}🔨 Step 4: Building Release Packaging Artifacts...{Colors.RESET}")

    # 4a. Build APK
    print(f"\n📱 [Release Build] Android APK (build_apk.py)...")
    apk_proc = run_command([sys.executable, str(TOOLS_DIR / "build_apk.py"), "--skip-tests"])
    if apk_proc.returncode != 0:
        print(f"{Colors.RED}❌ APK build failed:\n{apk_proc.stderr}{Colors.RESET}")
        return False
    print(f"{Colors.GREEN}✅ Android APK build complete.{Colors.RESET}")

    # 4b. Build Cross-Platform OS Binaries
    target_os = getattr(args, "target", "universal")
    print(f"\n🖥️  [Release Build] Cross-Platform Packages for target '{target_os}' (build_all.py)...")
    build_all_proc = run_command([sys.executable, str(TOOLS_DIR / "build_all.py"), "--target", target_os, "--skip-tests"])
    if build_all_proc.returncode != 0:
        print(f"{Colors.RED}❌ Cross-platform build failed:\n{build_all_proc.stderr}{Colors.RESET}")
        return False
    print(f"{Colors.GREEN}✅ Cross-platform packages build complete.{Colors.RESET}")

    # 5. Step 5: Generate Changelog
    print(f"\n{Colors.BOLD}📝 Step 5: Generating Release Changelog...{Colors.RESET}")
    changelog_content = generate_changelog(target_version)
    changelog_path = DIST_DIR / f"CHANGELOG_{target_version}.md"
    changelog_path.write_text(changelog_content)
    print(f"{Colors.GREEN}✅ Written {changelog_path.relative_to(ROOT)}{Colors.RESET}")

    # 6. Step 6: Generate Release Manifest JSON
    print(f"\n{Colors.BOLD}📄 Step 6: Generating Release Manifest...{Colors.RESET}")
    artifacts = []
    valid_exts = {".apk", ".gz", ".deb", ".rpm", ".dmg", ".zip", ".exe", ".ipa", ".tar"}

    for item in DIST_DIR.iterdir():
        if item.is_file() and any(item.name.endswith(ext) for ext in valid_exts):
            size_bytes = item.stat().st_size
            size_mb = round(size_bytes / (1024 * 1024), 2)
            sha256 = compute_sha256(item)

            artifacts.append({
                "filename": item.name,
                "size_bytes": size_bytes,
                "size_mb": size_mb,
                "sha256": sha256,
                "path": str(item.relative_to(ROOT))
            })

    manifest = {
        "project": "SwiftBeam",
        "version": target_version,
        "tag": tag_name,
        "commit": get_git_commit_hash(),
        "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "artifacts_count": len(artifacts),
        "artifacts": artifacts
    }

    manifest_path = DIST_DIR / "release_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2))
    print(f"{Colors.GREEN}✅ Written {manifest_path.relative_to(ROOT)}{Colors.RESET}")

    # 7. Step 7: Release Summary
    print(f"\n{Colors.BOLD}{Colors.CYAN}{'=' * 68}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.CYAN} 🎉 SWIFTBEAM RELEASE READY: v{target_version} 🎉 {Colors.RESET}".center(76))
    print(f"{Colors.BOLD}{Colors.CYAN}{'=' * 68}{Colors.RESET}\n")

    print(f"  📌 {Colors.BOLD}Version:{Colors.RESET}   v{target_version}")
    print(f"  🏷️  {Colors.BOLD}Git Tag:{Colors.RESET}   {tag_name}")
    print(f"  🔗 {Colors.BOLD}Commit:{Colors.RESET}    {get_git_commit_hash()}")
    print(f"  📦 {Colors.BOLD}Artifacts ({len(artifacts)}):{Colors.RESET}")

    for a in artifacts:
        print(f"     • {Colors.BOLD}{a['filename']}{Colors.RESET} ({a['size_mb']} MB)")
        print(f"       SHA256: {Colors.CYAN}{a['sha256']}{Colors.RESET}")

    print(f"\n📁 Manifest & Changelog saved in: {Colors.BOLD}{DIST_DIR.relative_to(ROOT)}/{Colors.RESET}\n")
    return True


# ==============================================================================
# MAIN CLI ENTRYPOINT
# ==============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="SwiftBeam Local CI & Release Automation Script (CorePy Tooling)"
    )
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # CI Subparser
    ci_parser = subparsers.add_parser("ci", help="Run Local CI quality pipeline")
    ci_parser.add_argument("--fix", "-f", action="store_true", help="Auto-fix formatting (cargo fmt, dart format)")
    ci_parser.add_argument("--rust-only", action="store_true", help="Run only Rust core checks")
    ci_parser.add_argument("--flutter-only", action="store_true", help="Run only Flutter mobile checks")
    ci_parser.add_argument("--skip-tests", action="store_true", help="Skip running test suites")
    ci_parser.add_argument("--fast", action="store_true", help="Fast mode (skip test suites, run fmt & linter)")

    # Release Subparser
    rel_parser = subparsers.add_parser("release", help="Run Release packaging pipeline")
    rel_parser.add_argument("--version", type=str, help="Specify release version (e.g. 1.0.0)")
    rel_parser.add_argument("--bump", choices=["patch", "minor", "major"], help="Bump semantic version")
    rel_parser.add_argument("--target", default="universal", help="Target OS packaging (linux, macos, windows, ios, universal, all)")
    rel_parser.add_argument("--skip-ci", action="store_true", help="Skip running local CI pre-checks")
    rel_parser.add_argument("--tag", "--create-tag", dest="tag", action="store_true", help="Create local git tag for release")
    rel_parser.add_argument("--push", action="store_true", help="Push git tag and commits to remote")
    rel_parser.add_argument("--allow-dirty", action="store_true", help="Allow building release with dirty git tree")

    # Pass through CI options to release subparser if CI runs
    rel_parser.add_argument("--fix", action="store_true", help=argparse.SUPPRESS)
    rel_parser.add_argument("--rust-only", action="store_true", help=argparse.SUPPRESS)
    rel_parser.add_argument("--flutter-only", action="store_true", help=argparse.SUPPRESS)
    rel_parser.add_argument("--skip-tests", action="store_true", help=argparse.SUPPRESS)
    rel_parser.add_argument("--fast", action="store_true", help=argparse.SUPPRESS)

    # Default to CI if no subcommand provided
    if len(sys.argv) == 1:
        args = parser.parse_args(["ci"])
    else:
        args = parser.parse_args()

    if args.command == "ci":
        success = run_ci(args)
        sys.exit(0 if success else 1)
    elif args.command == "release":
        success = run_release(args)
        sys.exit(0 if success else 1)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
