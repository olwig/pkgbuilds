---
mode: agent
description: "Fetch Grok Build stable upstream version and map it to the GitHub mirror commit"
---

Get the current **stable** Grok Build version from upstream only, then map that version to the GitHub mirror commit.

Requirements:
- You must use the existing skills for this workflow.
- First invoke skill `grok-build-version` to fetch the **stable** upstream version.
- Do not guess the version and do not use local `grok --version`.
- Then invoke skill `grok-build-commit` with the exact version number returned by `grok-build-version`.
- Use only the commit mapping method defined by `grok-build-commit` (first matching commit on `origin/main` for `crates/codegen/xai-grok-version/Cargo.toml`).
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
