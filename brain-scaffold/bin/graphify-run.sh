#!/usr/bin/env bash
# graphify con fallback automatico tra modelli Gemini.
# Parte dal primo modello di GRAPHIFY_GEMINI_MODELS; se quello esaurisce la quota
# giornaliera (429 / RESOURCE_EXHAUSTED), passa automaticamente al successivo.
#
# Uso:  ~/brain/bin/graphify-run.sh [percorso]   (default: cartella corrente)
set -uo pipefail

# Lista modelli (override via env GRAPHIFY_GEMINI_MODELS). Default = i 3 modelli dell'utente.
read -r -a MODELS <<< "${GRAPHIFY_GEMINI_MODELS:-gemini-3.5-flash gemini-3-flash-preview gemini-3.1-flash-lite}"
target="${1:-.}"

if [ -z "${GEMINI_API_KEY:-}" ]; then
  echo "[graphify-run] GEMINI_API_KEY non impostata. Mettila in ~/.config/brain.env e apri una nuova shell." >&2
  exit 2
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

for m in "${MODELS[@]}"; do
  echo "[graphify-run] modello: $m"
  GRAPHIFY_GEMINI_MODEL="$m" graphify "$target" 2>&1 | tee "$log"
  rc=${PIPESTATUS[0]}

  if [ "$rc" -eq 0 ]; then
    echo "[graphify-run] completato con $m"
    exit 0
  fi

  if grep -qiE '429|resource_exhausted|quota|exhaust|rate.?limit|too many requests|503|unavailable|overloaded|high.demand' "$log"; then
    echo "[graphify-run] $m non disponibile (quota esaurita o sovraccarico) → provo il prossimo modello"
    continue
  fi

  echo "[graphify-run] errore non legato alla quota (rc=$rc) su $m: mi fermo." >&2
  exit "$rc"
done

echo "[graphify-run] tutti i modelli hanno esaurito la quota giornaliera. Riprova domani." >&2
exit 1
