# AGENTS.md

Single source of truth for coding agents in this repository.
`CLAUDE.md` and `GEMINI.md` stay one-line shims (`@AGENTS.md`).
Do not copy these rules into other files.

## Repo

Personal monorepo of Arch Linux PKGBUILDs.

- `packages/<name>/` — one package each. Only packaging files: PKGBUILD,
  `.SRCINFO`, license, extra sources. These dirs are what `makepkg` and AUR
  sync copy. Do not put agent docs there.
- `.agents/skills/` — how-to for AUR, PKGBUILD, pacman, and package-specific
  lookups. Use a skill when its description matches the task.
- `.github/workflows/` — CI. Do not edit unless asked.

A PKGBUILD is a bash recipe `makepkg` runs to build an Arch package.
The AUR is Arch's unofficial user repo; some packages here are synced there,
most work stays in this GitHub repo.

Root license is MIT. Each package directory is 0BSD. `license=` inside a
PKGBUILD is the upstream software license.

## Rules

- Change only what the task needs. Do not restyle or "improve" a PKGBUILD
  without a reason.
- If you change a PKGBUILD, regenerate `.SRCINFO` in the same directory:
  `makepkg --printsrcinfo > .SRCINFO`
- Prefer skills under `.agents/skills/` over improvised AUR/PKGBUILD procedure.

## Validation

From the package directory, on Arch:

```bash
bash -n PKGBUILD
makepkg --printsrcinfo > .SRCINFO
```

Build with `makepkg -si --noconfirm` only when the task needs a real package
build, and only on Arch. Docs-only changes: skip the build.
