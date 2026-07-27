# SwiftBeam — Agent Rules

## Project

Rust + Flutter monorepo for cross-platform P2P file transfer.

- Rust workspace: `./core/`  (crates: swiftbeam-core, swiftbeam-net, swiftbeam-crypto, swiftbeam-ffi)
- Flutter app: `./apps/mobile/`
- Python tooling: `./tools/` (swiftbeam-tooling — build, emulator, codegen scripts)

## Build Commands

- Rust build:      `cargo build --workspace`
- Rust tests:      `cargo test --workspace`
- Flutter run:     `cd apps/mobile && flutter run`
- FFI codegen:     `cd apps/mobile && flutter_rust_bridge_codegen generate`
- Build APK:       `python3 tools/build_apk.py [--offline]`
- Build All OS:    `python3 tools/build_all.py --target [linux|macos|ios|windows|universal|all]`
- Launch emulator: `python3 tools/emulator.py`

## CI/CD (GitHub Actions)

- `.github/workflows/rust.yml`    — lint, clippy, test, cross-compile
- `.github/workflows/flutter.yml` — analyze, test, build APK + iOS
- `.github/workflows/release.yml` — auto-release + upload APK on version tag
- `.github/workflows/security.yml`— weekly `cargo audit`
- Release tag format: `v<major>.<minor>.<patch>`  (e.g. `git tag v1.0.0 && git push --tags`)

## Conventions

- All async Rust uses Tokio runtime — never `block_on` inside async context
- Error handling: `anyhow` for binaries/FFI, `thiserror` for library crates
- Chunk size constant: `swiftbeam-core/src/chunker.rs` → `CHUNK_SIZE = 1MB`
- Never expose raw pointers in FFI — always `Arc<T>` or `Box<T>`
- All crypto in `swiftbeam-crypto` crate only — no crypto code elsewhere
- Python scripts: Python 3.10+, use `pathlib.Path`, `subprocess.run(check=True)`

## Architecture Rules

- `swiftbeam-core`:   chunking, scheduling, resume logic only
- `swiftbeam-net`:    QUIC transport (quinn), mDNS discovery
- `swiftbeam-crypto`: X25519, ChaCha20-Poly1305, BLAKE3 only
- `swiftbeam-ffi`:    public API surface for flutter_rust_bridge
- **ECDH key exchange is in-band over the QUIC socket — never OOB/QR-embedded**
- QR codes use standard HTTP URLs (`http://<ip>:<port>/upload?data=<base64>`) for scanner compatibility

## Transport Priority (Sender → Receiver)

1. mDNS peer radar (ambient auto-discovery, app-to-app)
2. QR scan → QUIC (app-to-app, cross-network)
3. QR scan → HTTP web portal (no-app fallback, browser-based)

## Skills Available

- `.agents/skills/rust-transfer.md`          — Rust QUIC/chunking implementation rules
- `.agents/skills/flutter-ui.md`             — Flutter UI conventions
- `.agents/skills/swiftbeam-transfer-system.md` — Full protocol & web portal spec
- `.agents/skills/swiftbeam-tooling.md`       — Python tooling layer rules

## Workflows

- `/startbuild <feature>` — end-to-end feature build workflow

## Do Not Touch

- `apps/mobile/lib/core/ffi/`  ← auto-generated, always regenerate via codegen

## Safety

- Always run `cargo test --workspace` after any Rust change
- Always run `flutter analyze` after any Dart change
- Never delete `.cargo/registry`
- Ask before modifying `Cargo.toml` dependencies