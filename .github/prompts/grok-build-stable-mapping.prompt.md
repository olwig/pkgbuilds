---
mode: agent
description: "Fetch Grok Build stable upstream version and map it to the GitHub mirror commit"
---

Get the current **stable** Grok Build version from upstream only, then map that version to the GitHub mirror commit.

Requirements:
- Fetch stable version from `https://x.ai/cli/stable` (fallback: `https://storage.googleapis.com/grok-build-public-artifacts/cli/stable`).
- Do not guess the version.
- Validate version with regex: `^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9._]+)?$`.
- Map the version to `https://github.com/xai-org/grok-build` using the first commit (oldest on `origin/main`) where `crates/codegen/xai-grok-version/Cargo.toml` has `version = "<ver>"`.
- Confirm the matched commit has the target version and parent has the previous version.
- If no commit matches, say the version is not mirrored yet.

Return exactly in this format:

Grok Build: <version>
Channel: stable
Source: <url>

Version: <version>
Commit: <sha or empty>
Parent: <parent_sha and parent version, if available>
Repo: https://github.com/xai-org/grok-build
Note: snapshot heuristic; not an official xAI pin
