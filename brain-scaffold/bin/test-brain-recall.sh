#!/usr/bin/env bash
# Self-check end-to-end del recall semantico. Con GEMINI_API_KEY: verifica ranking + idempotenza.
# Senza key: skip pulito (exit 0). Non un framework — assert via test [ ].
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT="$(mktemp -d)"
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
  echo "SKIP: nessuna GEMINI_API_KEY — self-check ranking saltato (fail-open ok)"
  # verifica comunque fail-open
  out="$("$DIR/brain-recall" "chiave pubblica" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL: recall non fail-open (rc=$rc)"; exit 1; }
  echo "ALL PASS (skip-mode)"; exit 0
fi

# 1. backfill
"$DIR/brain-embed" --full >/dev/null 2>&1

# 2. ranking: query cripto → cripto.md primo
top="$("$DIR/brain-recall" "chiave pubblica RSA" --kb 2>/dev/null | grep -m1 -oE 'cripto\.md|cucina\.md')"
[ "$top" = "cripto.md" ] || { echo "FAIL: ranking errato, primo='$top'"; exit 1; }
echo "ok ranking"

# 3. idempotenza: re-embed su file invariato → 0 nuovi chunk
add="$( ( cd "$VAULT" && git commit -q --allow-empty -m noop; "$DIR/brain-embed" --full ) 2>&1 | grep -oE '\+[0-9]+ chunk')"
[ "$add" = "+0 chunk" ] || { echo "FAIL: idempotenza rotta, add='$add'"; exit 1; }
echo "ok idempotenza"

# 4. prune: edit di un file NON deve accumulare chunk stale (total resta 2)
cat > "$VAULT/wiki/cripto.md" <<'EOF2'
# Crittografia asimmetrica (rev)
Chiave pubblica e privata, RSA, scambio di chiavi, firma digitale. Testo revisionato.
EOF2
( cd "$VAULT" && git add -A && git commit -qm edit )
"$DIR/brain-embed" --full >/dev/null 2>&1
tot="$(cd "$DIR" && uv run --quiet --with chromadb python3 -c "import brain_semantic as bs; print(bs.get_collection('$VAULT').count())" 2>/dev/null)"
[ "$tot" = "2" ] || { echo "FAIL: prune, total=$tot (atteso 2)"; exit 1; }
echo "ok prune"

echo "ALL PASS"
