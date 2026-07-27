#!/usr/bin/env bash
# End-to-end self-check of the semantic recall. With GEMINI_API_KEY: checks ranking + idempotence.
# Without a key: clean skip (exit 0). Not a framework — assertions via test [ ].
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT="$(mktemp -d)"
# Git Bash: the scripts run on native Windows python, which reads /tmp/... as C:\tmp\...
command -v cygpath >/dev/null 2>&1 && VAULT="$(cygpath -m "$VAULT")"
export BRAIN_VAULT="$VAULT"
cleanup() { rm -rf "$VAULT"; }
trap cleanup EXIT

mkdir -p "$VAULT/conversations" "$VAULT/wiki"
( cd "$VAULT" && git init -q && git config user.email t@t && git config user.name t )

cat > "$VAULT/wiki/cripto.md" <<'EOF'
# Crittografia asimmetrica
Chiave pubblica e chiave privata. RSA, scambio di chiavi, firma digitale.
EOF
cat > "$VAULT/wiki/cucina.md" <<'EOF'
# Ricetta carbonara
Guanciale, uova, pecorino, pepe. Niente panna.
EOF
( cd "$VAULT" && git add -A && git commit -qm init )

if [ -z "${GEMINI_API_KEY:-}" ] && ! grep -q GEMINI_API_KEY "$HOME/.config/brain.env" 2>/dev/null; then
  echo "SKIP: no GEMINI_API_KEY — ranking self-check skipped (fail-open ok)"
  # check fail-open anyway
  out="$("$DIR/brain-recall" "chiave pubblica" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL: recall did not fail open (rc=$rc)"; exit 1; }
  echo "ALL PASS (skip-mode)"; exit 0
fi

# 1. backfill
"$DIR/brain-embed" --full >/dev/null 2>&1

# 2. ranking: crypto query → cripto.md first
top="$("$DIR/brain-recall" "chiave pubblica RSA" --kb 2>/dev/null | grep -m1 -oE 'cripto\.md|cucina\.md')"
[ "$top" = "cripto.md" ] || { echo "FAIL: wrong ranking, first='$top'"; exit 1; }
echo "ok ranking"

# 3. idempotence: re-embedding an unchanged file → 0 new chunks
add="$( ( cd "$VAULT" && git commit -q --allow-empty -m noop; "$DIR/brain-embed" --full ) 2>&1 | grep -oE '\+[0-9]+ chunk')"
[ "$add" = "+0 chunk" ] || { echo "FAIL: idempotence broken, add='$add'"; exit 1; }
echo "ok idempotence"

# 4. prune: editing a file must NOT accumulate stale chunks (total stays 2)
cat > "$VAULT/wiki/cripto.md" <<'EOF2'
# Crittografia asimmetrica (rev)
Chiave pubblica e privata, RSA, scambio di chiavi, firma digitale. Testo revisionato.
EOF2
( cd "$VAULT" && git add -A && git commit -qm edit )
"$DIR/brain-embed" --full >/dev/null 2>&1
tot="$(cd "$DIR" && uv run --quiet --with chromadb python -c "import brain_semantic as bs; print(bs.get_collection('$VAULT').count())" 2>/dev/null)"
[ "$tot" = "2" ] || { echo "FAIL: prune, total=$tot (expected 2)"; exit 1; }
echo "ok prune"

echo "ALL PASS"
