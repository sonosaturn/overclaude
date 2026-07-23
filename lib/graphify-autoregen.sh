#!/usr/bin/env sh
# Rigenera il grafo semantico graphify dopo un commit — SOLO nel vault brain. Detached: non blocca mai git.
# Commit-driven: il grafo sta sempre al passo col vault (conversazioni, wiki, sources). Incrementale:
# graphify rielabora solo i file cambiati, quindi il costo per commit è minimo dopo il primo run.
# ponytail: no-op silenzioso se non è il vault, se graphify manca, o se manca la key Gemini;
# un commit non deve MAI fallire per questo. Ceiling: costo Gemini per commit; se diventa troppo,
# aggiungere un debounce (skip se l'ultimo run è < N minuti fa) qui.
command -v graphify >/dev/null 2>&1 || exit 0
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$repo" ] || exit 0
# Guardia "è il vault brain": il wrapper graphify-run.sh esiste solo nel vault (lo mette lo scaffold).
[ -f "$repo/bin/graphify-run.sh" ] || exit 0
# L'hook gira in un env minimale: carica la key Gemini da brain.env (graphify-run.sh non la sorgente da solo).
[ -f "$HOME/.config/brain.env" ] && . "$HOME/.config/brain.env"
[ -n "${GEMINI_API_KEY:-}" ] || exit 0
export GEMINI_API_KEY
setsid sh "$repo/bin/graphify-run.sh" "$repo" >>/tmp/graphify-regen.log 2>&1 </dev/null &
exit 0
