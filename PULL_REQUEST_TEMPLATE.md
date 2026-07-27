# Pull Request Template

## Description

<!-- Describe your changes clearly. What problem does this solve? -->

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Refactor / cleanup
- [ ] Documentation
- [ ] CI/CD

## Testing

- [ ] `cargo test --workspace` passes
- [ ] `flutter analyze` passes
- [ ] Manually tested on device

## Checklist

- [ ] All crypto changes are confined to `swiftbeam-crypto` crate only
- [ ] No raw pointers in FFI (`Arc<T>` or `Box<T>` only)
- [ ] AGENTS.md updated if conventions changed
- [ ] `.agents/skills/` updated if new patterns introduced
