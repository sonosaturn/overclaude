#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
# On Windows 'python3' is the Microsoft Store alias: it is in PATH but runs nothing.
# Stesso probe dell'hook (vedi docs/WINDOWS.md).
PY=""
for p in python3 python py; do "$p" -c "" >/dev/null 2>&1 && { PY="$p"; break; }; done
[ -n "$PY" ] || fail "python required"

hook="$root/plugins/overclaude/hooks/log-session.py"
tmp="$(mktemp -d)"
# Path MSYS (/tmp/...) letto da un python nativo diventa C:\tmp\...: altra directory.
command -v cygpath >/dev/null 2>&1 && tmp="$(cygpath -m "$tmp")"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/brain/conversations"

# Synthetic transcript: two user turns, with a tool_result and an isMeta line in between,
# which must not be mistaken for prompts.
cat > "$tmp/t.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-23T10:00:00Z","message":{"content":"first test prompt, long enough to act as a key"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"first answer ```code to strip``` end"}]}}
{"type":"user","message":{"content":[{"type":"tool_result","content":"output"}]}}
{"type":"user","isMeta":true,"message":{"content":[{"type":"text","text":"[Image: system injection]"}]}}
{"type":"user","timestamp":"2026-07-23T10:05:00Z","message":{"content":"second test prompt, long enough to act as a key"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"seconda risposta"}]}}
JSONL

conv="$tmp/brain/conversations/Conv_test.md"
printf '%s\n' "$conv" > "$tmp/brain/conversations/.current-session"
# USERPROFILE as well as HOME: expanduser("~") on Windows looks at that one, not HOME.
run() { printf '{"transcript_path":"%s"}' "$tmp/t.jsonl" \
  | HOME="$tmp" USERPROFILE="$tmp" "$PY" "$hook" >/dev/null; }

# 1. File without the marker: full regeneration, code stripped, no tool_result
#    or isMeta lines mistaken for prompts.
: > "$conv"
run
grep -q 'first test prompt' "$conv"       || fail "turn 1 missing"
grep -q 'second test prompt' "$conv" || fail "turn 2 missing"
grep -q 'codice omesso' "$conv"           || fail "code block not stripped"
! grep -q 'system injection' "$conv"  || fail "isMeta line treated as a prompt"
! grep -q 'tool_result' "$conv"           || fail "tool_result treated as a prompt"

# 2. Curated and complete: nothing is touched.
cat > "$conv" <<'MD'
# Conversazione
<!-- curated -->
## 10:00 — Utente
first test prompt, long enough to act as a key
## 10:05 — Utente
second test prompt, long enough to act as a key
MD
before="$(cat "$conv")"
run
[ "$before" = "$(cat "$conv")" ] || fail "file curato e completo modificato"

# 3. Half-curated: the missing turns are appended, the curated part stays intact.
#    This is the case the binary version of the marker lost entirely.
cat > "$conv" <<'MD'
# Conversazione
<!-- curated -->
## 10:00 — Utente
first test prompt, long enough to act as a key

Hand-curated summary of the first turn.
MD
run
grep -q 'Hand-curated summary' "$conv"     || fail "curated content lost"
grep -q 'second test prompt' "$conv"     || fail "missing turn not appended"
[ "$(grep -c 'first test prompt' "$conv")" -eq 1 ] || fail "curated turn duplicated"

# 4. Idempotence: a second run appends nothing.
before="$(cat "$conv")"
run
[ "$before" = "$(cat "$conv")" ] || fail "appending is not idempotent"

# 5. The marker quoted INSIDE the log must not make the file count as curated: it really
#    happens, in any session about the marker the answers quote it verbatim.
cat > "$conv" <<'MD'
# Conversazione

<!-- auto-generated: log-session.py -->

## 10:00 — Utente
first test prompt, long enough to act as a key

## Claude
- Il marker <!-- curated --> segnala un log scritto dal modello.
MD
run
grep -q 'second test prompt' "$conv" || fail "marker quoted in the body mistaken for the header"

echo "PASS test_log_session"
