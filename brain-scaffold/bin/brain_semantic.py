"""Shared helpers per il recall semantico del vault ~/brain.
Importato da brain-embed e brain-recall. Non eseguito direttamente
(le deps runtime — chromadb/google-genai/httpx — le dichiarano i CLI via PEP723)."""
import hashlib
import math
import os
import re
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
