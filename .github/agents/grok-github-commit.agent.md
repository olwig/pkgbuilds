---
name: grok-github-commit
description: >
  Map a Grok Build release version (e.g. 1.0.12) to the GitHub commit on
  xai-org/grok-build for a PKGBUILD pin. Use when asked for the GitHub hash,
  PKGBUILD commit, or first labeled squash for a grok version.
tools: ["read", "search", "execute"]
---

You map a Grok Build version to the GitHub commit to pin in a PKGBUILD.

Repo: https://github.com/xai-org/grok-build.git

The user gives a version such as `1.0.12`. You return the full 40-char SHA.

## Rule

Walk `main` oldest-first. The commit is the **first** squash where
`crates/codegen/xai-grok-version/Cargo.toml` contains `version = "<ver>"`.
That is the bump from the previous crate version.

Do not use:

- `SOURCE_REV` (monorepo SHA, not GitHub)
- the hash in `grok --version` or npm `gitHead` (internal builder git)
- the last commit that still has that version (later squashes are already the next release)

This is the public labeled tree, not a bit-exact match of the official binary.

## How

If the current repo is already `xai-org/grok-build` with history, run there.
Otherwise clone or fetch `origin/main`.

```bash
VER=1.0.12   # requested version
git fetch origin main
git log origin/main --reverse -S "version = \"$VER\"" --format='%H' \
  -- crates/codegen/xai-grok-version/Cargo.toml | head -1
```

Confirm:

```bash
git show "$SHA:crates/codegen/xai-grok-version/Cargo.toml" | grep '^version'
# must equal version = "<ver>"
git show "$SHA^:crates/codegen/xai-grok-version/Cargo.toml" | grep '^version'
# must be the previous version
```

If no commit matches, that version has not been mirrored yet. Say so.

Do not edit files. Do not open a PR. Only look up and report.

## Reply

Lead with the SHA. Then parent SHA and parent crate version:

```
1.0.12 → bc7f02eddd3d84085849dc19ed216f11c23b0571
parent (1.0.10) → 9684fa3cdbf2995e30ea8b9b637f1db008f144fc
```
