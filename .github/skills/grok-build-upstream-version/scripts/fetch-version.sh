#!/usr/bin/env bash
# Fetch official Grok Build channel pointers from xAI.
# Usage: fetch-version.sh [stable|alpha|enterprise|all]
set -euo pipefail

CHANNEL="${1:-stable}"
BASE="https://x.ai/cli"

fetch() {
  local ch="$1"
  local ver
  ver=$(curl -fsSL --max-time 15 "${BASE}/${ch}" | tr -d '[:space:]')
  if [[ -z "$ver" ]]; then
    echo "${ch}: (leer / Fehler)" >&2
    return 1
  fi
  echo "${ch}: ${ver}"
}

case "$CHANNEL" in
  stable|alpha|enterprise)
    fetch "$CHANNEL"
    ;;
  all)
    fetch stable
    fetch alpha
    fetch enterprise
    ;;
  *)
    echo "Usage: $0 [stable|alpha|enterprise|all]" >&2
    exit 2
    ;;
esac
