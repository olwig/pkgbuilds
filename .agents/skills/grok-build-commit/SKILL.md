---
description: Finds the best-effort GitHub SHA in `xai-org/grok-build` for an exact Grok Build version string such as `1.0.13`. The user must provide the version. Match the first public snapshot commit that sets `xai-grok-version` to that exact version. Use for version-to-commit lookups and /grok-build-commit. This is not a channel lookup and not the published binary version.
metadata:
    github-path: skills/grok-build/grok-build-commit
    github-ref: refs/heads/main
    github-repo: https://github.com/olwig/skills
    github-tree-sha: aabf88b1fe02aebb6b8b4b023ce389aa6ca4dbca
name: grok-build-commit
---
# Grok Build commit

Use this skill when the user gives an exact **version number** and needs the matching GitHub commit from the upstream GitHub snapshot repo.

This is not the prebuilt binary version and not an official xAI pin.

The user must provide the version exactly. If they do not give a version, ask for it. Never fetch the version externally in this skill. Do not infer it from `stable`, `alpha`, or `enterprise`. Do not run `grok --version`.

## What the SHA is

Repo: https://github.com/xai-org/grok-build.git

`xai-org/grok-build` is the upstream GitHub repo. It is a public snapshot repo of xAI's internal monorepo. Snapshot commits usually say `Synced from monorepo`. There are no GitHub tags or releases for this mapping. `SOURCE_REV` is the internal monorepo SHA, not the GitHub SHA you should return.

Return the **first** commit (the oldest one on `main`) where

`crates/codegen/xai-grok-version/Cargo.toml`

has `version = "<ver>"`. That crate tracks the CLI version. Match the first appearance of that exact version string, without trying to place it in a stable, alpha, or enterprise channel. Later snapshots may still show the same version string. Do not return `HEAD` just because the same version is still there.

Do not treat the given version as belonging to any upstream channel. Just match the first appearance of that exact version. If the search finds nothing, say that clearly.

## Fetch the repo

You need full history for that file, so do not use `--depth`. If the current repo is already `xai-org/grok-build` with full history, use it. Otherwise clone to a temp dir, not into the user’s project:

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

If no commit matches, that version has not been mirrored to the public repo yet. Do not substitute `HEAD` or a tag.

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

If the user asks for JSON, return a JSON object instead, for example:

```json
{
  "version": "1.0.13",
  "commit": "bb7f39d5858cbf5e00de639367f59debbdcb0138",
  "parent": {
    "commit": "bc7f02eddd3d84085849dc19ed216f11c23b0571",
    "version": "1.0.12"
  },
  "repo": "https://github.com/xai-org/grok-build",
  "note": "snapshot heuristic; not an official xAI pin"
}
```
