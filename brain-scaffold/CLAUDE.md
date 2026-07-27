# Project context — brain vault

Personal second brain, LLM-wiki pattern. Structure and conventions: `README.md` and `BRAIN.md`.

- `conversations/` — one markdown "snapshot" per session + `INDEX.md` (TOC). Written by the
  overclaude plugin's `SessionStart` hook and by the `overclaude:conversation-log` skill:
  user prompts **verbatim**, answers **summarised without code blocks**, overwriting the
  current session's file on every turn.
- `wiki/` — markdown pages with `[[...]]` cross-references for Obsidian.
- `claude-memory/` — Claude Code's auto-memory, symlinked here by the installer.
- `bin/brain-recall` — semantic recall; fails open to `rg` + `INDEX.md` if the key is missing.

Ingest, query and lint of the vault: the `overclaude:brain` skill. The recall **trigger** for
other sessions lives in the global `CLAUDE.md`, not here: it must fire from any folder.

## Automatic commits

**Commit automatically, without asking for confirmation**, at every unit of work finished in
the vault: an ingest completed, a set of wiki pages, a script fix, a lint pass applied.
**Not every turn and never mid-work — one milestone = one commit.**

```
cd ~/brain && git add -A && git commit -m "<type>: <clear description>"
```

`<type>` = feat | fix | docs | refactor | chore. The vault only, never `git -C` into other
repos. **No automatic push.**

## What does not belong in the vault

API keys and secrets: they live in `~/.config/brain.env`, which is outside any repo.
The vault is versioned, so treat anything you write into it as permanent.
