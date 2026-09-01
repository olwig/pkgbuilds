---
description: 'Best-effort GitHub SHA on xai-org/grok-build for a Grok Build version string (e.g. 1.0.13), for PKGBUILD pins. The public repo is monorepo snapshots; xAI publishes no tags. Use the first squash that sets xai-grok-version to that version. Triggers: "github commit for grok 1.0.13", PKGBUILD hash, first labeled commit, /grok-build-commit. Not an official channel→commit map and not the prebuilt binary. For the published binary version, use /grok-build-version.'
metadata:
    github-path: skills/grok-build/grok-build-commit
    github-ref: refs/heads/main
    github-repo: https://github.com/olwig/skills
    github-tree-sha: f86ff156146e369eada633cc9ace638855052e20
name: grok-build-commit
---
# Grok Build commit

Map a **version number** to a GitHub commit on the public snapshot repo. This is not the prebuilt binary and not an official xAI pin.

If the user names a channel (stable / alpha / enterprise) or does not give a version, get the number from `grok-build-version`, then continue here. Do not fetch channel pointers in this skill. Do not run `grok --version`.

## What the SHA is

Repo: https://github.com/xai-org/grok-build.git

Periodic squashes of an internal monorepo (commit message `Synced from monorepo`). No GitHub tags or releases. `SOURCE_REV` is the internal monorepo SHA, not this GitHub SHA.

The pin is the **first** commit (oldest on `main`) where

`crates/codegen/xai-grok-version/Cargo.toml`

has `version = "<ver>"`. That crate is the lockstepped CLI version. Later syncs keep the same string until the next bump — do not use HEAD just because it still shows the version.

GitHub has no channels. Alpha often is not mirrored yet; if the pickaxe finds nothing, say so.

## Fetch the repo

Need full history of that file — no `--depth`. If the current repo is already `xai-org/grok-build` with full history, use it. Otherwise clone to a temp dir (do not clone into the user’s project):

```bash
git clone --single-branch https://github.com/xai-org/grok-build.git
```

## Pick the commit

```bash
VER=1.0.13   # the version number
git fetch origin main
git log origin/main --reverse -S "version = \"$VER\"" --format='%H' \
  -- crates/codegen/xai-grok-version/Cargo.toml | head -1
```

Confirm:

```bash
git show "$SHA:crates/codegen/xai-grok-version/Cargo.toml" | grep '^version'
# must print: version = "1.0.13"
git show "$SHA^:crates/codegen/xai-grok-version/Cargo.toml" | grep '^version'
# must be the previous version
```

If no commit matches, that version has not been mirrored yet. Do not substitute HEAD or a tag.

Do not use as the GitHub SHA:

- `SOURCE_REV`
- the hash in `grok --version` / npm `gitHead`
- GitHub tags or releases

## Output

```
Version: 1.0.13
Commit: bb7f39d5858cbf5e00de639367f59debbdcb0138
Parent: bc7f02eddd3d84085849dc19ed216f11c23b0571 (1.0.12)
Repo: https://github.com/xai-org/grok-build
Note: snapshot heuristic; not an official xAI pin
```
