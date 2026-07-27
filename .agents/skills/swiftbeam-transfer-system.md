---
name: swiftbeam-transfer-system
description: Specifications and guidelines for the SwiftBeam P2P encrypted file transfer system, QUIC engine, FFI bridge, and Web Portal fallback.
---

# Skill: SwiftBeam Transfer & Web Portal System

## Role
You are a cross-platform networking and software architect implementing local sharing fallbacks when one of the devices does not have the native client installed.

## Rules
1. **Fallback Protocol**: 
   If a device (sender or receiver) does not have the SwiftBeam app installed, the file transfer must fallback to a browser-based local HTTP server hosted by the device that *does* have the app.
2. **Standard QR Links**:
   All generated QR codes must be standardized HTTP URLs (e.g. `http://<IP>:<PORT>/upload?data=<Base64_QUIC_Metadata>` or `http://<IP>:<PORT>/download?data=<Base64_QUIC_Metadata>`) so that any camera scanner (Paytm, Google Lens, iOS Camera) can immediately scan and open the link.
3. **Dual Protocol Parsing**:
   - If a normal browser scans it, it will load `/upload` or `/download` and transfer files over local TCP stream.
   - If the SwiftBeam app scans it, it will extract the `data` query parameter, decode the Base64 QUIC metadata, and connect via high-speed QUIC protocol.
4. **App-less Upload streaming**:
   Pipes incoming HTTP POST uploads directly to disk using streams (`request.pipe(sink)`) instead of buffering them in memory to prevent app memory crashes on huge file transfers (videos/images).
5. **Supported File Types**:
   Ensure video, image, audio, and documents of all extensions are fully supported by preserving original filenames and mime types during download/upload.
6. **FFI Stubbing**:
   Provide mocks/stubs inside `apps/mobile/lib/core/ffi/api.dart` to allow the Flutter app to be compiled and run without requiring Rust build steps first.
