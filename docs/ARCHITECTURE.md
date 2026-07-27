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
| 1MB Memory Map    |  | QUIC / quinn       |  | X25519 ECDH        |
| BLAKE3 Checksums  |  | mDNS Peer Radar    |  | ChaCha20-Poly1305  |
| Resume Machine    |  | WebAssembly (Wasm) |  | BLAKE3 Hashing     |
+-----------------------+  +--------------------+  +--------------------+
```

---

## Transport Layers & Fallback Priority

SwiftBeam dynamically selects the optimal transport path:

1. **mDNS Peer Radar** (Ambient auto-discovery, app-to-app, high-speed QUIC)
2. **QR Code Scan → QUIC** (Direct P2P socket across subnets)
3. **QR Code Scan → Web Portal HTTP** (No-app fallback for iOS, Mac, Windows, Android browsers)
4. **Local Wi-Fi AP Hotspot** (Offline direct AP mode)

---

## Security Model

- **Key Exchange**: Ephemeral X25519 ECDH in-band over QUIC socket (never embedded in QR codes).
- **Symmetric Cipher**: ChaCha20-Poly1305 AEAD payload encryption.
- **Chunk Integrity**: 1MB chunks hashed with BLAKE3.

---

## Universal Multi-OS & Multi-Architecture Bundle

SwiftBeam builds a single universal `.tar.gz` bundle (`swiftbeam-1.0.0-universal-multiarch.tar.gz`) containing native binaries for:

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
