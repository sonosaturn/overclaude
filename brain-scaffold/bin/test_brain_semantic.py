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
