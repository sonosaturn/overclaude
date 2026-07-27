# STACK — creative config snapshot (review Jul 2026)

Snapshot of the skill/plugin/MCP review round aimed at **design + a portfolio worth showing**.
The source of truth stays `lib/components.manifest`; this file holds the *why*, for humans.

## Added

### Design / UI
- **frontend-design** (anthropics/skills) — a gate: pick an aesthetic direction before generating.
- **superdesign** (superdesigndev) — iterative canvas, returns code.
- **design-dna** (zanwei) — reference (screenshot/URL) → JSON DNA → generates consistent UI.
- **brandkit** (Leonxlnx/taste-skill) — premium identity boards (image-gen, see the nano-banana note).
- **magic** MCP (21st.dev) — `/ui` → a React/shadcn component. Key in `.env` (`MAGIC_API_KEY`).
- **designer-toolkit / ux-strategy / cognitive-accessibility / accessible-content**
  (plugins from `Owl-Listener/designer-skills`) — case studies/IA/a11y. Cherry-picked: the other
  ~29 plugins in that marketplace are **not** enabled (team/leadership/AI — trigger noise).

### Motion
- **gsap-skills** (greensock, 8 skills: core/scrolltrigger/react/…) — motion library of choice = **GSAP**.
- **motion-design** (LottieFiles) — tool-agnostic motion principles.

### 3D / generative art
- **algorithmic-art** + **canvas-design** (anthropics/skills) — p5.js generative work / graphics by code.

### Video
- **claude-video** → the `watch` skill (video analysis: yt-dlp + ffmpeg + transcript).

## Standby / notes
- **nano-banana** (Gemini image-gen) installed but on **standby**: the Gemini free tier has an
  image quota of 0 → the key's project needs **billing** (`GEMINI_API_KEY`). It unlocks brandkit.
- **open-generative-ai**: an external app (AppImage in `~/Applications`), Muapi key, not Claude config.

## Manifest automation (fix)
The `bin/overclaude-sync.sh` hook (PostToolUse Bash) was **dead**: wrong path
(`~/overclaude` instead of `~/projects/overclaude`) + no handling for plugins/skills-repo.
Repaired: correct path, **secret redaction** before the push, `claude plugin install`
(resolves the marketplace from the settings) and `npx skills add` without `--skill`
(→ `skills-repo`). Every addition now auto-syncs into the manifest + commit + push.

## Deferred backlog
Skills reviewed and deliberately **not** installed (situational) → `~/.claude/DEFERRED-SKILLS.md`,
consulted when starting a new project (rule in the global CLAUDE.md): trailofbits (security for
C/Rust/Solidity), figma-mcp, threejs-skills, remotion, camofox-browser, taste/token swap candidates.
