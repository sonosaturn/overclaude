# brain — second brain / knowledge base

Personal markdown knowledge base, maintained by the LLM (*LLM-wiki* pattern).
Obsidian vault + document ingest via **markitdown** + graph via **graphify**.

## The folders

| Folder | What it holds |
|---|---|
| `sources/` | Raw, immutable sources. What you ingest lands here and is never touched again. |
| `wiki/` | Generated pages: entities, summaries, `[[...]]` cross-references. This is where you write. |
| `conversations/` | One markdown "snapshot" per session + `INDEX.md`, the TOC recall leans on. |
| `claude-memory/` | Claude Code's auto-memory, symlinked here by the installer so it gets versioned. |
| `bin/` | Vault tooling: `brain-recall` (semantic recall), `brain-embed`, `graphify-run.sh`. |
| `graphify-out/` | Graph output. Regenerable, so not versioned. |

`BRAIN.md` describes the schema and the workflows: read it before writing into the vault.

## Use with Claude Code

The `overclaude:brain` skill implements the flows:

- "ingest `<file>` into the KB" → INGEST
- "what do I know about `<X>`?" → QUERY
- "lint the KB" → LINT

The conversation log is kept by `overclaude:conversation-log`, activated by the plugin's
`SessionStart` hook, which creates the session file and writes its path into
`conversations/.current-session`.

The log's structural strings (`# Conversazione`, `## HH:MM — Utente`, `[codice omesso]`) are in
Italian, the language this vault's conversations are held in — the body of each log follows the
conversation anyway. To move them to your own language, the conversation-log skill lists the four
files that must be changed together (`SKILL.md` § "Why the format below is in Italian").

## Opening it in Obsidian

*Open folder as vault* → this folder. The configuration in `.obsidian/` is already included
(theme, core plugins, graph view settings), so the vault is usable with no setup: the graph
view shows the `[[wikilinks]]` between pages and between conversations.

`workspace.json` is deliberately not versioned: it is the state of the open panes, it changes
on every use and only makes sense on the machine that wrote it.

## Semantic recall

`bin/brain-recall "<query>"` searches by meaning, not by string, and covers the paraphrases
`rg` misses. It needs `GEMINI_API_KEY` in `~/.config/brain.env` (never in `settings.json`:
that file lives inside a repo). Without a key or without an index it degrades to `rg` +
`INDEX.md` instead of failing.
