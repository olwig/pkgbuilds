---
name: grok-build-upstream-version
description: Reads the current Grok Build CLI version from official xAI channel pointers. Use for Grok Build version, stable, alpha, enterprise, x.ai/cli/stable, grok --version, or update status. Not for model names such as Grok 4.6.
---

# Grok Build Version

Read the **CLI / harness version** of Grok Build (`grok`), not the chat model name.

## Canonical sources

Channel pointers are plain text (one version string):

- Stable — https://x.ai/cli/stable
- Alpha — https://x.ai/cli/alpha
- Enterprise — https://x.ai/cli/enterprise

npm `@xai-official/grok` — dist-tag `latest` = stable, `alpha` = alpha.

Source repo (not always identical to the binary channel) — https://github.com/xai-org/grok-build

Changelog — https://x.ai/build/changelog

## Procedure

1. Infer the channel from the question. Default is **stable**.
2. Fetch live. Do not guess. Do not infer from GitHub tags.

```bash
curl -fsSL https://x.ai/cli/stable
```

Optional helper in this skill (same HTTP GET):

```bash
bash scripts/fetch-version.sh stable
bash scripts/fetch-version.sh all
```

3. Answer briefly — channel + number. Example — `Grok Build stable 1.0.13`.
4. Optional extras — other channels, changelog link, `grok update` refreshes the local binary.
5. Never confuse this with the chat model (Grok 4.6 = model; `1.x.x` = CLI).

## GitHub / CI

No extra script is required. A workflow step is enough:

```yaml
- name: Grok Build channel versions
  run: |
    echo "stable=$(curl -fsSL https://x.ai/cli/stable)"
    echo "alpha=$(curl -fsSL https://x.ai/cli/alpha)"
    echo "enterprise=$(curl -fsSL https://x.ai/cli/enterprise)"
```

Same URLs work in badges, release notes, or install docs. Tags on `xai-org/grok-build` are secondary. The channel pointer is the published install version.

## Errors

If `x.ai/cli/<channel>` fails:

1. Retry curl with `--max-time 15`.
2. Fallback — npm dist-tag of `@xai-official/grok` (`latest` or `alpha`).
3. Changelog and GitHub releases are context only, not channel truth.
4. Tell the user which source worked.

## Output

```
Grok Build: 1.0.13
Channel: stable
Source: https://x.ai/cli/stable
```

For all channels, one line each.

## Triggers

- What is the current Grok stable version?
- Fetch the Grok enterprise version
- Get Grok Build version
- Is my grok CLI up to date?
