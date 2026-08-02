#!/usr/bin/env python3
"""
SwiftBeam APK Build Helper (swiftbeam-tooling)
Builds the Android release APK and places it in dist/.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.resolve()
MOBILE = ROOT / "apps" / "mobile"
ANDROID = MOBILE / "android"
LOCAL_PROPS = ANDROID / "local.properties"
DIST = ROOT / "dist"


def configure_jdk_environment():
    """Ensure JAVA_HOME points to a valid JDK installation containing javac compiler."""
    current = os.environ.get("JAVA_HOME")
    if current and (Path(current) / "bin" / "javac").exists():
        print(f"☕  Using JAVA_HOME: {current}")
        return

    candidates = [
        Path("/snap/android-studio/current/jbr"),
        Path("/usr/lib/jvm/java-21-openjdk-amd64"),
        Path("/usr/lib/jvm/java-17-openjdk-amd64"),
        Path("/usr/lib/jvm/default-java"),
    ]

    snap_as = Path("/snap/android-studio")
    if snap_as.exists():
        candidates.extend(snap_as.glob("*/jbr"))

    for c in candidates:
        if (c / "bin" / "javac").exists():
            os.environ["JAVA_HOME"] = str(c)
            print(f"☕  Auto-detected JDK JAVA_HOME: {c}")
            return

    print("⚠️  Warning: No JDK with 'javac' compiler found. Build may require JDK installation.")


def clear_gradle_locks():
    """Clear stale Gradle lock files to prevent build logic queue timeouts."""
    gradle_dir = ANDROID / ".gradle"
    if gradle_dir.exists():
        try:
            # Kill any orphaned gradle processes if running
            subprocess.run(["pkill", "-f", "gradle"], capture_output=True)
        except Exception:
            pass
        for lock_file in gradle_dir.rglob("*.lock"):
            try:
                lock_file.unlink(missing_ok=True)
            except Exception:
                pass


def set_sdk_versions():
    """Write/update flutter SDK version overrides in local.properties."""
    ANDROID.mkdir(parents=True, exist_ok=True)
    existing = LOCAL_PROPS.read_text() if LOCAL_PROPS.exists() else ""

    lines = [l for l in existing.splitlines()
             if not l.startswith("flutter.minSdkVersion")
             and not l.startswith("flutter.targetSdkVersion")
             and not l.startswith("flutter.compileSdkVersion")]

    lines += [
        "flutter.minSdkVersion=23",
        "flutter.targetSdkVersion=36",
        "flutter.compileSdkVersion=36",
    ]

    LOCAL_PROPS.write_text("\n".join(lines) + "\n")
    print("✅  local.properties updated (minSdk=23, targetSdk=36, compileSdk=36)")



def get_version() -> str:
    pubspec = (MOBILE / "pubspec.yaml").read_text()
    for line in pubspec.splitlines():
        if line.startswith("version:"):
            return line.split(":")[1].strip().split("+")[0]
    return "dev"


def run_tests():
    print("🔬  Running Rust tests...")
    subprocess.run(
        ["cargo", "test", "--workspace"],
        cwd=ROOT / "core",
        check=True,
    )
    print("✅  Rust tests passed")


def build_apk(offline: bool = False):
    print("🔨  Building release APK...")
    clear_gradle_locks()
    
    pub_cmd = ["flutter", "pub", "get"]
    if offline:
        pub_cmd.append("--offline")

    subprocess.run(
        pub_cmd,
        cwd=MOBILE,
        check=True,
    )

    cmd = ["flutter", "build", "apk", "--release"]
    subprocess.run(
        cmd,
        cwd=MOBILE,
        check=True,
    )


def verify_apk_native_libraries(apk_path: Path):
    """Verify that libswiftbeam_ffi.so is embedded inside the compiled APK."""
    import zipfile
    print(f"🔍  Verifying native libraries in {apk_path.name}...")
    with zipfile.ZipFile(apk_path) as z:
        so_files = [f for f in z.namelist() if f.endswith("libswiftbeam_ffi.so")]
        if not so_files:
            print(f"❌  Error: libswiftbeam_ffi.so missing from APK {apk_path}", file=sys.stderr)
            sys.exit(1)
        for f in sorted(so_files):
            print(f"   ✓ Found native library: {f}")
    print("✅  APK verification successful! All native libraries correctly packaged.")


def collect_apk(version: str) -> Path:
    src = MOBILE / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not src.exists():
        print("❌  APK not found. Build may have failed.", file=sys.stderr)
        sys.exit(1)

    DIST.mkdir(exist_ok=True)
    dest = DIST / f"swiftbeam-{version}-release.apk"
    dest.write_bytes(src.read_bytes())
    print(f"📦  APK saved to {dest}")
    verify_apk_native_libraries(dest)
    return dest


def run_codegen():
    print("🛠️  Running FFI Codegen...")
    subprocess.run(
        [sys.executable, str(ROOT / "tools" / "codegen.py")],
        check=True,
    )
    print("✅  FFI Codegen complete.")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="SwiftBeam APK Builder")
    parser.add_argument("--skip-tests", action="store_true", help="Skip Rust test run")
    parser.add_argument("--skip-codegen", action="store_true", help="Skip flutter_rust_bridge codegen")
    parser.add_argument("--offline", action="store_true", help="Build offline using cached dependencies")
    args = parser.parse_args()

    version = get_version()
    print(f"🚀  Building SwiftBeam {version} APK\n")

    configure_jdk_environment()
    set_sdk_versions()

    if not args.skip_codegen:
        run_codegen()

    if not args.skip_tests:
        run_tests()

    build_apk(offline=args.offline)
    apk = collect_apk(version)

    print(f"\n✅  Done! Install on device:\n    adb install -r {apk}")


if __name__ == "__main__":
    main()
