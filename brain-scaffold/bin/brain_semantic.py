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
