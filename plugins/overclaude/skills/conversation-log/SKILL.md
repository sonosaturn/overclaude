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
the start of the session to now. Same file for the whole session; a **new file** is only born
with a new session (the hook does that).

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
- Language: the same as the conversation. The vault is private, so the log (and the Italian
  wording of the format below) follows how the user actually talks.

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
`~/.claude/CLAUDE.md`). **At the end of a session** (or once the themes are clear) add or
update the current session's line:

```
- [Conv_DD-MM-YY_HH-MM](Conv_DD-MM-YY_HH-MM.md) — DD/MM HH:MM · <short themes, semicolon-separated> · *progetti:* [[project-1]] [[project-2]]
```

One line per session, chronological order. It is the "search surface": it must be enough to
decide which `Conv_*.md` to open without reading them all. No code blocks.

## Notes
- The vault is committed automatically per milestone (see `~/.claude/CLAUDE.md`): the
  end-of-session `INDEX.md` update belongs to the current milestone's commit.
- The `.current-session` marker must not be versioned (see the vault's .gitignore).
