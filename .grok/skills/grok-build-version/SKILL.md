---
description: Reads the live Grok Build CLI/harness version from official xAI channel pointers (stable, alpha, enterprise), matching https://x.ai/cli/install.sh. That string is the prebuilt binary xAI publishes. Use for Grok Build version, x.ai/cli/stable, channel pointer, or /grok-build-version. Not for the local grok binary, grok --version, update status, GitHub tags, or chat model names such as Grok 4.6. For a GitHub SHA, use /grok-build-commit.
metadata:
    github-path: skills/grok-build/grok-build-version
    github-ref: refs/heads/main
    github-repo: https://github.com/olwig/skills
    github-tree-sha: 329694682b39dca7c156b2b8663ebe6338e65c80
name: grok-build-version
---
# Grok Build Version

Read the **published CLI / harness version** of Grok Build the same way `https://x.ai/cli/install.sh` does. Do not run `grok --version` and do not compare against the local install. `1.x.x` is the CLI; Grok 4.6 is the chat model.

The pointer is the version of the **prebuilt binary** xAI ships. It matches the install artifact. It is not a GitHub tag.

## Sources

Channel pointers are plain text. First line, stripped of CR and whitespace, is the published install version.

| | Base |
|---|---|
| Primary | `https://x.ai/cli/<channel>` |
| Fallback | `https://storage.googleapis.com/grok-build-public-artifacts/cli/<channel>` |

Channels: `stable`, `alpha`, `enterprise`. Default `stable`.

npm dist-tags and https://x.ai/build/changelog are context only. The pointer wins.

## Binary vs GitHub

`xai-org/grok-build` is periodic snapshots of an internal xAI monorepo. xAI does not publish GitHub tags or any official map from a channel version to a commit. There is no 1:1 mapping: you cannot say “stable 1.0.13 is commit X” from this skill.

If the user needs a GitHub SHA / PKGBUILD pin, use `grok-build-commit` with the version **number** found here (not the channel name).

## Channel

| User intent | Channel |
|---|---|
| names stable / alpha / enterprise | that channel |
| latest / canary / preview / nightly | alpha |
| all channels / compare | all three |
| unspecified | stable |

## Fetch

Do not guess. Fetch live. Prefer curl; wget is the installer’s alternative (`wget -q -O - URL`).

```bash
curl -fsSL --max-time 15 https://x.ai/cli/stable \
  | tr -d '\r' | head -n1 | tr -d '[:space:]'
```

Accept only the installer regex:

```
^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9._]+)?$
```

(`X.Y.Z` or `X.Y.Z-suffix`.) Reject empty bodies, HTML, and anything else.

For all channels, fetch each independently so one failure does not hide the others.

## Errors

If the primary pointer fails (timeout, HTTP error, empty, or invalid version), fetch the same channel from the GCS fallback. Do not use npm, changelog, or GitHub as the version. State which source worked, or that none did.

## Output

```
Grok Build: 1.0.13
Channel: stable
Source: https://x.ai/cli/stable
```

For all channels, one block each.

Optional extra if useful: changelog https://x.ai/build/changelog.
