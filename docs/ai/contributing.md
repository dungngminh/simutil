# Contributing workflow

Companion doc to [AGENTS.md](../../AGENTS.md). Covers what to do alongside the
code change itself.

## Per-PR checklist

1. **Update the changelog.** Add mainly user-visible changes under `[Unreleased]` in
   [CHANGELOG.md](../../CHANGELOG.md) using the existing
   [Keep-a-Changelog](https://keepachangelog.com/en/1.1.0/) sections
   (`Added` / `Changed` / `Fixed` / `Removed`). One bullet per user-visible change.
2. **Run the same checks CI runs** (see [docs/ai/running_tests.md](running_tests.md)
   and [.github/workflows/ci.yaml](../../.github/workflows/ci.yaml)):

   ```bash
   dart analyze --fatal-infos
   dart test
   ```

3. **Fill in the PR template** at
   [.github/PULL_REQUEST_TEMPLATE.md](../../.github/PULL_REQUEST_TEMPLATE.md):
   write a Description and tick the relevant Type-of-Change checkboxes.
4. **Touch generated code only via its generator.** If you bumped the version in
   [pubspec.yaml](../../pubspec.yaml), regenerate
   [lib/utils/version.dart](../../lib/utils/version.dart) with
   `dart run build_runner build`. Never edit it by hand.

## Branching & commits

- Branch from `main`. Both `push` and `pull_request` to `main` trigger CI.
- No enforced commit-message format, but match the existing [CHANGELOG.md](../../CHANGELOG.md)
  voice (imperative, one line per change) so it is easy to copy across.

## Release pipeline (maintainer-only, FYI)

Tag-driven: pushing `vX.Y.Z` builds four-target binaries, drafts a GitHub
Release, and publishes to pub.dev. Publishing the draft fans out to the Homebrew
tap; WinGet is manual. **Full pipeline, secrets, and the cut-a-release
checklist live in [docs/ai/deployment.md](deployment.md).**

When preparing a release, move the `[Unreleased]` block in
[CHANGELOG.md](../../CHANGELOG.md) under a new `[x.y.z] - YYYY-MM-DD` heading and
bump `version:` in [pubspec.yaml](../../pubspec.yaml) to match — then follow
[docs/ai/deployment.md § Cutting a release](deployment.md#cutting-a-release-maintainer-checklist).
