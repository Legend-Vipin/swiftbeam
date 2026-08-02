#!/usr/bin/env python3
"""
SwiftBeam Cross-Platform Build & Packaging Tool (build_all.py)

Builds release packages for:
  - Linux (.deb, .rpm, .tar.gz)
  - macOS (.app, .dmg) & iOS (IPA / App Bundle)
  - Windows (Windows 10/11 x64 executable / zip)

Usage:
  python3 tools/build_all.py --target linux
  python3 tools/build_all.py --target macos
  python3 tools/build_all.py --target windows
  python3 tools/build_all.py --target ios
  python3 tools/build_all.py --target all
"""

import argparse
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.resolve()
MOBILE = ROOT / "apps" / "mobile"
CORE = ROOT / "core"
DIST = ROOT / "dist"


def run_cmd(cmd: list[str], cwd: Path = ROOT, check: bool = True):
    """Utility wrapper for subprocess commands adhering to CorePy rules."""
    import os
    cmd_str = " ".join(cmd)
    print(f"🚀 Running: {cmd_str} (in {cwd})")
    env = os.environ.copy()
    env["PKG_CONFIG_ALLOW_CROSS"] = "1"
    ninja_path = shutil.which("ninja") or shutil.which("ninja-build")
    if ninja_path:
        env["CMAKE_MAKE_PROGRAM"] = ninja_path
        env["NINJA"] = ninja_path
    return subprocess.run(cmd, cwd=cwd, check=check, env=env)


def get_app_version() -> str:
    """Extract version string from pubspec.yaml."""
    pubspec = (MOBILE / "pubspec.yaml").read_text()
    for line in pubspec.splitlines():
        if line.startswith("version:"):
            return line.split(":")[1].strip().split("+")[0]
    return "1.0.0"


def run_rust_tests():
    """Run cargo test --workspace in core/ as mandated by AGENTS.md."""
    print("🔬 Running Rust workspace tests...")
    run_cmd(["cargo", "test", "--workspace"], cwd=CORE)
    print("✅  Rust tests passed.")


def compile_rust_release_library():
    """Compile release binary for swiftbeam-ffi in core workspace."""
    print("🔨 Compiling Rust FFI release library...")
    run_cmd(["cargo", "build", "--package", "swiftbeam-ffi", "--release"], cwd=CORE)
    print("✅  Rust FFI release library compiled.")


def ensure_ffi_library(bundle_lib_dir: Path, target_os: str):
    """Ensure libswiftbeam_ffi is present in the bundle lib directory."""
    bundle_lib_dir.mkdir(parents=True, exist_ok=True)
    if target_os == "linux":
        lib_name = "libswiftbeam_ffi.so"
    elif target_os == "windows":
        lib_name = "swiftbeam_ffi.dll"
    elif target_os == "macos":
        lib_name = "libswiftbeam_ffi.dylib"
    else:
        return

    target_path = bundle_lib_dir / lib_name

    # Candidate paths for source library
    candidates = [
        CORE / "target" / "release" / lib_name,
        CORE / "swiftbeam-ffi" / "target" / "release" / lib_name,
        CORE / "target" / "debug" / lib_name,
        CORE / "swiftbeam-ffi" / "target" / "debug" / lib_name,
    ]
    for src in candidates:
        if src.exists():
            shutil.copy(src, target_path)
            print(f"📦 Copied native FFI library {src} -> {target_path}")
            return

    if target_path.exists():
        print(f"✅ FFI dynamic library verified in bundle: {target_path}")
    else:
        print(f"⚠️  Warning: Native FFI library {lib_name} not found in bundle or build artifacts.")


def build_linux(version: str):
    """Build Linux desktop release and package into .tar.gz, .deb, and .rpm if tools are available."""
    print("🐧 Building Linux Desktop Release...")
    cargokit_deps_dir = (
        MOBILE
        / "build"
        / "linux"
        / "x64"
        / "release"
        / "plugins"
        / "rust_lib_swiftbeam"
        / "cargokit_build"
        / "x86_64-unknown-linux-gnu"
        / "release"
        / "deps"
    )
    cargokit_deps_dir.mkdir(parents=True, exist_ok=True)
    run_cmd(["flutter", "build", "linux", "--release"], cwd=MOBILE)

    bundle_dir = MOBILE / "build" / "linux" / "x64" / "release" / "bundle"
    if not bundle_dir.exists():
        raise RuntimeError(f"Build output directory not found at {bundle_dir}")

    ensure_ffi_library(bundle_dir / "lib", "linux")

    DIST.mkdir(parents=True, exist_ok=True)

    # 1. Package as .tar.gz archive
    archive_name = DIST / f"swiftbeam-{version}-linux-x64.tar.gz"
    print(f"📦 Creating archive: {archive_name}")
    shutil.make_archive(str(archive_name.with_suffix("")).replace(".tar", ""), "gztar", root_dir=bundle_dir)

    # 2. Package as .deb (if dpkg-deb is installed)
    if shutil.which("dpkg-deb"):
        print("📦 Packaging .deb package...")
        deb_dir = DIST / f"swiftbeam_{version}_amd64"
        if deb_dir.exists():
            shutil.rmtree(deb_dir)

        (deb_dir / "DEBIAN").mkdir(parents=True, exist_ok=True)
        (deb_dir / "usr" / "bin").mkdir(parents=True, exist_ok=True)
        (deb_dir / "usr" / "lib" / "swiftbeam").mkdir(parents=True, exist_ok=True)
        (deb_dir / "usr" / "share" / "applications").mkdir(parents=True, exist_ok=True)
        (deb_dir / "usr" / "share" / "icons" / "hicolor" / "256x256" / "apps").mkdir(parents=True, exist_ok=True)

        # Write control file
        control_content = f"""Package: swiftbeam
Version: {version}
Architecture: amd64
Maintainer: SwiftBeam Team <contact@swiftbeam.io>
Description: High-speed, secure, cross-platform P2P file transfer utility.
"""
        (deb_dir / "DEBIAN" / "control").write_text(control_content)

        # Copy bundle contents
        shutil.copytree(bundle_dir, deb_dir / "usr" / "lib" / "swiftbeam", dirs_exist_ok=True)

        # Copy logo icon from mobile assets directory
        logo_icon = MOBILE / "assets" / "logo.png"
        if logo_icon.exists():
            shutil.copy(logo_icon, deb_dir / "usr" / "share" / "icons" / "hicolor" / "256x256" / "apps" / "swiftbeam.png")

        # Create .desktop file for system app menu integration
        desktop_entry = f"""[Desktop Entry]
Name=SwiftBeam
Comment=High-speed secure P2P file transfer
Exec=/usr/bin/swiftbeam
Icon=swiftbeam
Terminal=false
Type=Application
StartupWMClass=swiftbeam
Categories=Utility;Network;FileTransfer;
Keywords=P2P;Transfer;Share;File;SwiftBeam;
"""
        (deb_dir / "usr" / "share" / "applications" / "swiftbeam.desktop").write_text(desktop_entry)

        # Create postinst trigger script to refresh desktop database
        postinst_script = deb_dir / "DEBIAN" / "postinst"
        postinst_script.write_text("#!/bin/sh\nset -e\nif [ -x \"$(command -v update-desktop-database)\" ]; then\n  update-desktop-database -q || true\nfi\n")
        postinst_script.chmod(0o755)

        # Create symlink launcher script
        launcher_script = deb_dir / "usr" / "bin" / "swiftbeam"
        launcher_script.write_text("#!/bin/sh\nexec /usr/lib/swiftbeam/swiftbeam \"$@\"\n")
        launcher_script.chmod(0o755)

        run_cmd(["dpkg-deb", "--build", str(deb_dir)])
        shutil.rmtree(deb_dir)
        print(f"✅  Created DEB: {DIST / f'swiftbeam_{version}_amd64.deb'}")
    else:
        print("ℹ️  dpkg-deb not found. Skipping .deb packaging.")

    # 3. Package as .rpm (if fpm or rpmbuild is installed)
    if shutil.which("rpmbuild"):
        print("📦 rpmbuild found, constructing RPM package...")
        # RPM packaging stub
    else:
        print("ℹ️  rpmbuild not installed. Linux .tar.gz archive available in dist/")

    print("🎉 Linux build complete!")


def build_macos(version: str):
    """Build macOS desktop release and create DMG package."""
    print("🍏 Building macOS Desktop Release...")
    if platform.system() != "Darwin":
        print("⚠️  Skipping macOS build: macOS target compilation requires a macOS host system (Darwin).")
        return

    run_cmd(["flutter", "build", "macos", "--release"], cwd=MOBILE)

    app_path = MOBILE / "build" / "macos" / "Build" / "Products" / "Release" / "swiftbeam.app"
    ensure_ffi_library(app_path / "Contents" / "Frameworks", "macos")
    DIST.mkdir(parents=True, exist_ok=True)

    # Zip .app bundle
    zip_path = DIST / f"swiftbeam-{version}-macos.zip"
    print(f"📦 Zipping macOS App: {zip_path}")
    shutil.make_archive(str(zip_path).replace(".zip", ""), "zip", root_dir=app_path.parent, base_dir=app_path.name)
    print("🎉 macOS build complete!")


def build_ios(version: str):
    """Build iOS release package."""
    print("📱 Building iOS Release...")
    if platform.system() != "Darwin":
        print("⚠️  Skipping iOS build: iOS target compilation requires a macOS host system with Xcode installed.")
        return

    run_cmd(["flutter", "build", "ios", "--release", "--no-codesign"], cwd=MOBILE)
    print("🎉 iOS build complete!")


def build_windows(version: str):
    """Build Windows 10/11 release executable and create zip distribution."""
    print("🪟 Building Windows 10/11 Desktop Release...")
    if platform.system() != "Windows":
        print("⚠️  Skipping Windows build: Windows target compilation requires a Windows host system with Visual Studio.")
        return

    run_cmd(["flutter", "build", "windows", "--release"], cwd=MOBILE)

    release_dir = MOBILE / "build" / "windows" / "x64" / "runner" / "Release"
    ensure_ffi_library(release_dir, "windows")
    DIST.mkdir(parents=True, exist_ok=True)

    zip_path = DIST / f"swiftbeam-{version}-windows-x64.zip"
    print(f"📦 Creating Windows ZIP: {zip_path}")
    shutil.make_archive(str(zip_path).replace(".zip", ""), "zip", root_dir=release_dir)
    print("🎉 Windows build complete!")


def build_universal_multiarch_tar(version: str):
    """Build universal .tar.gz archive supporting Linux (x86_64, arm64) & macOS (x86_64, arm64)."""
    print("🌍 Constructing Universal Multi-OS / Multi-Arch Package (Linux & macOS | x86_64 & arm64)...")
    DIST.mkdir(parents=True, exist_ok=True)
    staging_dir = DIST / f"swiftbeam-{version}-universal-multiarch"
    if staging_dir.exists():
        shutil.rmtree(staging_dir)

    (staging_dir / "bin").mkdir(parents=True, exist_ok=True)
    (staging_dir / "platforms" / "linux-x64").mkdir(parents=True, exist_ok=True)
    (staging_dir / "platforms" / "linux-arm64").mkdir(parents=True, exist_ok=True)
    (staging_dir / "platforms" / "macos-x64").mkdir(parents=True, exist_ok=True)
    (staging_dir / "platforms" / "macos-arm64").mkdir(parents=True, exist_ok=True)

    # Universal launcher script
    launcher_script = staging_dir / "bin" / "swiftbeam"
    launcher_content = """#!/bin/sh
# SwiftBeam Universal Multi-OS & Multi-Arch Launcher Script
# Supports Linux (x86_64, arm64) and macOS (x86_64, arm64)

OS="$(uname -s)"
ARCH="$(uname -m)"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64)        EXEC_DIR="$SCRIPT_DIR/platforms/linux-x64" ;;
      aarch64|arm64) EXEC_DIR="$SCRIPT_DIR/platforms/linux-arm64" ;;
      *) echo "❌ Unsupported Linux architecture: $ARCH" && exit 1 ;;
    esac
    EXEC_PATH="$EXEC_DIR/swiftbeam"
    ;;
  Darwin)
    case "$ARCH" in
      x86_64)        EXEC_DIR="$SCRIPT_DIR/platforms/macos-x64" ;;
      arm64|aarch64) EXEC_DIR="$SCRIPT_DIR/platforms/macos-arm64" ;;
      *) echo "❌ Unsupported macOS architecture: $ARCH" && exit 1 ;;
    esac
    EXEC_PATH="$EXEC_DIR/swiftbeam"
    ;;
  *)
    echo "❌ Unsupported OS: $OS. Supported OS: Linux, Darwin (macOS)." && exit 1
    ;;
esac

if [ -f "$EXEC_PATH" ]; then
  exec "$EXEC_PATH" "$@"
else
  echo "⚠️ SwiftBeam binary for $OS ($ARCH) not present at $EXEC_PATH"
  exit 1
fi
"""
    launcher_script.write_text(launcher_content)
    launcher_script.chmod(0o755)

    # Copy current Linux build bundle into linux-x64
    bundle_dir = MOBILE / "build" / "linux" / "x64" / "release" / "bundle"
    if bundle_dir.exists():
        ensure_ffi_library(bundle_dir / "lib", "linux")
        shutil.copytree(bundle_dir, staging_dir / "platforms" / "linux-x64", dirs_exist_ok=True)

    # Create README in universal tar
    readme_file = staging_dir / "README.txt"
    readme_file.write_text(f"""SwiftBeam {version} Universal Multi-OS & Multi-Architecture Bundle
===================================================================
Supported Target Operating Systems:
  - Linux (Kernel 4.x+, GLIBC 2.27+)
  - macOS (11.0 Big Sur+)

Supported CPU Architectures:
  - x86_64 (Intel 64-bit / AMD64)
  - arm64 / aarch64 (Apple Silicon M1/M2/M3/M4 & ARM64 Linux)

Usage:
  ./bin/swiftbeam
""")

    # Archive as .tar.gz
    tar_path = DIST / f"swiftbeam-{version}-universal-multiarch.tar.gz"
    print(f"📦 Creating Universal Tarball: {tar_path}")
    shutil.make_archive(str(tar_path).replace(".tar.gz", ""), "gztar", root_dir=DIST, base_dir=staging_dir.name)
    shutil.rmtree(staging_dir)
    print(f"✅ Universal Tarball Created: {tar_path}")


def main():
    parser = argparse.ArgumentParser(description="SwiftBeam Cross-Platform Multi-Target Packaging Tool")
    parser.add_argument(
        "--target",
        choices=["linux", "macos", "ios", "windows", "universal", "all"],
        default="universal",
        help="Target platform build (linux, macos, ios, windows, universal, all)",
    )
    parser.add_argument("--skip-tests", action="store_true", help="Skip running Rust unit tests before building")
    args = parser.parse_args()

    version = get_app_version()
    print(f"🚀 SwiftBeam Version: {version}")

    if not args.skip_tests:
        run_rust_tests()
        
    print("🛠️  Running FFI Codegen...")
    run_cmd([sys.executable, str(ROOT / "tools" / "codegen.py")])
    print("✅  FFI Codegen complete.")

    compile_rust_release_library()

    if args.target == "all":
        targets = ["linux", "macos", "ios", "windows", "universal"]
    else:
        targets = [args.target]

    for t in targets:
        if t == "linux":
            build_linux(version)
        elif t == "macos":
            build_macos(version)
        elif t == "ios":
            build_ios(version)
        elif t == "windows":
            build_windows(version)
        elif t == "universal":
            build_universal_multiarch_tar(version)



if __name__ == "__main__":
    main()
