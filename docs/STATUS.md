# OverClaude — Stato del progetto

Ultimo aggiornamento: 2026-07-06

## Aggiornamento 2026-07-06 — allineamento alla config live

Sincronizzata la repo con la config Claude Code effettivamente in uso:

- **Fix `skills-cli` dispatcher** (`lib/run-component.sh`): `npx skills add <repo>` installa
  l'**intero** repo (verificato dal vivo: `mattpocock/skills` → 38 skill). Aggiunto
  `--skill $name --agent claude --global --yes` così installa **solo** la skill nominata.
- **Bundle `context7-mcp`** nel plugin proprio (`plugins/overclaude/skills/context7-mcp/`):
  è una skill companion custom senza upstream, come brain/conversation-log.
- **Exa** documentato nel README come connector lato account claude.ai (non scriptabile).
- playwright/grill-me/caveman erano già nel manifest → confermati come default voluti e
  installati anche in locale (macchina e manifest ora combaciano).

## Stato: BUILD COMPLETA ✅

Tutti i 12 task del [piano](superpowers/plans/2026-06-29-overclaude.md) implementati,
testati e mergiati su `master`. Suite shell verde (10 pass, 1 skip per assenza `pwsh`).

| # | Task | Commit | Stato |
|---|------|--------|-------|
| 1 | Repo skeleton + manifests | `2c959ce` | ✅ |
| 2 | Bundle skill brain + conversation-log | `24adc78`, `2f7535e` | ✅ |
| 3 | Hook SessionStart new-session (sh + ps1) | `185da7d` | ✅ |
| 4 | Scaffold brain vuoto | `97f7e09` | ✅ |
| 5 | Config template + .env.example | `299a1ff` | ✅ |
| 6 | lib/detect-os | `725562d` | ✅ |
| 7 | lib/merge-settings (non distruttivo) | `0a982dc` | ✅ |
| 8 | components.manifest + dispatcher | `579da66` | ✅ |
| 9 | install.sh (POSIX) | `96aee1b` | ✅ |
| 10 | verify.sh | `40c0ce7` | ✅ |
| 11 | install.ps1 + verify.ps1 (Windows) | `42fce88` | ⚠️ vedi sotto |
| 12 | README + test runner | `79d22e0` | ✅ |

## Modalità di esecuzione
Task 1-2 eseguiti subagent-driven (review su sonnet, approvati). Dal Task 3 i subagent
hanno colpito il limite di sessione → esecuzione inline (codice preso dal piano, ogni test
eseguito, commit per task).

## Bug del piano corretti in corsa
- Test manifest: `NF!=3` → `NF<3` (la riga `caveman` contiene `| bash`; l'arg può avere pipe).
- Test dispatch: `read` senza newline finale ritornava 1 sotto `set -e` → aggiunto `\n`.

## Gate di sicurezza (pre-pubblicazione) — superato
Zero path assoluti, zero chiavi, zero symlink, `.env` non tracciato, scaffold con solo
schema + placeholder vuoti, `~/.claude/settings.json` viva intatta dopo il dry-run.

## Follow-up aperti
- [ ] ⚠️ **`install.ps1` / `verify.ps1`: sintassi NON validata** (manca `pwsh` sulla macchina di build). Testare su Windows reale.
- [x] ~~Confermare i sottocomandi CLI esatti~~ — verificato con `claude plugin --help` (2026-06-29): `claude plugin marketplace add <source>` e `claude plugin install <plugin>@<marketplace>` sono corretti così come in `lib/run-component.sh`.
- [ ] Caveat Windows hook SessionStart: la variante `.ps1` esiste ma il rewrite del comando hook per Windows è documentato, non automatizzato (fallback WSL nel README).
- [x] ~~Nessun git remote~~ — repo pubblica creata e pushata (2026-06-29): https://github.com/sonosaturn/overclaude
- [x] ~~Layer 2 personale (`overclaude-personal`)~~ — creato (2026-06-29): `~/brain` reale pushato su repo GitHub **privata** `sonosaturn/overclaude-personal`. Round-trip verificato (clone → `install.sh --personal=<clone>` → `WOULD OVERLAY`). La auto-memoria è inclusa: la dir live `~/.claude/projects/<home>/memory/` è un symlink a `~/brain/claude-memory/` (single source of truth, versionata col vault); `install.sh --personal` ricrea il symlink dopo l'overlay (step 6b). Test dry-run copre l'annuncio `WOULD LINK`.

## Note operative
- Key context7 ruotata il 2026-06-29 (la vecchia era stata esposta in chat; rigenerata).
- `.env` locale popolato (context7 + Gemini), gitignorato.
- Il ledger SDD vive in `.superpowers/` (gitignorato): non fa parte del repo pubblico.
