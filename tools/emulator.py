#!/usr/bin/env python3
"""
SwiftBeam Emulator Helper (swiftbeam-tooling)
Lists, launches, and installs APK on Android emulators running on Linux.
"""

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).parent.parent.resolve()
DIST = ROOT / "dist"

def find_bin(name: str) -> str:
    """Find binary from PATH or standard Android SDK directories."""
    if shutil.which(name):
        return name
    sdk_root = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT") or os.path.expanduser("~/Android/Sdk")
    candidates = [
        Path(sdk_root) / "cmdline-tools" / "latest" / "bin" / name,
        Path(sdk_root) / "cmdline-tools" / "bin" / name,
        Path(sdk_root) / "tools" / "bin" / name,
        Path(sdk_root) / "emulator" / name,
        Path(sdk_root) / "platform-tools" / name,
    ]
    for c in candidates:
        if c.exists():
            return str(c)
    return name


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kwargs)


def list_avds() -> list[str]:
    """Return list of installed Android Virtual Devices."""
    avdmanager_bin = find_bin("avdmanager")
    if shutil.which(avdmanager_bin) or os.path.exists(avdmanager_bin):
        result = run([avdmanager_bin, "list", "avd", "-c"])
        if result.returncode == 0:
            return [line.strip() for line in result.stdout.splitlines() if line.strip()]

    # Fallback to emulator binary if avdmanager is not found
    emulator_bin = find_bin("emulator")
    if shutil.which(emulator_bin) or os.path.exists(emulator_bin):
        result = run([emulator_bin, "-list-avds"])
        if result.returncode == 0:
            return [line.strip() for line in result.stdout.splitlines() if line.strip()]
            
    return []


def list_apks() -> list[Path]:
    return sorted(DIST.glob("*.apk")) if DIST.exists() else []


def is_emulator_booted() -> bool:
    """Check if an emulator is booted and ready."""
    adb_bin = find_bin("adb")
    result = run([adb_bin, "shell", "getprop", "sys.boot_completed"])
    return result.stdout.strip() == "1"


def wait_for_boot(timeout: int = 120):
    print("⏳  Waiting for emulator to boot...", end="", flush=True)
    start = time.time()
    while time.time() - start < timeout:
        if is_emulator_booted():
            print(" ✅  Booted!")
            return
        print(".", end="", flush=True)
        time.sleep(3)
    print("\n❌  Emulator did not boot within timeout.", file=sys.stderr)
    sys.exit(1)


def launch_emulator(avd_name: str):
    """Launch an AVD emulator in the background."""
    print(f"🚀  Launching emulator: {avd_name}")
    emulator_bin = find_bin("emulator")
    subprocess.Popen(
        [emulator_bin, f"@{avd_name}", "-netdelay", "none", "-netspeed", "full", "-no-snapshot-save"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    wait_for_boot()


def install_apk(apk_path: Path):
    """Install an APK on the running emulator via adb."""
    print(f"📦  Installing {apk_path.name}...")
    adb_bin = find_bin("adb")
    result = run([adb_bin, "install", "-r", str(apk_path)])
    if result.returncode != 0:
        print(f"❌  Install failed:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    print("✅  APK installed!")


def launch_app():
    """Launch SwiftBeam on the emulator."""
    package = "com.example.swiftbeam"
    activity = f"{package}/.MainActivity"
    adb_bin = find_bin("adb")
    result = run([adb_bin, "shell", "am", "start", "-n", activity])
    if result.returncode == 0:
        print("📱  SwiftBeam launched on emulator!")
    else:
        print(f"⚠️  Could not launch app automatically. Open it manually.\n{result.stderr}")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="SwiftBeam Emulator Manager")
    parser.add_argument("--avd", help="AVD name to launch (skips selection prompt)")
    parser.add_argument("--apk", help="APK path to install (defaults to latest in dist/)")
    parser.add_argument("--no-launch", action="store_true", help="Don't auto-launch the app after install")
    args = parser.parse_args()

    # -- Select AVD --
    avd_name = args.avd
    if not avd_name:
        avds = list_avds()
        if not avds:
            print("❌  No AVDs found. Create one with Android Studio or:")
            print("    avdmanager create avd -n SwiftBeam_Pixel8 -k 'system-images;android-36;google_apis;x86_64'")
            sys.exit(1)

        print("\nAvailable AVDs:")
        for i, avd in enumerate(avds):
            print(f"  [{i}] {avd}")
        choice = int(input("\nSelect AVD (number): "))
        avd_name = avds[choice]

    # -- Select APK --
    apk_path: Path
    if args.apk:
        apk_path = Path(args.apk)
    else:
        apks = list_apks()
        if not apks:
            print("❌  No APKs found in dist/. Run: python3 tools/build_apk.py")
            sys.exit(1)
        apk_path = apks[-1]  # Latest
        print(f"📁  Using latest APK: {apk_path.name}")

    # -- Launch emulator --
    launch_emulator(avd_name)

    # -- Install APK --
    install_apk(apk_path)

    # -- Launch app --
    if not args.no_launch:
        launch_app()


if __name__ == "__main__":
    main()
