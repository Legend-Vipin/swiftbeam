# SwiftBeam Architecture & Protocol Specification

## System Overview

SwiftBeam is a cross-platform, zero-internet P2P encrypted file transfer application written in **Rust** (`core/`) and **Flutter/Dart** (`apps/mobile/`).

```text
+-------------------------------------------------------------+
|                      Flutter Mobile App                     |
|            (Material 3, Riverpod State, UI Views)           |
+-------------------------------------------------------------+
                              |
               flutter_rust_bridge (v2.12.0)
                              |
+-------------------------------------------------------------+
|                      swiftbeam-ffi                          |
|             (Thread-safe C FFI Binding Surface)             |
+-------------------+--------------------+--------------------+
                    |                    |
+-----------------------+  +--------------------+  +--------------------+
|   swiftbeam-core      |  |   swiftbeam-net    |  | swiftbeam-crypto   |
| 1MB Memory Map        |  | QUIC / quinn       |  | X25519 ECDH        |
| BLAKE3 Checksums      |  | mDNS Peer Radar    |  | ChaCha20-Poly1305  |
| Resume Machine        |  | WebAssembly (Wasm) |  | BLAKE3 Hashing     |
+-----------------------+  +--------------------+  +--------------------+
```

---

## Transport Layers & Fallback Priority

SwiftBeam dynamically negotiates transport protocols between Sender and Receiver based on network and hardware availability:

| Sender Bluetooth | Receiver Bluetooth | Connection & Discovery Mode | Data Transfer Transport |
| :--- | :--- | :--- | :--- |
| **Available** | **Available** | **Bluetooth + Wi-Fi Dual Mode** | BLE Proximity + High-Speed QUIC over Wi-Fi Direct / Local Wi-Fi |
| **Unavailable** | **Available** | **Only Wi-Fi Mode** | Local mDNS / Wi-Fi Direct QUIC Stream |
| **Available** | **Unavailable** | **Only Wi-Fi Mode** | Local mDNS / Wi-Fi Direct QUIC Stream |
| **Unavailable** | **Unavailable** | **Only Wi-Fi Mode** | Local mDNS / Wi-Fi Direct QUIC Stream |

### Transport Hierarchy:
1. **mDNS Peer Radar**: Ambient auto-discovery for nearby app-to-app peers over local Wi-Fi.
2. **Bluetooth LE + QUIC (Dual Mode)**: BLE proximity pairing when enabled on both Sender & Receiver + high-speed QUIC transport over Wi-Fi Direct.
3. **QR Code Scan → QUIC**: QR metadata scanning containing Base64 parameters for cross-subnet app-to-app connection.
4. **QR Code Scan → Web Portal HTTP**: Browser fallback for devices without the native client installed.

---

## Security Model

- **Key Exchange**: Ephemeral X25519 ECDH in-band over QUIC socket (never embedded in QR codes).
- **Symmetric Cipher**: ChaCha20-Poly1305 AEAD payload encryption.
- **Chunk Integrity**: 1MB chunks hashed with BLAKE3.

---

## Transfer History & Persistence System

- **Automatic Persistence**: Completed and failed transfers are saved automatically to device storage via `SharedPreferences` (`swiftbeam_transfer_history_v1`).
- **Real-Time Search & Filter**: Filter transfer history by filename/peer name and category chips (`All`, `Sent`, `Received`, `Success`, `Failed`).
- **Record Details Modal**: Glassmorphic sheet displaying transfer ID, size, direction, peer name, status, and precise timestamp.

---

## Universal Multi-OS & Multi-Architecture Bundle

SwiftBeam builds a single universal `.tar.gz` bundle (`swiftbeam-1.0.1-universal-multiarch.tar.gz`) containing native binaries for:

- **Linux**: `x86_64` (Intel/AMD) and `arm64` / `aarch64`
- **macOS**: `x86_64` (Intel) and `arm64` (Apple Silicon M1-M4)
- **POSIX Launcher**: `./bin/swiftbeam` auto-detects host OS and CPU architecture at runtime.

---

## UI/UX Design System & Adaptive Layout Architecture

- **Theme Tokens**: Dark Slate canvas (`#0F172A`), Glassmorphic Surface Cards (`#161B22`), Electric Cyan primary (`#00D9FF`), Indigo (`#6D5DF6`), and Purple (`#9B5CFF`).
- **Adaptive Layout Breakpoints**:
  - **Mobile (`< 600px`)**: Single column vertical card layout with frosted `BottomNavigationBar`.
  - **Tablet (`600px - 1024px`)**: Dual-pane layout with compact `NavigationRail`.
  - **Desktop (`>= 1024px`)**: Resizable multi-pane layout with extended `NavigationRail` sidebar and mouse hover support.
- **Customizable Device Name**: Dynamic local device state managed via `deviceSettingsProvider` in `apps/mobile/lib/providers/settings_provider.dart`.
