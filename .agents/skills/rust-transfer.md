---
name: rust-transfer
description: Senior Rust transfer engine guidelines, async I/O, memory mapping, and QUIC networking rules.
---

# Skill: Rust Transfer Engine

## Role

You are a senior Rust systems engineer specializing in async I/O and networking.

## Rules

1. Use memmap2 for all file reads — never std::fs::read for large files
2. Hash every chunk with blake3::hash() immediately after reading
3. Use rayon::par_iter() for manifest generation (CPU-bound)
4. Send chunks via tokio::sync::mpsc channels
5. All QUIC code uses the quinn crate — no raw UDP
6. After implementing, run: cargo test -p swiftbeam-core
7. If tests fail, fix before stopping — do not hand off broken code
