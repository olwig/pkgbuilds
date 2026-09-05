# AGENTS.md

Global instructions for coding agents in this repository.
This file is the single source of truth. Do not invent a second policy.

`CLAUDE.md` and `GEMINI.md` must stay one-line shims that point here.
If a tool requires another filename, add a one-line shim that references `@AGENTS.md`.
Do not copy these rules into provider-specific files.

## What this repo is

Personal Arch Linux PKGBUILD monorepo. Package trees live under `packages/<name>/`.
Goal: keep those packages correct, reproducible, and small. Prefer a precise PKGBUILD
edit over a repo-wide cleanup.

Current packages:

| Directory | Kind | AUR today | Version source |
|---|---|---|---|
| `packages/grok-build-bin` | prebuilt binary from `https://x.ai/cli/` | yes | channel pointer (`stable` unless asked otherwise) |
| `packages/grok-build` | build from pinned `xai-org/grok-build` commit | no | same published version + snapshot SHA |
| `packages/grok-build-git` | build from unpinned upstream HEAD | yes | dynamic `pkgver()` |

All three `provide`/`conflict` `grok`. Do not change that unless the task says so.
Install path is `/usr/bin/grok`. Keep it stable.
`requirements.toml` is packaged to `/etc/grok/requirements.toml` and listed in `backup=`.
Do not drop or relocate it without an explicit request.

Root license is MIT. Each package directory is 0BSD (Arch PKGBUILD convention).
The *software* license inside the PKGBUILD (`license=`) is upstream, currently Apache-2.0.

## Do first

1. State a short plan (files, version/commit if any, how you will validate).
2. Touch only what the task needs.
3. Stop and ask when mapping rules disagree or upstream is not mirrored yet.

## Do

- Edit `packages/<name>/PKGBUILD` and regenerate that package's `.SRCINFO` in the same change.
- When `source` / artifact URLs / files change, refresh checksums in the same change.
- When the published version changes for a pinned package:
  - bump `pkgver`
  - reset `pkgrel` to `1` unless you are only fixing packaging (then increment `pkgrel` and leave `pkgver`)
  - refresh checksums
  - for `grok-build`, update `_commit` and the version comment next to it
- Keep Arch fields idiomatic: `pkgver`, `pkgrel`, `source`, checksums, `arch`, `license`, `provides`, `conflicts`.
- For `grok-build-git`, leave `pkgver()` dynamic. Do not pin `_commit` there.
- Use existing skills under `.agents/skills/` instead of guessing procedures.

## Do not

- Change package behavior, install paths, provides/conflicts, or sandbox defaults unless asked.
- Add packages, workflows, or `repo.yml` because a comment mentioned them.
- Rewrite workflows, secrets handling, or AUR SSH.
- Push to AUR, disable dry-run, or expand the AUR package list unless asked.
- Commit build artifacts, `pkg/`, `src/`, or `*.pkg.tar.*`.
- Source a PKGBUILD into the agent shell to "parse" it when `awk`/`grep` will do.
- Use `grok --version`, GitHub tags, or npm as the published version.
- Substitute `HEAD` or a nearby commit when a version is not on the public mirror.
- Mix unrelated cleanup with a version bump.

## Version and commit lookup

Do not guess versions or SHAs.

1. Published CLI version: skill `grok-build-version` (default channel `stable`).
2. Snapshot SHA for an exact version string: skill `grok-build-commit`.
3. Apply the result to the PKGBUILD you were asked to update.

`xai-org/grok-build` is a public snapshot, not an official channel-to-commit map.
The PKGBUILD comments in `packages/grok-build/PKGBUILD` describe the pin used *for that package*.
If a skill and that comment disagree, do not pick a winner. Report both and stop.

`.github/agents/grok-build-stable-mapping.agent.md` is a Copilot custom agent for that lookup.
It is not a second policy file and must not contradict the two skills.

## Layout agents actually need

```
packages/<name>/PKGBUILD
packages/<name>/.SRCINFO
packages/<name>/requirements.toml
packages/<name>/LICENSE          # 0BSD packaging license
.agents/skills/                  # how-to for version, commit, AUR
.github/workflows/makepkg.yml    # matrix build + install test (manual / callable)
.github/workflows/update-versions.yml  # checks upstream; opens Issues; does not edit PKGBUILDs
.github/workflows/aur-sync-light.yml   # copies a hardcoded AUR set; default push is dry-run
```

## Workflows as they are today

- `makepkg.yml` builds `packages/*` that contain a PKGBUILD. Empty `pkgs` input means all of them. Runs in an Arch container. Prefer this, or a local Arch `makepkg`, for validation.
- `update-versions.yml` compares published `stable` to PKGBUILD `pkgver` and creates a GitHub issue. It does not bump versions or checksums.
- `aur-sync-light.yml` currently syncs only `grok-build-git` and `grok-build-bin`. Default `push_dry_run=true`. `grok-build` is not on that list.

Treat comments about a future `repo.yml` mapping library as unimplemented. Do not build it in passing.

## Validation

Target only the packages you changed.

On Arch (local or the repo CI container), from the package directory:

```bash
makepkg -si --noconfirm
makepkg --printsrcinfo > .SRCINFO
shellcheck --shell=bash --exclude=SC2034,SC2154,SC2164 PKGBUILD
```

Do not run `makepkg` on a non-Arch host and call it verified.
Docs-only or instruction-file changes: skip the build.
If you cannot build, say so and still ship a consistent PKGBUILD + `.SRCINFO` + checksums.

## Done

- Diff is limited to the requested package(s) or instruction files.
- `pkgver` / `pkgrel` / sources / checksums / `_commit` agree with each other.
- `.SRCINFO` matches the PKGBUILD.
- `provides`/`conflicts` and `/usr/bin/grok` unchanged unless requested.
- Validation ran, or the reason it did not is in the PR/issue text.
- No AUR push unless the task explicitly asked for a real push.
