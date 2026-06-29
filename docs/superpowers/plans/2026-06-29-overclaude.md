# OverClaude Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the public `overclaude` repo that auto-configures a fresh Claude Code into the reference advanced setup (plugins, skills, MCP, hooks, second-brain) on Linux/macOS/Windows.

**Architecture:** Approach C — third-party components are *orchestrated* via their official installers (driven by a single `components.manifest`), never re-hosted. The user's own pieces (`brain` + `conversation-log` skills, `new-session` SessionStart hook) ship as a Claude Code plugin in this repo's own marketplace. A thin, idempotent, cross-platform installer wires everything and merges config non-destructively into `~/.claude`.

**Tech Stack:** POSIX sh + PowerShell (installers), `jq` (JSON merge/validation), Node-based Claude Code plugin format, plain assert-based shell tests (no framework).

## Global Constraints

- Slug `overclaude`; tagline "Claude on steroids" (repo description only).
- **Zero secrets in repo:** only `.env.example` with placeholders; `.env` gitignored; never `.credentials.json`.
- **Zero absolute paths:** use `${CLAUDE_PLUGIN_ROOT}` (plugin/hooks) and `$HOME` (scripts). Forbidden literal: `/home/xsaturn`.
- **Zero personal data:** only an empty `brain-scaffold/`; real vault data lives in the optional layer-2 repo.
- **Idempotent installer:** every step checks state before acting; re-running is safe and non-destructive.
- **Cross-platform:** `install.sh` (Linux/macOS) + `install.ps1` (Windows); shared data in `lib/`.
- Tests are plain shell scripts that `exit 1` on failure — no bats/pytest.
- Commit after every task.

---

### Task 1: Repo skeleton, gitignore, marketplace + plugin manifests

**Files:**
- Create: `/home/xsaturn/overclaude/.gitignore`
- Create: `/home/xsaturn/overclaude/.claude-plugin/marketplace.json`
- Create: `/home/xsaturn/overclaude/plugins/overclaude/.claude-plugin/plugin.json`
- Test: `/home/xsaturn/overclaude/tests/test_manifests.sh`

**Interfaces:**
- Produces: a valid Claude Code marketplace at repo root exposing one plugin named `overclaude`. Plugin root path: `plugins/overclaude/`.

- [ ] **Step 1: Write the failing test**

```sh
# tests/test_manifests.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required to run tests"

jq -e . "$root/.claude-plugin/marketplace.json" >/dev/null || fail "marketplace.json invalid JSON"
jq -e . "$root/plugins/overclaude/.claude-plugin/plugin.json" >/dev/null || fail "plugin.json invalid JSON"

# marketplace must reference the overclaude plugin by source path
jq -e '.plugins[] | select(.name=="overclaude") | .source=="./plugins/overclaude"' \
  "$root/.claude-plugin/marketplace.json" >/dev/null || fail "marketplace missing overclaude plugin source"

jq -e '.name=="overclaude"' "$root/plugins/overclaude/.claude-plugin/plugin.json" >/dev/null \
  || fail "plugin.json name != overclaude"

echo "PASS test_manifests"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_manifests.sh`
Expected: FAIL (files do not exist yet)

- [ ] **Step 3: Create the files**

`.gitignore`:
```gitignore
.env
*.local
.DS_Store
node_modules/
```

`.claude-plugin/marketplace.json`:
```json
{
  "name": "overclaude",
  "owner": { "name": "xsaturn" },
  "plugins": [
    {
      "name": "overclaude",
      "source": "./plugins/overclaude",
      "description": "Brain second-brain skills + conversation-log + SessionStart hook"
    }
  ]
}
```

`plugins/overclaude/.claude-plugin/plugin.json`:
```json
{
  "name": "overclaude",
  "version": "0.1.0",
  "description": "Second-brain (brain, conversation-log) and conversation logging hook for Claude Code."
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_manifests.sh`
Expected: `PASS test_manifests`

- [ ] **Step 5: Commit**

```bash
git add .gitignore .claude-plugin plugins/overclaude/.claude-plugin tests/test_manifests.sh
git commit -m "feat: repo skeleton + marketplace and plugin manifests"
```

---

### Task 2: Bundle `brain` and `conversation-log` skills into the plugin

Copy the two existing user skills into the plugin, stripped of any absolute path or machine-specific reference.

**Files:**
- Create: `plugins/overclaude/skills/brain/SKILL.md` (from `~/.claude/skills/brain/SKILL.md`)
- Create: `plugins/overclaude/skills/conversation-log/SKILL.md` (from `~/.claude/skills/conversation-log/SKILL.md`)
- Copy any support files those skills reference (check each skill dir for extra files).
- Test: `tests/test_skills_clean.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: two skills loadable by the plugin. Skill names preserved: `brain`, `conversation-log`.

- [ ] **Step 1: Write the failing test**

```sh
# tests/test_skills_clean.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
for s in brain conversation-log; do
  f="$root/plugins/overclaude/skills/$s/SKILL.md"
  [ -f "$f" ] || fail "missing $f"
  head -1 "$f" | grep -q '^---' || fail "$s SKILL.md missing frontmatter"
  grep -q "^name: $s" "$f" || fail "$s SKILL.md name mismatch"
done
# no absolute home paths anywhere in the bundled skills
! grep -rIn '/home/xsaturn' "$root/plugins/overclaude/skills" || fail "absolute path leaked into skills"
echo "PASS test_skills_clean"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_skills_clean.sh`
Expected: FAIL (skill files missing)

- [ ] **Step 3: Copy and sanitize the skills**

```bash
mkdir -p plugins/overclaude/skills
cp -r ~/.claude/skills/brain plugins/overclaude/skills/brain
cp -r ~/.claude/skills/conversation-log plugins/overclaude/skills/conversation-log
# Replace any absolute home references with $HOME / ~ in prose:
grep -rIl '/home/xsaturn' plugins/overclaude/skills | while read -r f; do
  sed -i 's#/home/xsaturn#$HOME#g' "$f"
done
```

Then manually read both SKILL.md files and confirm: paths use `~`/`$HOME`, no Gemini key, no machine-specific assumptions. The `brain` skill references `~/brain`, `~/.config/brain.env`, and the `graphify-run.sh` wrapper — keep those as `~`-relative (they are created by the installer / live in the user's home, not the plugin).

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_skills_clean.sh`
Expected: `PASS test_skills_clean`

- [ ] **Step 5: Commit**

```bash
git add plugins/overclaude/skills tests/test_skills_clean.sh
git commit -m "feat: bundle brain and conversation-log skills into plugin"
```

---

### Task 3: SessionStart hook (`new-session`) — POSIX + PowerShell + hooks.json

Port the existing `~/brain/conversations/new-session.sh` into the plugin, path-independent via `${CLAUDE_PLUGIN_ROOT}` is NOT needed (the hook writes to `~/brain`, not the plugin dir), but the hook command path in `hooks.json` MUST use `${CLAUDE_PLUGIN_ROOT}`.

**Files:**
- Create: `plugins/overclaude/hooks/new-session.sh`
- Create: `plugins/overclaude/hooks/new-session.ps1`
- Create: `plugins/overclaude/hooks/hooks.json`
- Test: `tests/test_hook.sh`

**Interfaces:**
- Produces: a SessionStart hook (matcher `startup|resume|clear`) that creates `~/brain/conversations/Conv_<DD-MM-YY_HH-MM>.md`, writes `~/brain/conversations/.current-session`, and prints the "CONVERSATION LOG ATTIVO" context line to stdout.

- [ ] **Step 1: Write the failing test**

```sh
# tests/test_hook.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required"

jq -e . "$root/plugins/overclaude/hooks/hooks.json" >/dev/null || fail "hooks.json invalid"
jq -e '.hooks.SessionStart[0].matcher=="startup|resume|clear"' \
  "$root/plugins/overclaude/hooks/hooks.json" >/dev/null || fail "wrong matcher"
grep -q 'CLAUDE_PLUGIN_ROOT' "$root/plugins/overclaude/hooks/hooks.json" || fail "hook path not plugin-relative"

# Functional: run the POSIX hook against a temp HOME and check it created the session file.
tmp="$(mktemp -d)"
HOME="$tmp" sh "$root/plugins/overclaude/hooks/new-session.sh" >"$tmp/out.txt"
ls "$tmp/brain/conversations/"Conv_*.md >/dev/null 2>&1 || fail "no Conv file created"
[ -f "$tmp/brain/conversations/.current-session" ] || fail "no .current-session marker"
grep -q 'CONVERSATION LOG ATTIVO' "$tmp/out.txt" || fail "context line not printed"
rm -rf "$tmp"
echo "PASS test_hook"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_hook.sh`
Expected: FAIL (hook files missing)

- [ ] **Step 3: Create the hook files**

`plugins/overclaude/hooks/new-session.sh` (port of the original, unchanged logic):
```sh
#!/usr/bin/env bash
set -euo pipefail
dir="$HOME/brain/conversations"
mkdir -p "$dir"
ts="$(date +%d-%m-%y_%H-%M)"
file="$dir/Conv_${ts}.md"
if [ ! -f "$file" ]; then
  {
    printf '# Conversazione %s\n\n' "$(date '+%d/%m/%Y %H:%M')"
    printf '> Log curato. Prompt utente: verbatim. Risposte Claude: riassunte, senza blocchi di codice.\n'
  } > "$file"
fi
printf '%s\n' "$file" > "$dir/.current-session"
printf 'CONVERSATION LOG ATTIVO: %s\n' "$file"
printf 'Aggiorna questo file a ogni turno seguendo la skill "conversation-log": prompt utente verbatim, tue risposte riassunte senza blocchi di codice, sovrascrivendo sempre questo stesso file.\n'
```

`plugins/overclaude/hooks/new-session.ps1` (Windows equivalent):
```powershell
$dir = Join-Path $HOME 'brain/conversations'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$ts = Get-Date -Format 'dd-MM-yy_HH-mm'
$file = Join-Path $dir "Conv_$ts.md"
if (-not (Test-Path $file)) {
  $header = "# Conversazione $(Get-Date -Format 'dd/MM/yyyy HH:mm')`n`n> Log curato. Prompt utente: verbatim. Risposte Claude: riassunte, senza blocchi di codice."
  Set-Content -Path $file -Value $header -Encoding UTF8
}
Set-Content -Path (Join-Path $dir '.current-session') -Value $file -Encoding UTF8
Write-Output "CONVERSATION LOG ATTIVO: $file"
Write-Output 'Aggiorna questo file a ogni turno seguendo la skill "conversation-log": prompt utente verbatim, tue risposte riassunte senza blocchi di codice, sovrascrivendo sempre questo stesso file.'
```

`plugins/overclaude/hooks/hooks.json` (Claude Code picks `.sh` on Unix, `.ps1` on Windows via the wrapper script chosen by the installer — here we register the POSIX one; the Windows installer rewrites the command to the `.ps1`. ponytail: single source, installer adapts):
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          { "type": "command", "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/new-session.sh\"" }
        ]
      }
    ]
  }
}
```

Make the POSIX hook executable: `chmod +x plugins/overclaude/hooks/new-session.sh`.

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_hook.sh`
Expected: `PASS test_hook`

- [ ] **Step 5: Commit**

```bash
git add plugins/overclaude/hooks tests/test_hook.sh
git commit -m "feat: SessionStart new-session hook (posix + powershell)"
```

---

### Task 4: `brain-scaffold/` — empty vault skeleton

**Files:**
- Create: `brain-scaffold/BRAIN.md` (schema/workflow doc — generic, from `~/brain/BRAIN.md` stripped of personal entries)
- Create: `brain-scaffold/.gitignore` (from `~/brain/.gitignore`)
- Create: `brain-scaffold/sources/.gitkeep`, `brain-scaffold/wiki/.gitkeep`, `brain-scaffold/conversations/.gitkeep`, `brain-scaffold/bin/graphify-run.sh`
- Test: `tests/test_scaffold.sh`

**Interfaces:**
- Produces: a vault skeleton the installer copies to `~/brain` when absent. No personal notes/conversations.

- [ ] **Step 1: Write the failing test**

```sh
# tests/test_scaffold.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
[ -f "$root/brain-scaffold/BRAIN.md" ] || fail "no BRAIN.md"
for d in sources wiki conversations bin; do
  [ -d "$root/brain-scaffold/$d" ] || fail "missing dir $d"
done
# scaffold must contain no real conversation logs
! ls "$root/brain-scaffold/conversations/"Conv_*.md >/dev/null 2>&1 || fail "scaffold leaks conversations"
! grep -rIn '/home/xsaturn' "$root/brain-scaffold" || fail "absolute path in scaffold"
echo "PASS test_scaffold"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_scaffold.sh`
Expected: FAIL

- [ ] **Step 3: Build the scaffold**

```bash
mkdir -p brain-scaffold/sources brain-scaffold/wiki brain-scaffold/conversations brain-scaffold/bin
touch brain-scaffold/sources/.gitkeep brain-scaffold/wiki/.gitkeep brain-scaffold/conversations/.gitkeep
cp ~/brain/.gitignore brain-scaffold/.gitignore
cp ~/brain/bin/graphify-run.sh brain-scaffold/bin/graphify-run.sh
```

Create `brain-scaffold/BRAIN.md` from `~/brain/BRAIN.md` but keep ONLY the schema + workflow (ingest/query/lint) sections; delete any personal index/log entries. Sanitize absolute paths to `~`.

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_scaffold.sh`
Expected: `PASS test_scaffold`

- [ ] **Step 5: Commit**

```bash
git add brain-scaffold tests/test_scaffold.sh
git commit -m "feat: empty brain vault scaffold"
```

---

### Task 5: Config templates (settings, global CLAUDE.md, rules) + `.env.example`

**Files:**
- Create: `config/settings.template.json`
- Create: `config/CLAUDE.md.template`
- Create: `config/rules/context7.md` (copy from `~/.claude/rules/context7.md`)
- Create: `.env.example`
- Test: `tests/test_config.sh`

**Interfaces:**
- Produces: `settings.template.json` containing the managed keys (model, theme, statusLine, hooks for SessionStart + gitnexus Pre/PostToolUse, enabledPlugins, extraKnownMarketplaces) with NO absolute paths and NO secrets. Consumed by `lib/merge-settings` (Task 8).

- [ ] **Step 1: Write the failing test**

```sh
# tests/test_config.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required"
jq -e . "$root/config/settings.template.json" >/dev/null || fail "settings.template.json invalid"
! grep -RIn '/home/xsaturn' "$root/config" || fail "absolute path in config"
# no live secrets: the context7 key pattern must not appear
! grep -RIn 'ctx7sk-' "$root/config" "$root/.env.example" || fail "secret leaked"
grep -q 'CONTEXT7_API_KEY' "$root/.env.example" || fail ".env.example missing CONTEXT7_API_KEY"
grep -q 'GEMINI_API_KEY' "$root/.env.example" || fail ".env.example missing GEMINI_API_KEY"
echo "PASS test_config"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_config.sh`
Expected: FAIL

- [ ] **Step 3: Create the config files**

`config/settings.template.json` (paths use `${CLAUDE_PLUGIN_ROOT}` where Claude Code expands it; the gitnexus hooks are registered by `gitnexus setup`, so we do NOT duplicate them here — only our SessionStart hook comes from the plugin, so settings.template carries model/theme/statusLine/plugins only):
```json
{
  "model": "opus",
  "theme": "dark",
  "enabledPlugins": {
    "superpowers@superpowers-dev": true,
    "ponytail@ponytail": true,
    "overclaude@overclaude": true
  },
  "extraKnownMarketplaces": {
    "superpowers-dev": { "source": { "source": "github", "repo": "obra/superpowers" } },
    "ponytail": { "source": { "source": "github", "repo": "DietrichGebert/ponytail" } }
  }
}
```
> Note: SessionStart + gitnexus hooks are NOT in settings.template.json. The SessionStart hook ships via the plugin's `hooks.json` (Task 3); the gitnexus hooks are generated by `gitnexus setup`. The ponytail statusLine is registered by the ponytail plugin itself. This keeps the template free of absolute/versioned paths. (ponytail: less to maintain, no path drift.)

`config/CLAUDE.md.template` — a GENERIC global instructions file: the brain auto-recall rules and the brain auto-commit rules, with `~/brain` references kept relative. Strip the ricing-specific project block entirely (that belongs to layer 2). Keep the context7 rule pointer.

`.env.example`:
```dotenv
# Copy to .env and fill in. .env is gitignored — never commit real keys.
CONTEXT7_API_KEY=
GEMINI_API_KEY=
GRAPHIFY_GEMINI_MODEL=gemini-3.5-flash
GRAPHIFY_GEMINI_MODELS=gemini-3.5-flash,gemini-3-flash-preview,gemini-3.1-flash-lite
```

`config/rules/context7.md`: `cp ~/.claude/rules/context7.md config/rules/context7.md`.

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_config.sh`
Expected: `PASS test_config`

- [ ] **Step 5: Commit**

```bash
git add config .env.example tests/test_config.sh
git commit -m "feat: config templates + .env.example (sanitized, no secrets)"
```

---

### Task 6: `lib/detect-os.sh` — OS + package manager detection

**Files:**
- Create: `lib/detect-os.sh`
- Test: `tests/test_detect_os.sh`

**Interfaces:**
- Produces: `detect_pkg_mgr()` → echoes one of `pacman|apt-get|dnf|zypper|brew|unknown`; `detect_os()` → echoes `linux|macos|unknown`. Both sourced by `install.sh`.

- [ ] **Step 1: Write the failing test**

```sh
# tests/test_detect_os.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
. "$root/lib/detect-os.sh"
# detect_pkg_mgr must return a known token (whatever this machine has, or unknown)
m="$(detect_pkg_mgr)"
case "$m" in pacman|apt-get|dnf|zypper|brew|unknown) : ;; *) fail "bad pkg mgr: $m" ;; esac
o="$(detect_os)"
case "$o" in linux|macos|unknown) : ;; *) fail "bad os: $o" ;; esac
echo "PASS test_detect_os"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_detect_os.sh`
Expected: FAIL (lib missing)

- [ ] **Step 3: Implement**

`lib/detect-os.sh`:
```sh
# shellcheck shell=sh
detect_os() {
  case "$(uname -s)" in
    Linux) echo linux ;;
    Darwin) echo macos ;;
    *) echo unknown ;;
  esac
}
detect_pkg_mgr() {
  for m in pacman apt-get dnf zypper brew; do
    if command -v "$m" >/dev/null 2>&1; then echo "$m"; return 0; fi
  done
  echo unknown
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_detect_os.sh`
Expected: `PASS test_detect_os`

- [ ] **Step 5: Commit**

```bash
git add lib/detect-os.sh tests/test_detect_os.sh
git commit -m "feat: OS and package-manager detection"
```

---

### Task 7: `lib/merge-settings.sh` — non-destructive settings.json merge

**Files:**
- Create: `lib/merge-settings.sh`
- Test: `tests/test_merge_settings.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `merge_settings <existing.json|/dev/null> <template.json>` → prints merged JSON to stdout. Template values win on key conflicts (so re-running updates managed keys); keys present only in existing are preserved. If existing is missing/empty, output = template. Used by `install.sh`.

- [ ] **Step 1: Write the failing test**

```sh
# tests/test_merge_settings.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || fail "jq required"
. "$root/lib/merge-settings.sh"
tmp="$(mktemp -d)"
printf '{"model":"sonnet","theme":"light","permissions":{"allow":["X"]}}' > "$tmp/existing.json"
printf '{"model":"opus","theme":"dark","enabledPlugins":{"overclaude@overclaude":true}}' > "$tmp/tmpl.json"
out="$(merge_settings "$tmp/existing.json" "$tmp/tmpl.json")"
echo "$out" | jq -e '.model=="opus"' >/dev/null || fail "template did not win on model"
echo "$out" | jq -e '.permissions.allow[0]=="X"' >/dev/null || fail "existing key lost"
echo "$out" | jq -e '.enabledPlugins["overclaude@overclaude"]==true' >/dev/null || fail "template key missing"
# missing existing -> output equals template
out2="$(merge_settings /nonexistent "$tmp/tmpl.json")"
echo "$out2" | jq -e '.model=="opus"' >/dev/null || fail "missing-existing path broken"
rm -rf "$tmp"
echo "PASS test_merge_settings"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_merge_settings.sh`
Expected: FAIL

- [ ] **Step 3: Implement**

`lib/merge-settings.sh`:
```sh
# shellcheck shell=sh
# merge_settings EXISTING TEMPLATE -> merged JSON on stdout.
# Recursive object merge; template wins on scalar conflicts; existing-only keys kept.
# ponytail: arrays are replaced by template's version (not concatenated). If a user
# hand-adds custom hooks/permissions arrays under a managed key, re-running overwrites
# that array. Upgrade path: switch to a keyed deep-merge if that ever bites.
merge_settings() {
  existing="$1"; template="$2"
  if [ -f "$existing" ] && [ -s "$existing" ]; then
    jq -s '.[0] * .[1]' "$existing" "$template"
  else
    jq '.' "$template"
  fi
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_merge_settings.sh`
Expected: `PASS test_merge_settings`

- [ ] **Step 5: Commit**

```bash
git add lib/merge-settings.sh tests/test_merge_settings.sh
git commit -m "feat: non-destructive settings.json merge"
```

---

### Task 8: `lib/components.manifest` + `lib/run-component.sh` dispatcher

**Files:**
- Create: `lib/components.manifest`
- Create: `lib/run-component.sh`
- Test: `tests/test_dispatch.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `run_component <type> <name> <arg>` that, in `DRY_RUN=1` mode, echoes the exact command it would run; otherwise executes it. Types: `plugin` (marketplace add+install), `mcp` (claude mcp add), `cmd` (raw shell), `npm-global`, `uv-tool`, `skills-cli` (`npx skills@latest add`). Driven by `components.manifest` (one `type|name|arg` line per component).

- [ ] **Step 1: Write the failing test**

```sh
# tests/test_dispatch.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
. "$root/lib/run-component.sh"
DRY_RUN=1
out="$(run_component mcp playwright 'npx @playwright/mcp@latest')"
echo "$out" | grep -q 'claude mcp add playwright' || fail "mcp dispatch wrong: $out"
out="$(run_component plugin ponytail 'DietrichGebert/ponytail')"
echo "$out" | grep -q 'plugin marketplace add DietrichGebert/ponytail' || fail "plugin dispatch wrong"
out="$(run_component skills-cli grill-me 'mattpocock/skills')"
echo "$out" | grep -q 'npx skills@latest add mattpocock/skills' || fail "skills-cli dispatch wrong"
# manifest is parseable: every non-comment line has 3 pipe-fields
awk -F'|' 'NF && $0 !~ /^#/ && NF!=3 {print; exit 1}' "$root/lib/components.manifest" || fail "manifest malformed"
echo "PASS test_dispatch"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_dispatch.sh`
Expected: FAIL

- [ ] **Step 3: Implement dispatcher + manifest**

`lib/run-component.sh`:
```sh
# shellcheck shell=sh
# run_component TYPE NAME ARG. With DRY_RUN=1, echo the command instead of running it.
_rc_exec() { if [ "${DRY_RUN:-0}" = "1" ]; then echo "$*"; else eval "$*"; fi; }
run_component() {
  type="$1"; name="$2"; arg="$3"
  case "$type" in
    plugin)     _rc_exec "claude plugin marketplace add $arg && claude plugin install ${name}@${name}" ;;
    mcp)        _rc_exec "claude mcp add $name -- $arg" ;;
    cmd)        _rc_exec "$arg" ;;
    npm-global) _rc_exec "npm install -g $arg" ;;
    uv-tool)    _rc_exec "uv tool install $arg" ;;
    skills-cli) _rc_exec "npx skills@latest add $arg" ;;
    *) echo "unknown component type: $type" >&2; return 1 ;;
  esac
}
```
> Note: `claude plugin marketplace add` / `claude plugin install` are the non-interactive CLI forms of the `/plugin` slash commands. Verify exact subcommands with `claude plugin --help` during implementation and adjust if the CLI differs; the dispatcher localizes any such fix to one place.

`lib/components.manifest`:
```
# type|name|arg   — single source of truth for third-party components
plugin|superpowers|obra/superpowers
plugin|ponytail|DietrichGebert/ponytail
npm-global|gitnexus|gitnexus
uv-tool|markitdown|markitdown[all]
uv-tool|graphify|graphify[gemini]
mcp|context7|npx -y @upstash/context7-mcp
mcp|playwright|npx @playwright/mcp@latest
skills-cli|find-skills|vercel-labs/skills
skills-cli|skill-creator|anthropics/skills
skills-cli|handoff|mattpocock/skills
skills-cli|grill-me|mattpocock/skills
cmd|caveman|curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash
cmd|impeccable|npx -y impeccable install
cmd|gitnexus-setup|gitnexus setup
```
> `context7` needs its API key appended at install time from `.env`; `install.sh` handles that (Task 9), so the manifest keeps the base command only.

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_dispatch.sh`
Expected: `PASS test_dispatch`

- [ ] **Step 5: Commit**

```bash
git add lib/components.manifest lib/run-component.sh tests/test_dispatch.sh
git commit -m "feat: component manifest + dispatcher (dry-run testable)"
```

---

### Task 9: `install.sh` — POSIX orchestrator (Linux/macOS)

Wires the tested libs into the 8-step flow. Keep it thin: it loops the manifest and calls the libs.

**Files:**
- Create: `install.sh`
- Test: `tests/test_install_dryrun.sh`

**Interfaces:**
- Consumes: `lib/detect-os.sh`, `lib/merge-settings.sh`, `lib/run-component.sh`, `lib/components.manifest`, `config/*`, `brain-scaffold/`, `.env.example`.
- Produces: a runnable installer. Supports `--dry-run`, `--personal <path>`, `--check`.

- [ ] **Step 1: Write the failing test**

```sh
# tests/test_install_dryrun.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
out="$(sh "$root/install.sh" --dry-run 2>&1)" || fail "dry-run exited nonzero"
echo "$out" | grep -q 'marketplace add obra/superpowers' || fail "superpowers not orchestrated"
echo "$out" | grep -q 'claude mcp add context7' || fail "context7 not orchestrated"
echo "$out" | grep -q 'claude mcp add playwright' || fail "playwright not orchestrated"
echo "$out" | grep -q 'gitnexus setup' || fail "gitnexus setup not orchestrated"
# dry-run must not touch the real ~/.claude
echo "$out" | grep -qi 'DRY-RUN' || fail "dry-run banner missing"
echo "PASS test_install_dryrun"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_install_dryrun.sh`
Expected: FAIL

- [ ] **Step 3: Implement `install.sh`**

```sh
#!/usr/bin/env sh
set -eu
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "$HERE/lib/detect-os.sh"
. "$HERE/lib/merge-settings.sh"
. "$HERE/lib/run-component.sh"

DRY_RUN=0; PERSONAL=""; CHECK=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --check) CHECK=1 ;;
    --personal=*) PERSONAL="${a#--personal=}" ;;
  esac
done
export DRY_RUN
[ "$DRY_RUN" = 1 ] && echo "=== DRY-RUN: no changes will be made ==="

if [ "$CHECK" = 1 ]; then exec sh "$HERE/verify.sh"; fi

log() { echo ">>> $*"; }

# 1. runtimes (best-effort; user installs sudo packages themselves if prompted)
mgr="$(detect_pkg_mgr)"
log "OS=$(detect_os) pkg-mgr=$mgr"
for bin in node uv git rg; do
  command -v "$bin" >/dev/null 2>&1 || log "MISSING runtime: $bin (install via $mgr)"
done

# 2-3. orchestrate components from the manifest
while IFS='|' read -r type name arg; do
  case "$type" in ''|\#*) continue ;; esac
  log "component: $type/$name"
  if [ "$name" = "context7" ] && [ -f "$HERE/.env" ]; then
    # shellcheck disable=SC1090
    . "$HERE/.env"
    [ -n "${CONTEXT7_API_KEY:-}" ] && arg="$arg --api-key $CONTEXT7_API_KEY"
  fi
  run_component "$type" "$name" "$arg" || log "WARN: $name failed (continuing)"
done < "$HERE/lib/components.manifest"

# 4. own plugin marketplace + install (this repo)
run_component plugin overclaude "$HERE" || log "WARN: overclaude plugin install failed"

# 5. merge config into ~/.claude
mkdir -p "$HOME/.claude/rules"
merged="$(merge_settings "$HOME/.claude/settings.json" "$HERE/config/settings.template.json")"
if [ "$DRY_RUN" = 1 ]; then echo "WOULD WRITE ~/.claude/settings.json"; else printf '%s\n' "$merged" > "$HOME/.claude/settings.json"; fi
[ -f "$HOME/.claude/CLAUDE.md" ] || { [ "$DRY_RUN" = 1 ] && echo "WOULD COPY CLAUDE.md" || cp "$HERE/config/CLAUDE.md.template" "$HOME/.claude/CLAUDE.md"; }
[ "$DRY_RUN" = 1 ] || cp "$HERE/config/rules/context7.md" "$HOME/.claude/rules/context7.md"

# 6. brain scaffold
if [ ! -d "$HOME/brain" ]; then
  [ "$DRY_RUN" = 1 ] && echo "WOULD SCAFFOLD ~/brain" || { cp -r "$HERE/brain-scaffold" "$HOME/brain"; (cd "$HOME/brain" && git init -q 2>/dev/null || true); }
fi
[ -n "$PERSONAL" ] && { [ "$DRY_RUN" = 1 ] && echo "WOULD OVERLAY personal from $PERSONAL" || cp -r "$PERSONAL/." "$HOME/brain/"; }

# 7. secrets
[ -f "$HERE/.env" ] || { [ "$DRY_RUN" = 1 ] && echo "WOULD CREATE .env from example" || cp "$HERE/.env.example" "$HERE/.env"; }

log "done. Run 'sh install.sh --check' to verify."
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_install_dryrun.sh`
Expected: `PASS test_install_dryrun`

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/test_install_dryrun.sh
git commit -m "feat: POSIX install orchestrator (dry-run tested)"
```

---

### Task 10: `verify.sh` — post-install self-check

**Files:**
- Create: `verify.sh`
- Test: covered by running it (it IS a check); add `tests/test_verify_runs.sh` for a smoke check.

**Interfaces:**
- Produces: prints PASS/FAIL per check and exits non-zero if any FAIL. Checks: tooling in PATH (node, uv, gitnexus, markitdown, graphify), `~/.claude/settings.json` valid + contains `overclaude@overclaude`, `~/brain` exists.

- [ ] **Step 1: Write the failing smoke test**

```sh
# tests/test_verify_runs.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fail() { echo "FAIL: $1" >&2; exit 1; }
# verify.sh must run and emit at least one CHECK line (exit code may be nonzero on a bare CI box)
out="$(sh "$root/verify.sh" 2>&1 || true)"
echo "$out" | grep -q 'CHECK' || fail "verify produced no checks"
echo "PASS test_verify_runs"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_verify_runs.sh`
Expected: FAIL (verify.sh missing)

- [ ] **Step 3: Implement `verify.sh`**

```sh
#!/usr/bin/env sh
fails=0
ck() { if eval "$2" >/dev/null 2>&1; then echo "CHECK PASS: $1"; else echo "CHECK FAIL: $1"; fails=$((fails+1)); fi; }
for b in node uv gitnexus markitdown graphify; do ck "tool $b in PATH" "command -v $b"; done
ck "settings.json valid" "jq -e . \"$HOME/.claude/settings.json\""
ck "overclaude plugin enabled" "jq -e '.enabledPlugins[\"overclaude@overclaude\"]==true' \"$HOME/.claude/settings.json\""
ck "~/brain exists" "[ -d \"$HOME/brain\" ]"
[ "$fails" -eq 0 ] && echo "ALL CHECKS PASSED" || echo "$fails CHECK(S) FAILED"
exit "$fails"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_verify_runs.sh`
Expected: `PASS test_verify_runs`

- [ ] **Step 5: Commit**

```bash
git add verify.sh tests/test_verify_runs.sh
git commit -m "feat: post-install verify self-check"
```

---

### Task 11: `install.ps1` + `verify.ps1` — Windows orchestrators

Mirror Tasks 9–10 in PowerShell. Reuse `lib/components.manifest` (parse the same `type|name|arg` lines). Register the hook command as the `.ps1` variant.

**Files:**
- Create: `install.ps1`
- Create: `verify.ps1`
- Test: `tests/test_ps_syntax.sh` (syntax-parse only — gated on `pwsh` being available)

**Interfaces:**
- Produces: Windows equivalents of `install.sh`/`verify.sh`. Same flags (`-DryRun`, `-Personal`, `-Check`). On Windows, after the plugin installs, rewrite the SessionStart hook command in `~/.claude/settings.json`/plugin to call `new-session.ps1` via `powershell` (the `.sh` won't run without WSL). Document the WSL fallback in README.

- [ ] **Step 1: Write the failing test**

```sh
# tests/test_ps_syntax.sh
#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
if ! command -v pwsh >/dev/null 2>&1; then echo "SKIP (no pwsh)"; exit 0; fi
for f in install.ps1 verify.ps1; do
  pwsh -NoProfile -Command "\$null = [System.Management.Automation.Language.Parser]::ParseFile('$root/$f',[ref]\$null,[ref]\$null); if (\$?) {exit 0} else {exit 1}" || { echo "FAIL: $f parse"; exit 1; }
done
echo "PASS test_ps_syntax"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `sh tests/test_ps_syntax.sh`
Expected: FAIL if `pwsh` present and files missing; `SKIP` otherwise (then create the files anyway).

- [ ] **Step 3: Implement `install.ps1` and `verify.ps1`**

`install.ps1` — same 8-step flow: detect winget/scoop; loop `lib/components.manifest` translating each `type` to the equivalent command (`claude plugin ...`, `claude mcp add ...`, `npm install -g`, `uv tool install`, `npx skills@latest add`, raw `cmd`); deep-merge settings via `jq` (require jq on PATH) or a PowerShell hashtable merge; copy `brain-scaffold` to `$HOME/brain`; copy `.env.example`→`.env`. Honor `-DryRun` by `Write-Output`-ing commands. Full script body:
```powershell
[CmdletBinding()]
param([switch]$DryRun, [switch]$Check, [string]$Personal)
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
function Run($cmd) { if ($DryRun) { Write-Output $cmd } else { Invoke-Expression $cmd } }
if ($DryRun) { Write-Output "=== DRY-RUN: no changes ===" }
if ($Check) { & "$Here/verify.ps1"; exit $LASTEXITCODE }

foreach ($line in Get-Content "$Here/lib/components.manifest") {
  if ($line -match '^\s*#' -or $line -notmatch '\|') { continue }
  $t,$name,$arg = $line.Split('|',3)
  switch ($t) {
    'plugin'     { Run "claude plugin marketplace add $arg"; Run "claude plugin install ${name}@${name}" }
    'mcp'        { Run "claude mcp add $name -- $arg" }
    'cmd'        { Run "$arg" }
    'npm-global' { Run "npm install -g $arg" }
    'uv-tool'    { Run "uv tool install $arg" }
    'skills-cli' { Run "npx skills@latest add $arg" }
  }
}
Run "claude plugin marketplace add `"$Here`""
Run "claude plugin install overclaude@overclaude"

$settings = Join-Path $HOME '.claude/settings.json'
New-Item -ItemType Directory -Force -Path (Split-Path $settings) | Out-Null
if ($DryRun) { Write-Output "WOULD MERGE settings.json" }
else {
  $tmpl = Get-Content "$Here/config/settings.template.json" -Raw | ConvertFrom-Json
  $base = if (Test-Path $settings) { Get-Content $settings -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
  foreach ($p in $tmpl.PSObject.Properties) { $base | Add-Member -Force -NotePropertyName $p.Name -NotePropertyValue $p.Value }
  $base | ConvertTo-Json -Depth 20 | Set-Content $settings -Encoding UTF8
}
if (-not (Test-Path (Join-Path $HOME 'brain'))) {
  if ($DryRun) { Write-Output "WOULD SCAFFOLD ~/brain" } else { Copy-Item "$Here/brain-scaffold" (Join-Path $HOME 'brain') -Recurse }
}
if ($Personal) { if ($DryRun) { Write-Output "WOULD OVERLAY $Personal" } else { Copy-Item "$Personal/*" (Join-Path $HOME 'brain') -Recurse -Force } }
if (-not (Test-Path "$Here/.env")) { if (-not $DryRun) { Copy-Item "$Here/.env.example" "$Here/.env" } }
Write-Output "done. Run '.\install.ps1 -Check' to verify."
```

`verify.ps1`:
```powershell
$fails = 0
function Ck($name,$test) { if (& $test) { Write-Output "CHECK PASS: $name" } else { Write-Output "CHECK FAIL: $name"; $script:fails++ } }
foreach ($b in 'node','uv','gitnexus','markitdown','graphify') { Ck "tool $b" { [bool](Get-Command $b -ErrorAction SilentlyContinue) } }
Ck "settings.json exists" { Test-Path (Join-Path $HOME '.claude/settings.json') }
Ck "~/brain exists" { Test-Path (Join-Path $HOME 'brain') }
if ($fails -eq 0) { Write-Output "ALL CHECKS PASSED" } else { Write-Output "$fails CHECK(S) FAILED" }
exit $fails
```

- [ ] **Step 4: Run test to verify it passes**

Run: `sh tests/test_ps_syntax.sh`
Expected: `PASS test_ps_syntax` (or `SKIP (no pwsh)` on a box without PowerShell)

- [ ] **Step 5: Commit**

```bash
git add install.ps1 verify.ps1 tests/test_ps_syntax.sh
git commit -m "feat: Windows install + verify orchestrators"
```

---

### Task 12: `tests/run.sh` aggregate + `README.md`

**Files:**
- Create: `tests/run.sh`
- Create: `README.md`

**Interfaces:**
- Produces: one command to run all shell tests; the public-facing quickstart.

- [ ] **Step 1: Write `tests/run.sh`**

```sh
#!/usr/bin/env sh
set -eu
here="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
rc=0
for t in "$here"/test_*.sh; do
  echo "--- $t"; sh "$t" || rc=1
done
[ "$rc" = 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit "$rc"
```

- [ ] **Step 2: Run the full suite**

Run: `sh tests/run.sh`
Expected: `ALL TESTS PASSED` (pwsh test may print SKIP — still passes)

- [ ] **Step 3: Write `README.md`**

Cover: what OverClaude is ("Claude on steroids"), one-line quickstart per OS, the component list (generated/kept in sync with `lib/components.manifest`), the `--personal` layer-2 explanation, the secrets/`.env` step, and the Windows SessionStart-hook/WSL caveat. Quickstart:
```bash
git clone https://github.com/<you>/overclaude && cd overclaude
cp .env.example .env   # fill in keys (optional)
sh install.sh          # or:  pwsh ./install.ps1   on Windows
sh install.sh --check
```

- [ ] **Step 4: Verify README has no secrets/abs paths**

Run: `! grep -nE '/home/xsaturn|ctx7sk-' README.md && echo OK`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add tests/run.sh README.md
git commit -m "docs: README quickstart + aggregate test runner"
```

---

## Self-Review

**Spec coverage:**
- §2a third-party orchestration → Task 8 (manifest + dispatcher), Task 9/11 (install).
- §2b own plugin (brain, conversation-log, new-session, config) → Tasks 1–5.
- §3 two-layer / `--personal` → Task 9/11.
- §4 repo structure → Tasks 1–12 collectively create every listed path.
- §5 installer 8-step flow → Task 9 (POSIX), Task 11 (Windows).
- §6 security (no secrets, no abs paths, no personal data) → enforced by tests in Tasks 2,4,5,12.
- §7 verify → Task 10/11.
- §8 cross-platform → Task 11 + Windows hook note.
- §9 risks (gitnexus-setup ordering, non-destructive merge) → manifest runs `gitnexus-setup` before our settings merge (manifest order + Task 9 step ordering); merge is template-wins-preserving (Task 7).

**Placeholder scan:** No "TBD"/"handle edge cases"/uncoded steps — every code step has real content. Two explicit verify-during-impl notes (exact `claude plugin` subcommands; BRAIN.md/CLAUDE.md manual sanitization) are bounded human-review actions, not code placeholders.

**Type consistency:** `run_component <type> <name> <arg>`, `merge_settings <existing> <template>`, `detect_pkg_mgr`/`detect_os` used identically across Tasks 6–11. Manifest format `type|name|arg` consistent in Tasks 8/9/11. Plugin id `overclaude@overclaude` consistent in Tasks 5/9/10/11.

**Open item folded into impl:** the exact Claude Code CLI subcommands for plugin install (`claude plugin ...`) must be confirmed against `claude plugin --help` in Task 8 — the dispatcher isolates any correction to one function.
