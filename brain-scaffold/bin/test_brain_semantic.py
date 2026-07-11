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

def test_embed_quota_exhausted_returns_zero_vector():
    import tempfile
    d = tempfile.mkdtemp()
    bs._QUOTA_CACHE.clear()
    bs._write_quota_sentinel(d)
    v = bs.embed("qualsiasi testo", d)
    assert v == [0.0] * bs.EMBED_DIM
    bs._QUOTA_CACHE.clear()

if __name__ == "__main__":
    import sys
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for f in fns:
        f(); print(f"ok {f.__name__}")
    print("ALL PASS")
