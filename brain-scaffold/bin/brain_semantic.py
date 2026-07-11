"""Shared helpers per il recall semantico del vault ~/brain.
Importato da brain-embed e brain-recall. Non eseguito direttamente
(le deps runtime — chromadb/google-genai/httpx — le dichiarano i CLI via PEP723)."""
import hashlib
import math
import os
import re
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

CHUNK_SIZE = 1500
CHUNK_OVERLAP = 200
EMBED_MODEL = "models/gemini-embedding-001"
EMBED_DIM = 3072
COLLECTION = "vault"
_SCOPE = {"conversations": "conversation", "wiki": "wiki", "sources": "source"}
_MAX_CONSECUTIVE_FAILURES = 2
_QUOTA_CACHE: dict[str, bool] = {}
_consecutive_failures = 0


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
