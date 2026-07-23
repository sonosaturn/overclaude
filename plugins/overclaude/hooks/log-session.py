#!/usr/bin/env python3
"""Hook Stop: pavimento di sicurezza per il log conversazioni.

Il log lo cura il modello seguendo la skill conversation-log. Questo script esiste
per le sessioni in cui non lo fa: rigenera il Conv_*.md corrente dal transcript
.jsonl di Claude Code, in modo deterministico, cosi' il file non resta mai vuoto.

Tre casi, decisi dal marker "<!-- curated -->":

  * marker assente          -> riscrive tutto il file dal transcript;
  * marker presente, turni
    mancanti nel file       -> accoda SOLO quelli, senza toccare il curato;
  * marker presente, tutti
    i turni gia' nel file   -> non fa nulla.

Il caso di mezzo copre il log curato a meta': senza di esso, bastava un marker
scritto al primo turno per perdere tutti i turni successivi.

Input: JSON su stdin dall'hook Stop (campo transcript_path). Fallback: il .jsonl
piu' recente sotto ~/.claude/projects/.
"""
import json, os, re, sys, glob

HOME = os.path.expanduser("~")
CONV_DIR = os.path.join(HOME, "brain", "conversations")
CURATED_MARKER = "<!-- curated -->"
AUTO_MARKER = "<!-- auto-generated: log-session.py -->"
GAP_MARKER = "<!-- turni sotto: auto-estratti, non curati -->"
# Quanto testo del prompt usare per riconoscerlo dentro il file. Abbastanza da
# distinguere due prompt diversi, poco abbastanza da sopravvivere a una riga
# spezzata diversamente dal modello.
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
        with open(marker) as f:
            path = f.read().strip()
        return path or None
    except Exception:
        return None


def strip_code(text):
    # via i blocchi ``` ... ``` (regola della skill: niente code block nel log)
    return re.sub(r"```.*?```", "[codice omesso]", text, flags=re.DOTALL).strip()


def hhmm(ts):
    m = re.search(r"T(\d\d:\d\d)", ts or "")
    return m.group(1) if m else "--:--"


def extract_turns(transcript):
    """Lista di turni: {time, user, claude:[testi]}."""
    turns = []
    cur = None
    for line in open(transcript, encoding="utf-8"):
        try:
            o = json.loads(line)
        except Exception:
            continue
        t = o.get("type")
        m = o.get("message", {}) if isinstance(o.get("message"), dict) else {}
        c = m.get("content")
        if t == "user":
            if o.get("isMeta"):  # iniezione skill/sistema, non un prompt vero
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
    """Riusa l'header esistente (data/ora), altrimenti uno minimo."""
    try:
        with open(conv_file) as f:
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
    """Il marker vale solo nell'header, cioe' prima del primo turno.

    Cercarlo in tutto il file lo fa scattare anche quando compare *dentro* il log:
    basta una sessione in cui si parla del marker perche' le risposte lo citino
    verbatim, e un log non curato verrebbe scambiato per curato.
    """
    for line in text.splitlines():
        if line.startswith("## "):
            return False
        if CURATED_MARKER in line:
            return True
    return False


def missing_turns(text, turns):
    """Turni non ancora presenti nel file curato.

    Il confronto e' sul testo del prompt, non sul conteggio delle intestazioni:
    regge anche se il modello ha formattato il curato a modo suo. Il conteggio
    per chiave serve ai prompt ripetuti ("procedi" due volte non e' un duplicato).
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
        with open(conv_file, encoding="utf-8") as f:
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
        # Il separatore serve una volta sola: agli Stop successivi i turni accodati
        # risultano gia' presenti, e sotto lo stesso marker finisce il seguito.
        chunk = ["", GAP_MARKER, ""] if GAP_MARKER not in existing else [""]
        for tr in missing:
            chunk += render_turn(tr)
        with open(conv_file, "a", encoding="utf-8") as f:
            f.write("\n".join(chunk).rstrip() + "\n")
        print(json.dumps({"systemMessage":
                          "log-session: %d turni non curati accodati al log" % len(missing)}))
        return 0

    with open(conv_file, "w", encoding="utf-8") as f:
        f.write(build(conv_file, turns))
    return 0


if __name__ == "__main__":
    sys.exit(main())
