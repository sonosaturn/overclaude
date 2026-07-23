#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || fail "python3 required"

hook="$root/plugins/overclaude/hooks/log-session.py"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/brain/conversations"

# Transcript sintetico: due turni utente, con in mezzo un tool_result e una riga
# isMeta, che non devono essere scambiati per prompt.
cat > "$tmp/t.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-23T10:00:00Z","message":{"content":"primo prompt di prova lungo abbastanza da fare da chiave"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"prima risposta ```codice da strippare``` fine"}]}}
{"type":"user","message":{"content":[{"type":"tool_result","content":"output"}]}}
{"type":"user","isMeta":true,"message":{"content":[{"type":"text","text":"[Image: iniezione di sistema]"}]}}
{"type":"user","timestamp":"2026-07-23T10:05:00Z","message":{"content":"secondo prompt di prova lungo abbastanza da fare da chiave"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"seconda risposta"}]}}
JSONL

conv="$tmp/brain/conversations/Conv_test.md"
printf '%s\n' "$conv" > "$tmp/brain/conversations/.current-session"
run() { printf '{"transcript_path":"%s"}' "$tmp/t.jsonl" | HOME="$tmp" python3 "$hook" >/dev/null; }

# 1. File senza marker: rigenerazione completa, codice strippato, niente tool_result
#    né righe isMeta scambiate per prompt.
: > "$conv"
run
grep -q 'primo prompt di prova' "$conv"  || fail "turno 1 assente"
grep -q 'secondo prompt di prova' "$conv" || fail "turno 2 assente"
grep -q 'codice omesso' "$conv"           || fail "blocco di codice non strippato"
! grep -q 'iniezione di sistema' "$conv"  || fail "riga isMeta trattata come prompt"
! grep -q 'tool_result' "$conv"           || fail "tool_result trattato come prompt"

# 2. Curato e completo: non si tocca niente.
cat > "$conv" <<'MD'
# Conversazione
<!-- curated -->
## 10:00 — Utente
primo prompt di prova lungo abbastanza da fare da chiave
## 10:05 — Utente
secondo prompt di prova lungo abbastanza da fare da chiave
MD
before="$(cat "$conv")"
run
[ "$before" = "$(cat "$conv")" ] || fail "file curato e completo modificato"

# 3. Curato a metà: i turni mancanti vengono accodati, il curato resta intatto.
#    È il caso che la versione binaria del marker perdeva del tutto.
cat > "$conv" <<'MD'
# Conversazione
<!-- curated -->
## 10:00 — Utente
primo prompt di prova lungo abbastanza da fare da chiave

Riassunto curato a mano del primo turno.
MD
run
grep -q 'Riassunto curato a mano' "$conv"     || fail "contenuto curato perso"
grep -q 'secondo prompt di prova' "$conv"     || fail "turno mancante non accodato"
[ "$(grep -c 'primo prompt di prova' "$conv")" -eq 1 ] || fail "turno curato duplicato"

# 4. Idempotenza: un secondo giro non riaccoda nulla.
before="$(cat "$conv")"
run
[ "$before" = "$(cat "$conv")" ] || fail "accodamento non idempotente"

echo "PASS test_log_session"
