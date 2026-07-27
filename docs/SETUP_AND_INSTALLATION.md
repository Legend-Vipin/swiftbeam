# SwiftBeam Setup, Installation & Platform Compatibility Guide

This master guide provides complete step-by-step instructions for installing, running, and troubleshooting **SwiftBeam** across all supported operating systems, including tarball installation on Linux and macOS, platform specifications, high-speed 1Gbps–10Gbps wired LAN configuration, Wi-Fi 5/6/6E/7 bandwidth optimization, performance benchmarks, and development setup.

---

## 🌐 1. Supported Platforms & System Compatibility

SwiftBeam supports native execution across desktop and mobile operating systems:

| Platform | Supported Architectures | Minimum Version | Target / Compile SDK | Package Formats |
| :--- | :--- | :--- | :--- | :--- |
| **Linux** | `x86_64`, `arm64` (`aarch64`) | Kernel 4.x+, GLIBC 2.27+ | N/A | `.tar.gz`, `.deb`, `.rpm` |
| **macOS** | `x86_64` (Intel), `arm64` (Apple Silicon M1–M4) | macOS 11.0 (Big Sur)+ | macOS 15+ (Sequoia) | `.tar.gz`, `.app`, `.zip` |
| **Android** | `arm64-v8a`, `armeabi-v7a`, `x86_64` | Android 6.0 (API 23) | **API 36** (Android 16+ Baklava) | `.apk` |
| **iOS** | `arm64` | iOS 14.0+ | iOS 18+ | `.ipa` / App Bundle |
| **Windows** | `x86_64` | Windows 10 / 11 (64-bit) | N/A | `.zip` / `.exe` |

---

## 📦 2. Installing & Running `.tar.gz` Universal Bundle (Linux & macOS)

SwiftBeam releases a universal multi-architecture `.tar.gz` archive (`swiftbeam-1.0.0-universal-multiarch.tar.gz`) containing auto-detecting native binaries for Linux (`x86_64`, `arm64`) and macOS (`x86_64`, `arm64`).

### Step-by-Step Installation

#### Step 1: Download & Extract Archive
Open your terminal and extract the downloaded tarball:
```bash
# Extract the archive
tar -xvf swiftbeam-1.0.0-universal-multiarch.tar.gz

# Navigate into the extracted directory
cd swiftbeam-1.0.0-universal-multiarch
```

#### Step 2: Grant Execution Permissions
Ensure the launcher binary script has executable permissions:
```bash
chmod +x bin/swiftbeam
```

#### Step 3: Run SwiftBeam
Execute the auto-detecting launcher script:
```bash
./bin/swiftbeam
```
*The launcher automatically detects your operating system (Linux vs macOS) and processor architecture (Intel `x86_64` vs Apple Silicon `arm64`) and boots the appropriate binary.*

#### Step 4: System Integration (Optional)

##### Linux System Symlink & Desktop Entry:
```bash
# Create system-wide command shortcut
sudo ln -sf "$(pwd)/bin/swiftbeam" /usr/local/bin/swiftbeam

# Launch from anywhere in terminal:
swiftbeam
```

##### macOS Applications Folder Integration:
```bash
# Move SwiftBeam folder to Applications
mv swiftbeam-1.0.0-universal-multiarch /Applications/SwiftBeam

# Create terminal symlink
sudo ln -sf /Applications/SwiftBeam/bin/swiftbeam /usr/local/bin/swiftbeam
```

---

### 🔧 Troubleshooting Tarball Installation & Execution

#### Issue A: `Permission denied` when running `./bin/swiftbeam`
* **Cause**: File permissions were lost during extraction.
* **Fix**: Run `chmod -R +x bin/ platforms/` inside the extracted directory.

#### Issue B: macOS Gatekeeper blocking execution ("SwiftBeam cannot be opened because it is from an unidentified developer")
* **Cause**: macOS Quarantine attributes attached to untarred binaries.
* **Fix**: Remove the quarantine flag via terminal:
  ```bash
  xattr -d com.apple.quarantine bin/swiftbeam
  xattr -dr com.apple.quarantine platforms/
  ```

#### Issue C: Linux missing GTK3 or OpenGL runtime libraries
* **Cause**: Minimal Linux server distributions lacking desktop GUI libraries.
* **Fix**: Install required dependencies for your Linux distribution:
  ```bash
  # Ubuntu / Debian
  sudo apt update && sudo apt install -y libgtk-3-0 libglib2.0-0

  # Fedora
  sudo dnf install -y gtk3 glib2

  # Arch Linux
  sudo pacman -S --needed gtk3 glib2
  ```

---

## 🔌 3. High-Speed Direct LAN Connection Guide (1 Gbps to 10 Gbps System-to-System)

This section details how to connect two computers directly using **1 Gbps, 2.5 Gbps, 5 Gbps, or 10 Gbps Ethernet LAN ports** to achieve maximum wired speed.

### Hardware Requirements

| LAN Speed | Recommended Cable Type | Max Distance | Host Requirements |
| :--- | :--- | :--- | :--- |
| **1 Gbps** | Cat5e or Cat6 | 100 meters | Standard RJ45 Gigabit Port |
| **2.5 Gbps** | Cat6 | 100 meters | 2.5GbE Motherboard / USB-C Adapter |
| **10 Gbps** | **Cat6A**, **Cat7**, or **Cat8** | 100 meters | 10GbE PCIe NIC (Intel X540 / Aquantia AQC107) or Thunderbolt 3/4 10GbE Adapter |

### Step-by-Step Setup Guide

#### Step 1: Direct Physical Connection
Connect one end of the Cat6A/Cat7 Ethernet cable to System 1's LAN port and the other end directly to System 2's LAN port. *(Modern NICs feature Auto-MDIX so crossover cables are not required; standard patch cables work).*

#### Step 2: Assign Static IP Addresses (Direct Link Without Router)
Since there is no DHCP router connected, assign static IP addresses on the high-speed Ethernet adapter:

* **System 1 (Sender)**:
  * IP Address: `192.168.50.1`
  * Subnet Mask: `255.255.255.0`
  * Default Gateway: Leave blank
* **System 2 (Receiver)**:
  * IP Address: `192.168.50.2`
  * Subnet Mask: `255.255.255.0`
  * Default Gateway: Leave blank

#### Step 3: Enable Jumbo Frames (MTU 9000)
To reduce CPU overhead and maximize 10GbE throughput:
* **Windows**: Device Manager $\rightarrow$ Network Adapters $\rightarrow$ Select 10GbE Adapter $\rightarrow$ Properties $\rightarrow$ Advanced $\rightarrow$ **Jumbo Packet** $\rightarrow$ Set to **9014 Bytes** / **9 KB**.
* **Linux**: `sudo ip link set dev eth0 mtu 9000`
* **macOS**: System Settings $\rightarrow$ Network $\rightarrow$ Ethernet $\rightarrow$ Advanced $\rightarrow$ Hardware $\rightarrow$ MTU: Custom $\rightarrow$ **9000**.

#### Step 4: Launch SwiftBeam & Transfer
1. Launch SwiftBeam on both systems.
2. SwiftBeam's mDNS peer radar automatically detects the `192.168.50.x` high-speed interface.
3. Select your file(s) and start transfer — SwiftBeam's QUIC engine will saturate the link!

---

### ⚠️ Precautions & Disk Bottleneck Warnings for 10GbE

1. 🚨 **NVMe SSD Storage Requirement**:
   * **10 Gbps LAN** transfers data at **~1.15 GB/s (1,150 MB/s)**.
   * Traditional Mechanical HDDs top out at ~150–200 MB/s.
   * SATA SSDs top out at ~550 MB/s.
   * **Both systems MUST read/write using NVMe PCIe Gen3/Gen4/Gen5 SSDs** (capable of >2,000 MB/s) to achieve 10 Gbps speeds without disk write throttling.
2. 🛡️ **Firewall Rules**:
   * Ensure UDP port 8888 and SwiftBeam binaries are allowed in Windows Defender Firewall / UFW (`sudo ufw allow 8888/udp`).

---

## 📡 4. Maximizing Peak Wi-Fi Bandwidth (Wi-Fi 5, 6, 6E & 7)

### Wi-Fi Generation Speed Expectations

| Generation | Band | Channel Width | Max Theoretical PHY Rate | SwiftBeam Peak P2P Speed |
| :--- | :--- | :--- | :--- | :--- |
| **Wi-Fi 5 (802.11ac)** | 5 GHz | 80 MHz | 866 Mbps | **40 – 60 MB/s** |
| **Wi-Fi 6 (802.11ax)** | 5 GHz | 80 MHz / 160 MHz | 1200 – 2400 Mbps | **60 – 110 MB/s** |
| **Wi-Fi 6E (802.11ax)** | 6 GHz (Clean) | 160 MHz | 2400 Mbps | **100 – 140 MB/s** |
| **Wi-Fi 7 (802.11be)** | 5 GHz / 6 GHz | 320 MHz | 5760+ Mbps | **200 – 350+ MB/s** |

### Step-by-Step Wi-Fi Speed Optimization

1. **Force 5 GHz or 6 GHz Frequency Bands**: Never use 2.4 GHz for transfers (2.4 GHz maxes out at ~10-15 MB/s and suffers heavy interference). Separate 2.4 GHz and 5 GHz / 6 GHz SSIDs in router settings.
2. **Set Maximum Channel Width in Router Settings**:
   * Set 5 GHz Channel Width to **80 MHz** or **160 MHz**.
   * Set 6 GHz Channel Width to **160 MHz** or **320 MHz** (Wi-Fi 7).
3. **Use Personal Hotspot / Wi-Fi Direct Mode**: Router Wi-Fi operates in half-duplex (Sender $\rightarrow$ Router $\rightarrow$ Receiver cuts speed in half). Turn on **5 GHz Personal Hotspot** on System 1 and connect System 2 directly to it for a full-speed point-to-point wireless link!

---

## ⚡ 5. Overall Peak Transfer Speed Benchmarks

SwiftBeam's Rust network core (`swiftbeam-net`) combines zero-copy memory mapping (`memmap2`), parallel BLAKE3 hashing (`rayon`), and UDP QUIC multiplexing (`quinn`) to fully saturate physical connection hardware limits:

| Connection / Interface | Peak Speed | Bandwidth Utilization |
| :--- | :--- | :--- |
| **Wi-Fi 6 / 6E / Wi-Fi Direct (5 GHz / 6 GHz)** | **60 MB/s – 120+ MB/s** | ~480 Mbps – 1.0 Gbps (Saturates Wi-Fi radio) |
| **1 Gbps LAN Ethernet** | **110 MB/s – 115 MB/s** | ~920 Mbps – 950 Mbps (Gigabit line limit) |
| **2.5 Gbps / Multi-Gig LAN** | **250 MB/s – 280 MB/s** | ~2.0 Gbps – 2.3 Gbps |
| **Local NVMe SSD Loopback Benchmark** | **500 MB/s – 1.2 GB/s** | Disk / PCIe NVMe I/O Bandwidth Bound |

---

## 📋 6. System Requirements & Development Setup

### System Prerequisites
- **Rust Toolchain**: Rust 1.75+ (`rustup`)
- **Flutter SDK**: Flutter 3.19+
- **Java Development Kit (JDK)**: JDK 17+ (Auto-detected by build toolchain)
- **Python**: Python 3.10+
- **flutter_rust_bridge_codegen**: `cargo install flutter_rust_bridge_codegen --version 2.12.0`

### Quick Start Development Commands

```bash
# 1. Build & Test Rust Core
cd core && cargo test --workspace

# 2. Regenerate FFI Bindings
python3 tools/codegen.py

# 3. Build Release Android APK (API 36)
python3 tools/build_apk.py [--offline]

# 4. Build Universal Linux & macOS Tarball
python3 tools/build_all.py --target universal

# 5. Run Standalone Python Web Portal
python3 tools/web_portal.py

# 6. Complete Workspace Cleanup
python3 tools/clean.py

# 7. Run Complete Test Suite (Rust + Flutter)
python3 tools/test_runner.py
```

---

## 🧪 7. Verification Commands

Run full workspace verification prior to publishing releases:
```bash
# Verify Rust core engine & crypto primitives
cd core && cargo test --workspace

# Verify Flutter UI static analysis
cd ../apps/mobile && flutter analyze
```
