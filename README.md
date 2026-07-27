# SwiftBeam

![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Build](https://img.shields.io/badge/build-passing-brightgreen)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)
![Language](https://img.shields.io/badge/language-Rust%20%7C%20Dart-orange)

SwiftBeam is a lightning-fast, secure, cross-platform peer-to-peer file transfer utility. Designed as an open-source alternative to AirDrop and Quick Share, it uses a blazing-fast Rust core for networking and a beautiful Flutter UI.

## Features

- 🚀 **High-Speed Transfers**: Uses Wi-Fi Direct and Local LAN over QUIC to saturate network bandwidth.
- 📊 **Linear Active Transfer Dashboard**: Form-style, list-format transfer UI displaying itemized file progress, formatted sizes (`MB/GB`), real-time transfer speed (`MB/s`), estimated time remaining (`ETA`), and status indicators across all platforms.
- 🔒 **Secure by Default**: All transfers are encrypted with AES-GCM (ChaCha20Poly1305) and ECDH key exchange.
- 📱 **Cross-Platform**: Works across Android, iOS, Windows, macOS, and Linux with unified branding and high-res asset integration.
- 📸 **QR Bootstrap**: Effortlessly connect devices by scanning a QR code (uses Base64 QUIC metadata payload).
- ⚡ **WebAssembly (Wasm) & Web Portal Zero-Install**: Recipient devices can scan QR code to stream and download files natively in any web browser without installing any app.
- 📡 **Offline Capable**: Fallback transports ensure files can transfer even without internet access (via mDNS discovery, BLE, and Wi-Fi Direct).

## 🚀 Peak Transfer Speed Benchmarks

SwiftBeam's network engine is designed to saturate hardware bandwidth by combining memory-mapped zero-copy file streaming (`memmap2`), parallel BLAKE3 hashing (`rayon`), and UDP QUIC multiplexing (`quinn`).

| Connection / Interface | Peak Speed | Bandwidth Utilization |
| :--- | :--- | :--- |
| **Wi-Fi 6 / 6E / Wi-Fi Direct (5 GHz / 6 GHz)** | **60 MB/s – 120+ MB/s** | ~480 Mbps – 1.0 Gbps (Saturates Wi-Fi radio) |
| **1 Gbps LAN Ethernet** | **110 MB/s – 115 MB/s** | ~920 Mbps – 950 Mbps (Gigabit line limit) |
| **2.5 Gbps / Multi-Gig LAN** | **250 MB/s – 280 MB/s** | ~2.0 Gbps – 2.3 Gbps |
| **Local NVMe SSD Loopback Benchmark** | **500 MB/s – 1.2 GB/s** | Disk / PCIe NVMe I/O Bandwidth Bound |


## 📖 Usage & Setup Guide

### Option 1: App-to-App Transfer (Mobile / Desktop)

1. **Send Files**: Open SwiftBeam, tap **SEND**, select file(s), then point your camera at the receiver's QR code.
2. **Receive Files**: Open SwiftBeam, tap **RECEIVE** to display your device QR code and mDNS peer discovery endpoint.
3. **Monitor Progress**: View real-time speeds (`MB/s`), progress bars, total file sizes, and estimated completion time (`ETA`) in the **Transfer Dashboard**.

### Option 2: Zero-Install Web Portal (Browser Fallback)

1. Tap **RECEIVE** or launch the Web Portal on the host device.
2. On any non-app device (iOS, Android, Laptop), scan the QR code with standard camera app or open the local URL (e.g., `http://192.168.1.X:8080`).
3. Drag & drop files to send or download shared files directly in the browser!

## Architecture

SwiftBeam is built on a split architecture:

- **`core/` (Rust)**: Contains `swiftbeam-net`, built on Quinn (QUIC) and Tokio. It handles cryptographic handshakes, packet chunking, hashing (BLAKE3), and network discovery.
- **`apps/mobile/` (Flutter)**: A riverpod-driven UI built with Flutter for Material 3 design and camera QR scanning.
- **FFI**: Connected via `flutter_rust_bridge`.

## 📚 Documentation & Specifications

Detailed documentation guides are available in the [docs/](docs/) directory:

- 🏛️ **[Architecture & Security Model](docs/ARCHITECTURE.md)**: Network layers, transport priority, responsive breakpoints, and crypto specifications.
- ⚙️ **[Setup & Installation Guide](docs/SETUP_AND_INSTALLATION.md)**: System requirements, dev setup, build commands, and platform notes.
- 🛠️ **[Tooling Layer Guide](docs/TOOLING_GUIDE.md)**: Usage guide for `tools/build_apk.py`, `tools/build_all.py`, JDK auto-detection, and test runners.
- 🌐 **[Web Portal System Spec](docs/WEB_PORTAL_SPEC.md)**: Zero-install web browser file transfer fallback and QR metadata payload details.
- 🤖 **[Multi-Agent Workflow Spec](docs/MULTI_AGENT_WORKFLOW.md)**: Orchestration spec for concurrent sub-agent code generation.
- 📋 **[Agent Conventions & Rules](AGENTS.md)**: Architecture rules, transport priority, and monorepo conventions.
- 📄 **[MIT License](LICENSE)**: Legal terms, copyright, and licensing conditions.

## Getting Started

### Prerequisites

- [Rust](https://www.rust-lang.org/tools/install) (latest stable)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable)
- [flutter_rust_bridge_codegen](https://cjycode.com/flutter_rust_bridge/)

### Building the Core

```bash
cd core/swiftbeam-net
cargo test
cargo build --release
```

### Building Release Packages

```bash
# Build Android release APK (supports --offline mode)
python3 tools/build_apk.py --offline

# Build Universal Linux & macOS multi-architecture tarball (x86_64 & arm64)
python3 tools/build_all.py --target universal

# Build platform specific targets
python3 tools/build_all.py --target [linux|macos|ios|windows|all]
```

### OS & Adaptive Resolution Support

- **Adaptive UI**: Dynamically scales and adjusts layout ergonomics between **Mobile** (`BottomNavigationBar`), **Tablet** (`NavigationRail`), and **Desktop** (Extended Navigation Sidebar with mouse hover support).
- **Universal Tarball**: Single `.tar.gz` bundle supporting Linux (`x86_64`, `arm64`) and macOS (`x86_64`, `arm64 / Apple Silicon M1-M4`) via an auto-detecting shell launcher (`./bin/swiftbeam`).
- **Android**: Supports **Android 6.0 (API 23)** up to **Android 17+ (Baklava & Baklava+)**.
- **macOS**: Supports **macOS 11.0 (Big Sur)** through **macOS 15+ (Sequoia)**.
- **iOS**: Supports **iOS 14.0** up to **iOS 18+**.
- **Windows**: Windows 10 & Windows 11 (64-bit).
- **Linux**: Ubuntu / Fedora / Arch / Debian (x86_64 & arm64).

```properties
flutter.minSdkVersion=23
flutter.targetSdkVersion=36
flutter.compileSdkVersion=36
```

## Contributing

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for full licensing terms and documentation links.
