# AGENTS.md

Global instructions for coding agents working in this repository.

## Mission

- Maintain Arch Linux PKGBUILDs in `packages/`.
- Keep changes minimal, auditable, and package-focused.
- Prefer correctness and reproducibility over broad refactors.

## Repository Layout

- `packages/<name>/PKGBUILD` — package definitions.
- `packages/<name>/requirements.toml` — default Grok requirements config used by packages.
- `.github/workflows/makepkg.yml` — CI build matrix and package build/install checks.
- `.github/workflows/update-versions.yml` — upstream version monitoring for Grok packages.

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
