# Recall Semantico nel Vault ~/brain — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aggiungere un layer di recall semantico (embeddings Gemini + ChromaDB) al vault `~/brain`, commit-driven e senza sprechi di embedding, accanto al recall esistente rg+INDEX.

**Architecture:** Modulo Python condiviso (`brain_semantic.py`) con embed/chunk/quota-guard/chroma/rerank; due CLI (`brain-embed` indicizza, `brain-recall` interroga); hook `post-commit` che embedda solo i file cambiati nel commit. Una sola collection ChromaDB con metadata `type`. Reranking pesato sui `[[wikilink]]`. Canonico in `overclaude/brain-scaffold` + `overclaude/lib`, deployato nel vault.

**Tech Stack:** Python 3.11+, `uv run --script` (deps PEP723 inline: `chromadb>=1.0.0`, `google-genai>=0.1.0`, `httpx`), ChromaDB PersistentClient, Gemini `gemini-embedding-001`, shell POSIX per hook.

## Global Constraints

- Embedding model: `gemini-embedding-001`, 3072 dim, REST endpoint `https://generativelanguage.googleapis.com/v1/{model}:embedContent`. Task type `RETRIEVAL_DOCUMENT` in index, `RETRIEVAL_QUERY` in query. Copiati verbatim dalla spec.
- Chunk: 1500 char, overlap 200.
- Store: ChromaDB `PersistentClient` in `$VAULT/.chroma_db/`, collection unica `vault`, metadata `hnsw:space=cosine`, campo `type ∈ {conversation, wiki, source}`.
- Rerank: `score = 0.7*cos_sim + 0.3*graph_weight`, `graph_weight = log(freq+1)/log(max_freq+1)`.
- Key Gemini: letta da `~/.config/brain.env` (var `GEMINI_API_KEY`). Se assente → ogni componente **fail-open** (no-op, exit 0).
- VAULT root: `os.environ["BRAIN_VAULT"]` se presente, altrimenti `git rev-parse --show-toplevel`, altrimenti `~/brain`.
- Tutti gli script eseguibili via shebang `#!/usr/bin/env -S uv run --script`.
- Canonico in `overclaude`; nessun trailer AI nei commit (repo pubblico).
- Un commit non deve MAI fallire per questo layer (hook detached, no-op su errore).

---

### Task 1: Modulo condiviso — helper puri (chunk, hash, type, doc_id)

**Files:**
- Create: `brain-scaffold/bin/brain_semantic.py`
- Test: `brain-scaffold/bin/test_brain_semantic.py`

**Interfaces:**
- Produces:
  - `chunks(text: str) -> list[str]`
  - `file_hash(path: str) -> str` (md5 primi 10 char)
  - `type_from_relpath(relpath: str) -> str | None` (`conversation|wiki|source` o None se fuori scope)
  - `doc_id(relpath: str, i: int, fhash: str) -> str`
  - Costanti: `CHUNK_SIZE=1500`, `CHUNK_OVERLAP=200`

- [ ] **Step 1: Write the failing test**

```python
# brain-scaffold/bin/test_brain_semantic.py
import brain_semantic as bs

def test_chunks_short_text_single():
    assert bs.chunks("ciao") == ["ciao"]

def test_chunks_long_text_overlap():
    text = "x" * 3200
    cs = bs.chunks(text)
    assert len(cs) == 3
    assert cs[0][-bs.CHUNK_OVERLAP:] == cs[1][:bs.CHUNK_OVERLAP]

def test_type_from_relpath():
    assert bs.type_from_relpath("conversations/Conv_01.md") == "conversation"
    assert bs.type_from_relpath("wiki/brain.md") == "wiki"
    assert bs.type_from_relpath("sources/paper.md") == "source"
    assert bs.type_from_relpath("claude-memory/x.md") is None
    assert bs.type_from_relpath("BRAIN.md") is None

def test_doc_id_stable():
    assert bs.doc_id("wiki/a.md", 2, "abc") == "wiki/a.md::2::abc"

if __name__ == "__main__":
    import sys
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for f in fns:
        f(); print(f"ok {f.__name__}")
    print("ALL PASS")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd overclaude/brain-scaffold/bin && python3 test_brain_semantic.py`
Expected: FAIL — `ModuleNotFoundError: No module named 'brain_semantic'`

- [ ] **Step 3: Write minimal implementation**

```python
# brain-scaffold/bin/brain_semantic.py
"""Shared helpers per il recall semantico del vault ~/brain.
Importato da brain-embed e brain-recall. Non eseguito direttamente
(le deps runtime — chromadb/google-genai/httpx — le dichiarano i CLI via PEP723)."""
import hashlib
from pathlib import Path

CHUNK_SIZE = 1500
CHUNK_OVERLAP = 200
_SCOPE = {"conversations": "conversation", "wiki": "wiki", "sources": "source"}


def chunks(text: str) -> list[str]:
    if len(text) <= CHUNK_SIZE:
        return [text]
    out, start = [], 0
    while start < len(text):
        out.append(text[start:start + CHUNK_SIZE])
        start += CHUNK_SIZE - CHUNK_OVERLAP
    return out


def file_hash(path: str) -> str:
    try:
        return hashlib.md5(Path(path).read_bytes()).hexdigest()[:10]
    except Exception:
        return "0"


def type_from_relpath(relpath: str) -> str | None:
    top = relpath.replace("\\", "/").split("/")[0]
    return _SCOPE.get(top)


def doc_id(relpath: str, i: int, fhash: str) -> str:
    return f"{relpath}::{i}::{fhash}"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd overclaude/brain-scaffold/bin && python3 test_brain_semantic.py`
Expected: PASS — stampa `ALL PASS`

- [ ] **Step 5: Commit**

```bash
cd overclaude
git add brain-scaffold/bin/brain_semantic.py brain-scaffold/bin/test_brain_semantic.py
git commit -m "feat(brain-semantic): helper puri chunk/hash/type/doc_id + test"
```

---

### Task 2: Rerank graph-weighted sui wikilink

**Files:**
- Modify: `brain-scaffold/bin/brain_semantic.py` (aggiungi funzioni)
- Modify: `brain-scaffold/bin/test_brain_semantic.py` (aggiungi test)

**Interfaces:**
- Consumes: niente di nuovo.
- Produces:
  - `wikilink_freq(vault: str) -> dict[str, int]`
  - `rerank(docs, metas, dists, freq_map, w_graph=0.3) -> list[tuple[str, dict, float]]`

- [ ] **Step 1: Write the failing test** (append al test file)

```python
def test_wikilink_freq(tmp_path=None):
    import tempfile, os
    d = tempfile.mkdtemp()
    os.makedirs(os.path.join(d, "wiki"))
    with open(os.path.join(d, "wiki", "a.md"), "w") as f:
        f.write("vedi [[brain-KB]] e [[brain-KB]] e [[ricing-hyprland]]")
    freq = bs.wikilink_freq(d)
    assert freq["brain-KB"] == 2
    assert freq["ricing-hyprland"] == 1

def test_rerank_blends_similarity_and_graph():
    # doc A: sim alta (dist 0.1) ma freq 0; doc B: sim media (dist 0.4) ma freq alta
    docs = ["A", "B"]
    metas = [{"file": "A.md"}, {"file": "B.md"}]
    dists = [0.1, 0.4]
    freq = {"A.md": 0, "B.md": 50}
    scored = bs.rerank(docs, metas, dists, freq, w_graph=0.3)
    # A resta primo (0.7*0.9=0.63 > B 0.7*0.6+0.3*1.0=0.72)? verifichiamo il calcolo reale
    order = [m["file"] for _, m, _ in scored]
    # B ha graph_weight massimo → 0.42+0.3=0.72 > A 0.63 → B primo
    assert order[0] == "B.md"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 test_brain_semantic.py`
Expected: FAIL — `AttributeError: module 'brain_semantic' has no attribute 'wikilink_freq'`

- [ ] **Step 3: Write minimal implementation** (append a `brain_semantic.py`)

```python
import math
import os
import re

_WIKILINK_RE = re.compile(r'\[\[([^\]|#\n]+?)(?:\|[^\]]+)?\]\]')


def wikilink_freq(vault: str) -> dict[str, int]:
    freq: dict[str, int] = {}
    for root, _, files in os.walk(vault):
        if os.path.basename(root).startswith("."):
            continue
        for fname in files:
            if not fname.endswith(".md"):
                continue
            try:
                content = Path(os.path.join(root, fname)).read_text(encoding="utf-8")
            except Exception:
                continue
            for m in _WIKILINK_RE.finditer(content):
                target = m.group(1).strip()
                freq[target] = freq.get(target, 0) + 1
                noext = target.removesuffix(".md")
                if noext != target:
                    freq[noext] = freq.get(noext, 0) + 1
    return freq


def rerank(docs, metas, dists, freq_map, w_graph: float = 0.3):
    if not docs:
        return []
    max_freq = max(freq_map.values(), default=1)
    scored = []
    for doc, meta, dist in zip(docs, metas, dists):
        similarity = max(0.0, 1.0 - dist)
        fname = meta.get("file", "")
        freq = max(freq_map.get(fname, 0), freq_map.get(fname.removesuffix(".md"), 0))
        graph_w = math.log(freq + 1) / math.log(max_freq + 1) if max_freq > 0 else 0.0
        final = (1 - w_graph) * similarity + w_graph * graph_w
        scored.append((doc, meta, final))
    scored.sort(key=lambda x: x[2], reverse=True)
    return scored
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 test_brain_semantic.py`
Expected: PASS — `ALL PASS`

- [ ] **Step 5: Commit**

```bash
cd overclaude
git add brain-scaffold/bin/brain_semantic.py brain-scaffold/bin/test_brain_semantic.py
git commit -m "feat(brain-semantic): rerank graph-weighted sui wikilink + test"
```

---

### Task 3: Config, quota-guard, embed(), ChromaDB collection

**Files:**
- Modify: `brain-scaffold/bin/brain_semantic.py`
- Modify: `brain-scaffold/bin/test_brain_semantic.py`

**Interfaces:**
- Produces:
  - `load_key() -> str | None` (da `~/.config/brain.env` o env)
  - `vault_root() -> str`
  - `chroma_path(vault) -> str`, `get_collection(vault)` (ChromaDB collection `vault`)
  - `is_quota_exhausted(vault) -> bool`, `embed(text, vault, task="RETRIEVAL_DOCUMENT") -> list[float]`
  - Costanti: `EMBED_MODEL="models/gemini-embedding-001"`, `EMBED_DIM=3072`, `COLLECTION="vault"`

- [ ] **Step 1: Write the failing test** (append; solo la parte pura testabile senza API)

```python
def test_quota_sentinel_roundtrip():
    import tempfile
    from datetime import datetime, timezone
    d = tempfile.mkdtemp()
    assert bs.is_quota_exhausted(d) is False
    bs._write_quota_sentinel(d)
    assert bs.is_quota_exhausted(d) is True
    # sentinel con data vecchia = non attivo
    p = bs._quota_sentinel(d)
    with open(p, "w") as f:
        f.write("2000-01-01")
    bs._QUOTA_CACHE.clear()
    assert bs.is_quota_exhausted(d) is False

def test_vault_root_env(monkeypatch=None):
    import os, tempfile
    d = tempfile.mkdtemp()
    os.environ["BRAIN_VAULT"] = d
    try:
        assert bs.vault_root() == d
    finally:
        del os.environ["BRAIN_VAULT"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 test_brain_semantic.py`
Expected: FAIL — `AttributeError: ... 'is_quota_exhausted'`

- [ ] **Step 3: Write minimal implementation** (append a `brain_semantic.py`)

```python
import subprocess
import time
from datetime import datetime, timezone

EMBED_MODEL = "models/gemini-embedding-001"
EMBED_DIM = 3072
COLLECTION = "vault"
_MAX_CONSECUTIVE_FAILURES = 2
_QUOTA_CACHE: dict[str, bool] = {}
_consecutive_failures = 0


def vault_root() -> str:
    v = os.environ.get("BRAIN_VAULT")
    if v:
        return v
    try:
        top = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=5)
        if top.returncode == 0 and top.stdout.strip():
            return top.stdout.strip()
    except Exception:
        pass
    return os.path.expanduser("~/brain")


def load_key() -> str | None:
    k = os.environ.get("GEMINI_API_KEY")
    if k:
        return k
    envf = os.path.expanduser("~/.config/brain.env")
    try:
        for line in Path(envf).read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("GEMINI_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    except Exception:
        return None
    return None


def chroma_path(vault: str) -> str:
    return os.path.join(vault, ".chroma_db")


def get_collection(vault: str):
    import chromadb
    client = chromadb.PersistentClient(path=chroma_path(vault))
    return client.get_or_create_collection(name=COLLECTION, metadata={"hnsw:space": "cosine"})


def _quota_sentinel(vault: str) -> str:
    os.makedirs(chroma_path(vault), exist_ok=True)
    return os.path.join(chroma_path(vault), ".quota_exhausted")


def _write_quota_sentinel(vault: str):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    try:
        Path(_quota_sentinel(vault)).write_text(today, encoding="utf-8")
        _QUOTA_CACHE[vault] = True
    except Exception:
        pass


def is_quota_exhausted(vault: str) -> bool:
    if _QUOTA_CACHE.get(vault):
        return True
    p = _quota_sentinel(vault)
    if not os.path.exists(p):
        return False
    try:
        written = Path(p).read_text(encoding="utf-8").strip()
        return written == datetime.now(timezone.utc).strftime("%Y-%m-%d")
    except Exception:
        return False


def embed(text: str, vault: str, task: str = "RETRIEVAL_DOCUMENT", _retry: int = 0) -> list[float]:
    """Zero-vector se quota esaurita, no-key, o errore. Backoff 30/60/120 su 429."""
    global _consecutive_failures
    import httpx
    if is_quota_exhausted(vault):
        return [0.0] * EMBED_DIM
    key = load_key()
    if not key:
        return [0.0] * EMBED_DIM
    url = f"https://generativelanguage.googleapis.com/v1/{EMBED_MODEL}:embedContent?key={key}"
    payload = {"model": EMBED_MODEL, "content": {"parts": [{"text": text[:8000]}]}, "taskType": task}
    try:
        resp = httpx.post(url, json=payload, timeout=30)
        if resp.status_code == 429:
            if _retry < 3:
                time.sleep(30 * (2 ** _retry))
                return embed(text, vault, task, _retry + 1)
            _consecutive_failures += 1
            if _consecutive_failures >= _MAX_CONSECUTIVE_FAILURES:
                _write_quota_sentinel(vault)
            return [0.0] * EMBED_DIM
        resp.raise_for_status()
        _consecutive_failures = 0
        return resp.json()["embedding"]["values"]
    except Exception:
        return [0.0] * EMBED_DIM
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 test_brain_semantic.py`
Expected: PASS — `ALL PASS` (i test toccano solo sentinel/vault_root; embed/chroma verificati nel self-check Task 6)

- [ ] **Step 5: Commit**

```bash
cd overclaude
git add brain-scaffold/bin/brain_semantic.py brain-scaffold/bin/test_brain_semantic.py
git commit -m "feat(brain-semantic): config, quota-guard, embed(), chroma collection"
```

---

### Task 4: CLI `brain-embed` (--full / --changed)

**Files:**
- Create: `brain-scaffold/bin/brain-embed`

**Interfaces:**
- Consumes: tutto `brain_semantic` (chunks, embed, get_collection, type_from_relpath, doc_id, file_hash, vault_root).
- Produces: eseguibile `brain-embed [--full|--changed]` (default `--changed`). Exit 0 sempre (fail-open).

- [ ] **Step 1: Write the implementation** (nessun test unità: è I/O+API; coperto dal self-check Task 6)

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["chromadb>=1.0.0", "google-genai>=0.1.0", "httpx"]
# ///
"""Indicizza i .md del vault in ChromaDB. Incrementale per chunk-hash.
--changed (default): solo i file toccati dall'ultimo commit. --full: tutto il vault."""
import os
import sys
import subprocess
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import brain_semantic as bs

EMBED_DELAY = 0.7  # secondi tra embed — free tier ~100 RPM


def _changed_files(vault: str) -> list[str]:
    try:
        out = subprocess.run(
            ["git", "-C", vault, "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"],
            capture_output=True, text=True, timeout=10)
        return [l for l in out.stdout.splitlines() if l.strip()]
    except Exception:
        return []


def _all_files(vault: str) -> list[str]:
    res = []
    for top in ("conversations", "wiki", "sources"):
        base = os.path.join(vault, top)
        for root, _, files in os.walk(base):
            for f in files:
                if f.endswith(".md"):
                    res.append(os.path.relpath(os.path.join(root, f), vault))
    return res


def _project_of(vault: str, relpath: str) -> str:
    """Estrae il primo [[wikilink]] della riga **Collegamenti:** (se conversazione)."""
    import re
    try:
        for line in Path(os.path.join(vault, relpath)).read_text(encoding="utf-8").splitlines():
            if line.startswith("**Collegamenti:**"):
                m = re.search(r'\[\[([^\]|#\n]+?)(?:\|[^\]]+)?\]\]', line)
                return m.group(1).strip() if m else ""
    except Exception:
        pass
    return ""


def main():
    mode = "--changed"
    if len(sys.argv) > 1:
        mode = sys.argv[1]
    vault = bs.vault_root()
    if bs.is_quota_exhausted(vault):
        print("quota Gemini esaurita — skip indexing", file=sys.stderr)
        return 0
    if not bs.load_key():
        print("GEMINI_API_KEY assente — skip indexing", file=sys.stderr)
        return 0

    rels = _all_files(vault) if mode == "--full" else _changed_files(vault)
    rels = [r for r in rels if bs.type_from_relpath(r) and r.endswith(".md")]
    if not rels:
        return 0

    col = bs.get_collection(vault)
    try:
        existing = set(col.get()["ids"])
    except Exception:
        existing = set()

    import time
    added = 0
    for rel in rels:
        fpath = os.path.join(vault, rel)
        try:
            content = Path(fpath).read_text(encoding="utf-8").strip()
        except Exception:
            continue
        if len(content) < 50:
            continue
        fhash = bs.file_hash(fpath)
        dtype = bs.type_from_relpath(rel)
        project = _project_of(vault, rel) if dtype == "conversation" else ""
        for i, chunk in enumerate(bs.chunks(content)):
            if bs.is_quota_exhausted(vault):
                print("quota esaurita durante indexing — stop", file=sys.stderr)
                print(f"+{added} chunk", file=sys.stderr)
                return 0
            did = bs.doc_id(rel, i, fhash)
            if did in existing:
                continue
            emb = bs.embed(chunk, vault, task="RETRIEVAL_DOCUMENT")
            if all(v == 0.0 for v in emb[:10]):
                continue  # embed fallito: non scrivo zero-vector, ritento al prossimo commit
            col.add(ids=[did], embeddings=[emb], documents=[chunk],
                    metadatas=[{"file": os.path.basename(rel), "path": rel,
                                "type": dtype, "chunk": i, "project": project}])
            added += 1
            time.sleep(EMBED_DELAY)
    print(f"brain-embed: +{added} chunk (totale {col.count()})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Make executable + smoke test (dry, no key needed)**

```bash
chmod +x overclaude/brain-scaffold/bin/brain-embed
# senza key deve uscire pulito exit 0
env -u GEMINI_API_KEY BRAIN_VAULT=/tmp/nonexistent overclaude/brain-scaffold/bin/brain-embed --changed; echo "exit=$?"
```
Expected: stampa `GEMINI_API_KEY assente — skip indexing`, `exit=0`

- [ ] **Step 3: Commit**

```bash
cd overclaude
git add brain-scaffold/bin/brain-embed
git commit -m "feat(brain-embed): CLI indexing incrementale --full/--changed"
```

---

### Task 5: CLI `brain-recall`

**Files:**
- Create: `brain-scaffold/bin/brain-recall`

**Interfaces:**
- Consumes: `brain_semantic` (embed, get_collection, wikilink_freq, rerank, vault_root).
- Produces: eseguibile `brain-recall "query" [--conv|--kb|--all]` (default `--all`). Stampa top-N su stdout.

- [ ] **Step 1: Write the implementation**

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["chromadb>=1.0.0", "google-genai>=0.1.0", "httpx"]
# ///
"""Recall semantico: embedda la query, cerca in ChromaDB, rerank sui wikilink, stampa top-N."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import brain_semantic as bs

N_RESULTS = 5


def main():
    args = [a for a in sys.argv[1:]]
    scope = "--all"
    for a in list(args):
        if a in ("--conv", "--kb", "--all"):
            scope = a
            args.remove(a)
    query = " ".join(args).strip()
    if not query:
        print("uso: brain-recall \"query\" [--conv|--kb|--all]", file=sys.stderr)
        return 2

    vault = bs.vault_root()
    if not bs.load_key():
        print("(recall semantico non disponibile: GEMINI_API_KEY assente — usa rg+INDEX)", file=sys.stderr)
        return 0
    try:
        col = bs.get_collection(vault)
        total = col.count()
    except Exception as e:
        print(f"(ChromaDB non disponibile: {e} — usa rg+INDEX)", file=sys.stderr)
        return 0
    if total == 0:
        print("(indice semantico vuoto — esegui 'brain-embed --full' — usa rg+INDEX)", file=sys.stderr)
        return 0

    where = None
    if scope == "--conv":
        where = {"type": {"$eq": "conversation"}}
    elif scope == "--kb":
        where = {"type": {"$in": ["wiki", "source"]}}

    qemb = bs.embed(query, vault, task="RETRIEVAL_QUERY")
    if all(v == 0.0 for v in qemb[:10]):
        print("(embed query fallito — usa rg+INDEX)", file=sys.stderr)
        return 0
    kw = {"query_embeddings": [qemb], "n_results": min(N_RESULTS * 2, total),
          "include": ["documents", "metadatas", "distances"]}
    if where:
        kw["where"] = where
    res = col.query(**kw)
    docs, metas, dists = res["documents"][0], res["metadatas"][0], res["distances"][0]
    if not docs:
        print("(nessun hit semantico)", file=sys.stderr)
        return 0

    freq = bs.wikilink_freq(vault)
    scored = bs.rerank(docs, metas, dists, freq)[:N_RESULTS]
    for doc, meta, score in scored:
        label = meta.get("type", "?").upper()
        print(f"{label}: {meta.get('file','?')}  (score {score:.2f})")
        print(doc.strip())
        print("---")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Make executable + smoke test**

```bash
chmod +x overclaude/brain-scaffold/bin/brain-recall
env -u GEMINI_API_KEY overclaude/brain-scaffold/bin/brain-recall "test" ; echo "exit=$?"
```
Expected: stampa `(recall semantico non disponibile: GEMINI_API_KEY assente ...)`, `exit=0`

- [ ] **Step 3: Commit**

```bash
cd overclaude
git add brain-scaffold/bin/brain-recall
git commit -m "feat(brain-recall): CLI query semantica + rerank wikilink"
```

---

### Task 6: Self-check end-to-end (embed reale + ranking + idempotenza)

**Files:**
- Create: `brain-scaffold/bin/test-brain-recall.sh`

**Interfaces:**
- Consumes: `brain-embed`, `brain-recall`. Usa la key reale se presente; altrimenti skip pulito.

- [ ] **Step 1: Write the self-check**

```bash
#!/usr/bin/env bash
# Self-check end-to-end del recall semantico. Con GEMINI_API_KEY: verifica ranking + idempotenza.
# Senza key: skip pulito (exit 0). Non un framework — assert via test [ ].
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT="$(mktemp -d)"
export BRAIN_VAULT="$VAULT"
cleanup() { rm -rf "$VAULT"; }
trap cleanup EXIT

mkdir -p "$VAULT/conversations" "$VAULT/wiki"
( cd "$VAULT" && git init -q && git config user.email t@t && git config user.name t )

cat > "$VAULT/wiki/cripto.md" <<'EOF'
# Crittografia asimmetrica
Chiave pubblica e chiave privata. RSA, scambio di chiavi, firma digitale.
EOF
cat > "$VAULT/wiki/cucina.md" <<'EOF'
# Ricetta carbonara
Guanciale, uova, pecorino, pepe. Niente panna.
EOF
( cd "$VAULT" && git add -A && git commit -qm init )

if [ -z "${GEMINI_API_KEY:-}" ] && ! grep -q GEMINI_API_KEY "$HOME/.config/brain.env" 2>/dev/null; then
  echo "SKIP: nessuna GEMINI_API_KEY — self-check ranking saltato (fail-open ok)"
  # verifica comunque fail-open
  out="$("$DIR/brain-recall" "chiave pubblica" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL: recall non fail-open (rc=$rc)"; exit 1; }
  echo "ALL PASS (skip-mode)"; exit 0
fi

# 1. backfill
"$DIR/brain-embed" --full >/dev/null 2>&1

# 2. ranking: query cripto → cripto.md primo
top="$("$DIR/brain-recall" "chiave pubblica RSA" --kb 2>/dev/null | grep -m1 -oE 'cripto\.md|cucina\.md')"
[ "$top" = "cripto.md" ] || { echo "FAIL: ranking errato, primo='$top'"; exit 1; }
echo "ok ranking"

# 3. idempotenza: re-embed su file invariato → 0 nuovi chunk
add="$( ( cd "$VAULT" && git commit -q --allow-empty -m noop; "$DIR/brain-embed" --full ) 2>&1 | grep -oE '\+[0-9]+ chunk')"
[ "$add" = "+0 chunk" ] || { echo "FAIL: idempotenza rotta, add='$add'"; exit 1; }
echo "ok idempotenza"

echo "ALL PASS"
```

- [ ] **Step 2: Run the self-check**

```bash
chmod +x overclaude/brain-scaffold/bin/test-brain-recall.sh
overclaude/brain-scaffold/bin/test-brain-recall.sh
```
Expected: `ALL PASS` (o `ALL PASS (skip-mode)` se manca la key)

- [ ] **Step 3: Commit**

```bash
cd overclaude
git add brain-scaffold/bin/test-brain-recall.sh
git commit -m "test(brain-semantic): self-check end-to-end ranking + idempotenza"
```

---

### Task 7: Hook commit-driven + deploy in install.sh

**Files:**
- Create: `lib/brain-embed-autoregen.sh`
- Modify: `git-template/hooks/post-commit`
- Modify: `install.sh`

**Interfaces:**
- Consumes: `brain-embed` presente in `$VAULT/bin/`.
- Produces: `~/.local/bin/brain-embed-autoregen.sh`, chained nel post-commit.

- [ ] **Step 1: Write the hook script**

```sh
# lib/brain-embed-autoregen.sh
#!/usr/bin/env sh
# Indicizza in ChromaDB i file cambiati dal commit — SOLO nel vault brain. Detached: non blocca git.
# Guardia vault: presenza di bin/brain-embed. No-op se manca uv/key. Un commit non fallisce mai per questo.
# ponytail: incrementale via git diff-tree; nessun re-embed di file invariati.
command -v uv >/dev/null 2>&1 || exit 0
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$repo" ] || exit 0
[ -f "$repo/bin/brain-embed" ] || exit 0
[ -f "$HOME/.config/brain.env" ] && . "$HOME/.config/brain.env"
[ -n "${GEMINI_API_KEY:-}" ] || exit 0
export GEMINI_API_KEY BRAIN_VAULT="$repo"
setsid sh -c "cd '$repo' && ./bin/brain-embed --changed" >>/tmp/brain-embed.log 2>&1 </dev/null &
exit 0
```

- [ ] **Step 2: Chain nel post-commit template**

Modify `git-template/hooks/post-commit` — aggiungi in coda (dopo la riga graphify):

```sh
"$HOME/.local/bin/brain-embed-autoregen.sh" 2>/dev/null || true
```

Risultato atteso del file completo:
```sh
#!/usr/bin/env sh
# Auto-installato nei nuovi repo via git init.templateDir (overclaude).
# Reindexa con GitNexus (ogni repo) + rigenera il grafo graphify + indicizza gli embeddings (solo vault).
"$HOME/.local/bin/gitnexus-autoreindex.sh" || true
"$HOME/.local/bin/graphify-autoregen.sh" 2>/dev/null || true
"$HOME/.local/bin/brain-embed-autoregen.sh" 2>/dev/null || true
```

- [ ] **Step 3: Deploy in install.sh**

Modify `install.sh` — dopo la riga `cp "$HERE/lib/graphify-autoregen.sh" ...` aggiungi:

```sh
  cp "$HERE/lib/brain-embed-autoregen.sh" "$bindir/brain-embed-autoregen.sh"; chmod +x "$bindir/brain-embed-autoregen.sh"
```

- [ ] **Step 4: Deploy live (bin nel vault + hook + script)**

```bash
chmod +x overclaude/lib/brain-embed-autoregen.sh
cp overclaude/lib/brain-embed-autoregen.sh ~/.local/bin/brain-embed-autoregen.sh; chmod +x ~/.local/bin/brain-embed-autoregen.sh
cp overclaude/brain-scaffold/bin/brain_semantic.py overclaude/brain-scaffold/bin/brain-embed overclaude/brain-scaffold/bin/brain-recall ~/brain/bin/
chmod +x ~/brain/bin/brain-embed ~/brain/bin/brain-recall
cp overclaude/git-template/hooks/post-commit ~/.config/git/template/hooks/post-commit; chmod +x ~/.config/git/template/hooks/post-commit
cp overclaude/git-template/hooks/post-commit ~/projects/brain/.git/hooks/post-commit; chmod +x ~/projects/brain/.git/hooks/post-commit
```

- [ ] **Step 5: Commit (overclaude)**

```bash
cd overclaude
git add lib/brain-embed-autoregen.sh git-template/hooks/post-commit install.sh
git commit -m "feat: indicizzazione embeddings commit-driven nel post-commit (solo vault)"
```

---

### Task 8: Regola recall (CLAUDE.md) + docs + gitignore

**Files:**
- Modify: `config/CLAUDE.md.template` (canonico) e `~/.claude/CLAUDE.md` (live)
- Modify: `brain-scaffold/BRAIN.md`
- Modify: `brain-scaffold/.gitignore`

**Interfaces:** nessuna (documentazione/config).

- [ ] **Step 1: Estendi la regola di recall**

In `config/CLAUDE.md.template`, nella sezione "Recall automatico delle conversazioni passate", dopo il punto 2 (`rg`), aggiungi il punto:

```markdown
2b. **Recall semantico** (per parafrasi/sinonimi che `rg` non prende): lancia
    `~/brain/bin/brain-recall "<query>" [--conv|--kb]`. Ritorna i chunk più vicini
    per significato con score. Fail-open: se manca la key o l'indice, degrada su rg+INDEX.
    Query embeddata solo qui (mai per-prompt) → nessuno spreco.
```

Applica la stessa modifica a `~/.claude/CLAUDE.md` (copia live).

- [ ] **Step 2: Documenta in BRAIN.md**

In `brain-scaffold/BRAIN.md`, aggiungi sezione:

```markdown
## Recall semantico (embeddings)
`bin/brain-embed --full` (backfill una volta) indicizza conversations/wiki/sources in ChromaDB
(`.chroma_db/`, gitignored) con embeddings Gemini. Poi ogni commit aggiorna solo i file cambiati
(hook post-commit → `brain-embed --changed`). Query: `bin/brain-recall "..."`.
Dipendenze risolte da `uv` (PEP723 inline negli script). Key in `~/.config/brain.env`.
```

- [ ] **Step 3: Ignora lo store vettoriale**

In `brain-scaffold/.gitignore`, aggiungi:
```
.chroma_db/
```
E nel vault live:
```bash
grep -qxF '.chroma_db/' ~/brain/.gitignore || echo '.chroma_db/' >> ~/brain/.gitignore
```

- [ ] **Step 4: Commit**

```bash
cd overclaude
git add config/CLAUDE.md.template brain-scaffold/BRAIN.md brain-scaffold/.gitignore
git commit -m "docs: regola recall semantico + BRAIN.md + gitignore .chroma_db"
```

---

### Task 9: Backfill + verifica live sul vault reale

**Files:** nessuno (operativo).

- [ ] **Step 1: Backfill iniziale**

```bash
cd ~/brain && BRAIN_VAULT=~/brain ./bin/brain-embed --full
```
Expected: stderr `brain-embed: +N chunk (totale N)` con N > 0 (le 9 conv reali + wiki).

- [ ] **Step 2: Verifica recall reale**

```bash
~/brain/bin/brain-recall "come avevamo deciso il tema del ricing" --conv
```
Expected: primo hit = una `Conv_*` sul ricing (es. Fase 11/Tokyo Night), score > 0.

- [ ] **Step 3: Verifica hook end-to-end**

```bash
: > /tmp/brain-embed.log
cd ~/projects/brain && git commit -q --allow-empty -m "test: hook brain-embed" && sleep 3
grep -q 'brain-embed:' /tmp/brain-embed.log && echo "HOOK OK"
git reset --soft HEAD~1   # rimuovi il commit di test vuoto
```
Expected: `HOOK OK`.

- [ ] **Step 4: Commit del vault (indice non versionato, ma il backfill può aver aggiornato graph/report)**

Nessun commit necessario per `.chroma_db/` (gitignored). Fine.

---

## Self-Review

**Spec coverage:**
- Store 1-collection+type → Task 3 (`get_collection`, metadata in Task 4 `col.add`). ✓
- Embeddings Gemini + task asimmetrici + chunk → Task 3 `embed`, Task 1 `chunks`. ✓
- Quota-guard → Task 3. ✓
- Indexer --changed/--full incrementale hash → Task 4. ✓
- brain-recall + rerank wikilink → Task 5 + Task 2. ✓
- Hook commit-driven → Task 7. ✓
- Regola recall CLAUDE.md → Task 8. ✓
- Deps uv PEP723 → Task 4/5 header. ✓
- Anti-spreco (solo changed, solo chunk nuovi, query on-demand, quota-guard) → Task 4 (`existing` skip + `_changed_files`), Task 5 (query embed solo all'uso), Task 3 (quota). ✓
- claude-memory escluso → `type_from_relpath` ritorna None (Task 1). ✓
- Self-check → Task 6. ✓
- Backfill una volta → Task 9. ✓

**Placeholder scan:** nessun TBD/TODO; ogni step ha codice o comando reale. ✓

**Type consistency:** `embed(text, vault, task)`, `get_collection(vault)`, `rerank(docs,metas,dists,freq_map,w_graph)`, `type_from_relpath`, `doc_id` usati coerenti tra Task 1/2/3/4/5. Metadata `{file,path,type,chunk,project}` scritti in Task 4 e letti in Task 5 (`meta.get('type'/'file')`). ✓

**Note operativa:** i test Python (`test_brain_semantic.py`) girano con `python3` diretto (helper puri, nessuna dep esterna). Solo i CLI e il self-check richiedono `uv`+deps. Coerente con Global Constraints.
