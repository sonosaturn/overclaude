# STACK — snapshot config creativa (review lug 2026)

Snapshot della tornata di review skill/plugin/MCP orientata a **design + portfolio di
livello**. Fonte-di-verità resta `lib/components.manifest`; qui il *perché* per gli umani.

## Aggiunto

### Design / UI
- **frontend-design** (anthropics/skills) — gate: scegli una direzione estetica prima di generare.
- **superdesign** (superdesigndev) — canvas iterativo, ritorna codice.
- **design-dna** (zanwei) — reference (screenshot/URL) → JSON DNA → genera UI coerente.
- **brandkit** (Leonxlnx/taste-skill) — board identità premium (image-gen, vedi nota nano-banana).
- **magic** MCP (21st.dev) — `/ui` → componente React/shadcn. Key in `.env` (`MAGIC_API_KEY`).
- **designer-toolkit / ux-strategy / cognitive-accessibility / accessible-content**
  (plugin da `Owl-Listener/designer-skills`) — case-study/IA/a11y. Cherry-pick: gli altri
  ~29 plugin del marketplace **non** abilitati (team/leadership/AI — trigger-noise).

### Motion
- **gsap-skills** (greensock, 8 skill: core/scrolltrigger/react/…) — scelta lib motion = **GSAP**.
- **motion-design** (LottieFiles) — principi motion tool-agnostici.

### 3D / arte generativa
- **algorithmic-art** + **canvas-design** (anthropics/skills) — generativo p5.js / grafiche via codice.

### Video
- **claude-video** → skill `watch` (analisi video: yt-dlp + ffmpeg + transcript).

## Standby / note
- **nano-banana** (image-gen Gemini) installato ma in **standby**: il free tier Gemini ha
  quota immagini = 0 → serve **billing** sul progetto della key (`GEMINI_API_KEY`). Sblocca brandkit.
- **open-generative-ai**: app esterna (AppImage in `~/Applications`), key Muapi, non è config Claude.

## Automazione manifest (fix)
L'hook `bin/overclaude-sync.sh` (PostToolUse Bash) era **morto**: path errato
(`~/overclaude` invece di `~/projects/overclaude`) + non gestiva plugin/skills-repo.
Riparato: path corretto, **redazione segreti** prima del push, `claude plugin install`
(risolve la marketplace dai settings) e `npx skills add` senza `--skill` (→ `skills-repo`).
Ora ogni aggiunta si auto-sincronizza nel manifest + commit + push.

## Backlog differiti
Skill valutate e volutamente **non** installate (situazionali) → `~/.claude/DEFERRED-SKILLS.md`,
consultato all'avvio di un nuovo progetto (regola nel CLAUDE.md globale): trailofbits (security
C/Rust/Solidity), figma-mcp, threejs-skills, remotion, camofox-browser, swap-candidate taste/token.
