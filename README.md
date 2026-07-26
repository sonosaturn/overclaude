# OverClaude

> **Claude on steroids** — a ready-to-go repo that turns a bare Claude Code into an
> advanced setup: process plugins, code intelligence, up-to-date docs, browser
> automation, terse prose, design, skill discovery and a local second brain.

OverClaude does not re-host third-party code: it **orchestrates** the official installers
of each component (a single `lib/components.manifest` to keep updated) and packages its own
parts (`brain`, `conversation-log`, the logging hook) as a Claude Code plugin served from
this repo's own marketplace.

## Quickstart

```bash
git clone https://github.com/<you>/overclaude && cd overclaude
cp .env.example .env        # optional: add your keys
sh install.sh               # Linux / macOS
sh install.sh --check       # verify
```

Windows (PowerShell):

```powershell
git clone https://github.com/<you>/overclaude; cd overclaude
Copy-Item .env.example .env
./install.ps1
./install.ps1 -Check
```

The installer is **idempotent**: re-running it is safe and non-destructive (the
`settings.json` merge preserves your local settings).

Every component is configured to be **model-invocable by default** (the model uses it
without a manual trigger), except what is user-only by design
(`disable-model-invocation: true`, such as `handoff`/`grill-me`, which you launch with
`/<name>`). Details in [`config/CLAUDE.md.template`](config/CLAUDE.md.template).

### Preview without changes

```bash
sh install.sh --dry-run     # prints what it would do, touching nothing
```

## What it installs

Single source in [`lib/components.manifest`](lib/components.manifest). In short:

| Component | Role |
|---|---|
| superpowers, ponytail | process plugins (brainstorm, TDD, debugging, lazy mode) |
| gitnexus | code intelligence (graph, impact analysis) + 9 skills + hook + auto-reindex on every commit in new repos (git `init.templateDir`) |
| context7 (MCP) | up-to-date documentation for libraries and SDKs |
| playwright (MCP) | real browser automation (E2E tests, screenshots) |
| caveman, grill-me | terse prose · adversarial interrogation of plans |
| impeccable | design language for UI |
| find-skills, skill-creator, handoff | skill discovery and authoring · session handoff |
| brain, conversation-log, context7-mcp (own plugin) | the `~/brain` second brain + curated conversation log + the context7 companion skill |
| codeburn | local AI token/cost tracker (TUI/web/menubar dashboard), a user-run CLI: `codeburn` |
| rtk | CLI proxy that compresses command output before it reaches the context (PreToolUse hook, ~60-90% less) |

User-space tooling installed separately: `node`, `uv`, `markitdown`, `graphify`.

The installer also writes into `~/.claude`: `CLAUDE.md` (only if missing), `rules/`, `RTK.md`
(which the global `CLAUDE.md` pulls in via `@RTK.md`) and the **statusline** with the badges
of the always-on modes — the `.ps1` variant on Windows, `.sh` elsewhere, with the absolute
path written into `settings.json` at install time rather than hardcoded in the repo.

> **Exa (web search MCP)** is not in the manifest: it is an **account-side connector on
> claude.ai** (`mcp.exa.ai/mcp`), not something a local script can install. Add it once from
> your Claude account settings, not per machine.

## Secrets

No keys in the repo. Copy `.env.example` to `.env` (gitignored) and fill in your own:

- `CONTEXT7_API_KEY` — optional (context7 has a free tier).
- `GEMINI_API_KEY` + `GRAPHIFY_GEMINI_MODEL(S)` — for the vault's `graphify` graph.
- `MAGIC_API_KEY` — for the `magic` MCP (21st.dev UI components).

**Runtime** secrets live in `~/.config/brain.env` instead, outside any repo: `install.sh`
creates it with mode `600` if missing. Never put keys in `~/.claude/settings.json`.

Where to get them and how to verify them, one step at a time:
**[`docs/MANUAL-STEPS.md`](docs/MANUAL-STEPS.md)**, which also covers the Exa connector and
the Groq key for the `watch` skill.

## Personal layer (optional)

The public repo ships only an **empty scaffold** of the vault (`brain-scaffold/`). To
restore YOUR data (`~/brain`: conversations, wiki, memory) on a new device, keep it in a
private repo or backup and overlay it:

```bash
sh install.sh --personal=/path/to/your/brain-backup
```

The backup also covers Claude Code's **auto-memory**: the live location
(`~/.claude/projects/<home>/memory/`) is a symlink to `~/brain/claude-memory/`, so memory
lives inside the vault, is versioned with its git and is restored along with it. The
installer recreates the symlink after the overlay (on Windows: use WSL).

## Windows

The config runs on native Windows (Git Bash), but there are traps that **fail silently**
instead of raising an error: `python3` is a Microsoft Store alias that executes nothing,
Git Bash `/tmp/...` paths are not the ones a native python sees, and a cp1252 console
crashes on any UTF-8 output. All reproduced and fixed:
**[`docs/WINDOWS.md`](docs/WINDOWS.md)**.

Read it before touching plugin hooks or scripts: publishing a change to the hooks requires
bumping the plugin version, otherwise the update is a no-op.

## Tests

```bash
sh tests/run.sh
```

Pure shell tests (no framework). Syntax validation of the `.ps1` files needs `pwsh`
(otherwise it is skipped with `SKIP`).

## Project status

See [`docs/STATUS.md`](docs/STATUS.md): completed tasks, open follow-ups, operational notes.
