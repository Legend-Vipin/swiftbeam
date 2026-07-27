# Multi-Agent Workflow & Collaboration Guide

## Overview

SwiftBeam utilizes specialized AI subagent roles and skills to divide responsibilities cleanly across Rust systems engineering, Flutter UI development, Python tooling, and security auditing.

```text
                  +--------------------------+
                  |  Lead Architect Agent    |
                  +------------+-------------+
                               |
       +-----------------------+-----------------------+
       |                       |                       |
+------v-------+       +-------v------+       +--------v-------+
|  Rust Agent  |       | Flutter Agent|       | Tooling Agent  |
|  (Core/Net)  |       |  (UI/State)  |       | (Python Tools) |
+--------------+       +--------------+       +----------------+
```

---

## Agent Skill Registry

| Skill Name | Frontmatter ID | Primary Scope |
| :--- | :--- | :--- |
| **Flutter UI** | `flutter-ui` | Riverpod providers, Material 3 glassmorphic design, 60fps streams. |
| **Rust Transfer** | `rust-transfer` | Tokio async I/O, `memmap2`, `quinn` QUIC sockets, BLAKE3 integrity. |
| **Transfer Protocol** | `swiftbeam-transfer-system` | Dual-protocol QR parsing, Web Portal HTTP fallback. |
| **Python Tooling** | `swiftbeam-tooling` | `tools/*.py` scripts for build, codegen, test runner, and emulators. |

---

## Guidelines for Multi-Agent Execution

1. **Isolated Subagent Tasks**: Delegate independent research, static analysis, or test runs to background subagents.
2. **Synchronized FFI Signature Updates**: When changing Rust API in `core/swiftbeam-ffi`, run `python3 tools/codegen.py` to keep Dart bindings in sync before starting Flutter UI edits.
3. **Continuous Verification**: Always run `python3 tools/test_runner.py` after multi-agent changes.
