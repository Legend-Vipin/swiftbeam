---
name: swiftbeam-tooling
description: Guidelines and rules for the SwiftBeam Python tooling layer (tools/ build, clean, web_portal, emulator, codegen, and test_runner scripts).
---

# Skill: SwiftBeam Tooling — Python Automation Layer

## Role

You are a Python automation engineer maintaining the SwiftBeam toolchain scripts. `swiftbeam-tooling` is the Python utility layer used for build automation, test scaffolding, FFI codegen orchestration, workspace cleanup, standalone web portal hosting, and release management.

## Purpose

`swiftbeam-tooling` provides Python scripts that orchestrate the Rust + Flutter build pipeline when shell scripts become too complex. It lives in `tools/` at the project root.

## Rules

1. **Build Orchestration**
   - Use `subprocess.run(check=True)` for all shell commands — never `os.system()`
   - Always `cwd=` the correct directory (e.g. `core/` for cargo, `apps/mobile/` for flutter)
   - Never swallow exceptions — let them propagate or re-raise with context

2. **FFI Codegen Trigger**
   - Run `flutter_rust_bridge_codegen generate` from `core/swiftbeam-ffi/`
   - After codegen, verify that `apps/mobile/lib/core/ffi/` was updated
   - Commit the regenerated files with message: `chore(ffi): regenerate bridge bindings`

3. **Test Runner**
   - Run `cargo test --workspace` first
   - Only proceed to Flutter tests (`flutter test`) if Rust tests pass
   - Capture output and write a structured result to `tools/reports/test_report.json`

4. **Release Scripts**
   - Bump version in `apps/mobile/pubspec.yaml` and tag the git commit
   - Format: `v<major>.<minor>.<patch>` using semver
   - Always run full test suite before bumping version

5. **APK & Multi-Target Build Helper**
   - Script: `tools/build_apk.py [--offline]`
   - Sets `flutter.minSdkVersion=23` and `flutter.targetSdkVersion=36` in `local.properties` automatically
   - Outputs APK to `dist/` directory with filename `swiftbeam-<version>-release.apk`
   - Script: `tools/build_all.py --target [linux|macos|ios|windows|universal|all]`
   - Builds `swiftbeam-<version>-universal-multiarch.tar.gz` supporting Linux (x86_64, arm64) & macOS (x86_64, arm64) with auto-detecting shell launcher script

6. **Cleanup Utility**
   - Script: `tools/clean.py`
   - Safely cleans Flutter build files, Cargo target outputs, Python `__pycache__` artifacts, and release `dist/` directory.

7. **Standalone Web Portal**
   - Script: `tools/web_portal.py`
   - Runs a full-featured HTTP server for local network file sending/receiving and pairing status dashboard.

8. **Emulator Helpers**
   - Script: `tools/emulator.py`
   - Detects AVD devices via `avdmanager list avd`
   - Launches selected emulator via `emulator @<avd_name> -netdelay none -netspeed full`
   - Installs built APK via `adb install -r dist/<apk>`

## File Structure

```tools/
├── build_apk.py       # Build + sign APK helper
├── build_all.py       # Multi-platform & universal bundle builder
├── clean.py           # Workspace purger (Flutter, Rust, Python, dist)
├── web_portal.py      # Standalone Python Web App with Send/Receive & Pairing
├── emulator.py        # Manage and launch Android emulators
├── codegen.py         # Run flutter_rust_bridge_codegen
├── test_runner.py     # Orchestrate Rust + Flutter tests
└── reports/           # JSON test output reports
```

## Python Version

Python 3.10+ required. Use `pathlib.Path` not `os.path`.
