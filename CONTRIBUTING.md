# Contributing to Echo

First — thank you. Echo is a Google Solution Challenge 2026 project addressing **Rapid Crisis Response**, and contributions from people who have lived through (or worked through) disasters are especially valuable.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## Ways to contribute

- **Report a bug** — Open an issue using the *Bug report* template. Include device model, Android version, repro steps, and `flutter doctor -v` output.
- **Suggest a feature** — Open an issue with the *Feature request* template. Anchor it to a real-world crisis-response scenario where possible.
- **Improve docs** — Typos, clarifications, translations of the README. PRs welcome with no issue required.
- **Submit code** — Pick an open issue (look for `good first issue` / `help wanted`) or one of the planned roadmap items in the README.
- **Report a vulnerability** — **Do not open a public issue.** Follow [SECURITY.md](SECURITY.md).

## Development setup

See the [Getting Started](README.md#getting-started) section of the main README. You will need:

- Flutter ≥ 3.8
- Android Studio + Android SDK ≥ API 31
- **Two physical Android devices** to test the mesh end-to-end

```bash
flutter pub get
flutter analyze            # static analysis (must pass)
flutter test               # unit tests (must pass)
flutter run --dart-define-from-file=dart-defines.json
```

## Pull-request checklist

Before opening a PR:

- [ ] `flutter analyze` is clean (zero warnings).
- [ ] `flutter test` passes locally.
- [ ] You have manually exercised the change on at least one physical device. For mesh changes, **two** devices.
- [ ] The PR description explains the *why*, not just the *what*.
- [ ] You have linked the issue it closes (`Closes #123`).
- [ ] You have not bumped the app `version:` in `pubspec.yaml` (maintainers do that at release time).
- [ ] You have not committed `dart-defines.json` (only `dart-defines.example.json`).

## Coding conventions

- **Dart formatting** — `dart format .` before committing.
- **Effective Dart** — follow the [official style guide](https://dart.dev/effective-dart/style).
- **Priority tags** — When you fix or extend a tagged item (`P1-3`, `P2-7`, …), keep the tag in the comment so the roadmap stays traceable.
- **No `print()`** in production code paths — use a proper logger or guard with `kDebugMode`.
- **Constants in `lib/core/constants.dart`** — never hard-code timing, hop counts, UUIDs, or thresholds elsewhere.
- **Wire-format changes** — bump the version (currently `v3`) and keep the previous decoder for backward compatibility. Mesh nodes in the field will not all upgrade at the same time.

## Commit messages

We loosely follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(mesh): add RSSI-weighted relay tie-breaker
fix(crypto): handle empty senderPublicKey on legacy v2 packets
docs(readme): clarify rescuer onboarding flow
```

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
