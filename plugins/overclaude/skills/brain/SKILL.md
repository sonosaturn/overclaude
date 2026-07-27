---
name: brain
description: >-
  Personal knowledge base (second brain) in ~/brain, LLM-wiki pattern. Use this skill when
  the user wants to INGEST a document/URL into the KB, QUERY the knowledge base ("what do I
  know about X?", "search my brain/wiki/second brain"), or LINT/maintain the vault. Converts
  documents with markitdown, keeps markdown wiki pages with [[...]] cross-references for
  Obsidian, and can generate a graph with graphify.
---

# Skill: brain

Manages the knowledge base in `~/brain`. **Always read `~/brain/BRAIN.md` first** (the
schema: structure, page conventions, workflows). This skill is the operational execution of
those workflows.

Prerequisites already installed: `markitdown` and `graphify` in `~/.local/bin` (if not in
PATH: `~/.local/bin/markitdown`).

## Recognising the intent

- **INGEST** — "add/ingest <file|URL> into the brain", "save this in the KB".
- **QUERY** — "what do I know about X?", "search my brain", "according to my wiki…".
- **LINT** — "lint/maintain the KB", "check the wiki".

## INGEST

1. **Convert the source to markdown** inside `~/brain/sources/` (`kebab-case.md` name):
   - files (PDF/DOCX/PPTX/XLSX/HTML/audio): `markitdown "<path>" -o ~/brain/sources/<name>.md`
   - URL/HTML: `markitdown "<url>" -o ~/brain/sources/<name>.md` (or WebFetch → save the markdown)
   - if already markdown/text: copy it into `sources/` as is.
2. **Read** the converted source.
3. **Update/create the relevant wiki pages** in `~/brain/wiki/` (typically 5-15 files):
   summary, entity pages, with frontmatter (see BRAIN.md) and `[[...]]` cross-references.
   Always cite `(fonte: sources/<file>)`.
4. **Update `index.md`** (new pages under the right category) and **`log.md`** (an ingest
   line with date and source).
5. One source at a time. When done, summarise for the user what was created/touched.

## QUERY

1. Search the vault: `rg -i "<term>" ~/brain/wiki ~/brain/index.md` (and `sources/` if needed).
2. Read the relevant pages and **synthesise with citations** to the pages/sources.
3. If the exploration produces new and useful knowledge, **file it** as a new wiki page and
   update `index.md`/`log.md` (ask for confirmation if it is a big change).

## LINT

Run the checks in `BRAIN.md` § LINT:
- orphan pages: `rg -L` cross-checking the `[[links]]` against the files in `wiki/`;
- `index.md` aligned with the real files (`ls ~/brain/wiki`);
- contradictions/stale statements (targeted reading);
- missing cross-references.
Report the problems, propose fixes, record the outcome in `log.md`.

## Graph (optional)
Use the wrapper with **automatic fallback across Gemini models** (quota/overload):
`~/brain/bin/graphify-run.sh .` → extracts the graph into `graphify-out/`.
Then `GRAPHIFY_GEMINI_MODEL=<active-model> graphify cluster-only ~/brain` for `graph.html` +
`GRAPH_REPORT.md`. Requires `GEMINI_API_KEY` (from `~/.config/brain.env`).

## Git
The vault is a git repo. **Automatic commit per milestone** (rule in `~/.claude/CLAUDE.md`):
once an ingest/lint is complete, commit without asking:
`cd ~/brain && git add -A && git commit -m "<type>: <description>"`. Push stays manual.
