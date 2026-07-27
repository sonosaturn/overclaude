# Windows — how to treat this config

Everything that behaves differently on native Windows (Git Bash + Claude Code, **no WSL**).
Every entry was reproduced and fixed on a real machine (Windows 11, July 2026); none of it is
theoretical caution.

The common thread: the repo's scripts run under **Git Bash**, but the interpreters they launch
(`python`, `node`) are **native Windows binaries**. The two halves share neither paths nor
codepage — that is where almost every problem below comes from.

## 1. `python3` does not exist — and it does not fail, which is worse

Windows drops **Microsoft Store aliases** into `%LOCALAPPDATA%\Microsoft\WindowsApps`:
`python3.exe` is there, it is in `PATH`, `command -v python3` finds it. Run it and it prints
"Python was not found…" and exits **49**.

Consequence: a script that just calls `python3` does not blow up, does not log — it simply does
nothing. That is how the `Stop` hook for conversation logging stayed inert for weeks without a
single error message.

**Rule:** never hardcode `python3`. Probe the interpreter and use the first one that actually
starts (`hooks/hooks.json` does exactly this):

```sh
for p in python3 python py; do "$p" -c "" >/dev/null 2>&1 && exec "$p" "$1"; done
```

The `-c ""` probe tells the real interpreter from the alias: the stub exits ≠ 0.
This also applies inside scripts (`uv run … python3 -c` has the same flaw: use `python`, which
uv resolves correctly on both platforms).

## 2. Git Bash paths are not Python paths

`mktemp -d` returns `/tmp/tmp.XYZ`, which in Git Bash is
`C:\Users\<you>\AppData\Local\Temp\tmp.XYZ`. Handed to a native python, that same `/tmp/tmp.XYZ`
becomes `C:\tmp\tmp.XYZ`: a different folder, which python creates on the fly without
complaining. Typical result: one script writes into one directory and another reads from
another, both "successfully".

**Rule:** every path that crosses the shell → native interpreter boundary must be converted.

```sh
VAULT="$(mktemp -d)"
command -v cygpath >/dev/null 2>&1 && VAULT="$(cygpath -m "$VAULT")"
```

`cygpath -m` gives the `C:/…` form (forward slashes), digestible by both python and the shell.
The other way round, to hand a path to an `.exe` that wants backslashes: `cygpath -w`.

## 3. cp1252 console: UTF-8 output crashes the scripts

A python process's stdout in the Windows console uses the ANSI codepage (cp1252 in an Italian
locale). Printing a character outside that table — `—`, `↔`, `…`, all things a markdown vault is
full of — raises `UnicodeEncodeError` and **kills the script mid-job**.

**Rule:** at the top of every CLI that prints non-ASCII content:

```python
for _s in (sys.stdout, sys.stderr):
    _s.reconfigure(encoding="utf-8", errors="replace")
```

Same story when reading: `open()` without `encoding=` uses the codepage, not UTF-8. The vault
files and the `.jsonl` transcripts must always be opened with `encoding="utf-8"` and, if the
file may have been touched by hand, `errors="replace"` — one dirty byte must not take a hook down.

## 4. Hooks and plugins: updates go through the version

The `overclaude` plugin is served by a `directory` marketplace pointing at the local clone of
the repo. Claude Code does not read the files live, though: at install time it makes a **copy**
in `~/.claude/plugins/cache/overclaude/overclaude/<version>/`. Editing the files in the repo
changes nothing for running sessions, nor for future ones.

To publish a change to the hooks:

1. bump `version` in `plugins/overclaude/.claude-plugin/plugin.json` (without it the update is a
   no-op: same version, same cache);
2. `claude plugin marketplace update overclaude`
3. `claude plugin update overclaude@overclaude`
4. **restart** the session: hooks are loaded at startup.

Check that the cache really holds the new files:

```sh
ls ~/.claude/plugins/cache/overclaude/overclaude/<version>/hooks/
```

A hook missing from the cache raises no error: it simply does not exist. If some automatic
behaviour "does not fire", this is the first thing to check, not the code.

## 5. Statusline of the mode plugins

The `[PONYTAIL]`/`[CAVEMAN]` badges come from the `*-statusline.ps1` scripts inside the plugin
cache, whose path contains the version. `config/statusline.ps1` aggregates them by resolving the
path with a glob, so a plugin version bump does not break the statusline. The installer copies it
to `~/.claude/statusline.ps1` and writes the command into `settings.json` — the absolute path is
born there, not in the repo. `detect_os` recognises Git Bash (`MINGW*`/`MSYS*`/`CYGWIN*`) and
picks the `.ps1` variant; elsewhere it copies `statusline.sh`. Result in `settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\<you>\\.claude\\statusline.ps1\""
}
```

## 6. GitNexus

- LadybugDB's full-text (BM25) extension is not in the package: the first analysis warns that FTS
  is disabled. Install it once, with network access:
  `GITNEXUS_LBUG_EXTENSION_INSTALL=auto gitnexus analyze --repair-fts`.
- The `VECTOR` index **is not available on this platform**: semantic search falls back to an
  exact scan (10k chunk limit). Not an error worth chasing, `gitnexus doctor` reports it as such.
- The `.gitnexus/` folder (~5 MB) should not be versioned.

## 7. SessionStart hook

`new-session` exists in two variants (`.sh` and `.ps1`). On this machine the `.sh` variant under
Git Bash **works** (the `Conv_*.md` file is created on every startup); the WSL fallback stays
valid if native SessionStart hooks do not fire in your installation.

## Summary

| Symptom | Cause |
|---|---|
| A hook "does nothing", no error | `python3` → Store alias (§1) or file missing from the plugin cache (§4) |
| Two scripts work on different data | unconverted MSYS path (§2) |
| `UnicodeEncodeError` / `UnicodeDecodeError` | cp1252 codepage on read or write (§3) |
| Hook change has no effect | plugin version not bumped, or session not restarted (§4) |
