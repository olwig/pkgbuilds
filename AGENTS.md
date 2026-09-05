# AGENTS.md

Global instructions for coding agents working in this repository.

## Mission

- Maintain this monorepo of selected Arch Linux PKGBUILDs in `packages/`.
- Keep changes minimal, auditable, and package-focused.
- Prefer correctness and reproducibility over broad refactors.
- Track upstream versions, update PKGBUILDs/checksums when needed, and verify builds before sync.
- Sync updated packages to external services (AUR and others) when required.
- `aur-sync-light.yml` is the light sync path and currently syncs a hardcoded package list.
- A non-light sync flow is planned around `repo.yml`, with a bash mapping library to resolve package sync settings.

## Repository Layout

- `packages/<name>/PKGBUILD` — package definitions.
- `.github/workflows/makepkg.yml` — CI workflow that builds/tests package directories in a matrix, including install checks.
- `.github/workflows/update-versions.yml` — workflow that checks upstream Grok releases and updates PKGBUILDs/checksums when newer versions are available.
- `.github/workflows/aur-sync-light.yml` — workflow for syncing a hardcoded package set from this monorepo to AUR.

## Working Rules

1. Make a short plan first and share it in the PR progress checklist.
2. Keep edits surgical; avoid unrelated cleanup.
3. Do not change package behavior unless requested.
4. Preserve Arch conventions (`pkgver`, `pkgrel`, `source`, checksums, `arch`, `license`).
5. If changing a PKGBUILD source URL or artifact, update checksums in the same change.
6. If upstream version changes:
   - bump `pkgver`,
   - reset/increment `pkgrel` as appropriate,
   - refresh checksums and any pinned commit/hash.
7. Keep root license/workflow changes separate from package logic changes when possible.

## PKGBUILD Change Checklist

- Verify the package still builds with `makepkg` flow used by this repo.
- Ensure `provides`/`conflicts` remain correct for `grok`-providing packages.
- Keep installed paths stable unless the issue explicitly requires path changes.
- For `-git` packages, preserve dynamic `pkgver()` behavior.
- For pinned source commits, document or keep version mapping comments accurate.

## Validation

- Prefer targeted validation for touched package(s).
- Useful commands (run from repo root):
  - `makepkg -si --noconfirm` inside the changed package directory.
  - `shellcheck --shell=bash --exclude=SC2034,SC2154,SC2164 PKGBUILD` for PKGBUILD shell linting.
- If only docs/instruction files change, skip build/test runs.

## Agent File Policy

- This file is the single source of truth for agent guidance.
- Provider-specific files must stay thin and point here:
  - `CLAUDE.md`
  - `GEMINI.md`
- If another tool later requires its own instruction filename, add a one-line shim that references `@AGENTS.md`.
