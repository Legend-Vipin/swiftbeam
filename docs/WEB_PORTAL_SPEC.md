# Web Portal & WebAssembly (Wasm) Zero-Install Specification

## Purpose

The Web Portal provides zero-install, zero-app file transfer capability powered by **WebAssembly (Wasm)** and pure HTTP streaming. Devices without the SwiftBeam app installed (e.g. iOS Camera app, Safari, Chrome, Edge, Firefox on any laptop or phone) scan a QR code or visit `http://<IP>:<PORT>` to send or receive files over local networks or remote links.

---

## ⚡ WebAssembly (Wasm) & Native HTTP Engine Features

When a browser opens the SwiftBeam Web Portal URL:

1. **Wasm In-Browser Crypto**: Rust cryptography primitives (`swiftbeam-crypto`) compiled to WebAssembly run natively inside the receiver's web browser sandbox.
2. **Client-Side Decryption & Verification**:
   - **X25519 ECDH**: In-browser key agreement.
   - **ChaCha20-Poly1305 / AES-256**: High-speed stream decryption inside WebAssembly memory buffers.
   - **BLAKE3 Checksums**: Hardware-accelerated chunk hashing directly in Wasm threads.
3. **Multi-File Batch Transfer**:
   - Stream multiple files concurrently with itemized progress tracking.
   - Live transfer dashboard calculating real-time speed (`MB/s`), total transferred size (`MB/GB`), completed file counts, and remaining time (`ETA`).
4. **Drag & Drop & Manual Link Copying**:
   - Intuitive drag-and-drop target zone.
   - One-click copy for manual URLs (`http://<IP>:<PORT>`) for devices without camera QR scanners.
5. **Zero Installation Required**: Works on iOS Safari, Android Chrome, Windows, macOS, and Linux without downloading or installing any native app.

---

## QR Code Format

Generated QR codes embed standard HTTP URLs with Base64-encoded QUIC & Wasm metadata:

```text
http://<IP>:<PORT>/download?data=<BASE64_METADATA>
```

### Decoded JSON Metadata

```json
{
  "device_id": "Host-Laptop",
  "session": "RECEIVER_1721667400",
  "ip": "10.198.153.140",
  "port": 8888,
  "token": "a8f9c2d7e1b34a",
  "pub_key": "x25519_base64_key",
  "version": "1.0",
  "wasm_enabled": true
}
```

---

## Dual-Protocol Execution

- **Browser Scan**: Opens web browser -> Downloads & executes WebAssembly module -> Decrypts stream -> Triggers browser file download.
- **SwiftBeam App Scan**: Extracts `data` query parameter -> Connects directly over native QUIC socket for maximum throughput.

---

## Web App Features & Standalone Tooling

- **⚡ Simultaneous Bidirectional Transfer**: Web browsers can upload files to the host device while downloading shared files simultaneously from the same web portal page.
- **📤 Send Mode**: Drag & drop or browse multiple files to stream directly into the host device's storage (`_outputDir`).
- **📥 Receive Mode**: Itemized multi-file download portal with live 3-second auto-polling (`/meta`), "Download All", and individual file stream links.
- **📡 Pairing Dashboard**: Live network IP, Wi-Fi Direct (P2P), and Bluetooth proximity status with automatic Wi-Fi fallback.
- **🛠️ Standalone Python Web Portal**: Run `python3 tools/web_portal.py` for headless or desktop browser testing without launching the full Flutter UI.

