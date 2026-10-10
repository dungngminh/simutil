# Contributing workflow

Companion doc to [AGENTS.md](../../AGENTS.md). Covers what to do alongside the
code change itself.

## Per-PR checklist

1. **Update the changelog.** First check whether the newest version heading is
   released: it has a git tag (`git tag -l 'v*'`, or `simutil_<pkg>-v*` for a
   library) or its version is on pub.dev. Not released: add the change under that
   version. Released: the app ([CHANGELOG.md](../../packages/simutil/CHANGELOG.md))
   uses `[Unreleased]`; a library bumps its `pubspec.yaml` version (patch for
   fixes, minor for new API) and adds a new `## X.Y.Z` heading. Use the existing
   [Keep-a-Changelog](https://keepachangelog.com/en/1.1.0/) sections
   (`Added` / `Changed` / `Fixed` / `Removed`). One bullet per user-visible change.
2. **Run the same checks CI runs** (see [.github/workflows/ci.yaml](../../.github/workflows/ci.yaml)):

   ```bash
   dart pub get
   dart run melos run check
   ```

   Or individually: `dart run melos run analyze`, `dart run melos run test`.

3. **Fill in the PR template** at
   [.github/PULL_REQUEST_TEMPLATE.md](../../.github/PULL_REQUEST_TEMPLATE.md):
   write a Description and tick the relevant Type-of-Change checkboxes.
4. **Touch generated code only via its generator.** If you bumped the version in
   [packages/simutil/pubspec.yaml](../../packages/simutil/pubspec.yaml) or edited [CHANGELOG.md](../../packages/simutil/CHANGELOG.md),
   regenerate `packages/simutil/lib/src/version.dart` /
   `packages/simutil_shared/lib/src/changelog_entries.dart` with
   `dart run melos run codegen`. Never edit them by hand.

## Branching & commits

- Branch from `main`. Both `push` and `pull_request` to `main` trigger CI.
- No enforced commit-message format, but match the existing [CHANGELOG.md](../../packages/simutil/CHANGELOG.md)
  voice (imperative, one line per change) so it is easy to copy across.

## Release pipeline (maintainer-only, FYI)

Tag-driven: pushing `vX.Y.Z` builds four-target binaries, drafts a GitHub
Release, and publishes to pub.dev. Publishing the draft fans out to the Homebrew
tap; WinGet is manual. **Full pipeline, secrets, and the cut-a-release
checklist live in [docs/ai/deployment.md](deployment.md).**

When preparing a release, move the `[Unreleased]` block in
[CHANGELOG.md](../../packages/simutil/CHANGELOG.md) under a new `[x.y.z] - YYYY-MM-DD` heading and
bump `version:` in [packages/simutil/pubspec.yaml](../../packages/simutil/pubspec.yaml) to match — then follow
[docs/ai/deployment.md § Cutting a release](deployment.md#cutting-a-release-maintainer-checklist).
