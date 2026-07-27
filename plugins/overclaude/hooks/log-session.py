#!/usr/bin/env python3
"""Stop hook: safety floor for the conversation log.

The model curates the log by following the conversation-log skill. This script exists
for the sessions where it does not: it regenerates the current Conv_*.md from Claude
Code's .jsonl transcript, deterministically, so the file is never left empty.

Three cases, decided by the "<!-- curated -->" marker:

  * marker absent           -> rewrites the whole file from the transcript;
  * marker present, turns
    missing from the file   -> appends ONLY those, without touching the curated part;
  * marker present, every
    turn already in place   -> does nothing.

The middle case covers a half-curated log: without it, a marker written on the first
turn was enough to lose every later turn.

The strings written into the log stay in Italian on purpose: they are content of a
private vault whose existing files use that wording.

Input: JSON on stdin from the Stop hook (transcript_path field). Fallback: the most
recent .jsonl under ~/.claude/projects/.
"""
import json, os, re, sys, glob

HOME = os.path.expanduser("~")
CONV_DIR = os.path.join(HOME, "brain", "conversations")
CURATED_MARKER = "<!-- curated -->"
AUTO_MARKER = "<!-- auto-generated: log-session.py -->"
GAP_MARKER = "<!-- turni sotto: auto-estratti, non curati -->"
# How much of the prompt to use to recognise it inside the file. Enough to tell two
# different prompts apart, short enough to survive a line the model wrapped differently.
KEY_LEN = 60


def read_stdin_json():
    try:
        return json.loads(sys.stdin.read() or "{}")
    except Exception:
        return {}


def find_transcript(hook):
    p = hook.get("transcript_path")
    if p and os.path.isfile(p):
        return p
    cands = glob.glob(os.path.join(HOME, ".claude", "projects", "*", "*.jsonl"))
    return max(cands, key=os.path.getmtime) if cands else None


def current_conv_file():
    marker = os.path.join(CONV_DIR, ".current-session")
    try:
        with open(marker, encoding="utf-8") as f:
            path = f.read().strip()
        return path or None
    except Exception:
        return None


def strip_code(text):
    # drop the ``` ... ``` blocks (skill rule: no code blocks in the log)
    return re.sub(r"```.*?```", "[codice omesso]", text, flags=re.DOTALL).strip()


def hhmm(ts):
    m = re.search(r"T(\d\d:\d\d)", ts or "")
    return m.group(1) if m else "--:--"


def extract_turns(transcript):
    """List of turns: {time, user, claude:[texts]}."""
    turns = []
    cur = None
    for line in open(transcript, encoding="utf-8", errors="replace"):
        try:
            o = json.loads(line)
        except Exception:
            continue
        t = o.get("type")
        m = o.get("message", {}) if isinstance(o.get("message"), dict) else {}
        c = m.get("content")
        if t == "user":
            if o.get("isMeta"):  # skill/system injection, not a real prompt
                continue
            is_res = isinstance(c, list) and any(
                isinstance(p, dict) and p.get("type") == "tool_result" for p in c
            )
            if is_res:
                continue
            if isinstance(c, str):
                txt = c
            else:
                txt = " ".join(
                    p.get("text", "")
                    for p in (c or [])
                    if isinstance(p, dict) and p.get("type") == "text"
                )
            txt = txt.strip()
            if not txt:
                continue
            cur = {"time": hhmm(o.get("timestamp")), "user": txt, "claude": []}
            turns.append(cur)
        elif t == "assistant" and cur is not None:
            texts = [
                p.get("text", "")
                for p in (c or [])
                if isinstance(p, dict) and p.get("type") == "text"
            ]
            joined = strip_code(" ".join(texts).strip())
            if joined:
                cur["claude"].append(joined)
    return turns


def header_lines(conv_file):
    """Reuse the existing header (date/time), otherwise a minimal one."""
    try:
        with open(conv_file, encoding="utf-8", errors="replace") as f:
            head = []
            for line in f:
                if line.startswith("## "):
                    break
                head.append(line.rstrip("\n"))
            while head and (head[-1] == "" or head[-1].startswith("<!--")):
                head.pop()
            if head:
                return head
    except Exception:
        pass
    return ["# Conversazione", "",
            "> Log curato. Prompt utente: verbatim. Risposte Claude: riassunte, senza blocchi di codice."]


def render_turn(tr):
    out = ["## %s — Utente" % tr["time"], tr["user"], "", "## Claude"]
    if tr["claude"]:
        out += ["- " + p.replace("\n", " ") for p in tr["claude"]]
    else:
        out.append("- (nessuna risposta testuale)")
    out.append("")
    return out


def build(conv_file, turns):
    out = header_lines(conv_file) + ["", AUTO_MARKER, ""]
    for tr in turns:
        out += render_turn(tr)
    return "\n".join(out).rstrip() + "\n"


def is_curated(text):
    """The marker only counts in the header, i.e. before the first turn.

    Searching the whole file makes it fire even when the marker shows up *inside* the
    log: one session that talks about the marker is enough for the answers to quote it
    verbatim, and an uncurated log would be mistaken for a curated one.
    """
    for line in text.splitlines():
        if line.startswith("## "):
            return False
        if CURATED_MARKER in line:
            return True
    return False


def missing_turns(text, turns):
    """Turns not yet present in the curated file.

    The comparison is on the prompt text, not on a count of headings: it holds even if
    the model formatted the curated log its own way. The per-key count handles repeated
    prompts ("go ahead" twice is not a duplicate).
    """
    seen = {}
    missing = []
    for tr in turns:
        key = tr["user"][:KEY_LEN]
        seen[key] = seen.get(key, 0) + 1
        if text.count(key) < seen[key]:
            missing.append(tr)
    return missing


def main():
    hook = read_stdin_json()
    conv_file = current_conv_file()
    if not conv_file:
        return 0
    try:
        with open(conv_file, encoding="utf-8", errors="replace") as f:
            existing = f.read()
    except FileNotFoundError:
        existing = ""

    transcript = find_transcript(hook)
    if not transcript:
        return 0
    turns = extract_turns(transcript)
    if not turns:
        return 0

    if is_curated(existing):
        missing = missing_turns(existing, turns)
        if not missing:
            return 0
        # The separator is needed only once: on later Stops the appended turns are
        # already present, and the continuation lands under the same marker.
        chunk = ["", GAP_MARKER, ""] if GAP_MARKER not in existing else [""]
        for tr in missing:
            chunk += render_turn(tr)
        with open(conv_file, "a", encoding="utf-8") as f:
            f.write("\n".join(chunk).rstrip() + "\n")
        print(json.dumps({"systemMessage":
                          "log-session: %d turni non curati accodati al log" % len(missing)}))
        return 0

    # build() re-reads the header from the file: compose BEFORE opening in "w", which truncates.
    content = build(conv_file, turns)
    with open(conv_file, "w", encoding="utf-8") as f:
        f.write(content)
    return 0


if __name__ == "__main__":
    sys.exit(main())
