# OverClaude — Project status

Last updated: 2026-07-26

## Update 2026-07-26 (b) — repo caught up with the live config

The reverse pass compared to the usual one: not "install what is missing on the machine", but
"bring into the repo what the machine has on top". Delta found and closed:

- **`rtk`** (rtk-ai/rtk) was the only component of the live config missing from the manifest.
  Added as an idempotent `cmd` (installs only if missing, then `rtk init -g --auto-patch`, which
  writes its own `PreToolUse` hook). Along with it `config/RTK.md`, which the global `CLAUDE.md`
  pulls in via `@RTK.md`, copied into `~/.claude` by the installer.
- **Statusline**: `config/statusline.ps1` (+ its `statusline.sh` twin for POSIX) and the step that
  installs it and writes `statusLine` into `settings.json`. The absolute path is produced by the
  installer; the repo stays free of hardcoded paths.
- **`CLAUDE.md.template`**: absorbed the preamble that only lived locally (Behavioral Guidelines
  + rtk section). 199 lines, right at the ~200 the template itself declares.
- `settings.template.json`: `autoUpdatesChannel: latest`.
- `detect_os` recognises Git Bash (`MINGW*`/`MSYS*`/`CYGWIN*`) → `windows`, used to pick the
  statusline variant.
- `install.ps1` brought in line on the points it lacked entirely: `rules/`, `RTK.md`, `CLAUDE.md`
  if missing, statusline, the `.caveman-active`/`.ponytail-active` flags.
  **Still out** (known lag, the install on this machine goes through Git Bash):
  `~/.config/brain.env`, the auto-memory symlink, the scripts in `~/.local/bin` and the git
  template for auto-reindexing.
- `verify.sh`: checks for `rtk`, `RTK.md` and the statusline. `test_ps_syntax` now also uses
  `powershell` 5.1 when `pwsh` is missing → the `.ps1` files are validated for the first time.

## Update 2026-07-26 (a) — native Windows: three silent failures

Machine ↔ repo alignment session on Windows 11 + Git Bash. All three bugs found had the same
profile: **no visible error, the function simply inert**. Documented in
[`docs/WINDOWS.md`](WINDOWS.md).

- **The conversation log `Stop` hook never ran** → July's `Conv_*.md` files were empty stubs.
  Three causes stacked: (a) `python3` on Windows is the Microsoft Store alias, present in `PATH`,
  which exits 49 without executing; (b) the installed plugin was 0.1.0, older than the addition of
  `log-session.py`, and the version had never been bumped → `plugin update` was a no-op;
  (c) `log-session.py` called `build()` *inside* `open(conv_file, "w")`, which truncates the file
  before the header is re-read → the session date/time lost on every regeneration.
  Fixed: interpreter probe in `hooks.json`, plugin version to **0.2.0**, `build()` before the
  `open`, reads with `encoding="utf-8", errors="replace"`.
- **`brain-recall` crashed on print** (`UnicodeEncodeError`, cp1252 console vs `↔`/`—`):
  `reconfigure(encoding="utf-8", errors="replace")` on stdout/stderr.
- **False-negative vault self-check**: `uv run … python3 -c` (Store alias) and a test vault in an
  MSYS `/tmp/...` path that native python reads as `C:\tmp\...` → embedding and count on different
  directories. Fixed with `python` and `cygpath -m`.
- `mattpocock/skills` switched to the whole pack in the manifest; `config/skills.expected`
  regenerated (69 skills) → `install.sh --check` **ALL CHECKS PASSED**.
- GitNexus: FTS extension installed (`GITNEXUS_LBUG_EXTENSION_INSTALL=auto … --repair-fts`), BM25
  active. `VECTOR` remains unavailable on Windows (exact scan).

## Update 2026-07-06 — alignment with the live config

Synced the repo with the Claude Code config actually in use:

- **`skills-cli` dispatcher fix** (`lib/run-component.sh`): `npx skills add <repo>` installs the
  **whole** repo (verified live: `mattpocock/skills` → 38 skills). Added
  `--skill $name --agent claude --global --yes` so it installs **only** the named skill.
- **`context7-mcp` bundled** into the own plugin (`plugins/overclaude/skills/context7-mcp/`): it
  is a custom companion skill with no upstream, like brain/conversation-log.
- **Exa** documented in the README as an account-side claude.ai connector (not scriptable).
- playwright/grill-me/caveman were already in the manifest → confirmed as intended defaults and
  installed locally too (machine and manifest now match).
- **Auto-sync** (`bin/overclaude-sync.sh`): a **maintainer** PostToolUse(Bash) hook that, when a
  skill (`npx skills … add <repo> --skill <name>`) or an MCP (`claude mcp add <name> -- <cmd>`) is
  added, appends the line to the manifest, commits and **pushes** automatically → the repo keeps
  up with the live config. Wired into the personal `settings.json` (gitignored, not in the public
  repo). Ceiling: only skills/MCPs via the standard Bash commands; plugins and interactive/manual
  adds → sync by hand.

## Status: BUILD COMPLETE ✅

All 12 tasks of the [plan](superpowers/plans/2026-06-29-overclaude.md) implemented, tested and
merged into `master`. Shell suite green (10 pass, 1 skip for missing `pwsh`).

| # | Task | Commit | Status |
|---|------|--------|--------|
| 1 | Repo skeleton + manifests | `2c959ce` | ✅ |
| 2 | Bundle brain + conversation-log skills | `24adc78`, `2f7535e` | ✅ |
| 3 | SessionStart new-session hook (sh + ps1) | `185da7d` | ✅ |
| 4 | Empty brain scaffold | `97f7e09` | ✅ |
| 5 | Config template + .env.example | `299a1ff` | ✅ |
| 6 | lib/detect-os | `725562d` | ✅ |
| 7 | lib/merge-settings (non-destructive) | `0a982dc` | ✅ |
| 8 | components.manifest + dispatcher | `579da66` | ✅ |
| 9 | install.sh (POSIX) | `96aee1b` | ✅ |
| 10 | verify.sh | `40c0ce7` | ✅ |
| 11 | install.ps1 + verify.ps1 (Windows) | `42fce88` | ⚠️ see below |
| 12 | README + test runner | `79d22e0` | ✅ |

## Execution mode
Tasks 1-2 ran subagent-driven (reviewed on sonnet, approved). From Task 3 on the subagents hit the
session limit → inline execution (code taken from the plan, every test run, one commit per task).

## Plan bugs fixed along the way
- Manifest test: `NF!=3` → `NF<3` (the `caveman` line contains `| bash`; the arg may hold a pipe).
- Dispatch test: `read` without a trailing newline returned 1 under `set -e` → added `\n`.

## Safety gate (pre-publication) — passed
Zero absolute paths, zero keys, zero symlinks, `.env` untracked, scaffold with schema only +
empty placeholders, `~/.claude/settings.json` left intact after the dry run.

## Open follow-ups
- [x] ~~⚠️ `install.ps1` / `verify.ps1`: syntax NOT validated~~ — validated on 2026-07-26 on real Windows: `test_ps_syntax` falls back to `powershell` 5.1 when `pwsh` is absent, and passes. The functional lag of `install.ps1` remains (see update 26/07 b).
- [x] ~~Confirm the exact CLI subcommands~~ — verified with `claude plugin --help` (2026-06-29): `claude plugin marketplace add <source>` and `claude plugin install <plugin>@<marketplace>` are correct as they stand in `lib/run-component.sh`.
- [x] ~~Windows SessionStart hook caveat~~ — verified on native Windows 11 (2026-07-26): the `.sh` variant under Git Bash **works**, the `Conv_*.md` is created on every startup. The WSL fallback stays documented for installations where native SessionStart hooks do not fire. Real Windows caveats collected in [`docs/WINDOWS.md`](WINDOWS.md).
- [x] ~~No git remote~~ — public repo created and pushed (2026-06-29): https://github.com/sonosaturn/overclaude
- [x] ~~Personal layer 2 (`overclaude-personal`)~~ — created (2026-06-29): the real `~/brain` pushed to the **private** GitHub repo `sonosaturn/overclaude-personal`. Round trip verified (clone → `install.sh --personal=<clone>` → `WOULD OVERLAY`). The auto-memory is included: the live dir `~/.claude/projects/<home>/memory/` is a symlink to `~/brain/claude-memory/` (single source of truth, versioned with the vault); `install.sh --personal` recreates the symlink after the overlay (step 6b). The dry-run test covers the `WOULD LINK` announcement.

## Operational notes
- context7 key rotated on 2026-06-29 (the old one had been exposed in chat; regenerated).
- Local `.env` populated (context7 + Gemini), gitignored.
- The SDD ledger lives in `.superpowers/` (gitignored): it is not part of the public repo.
