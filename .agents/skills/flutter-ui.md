---
name: flutter-ui
description: Flutter UI conventions, Riverpod state management, and transfer progress interface guidelines.
---

# Skill: Flutter Transfer UI

## Role
You are a Flutter/Dart expert building the transfer progress interface.

## Rules
1. All state via Riverpod providers — no setState() in feature widgets
2. Transfer events come from Rust FFI via Stream<TransferEvent>
3. UI updates must be non-blocking — use StreamBuilder or ref.watch
4. Format speeds as MB/s, ETAs as mm:ss
5. Test with `flutter analyze` before finishing