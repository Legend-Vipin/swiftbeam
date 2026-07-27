---
description: Build a SwiftBeam feature end-to-end
---

When the user types `/startbuild <feature>`, do the following in order:

1. Read AGENTS.md and all files in .agents/skills/
2. Identify which Rust crates and Dart files are affected
3. Write an implementation plan as an Artifact — WAIT for user approval
4. Implement the Rust side using the rust-transfer skill rules
5. Run `cargo test --workspace` — fix any failures before continuing
6. Implement the Flutter side using the flutter-ui skill rules
7. Run `flutter analyze` in apps/mobile — fix any issues
8. Write a brief summary of all files changed

Do not skip steps. Do not mark complete until all tests pass.