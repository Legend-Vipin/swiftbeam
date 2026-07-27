# SwiftBeam Tooling Layer (`swiftbeam-tooling`) Guide

## Overview

All automation scripts live under `tools/` and are built using Python 3.10+ (`pathlib.Path`, `subprocess.run(check=True)`).

```text
tools/
├── build_apk.py       # Compiles release APK, auto-detects JDK & copies to dist/
├── build_all.py       # Multi-platform & universal bundle packaging tool
├── clean.py           # Workspace purger for Flutter, Rust, Python caches & dist/
├── web_portal.py      # Standalone Python Web App with Send/Receive & Pairing Dashboard
├── emulator.py        # Manages and launches Android emulators
├── codegen.py         # Runs flutter_rust_bridge_codegen
└── test_runner.py     # Orchestrates Rust + Flutter test suites
```

---

## Tool Command Reference

### 1. Build Release APK

```bash
python3 tools/build_apk.py [--skip-tests] [--offline]
```

- Sets `flutter.minSdkVersion=23` and `flutter.targetSdkVersion=36`.
- Auto-detects JDK installation with `javac` compiler (e.g. Android Studio JBR).
- Clears stale `.gradle` lock files.
- Outputs release binary to `dist/swiftbeam-1.0.0-release.apk`.

### 2. Multi-Target & Universal Packaging

```bash
python3 tools/build_all.py --target [linux|macos|ios|windows|universal|all]
```

- `--target universal`: Creates `swiftbeam-1.0.0-universal-multiarch.tar.gz` for Linux (x86_64, arm64) and macOS (x86_64, arm64).
- `--target linux`: Builds Linux `.tar.gz` and `.deb` packages.
- `--target all`: Safely builds available targets for host operating system.

### 3. Workspace Cleanup Utility

```bash
python3 tools/clean.py
```

- Purges Flutter build artifacts (`build/`, `.dart_tool/`, `.flutter-plugins-dependencies`).
- Executes `cargo clean` and removes all Rust compilation directories (`core/target/`).
- Recursively removes Python `__pycache__` and `.pyc` files across the monorepo.
- Removes output distribution directory (`dist/`).

### 4. Standalone Python Web Portal App

```bash
python3 tools/web_portal.py
```

- Launches a full-featured HTTP Web Server on `http://<Local-IP>:8080`.
- Provides **📤 Send Tab** (drag & drop files to save to host system Downloads).
- Provides **📥 Receive Tab** (browse and download files hosted in system Downloads).
- Includes **📡 P2P Pairing Dashboard** displaying local Wi-Fi IP, Wi-Fi Direct, and Bluetooth status.

### 5. Run Complete Test Suite

```bash
python3 tools/test_runner.py
```

- Executes `cargo test --workspace` and `flutter test`.
- Writes JSON report to `tools/reports/test_report.json`.

### 6. Regenerate FFI Bindings

```bash
python3 tools/codegen.py
```

- Triggers `flutter_rust_bridge_codegen generate` from `core/swiftbeam-ffi/`.

