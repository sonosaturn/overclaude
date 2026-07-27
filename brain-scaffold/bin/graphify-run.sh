#!/usr/bin/env bash
# graphify with automatic fallback across Gemini models.
# Starts from the first model in GRAPHIFY_GEMINI_MODELS; if that one runs out of its daily
# quota (429 / RESOURCE_EXHAUSTED), it moves to the next one automatically.
#
# Usage:  ~/brain/bin/graphify-run.sh [path]   (default: current folder)
set -uo pipefail

# Model list (override via the GRAPHIFY_GEMINI_MODELS env var). Default = the user's 3 models.
read -r -a MODELS <<< "${GRAPHIFY_GEMINI_MODELS:-gemini-3.5-flash gemini-3-flash-preview gemini-3.1-flash-lite}"
target="${1:-.}"

if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "[graphify-run] GEMINI_API_KEY is not set. Put it in ~/.config/brain.env and open a new shell." >&2
  exit 2
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

for m in "${MODELS[@]}"; do
  echo "[graphify-run] model: $m"
  GRAPHIFY_GEMINI_MODEL="$m" graphify "$target" 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}

  if [ "$rc" -eq 0 ]; then
    echo "[graphify-run] completed with $m"
    exit 0
  fi

  if grep -qiE '429|resource_exhausted|quota|exhaust|rate.?limit|too many requests|503|unavailable|overloaded|high.demand' "$log"; then
    echo "[graphify-run] $m unavailable (quota exhausted or overloaded), trying the next model"
    continue
  fi

  echo "[graphify-run] error unrelated to quota (rc=$rc) on $m: stopping." >&2
  exit "$rc"
done

echo "[graphify-run] every model has exhausted its daily quota. Try again tomorrow." >&2
exit 1
