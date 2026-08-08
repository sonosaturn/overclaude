---
name: conversation-log
description: >-
  Keeps the curated conversation log in ~/brain/conversations (AutoBrain style). Activated
  automatically on every session by the SessionStart hook, which creates the file and writes
  its path to ~/brain/conversations/.current-session. Rules: store the user's prompts
  VERBATIM and SUMMARISE Claude's answers WITHOUT code blocks, overwriting the current
  session's file on every turn.
---

# Skill: conversation-log

Records conversations in the vault, a "snapshot" refreshed on every turn.

## Active file
The path of the current session's file is in `~/brain/conversations/.current-session`
(the SessionStart hook creates it). **Read that file** to know which `Conv_*.md` to update.
If it is missing (e.g. a first session before the hook), create one: `Conv_<DD-MM-YY_HH-MM>.md`
with the session start time, and write the path into the marker file.

## When to update
On **every turn** (after answering), **overwrite** the active file with the log updated from
the start of the session to now, **and update this session's line in `INDEX.md`** (see
§ Recall index). Same file for the whole session; a **new file** is only born with a new
session (the hook does that).

## The `<!-- curated -->` marker (IMPORTANT)
When you write the log following this skill, **always** include the line `<!-- curated -->`
right after the header (see Format). It is the signal that the file is curated by the model.

A **`Stop` hook** (`log-session.py`, shipped with the plugin) acts as a deterministic
parachute at the end of every turn:

- **No marker** → regenerates the whole file from the `.jsonl` transcript: prompts verbatim,
  answers with code stripped. The log is never empty.
- **Marker present, but turns missing** → it rewrites nothing you curated: it only appends
  the turns that are not in the file, under a separator that flags them as automatic. Covers
  the case where you curate the first turns and then skip.
- **Marker present and all turns there** → it touches nothing. Your version wins.

So: **curate the log yourself**, that is always the better version. The parachute exists for
the sessions where you skip, not to replace you.

## Content rules (strict)
- **User prompts**: copied **VERBATIM**, changing nothing.
- **Claude's answers**: **summarised**, in condensed form.
  - **No code blocks.** For file changes write: `modifica su "<path>": <explanation>`. For
    commands: `eseguito <command>: <outcome>`.
  - No long output: only decisions, actions, outcomes, files touched.
- Language: the same as the conversation.

### Why the format below is in Italian

The vault is private and this setup's conversations happen in Italian, so the log's structural
strings (`# Conversazione`, `## HH:MM — Utente`, `> Log curato…`, `**Collegamenti:**`) are
Italian, and every existing `Conv_*.md` uses them. They are the file's chrome, not its content.

**To switch them to your own language**, change the same strings in all four places that write
them — they must agree, or the Stop hook will not recognise its own header:

| Where | What to change |
|---|---|
| this file, § Format | the template you follow when curating |
| `hooks/new-session.sh` | the header `printf` lines (the `.sh` variant) |
| `hooks/new-session.ps1` | the `$header` string (the Windows variant) |
| `hooks/log-session.py` | `header_lines()` fallback, `render_turn()` (`— Utente`, `## Claude`, `(nessuna risposta testuale)`), `GAP_MARKER`, `strip_code()`'s `[codice omesso]` |

`brain-embed` also reads the `**Collegamenti:**` line to tag a conversation with its project: if
you rename it, update `_project_of()` in `bin/brain-embed` as well. Do not translate
`<!-- curated -->`: it is a machine marker, not prose. Existing logs keep the old wording — the
hook matches turns on prompt text, not on headings, so a mixed vault still works.

## `[[...]]` wikilinks (for the graph)
Conversations must become **connected nodes** in the graph (Obsidian/graphify), not orphan
files. Only `[[wikilink]]` creates an edge; markdown links `[text](file.md)` do not.
- **A `**Collegamenti:**` line** at the top of the file (after the header): lists the projects
  and recurring entities touched, each as `[[name]]`. Use the **same names** as the wiki pages
  or projects where they exist (e.g. `[[ricing-hyprland]]`, `[[brain-KB]]`,
  `[[config-repo-pubblica]]`), so the node resolves instead of staying "unresolved".
- Inline: at the **first mention** of a project or wiki page in the body, write it as
  `[[name]]`. Do not wikilink every repetition — only the first, and only concepts that
  deserve a node (projects, themes, wiki pages), not code files or commands.
- Consistent kebab-case names, identical across sessions: two spellings = two nodes.

## Format
```
# Conversazione DD/MM/YYYY HH:MM

> Log curato. Prompt utente: verbatim. Risposte Claude: riassunte, senza blocchi di codice.

<!-- curated -->

**Collegamenti:** [[progetto-1]] · [[tema-o-pagina-wiki]] · [[altro-progetto]]

## HH:MM — Utente
<prompt verbatim>

## Claude
- <action/decision, with [[project]] wikilinked at first mention>
- modifica su "path/file": <explanation>
- eseguito <command>: <short outcome>

## HH:MM — Utente
...
```

## Recall index (`INDEX.md`)
`~/brain/conversations/INDEX.md` is the curated TOC used for automatic recall (see the rule in
`~/.claude/CLAUDE.md`). Add or update the current session's line **on every turn**, right
after rewriting the `Conv_*.md`:

```
- [Conv_DD-MM-YY_HH-MM](Conv_DD-MM-YY_HH-MM.md) — DD/MM HH:MM · <short themes, semicolon-separated> · *progetti:* [[project-1]] [[project-2]]
```

One line per session, chronological order. It is the "search surface": it must be enough to
decide which `Conv_*.md` to open without reading them all. No code blocks.

Rewrite the line each turn as the session grows: early on it says what the session opened
with, by the end it says what it did. **Do not defer it to the end of the session** — a
session ends when the user closes the terminal, so there is no final turn to run it in, and
the `Stop` hook's parachute covers only the `Conv_*.md`, never this file. Deferring means it
never happens.

## Notes
- The vault is committed automatically per milestone (see `~/.claude/CLAUDE.md`): the
  `INDEX.md` line rides along with the current milestone's commit, like the log itself.
- The `.current-session` marker must not be versioned (see the vault's .gitignore).
