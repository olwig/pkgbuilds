---
description: Gets the published Grok Build CLI/harness version from the official xAI channel pointers (`stable`, `alpha`, `enterprise`). Use for Grok Build version lookups, channel pointers, and /grok-build-version. Do not use for `grok --version`, local install checks, GitHub tags, or chat model names such as Grok 4.6. For a GitHub SHA, use /grok-build-commit.
metadata:
    github-path: skills/grok-build/grok-build-version
    github-ref: refs/heads/main
    github-repo: https://github.com/olwig/skills
    github-tree-sha: dcc7fbf6040a7cf8f63ae4534a75de31d932e2a8
name: grok-build-version
---
# Grok Build Version

Use this skill to read the **published Grok Build CLI / harness version** from the same channel pointers the installer uses.

This is the version of the **prebuilt binary** xAI ships. It is not the version of a local install, and it is not a GitHub tag. `1.x.x` is the CLI version. Grok 4.6 is the chat model.

## Sources

Channel pointers are plain text. Read the first line, strip CR and whitespace, and use that as the published install version.

| | Base |
|---|---|
| Primary | `https://x.ai/cli/<channel>` |
| Fallback | `https://storage.googleapis.com/grok-build-public-artifacts/cli/<channel>` |
| Inspect on pointer failure | `https://x.ai/cli/install.sh` |

Channels: `stable`, `alpha`, `enterprise`. If the user does not name one, use `stable`.

npm dist-tags and https://x.ai/build/changelog can be useful context, but the channel pointer is the source of truth when it is healthy.

## Binary vs GitHub

`xai-org/grok-build` is a public snapshot repo. xAI does not publish GitHub tags or an official channel-to-commit map. This skill does **not** tell you which GitHub commit matches a channel pointer.

If the user needs a GitHub SHA for a specific published version, use `grok-build-commit` with the version **number** found here (not the channel name).

## Channel

| User intent | Channel |
|---|---|
| names stable / alpha / enterprise | that channel |
| latest / canary / preview / nightly | alpha |
| all channels / compare | all three |
| unspecified | stable |

## Fetch

Do not guess. Fetch the live pointer. Prefer curl. `wget -q -O - URL` is the fallback form.

```bash
curl -fsSL --max-time 15 https://x.ai/cli/stable \
  | tr -d '\r' | head -n1 | tr -d '[:space:]'
```

Accept only values that match the installer regex:

```
^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9._]+)?$
```

Published versions are usually plain `X.Y.Z`. Keep suffix support because Grok Build history also includes versions such as `0.2.0-dev`. Reject empty bodies, HTML, and anything else.

For all channels, fetch each independently so one failure does not hide the others.

## Errors

If the primary pointer fails (timeout, HTTP error, empty body, or invalid version), fetch the same channel from the GCS fallback.

If both pointer sources fail, inspect `https://x.ai/cli/install.sh` before giving up:

- Parse only the parts of the installer that are clearly about **version/channel resolution**.
- Extract any endpoints, channel mappings, or retrieval flow the installer uses to determine the published upstream version.
- Use installer-derived behavior only when it is safe and unambiguous that the installer has moved to a new authoritative version source or flow.
- Do **not** silently replace canonical pointer behavior when the pointer flow is healthy, or when the installer script is ambiguous.
- Do not use npm, the changelog, or GitHub as the version source.

If `install.sh` shows endpoint or workflow drift relative to this skill's instructions, include an explicit maintenance warning that the **skill may be outdated** and that the developer should update the skill definition to match current upstream installer behavior.

If neither pointer nor installer-derived resolution works, say that clearly instead of guessing.

## Installer fallback relevance filter

Only apply `install.sh`-derived behavior when the installer evidence is clearly relevant to version or channel resolution, for example:

- it resolves a channel to a pointer URL or artifact URL
- it fetches a version manifest or version endpoint
- it documents or implements a replacement for the current pointer flow

Ignore unrelated installer logic such as OS detection, download/extract steps, PATH setup, shell UX, or telemetry.

If the installer contains multiple possible flows, feature flags, or unclear branches, do not guess which one is authoritative. Report the ambiguity and include the maintenance warning when the flow appears to have drifted.

## Output

```
Grok Build: 1.0.13
Channel: stable
Source: https://x.ai/cli/stable
Resolution: pointer
```

If the user asks for all channels, return one block per channel.

If the result came from installer inspection, make that explicit:

```
Grok Build: 1.0.13
Channel: stable
Source: installer-derived fallback
Resolution: install.sh
Warning: skill may be outdated — install.sh appears to use a different version/channel resolution flow than this skill currently documents. Update the skill definition to match upstream installer behavior.
```

Optional extra if useful: changelog https://x.ai/build/changelog.
