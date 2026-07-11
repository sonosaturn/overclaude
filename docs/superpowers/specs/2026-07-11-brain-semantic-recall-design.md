# Design — Recall semantico nel vault ~/brain (fusione da AutoBrain)

**Data:** 2026-07-11
**Stato:** approvato (design), pre-implementazione
**Contesto:** porta il layer di recall semantico (embeddings + ChromaDB) da
[AutoBrain](https://github.com/sonosaturn/AutoBrain) nel vault `~/brain` (repo `~/projects/brain`,
tooling distribuito via `overclaude`), lasciando invariato ciò che qui è già ottimo.

## Obiettivo

Aggiungere un **terzo layer di recall** — semantico, per significato — accanto ai due esistenti
(`rg` keyword + `INDEX.md` curato). Il gap odierno: `rg` trova solo parole esatte; una query
parafrasata ("come avevamo deciso il tema") non recupera la sessione giusta. Gli embeddings colmano
questo.

## Cosa si porta / si lascia / si scarta

**Portato da AutoBrain** (parti fatte meglio là):
- Recall semantico via embeddings Gemini + ChromaDB.
- Quota-guard (sentinel giornaliero UTC + backoff) — robustezza free-tier.
- Reranking graph-weighted sui `[[wikilink]]` (`_rerank`).

**Lasciato invariato** (già ottimo qui — il semantico è *additivo*, non sostitutivo):
- `rg` + `INDEX.md` come recall primario.
- `graphify` (grafo semantico LLM), `gitnexus` (code graph).
- `claude-memory/` + `MEMORY.md` (typed facts) — vedi decisione sotto.
- Pattern commit-driven, distribuzione `overclaude`.

**Scartato di AutoBrain** (non adatto qui):
- Concept-first / `_Concepts` bridge nodes (università-specifico).
- Watchdog / session_end workers (causavano lo spreco di embeddings).
- jarvis (assistente vocale, fuori scope).

## Decisione: `claude-memory/` NON viene embeddato

MEMORY.md vince nettamente sugli embeddings per i typed-facts: corpus **piccolo, curato, già
caricato in contesto a ogni sessione** → recall zero-latenza e deterministico. Gli embeddings
pagano solo oltre la soglia del context-window, che i typed-facts non superano. Embeddarli sarebbe
puro overhead ridondante. Layer semantico = `conversations/` + `wiki/` + `sources/`.

## Architettura

### 1. Store
ChromaDB `PersistentClient` in `~/brain/.chroma_db/` (gitignored). **Una sola collection** `vault`,
HNSW cosine, con metadata `type ∈ {conversation, wiki, source}`. Il targeting per-tipo si ottiene
via `where={"type": ...}` (equivalente allo split fisico a questa scala, con meno codice e query
cross-tipo possibili).

### 2. Embeddings
- Modello: Gemini `gemini-embedding-001` (3072 dim), REST `embedContent`.
- Task asimmetrici: `RETRIEVAL_DOCUMENT` in index, `RETRIEVAL_QUERY` in query.
- Chunk: 1500 char / 200 overlap.
- Key: letta da `~/.config/brain.env` (`GEMINI_API_KEY`, già presente).
- **Quota-guard**: sentinel `~/brain/.chroma_db/.quota_exhausted` (data UTC), backoff 30/60/120s
  su 429, skip zero-vector, bail dopo N fallimenti consecutivi. Portato da `graph_manager.py`.

### 3. Indexer — `bin/brain-embed.py`
- `--changed` (default, invocato dall'hook): legge i file del commit corrente
  (`git diff-tree --no-commit-id --name-only -r HEAD`), filtra `conversations/|wiki/|sources/` `*.md`,
  chunk, embedda **solo i chunk nuovi** (`doc_id = relpath::chunk::md5hash`, salta gli ID già in
  collection), setta `type` dalla cartella di primo livello.
- `--full`: backfill iniziale una tantum su tutto il vault.
- Metadata per doc: `file, path, type, chunk` (+ `project` per le conversazioni, estratto dalla riga
  `**Collegamenti:**`/`INDEX` se presente).

### 4. Query CLI — `bin/brain-recall`
`brain-recall "query" [--conv | --kb | --all]` (default `--all`).
- Embedda la query (`RETRIEVAL_QUERY`), cerca in `vault` (con `where` se `--conv`/`--kb`).
- **Rerank graph-weighted**: `score = 0.7·cos_sim + 0.3·centralità_wikilink`, dove la centralità =
  `log(freq+1)/log(max_freq+1)` sulla frequenza dei `[[wikilink]]` nel vault (riusa i wikilink
  aggiunti al formato conversazioni). Cache della freq-map (TTL 10 min).
- Stampa top-N: `type` + file sorgente + score + chunk.
- DB vuoto / no-key / quota esaurita → messaggio pulito su stderr, exit 0 (rg+INDEX coprono).

### 5. Hook commit — `lib/brain-embed-autoregen.sh`
Mirror di `graphify-autoregen.sh`. Concatenato nel `post-commit` **dopo** graphify. Guardato al solo
vault (presenza `bin/brain-embed.py`), detached/non-bloccante, no-op se manca chromadb/key. Esegue
`brain-embed.py --changed`. Deployato in `~/.local/bin/` + `git-template/hooks/post-commit` +
`install.sh` (stesso pattern di gitnexus/graphify).

### 6. Regola di recall (CLAUDE.md)
Estendere la sezione "Recall automatico" in `~/.claude/CLAUDE.md` (canonico:
`overclaude/config/CLAUDE.md.template`): dopo INDEX+`rg`, **lanciare anche `brain-recall "<query>"`**
per gli hit semantici, quando il recall parte. Resta model-judgment (non per-prompt).

### 7. Dipendenze
`chromadb`, `google-genai`, `httpx` in un env `uv`/`pipx` dedicato (come graphify). Documentare in
`brain-scaffold/BRAIN.md` + step in `install.sh`.

## Anti-spreco embeddings (requisito esplicito)

Il problema in AutoBrain: l'automazione (watchdog) produceva embeddings anche quando non servivano.
Qui il commit-driven lo elimina alla radice:
- **Doc**: embeddati solo su commit, solo file cambiati (git), solo chunk nuovi (hash) → ogni chunk
  embeddato **esattamente una volta per modifica**. Nessun re-embed speculativo.
- **Query**: embeddata solo al recall reale (mai per-prompt, nessun hook che inietta contesto).
- **Quota-guard**: blocca runaway su 429 free-tier, sospende fino al reset UTC.
- **Backfill**: `--full` una volta a mano (non automatico).

## Data flow

```
commit nel vault
  → post-commit (detached)
      → gitnexus-autoreindex (code graph)
      → graphify-autoregen (grafo semantico LLM)
      → brain-embed-autoregen → brain-embed.py --changed
            git diff-tree → file cambiati → chunk nuovi → embed → ChromaDB

recall ("ricordi x")
  → modello legge INDEX.md + rg (come ora)
  → modello lancia brain-recall "<query>"
        embed query → ChromaDB query (+where) → rerank wikilink → top-N chunk
```

## Error handling
Ogni componente **fail-open**: assenza di key/chromadb/DB → no-op silenzioso, exit 0. Un commit non
deve MAI fallire per il layer semantico. Il recall degrada su rg+INDEX (già presenti). Embed error →
zero-vector NON scritto (salta il chunk, ritenta al prossimo commit che tocca il file).

## Testing (self-check)
`bin/test-brain-recall.sh` (assert-based, no framework):
1. Embedda 2 doc minimi con temi distinti (es. "crittografia" vs "cucina").
2. Query "chiave pubblica" → **assert** il doc crittografia è primo.
3. Re-run `--changed` su file invariato → **assert** 0 nuovi embed (hash skip).
4. No-key → **assert** exit 0 e nessun crash.

## File toccati
- Nuovi (canonico in `overclaude`): `brain-scaffold/bin/brain-embed.py`,
  `brain-scaffold/bin/brain-recall`, `lib/brain-embed-autoregen.sh`,
  `brain-scaffold/bin/test-brain-recall.sh`.
- Modificati: `git-template/hooks/post-commit`, `install.sh`, `config/CLAUDE.md.template`,
  `brain-scaffold/BRAIN.md`, `brain-scaffold/.gitignore` (aggiungi `.chroma_db/`).
- Deploy live nel vault attuale `~/brain`: copia bin/, hook, `~/.local/bin/brain-embed-autoregen.sh`,
  aggiorna `~/.claude/CLAUDE.md`, run `--full` backfill.

## Fuori scope (YAGNI)
Concept-first, MCP server, re-embed schedulato, embeddings su claude-memory, UI.
```
