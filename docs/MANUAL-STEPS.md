# Manual steps

`install.sh` does everything that can be automated. What is left needs an account, a key, or a
service-side setting: no script can create those for you.

This file is written to be **read by Claude Code**: if you are the user, open it and ask your
Claude to follow it. Every section says what you get, where to get it, where to write it, and
how to verify it worked.

---

## Exa — web search and fetch (claude.ai connector)

**What it gives:** the `mcp__claude_ai_Exa__web_search_exa` and `web_fetch_exa` tools, i.e. web
search and page reading of better quality than the base fetch.

**Why the script does not install it:** Exa is not a local MCP. It is a **connector at the
claude.ai account level**, it does not live in `~/.claude.json` and `claude mcp add` cannot
create it. You enable it once on the account and it follows your login on every machine.

**Steps:**

1. Open claude.ai with the account you use in Claude Code and go to **Settings → Connectors**
   (usually <https://claude.ai/settings/connectors>).
2. Find **Exa** in the list of available connectors and press **Connect**.
3. Authorise when the browser asks.
4. Go back to the terminal and restart Claude Code (the connector loads at session start).

**Verify:**

```sh
claude mcp list
```

A line `claude.ai Exa: https://mcp.exa.ai/mcp - ✔ Connected` must appear. The `claude.ai` prefix
is normal: it means exactly that it comes from the account and not from the local config.

**If it does not appear:** you are using a different account from the one logged into Claude Code
(`claude auth status` to check which), or the connector is not available on your plan.

---

## Where the secrets live (read this before the sections below)

Two places, and neither of them is `settings.json`:

| File | When it is read | What goes in it |
|---|---|---|
| this repo's `.env` | **at install time**, by `install.sh` | the keys needed to build the config (`CONTEXT7_API_KEY`, `MAGIC_API_KEY`, `GEMINI_API_KEY`) |
| `~/.config/brain.env` | **at runtime**, by the shell and the vault hooks | `GEMINI_API_KEY` and the graphify models |

`.env` is on the first line of `.gitignore` and there is a test that fails if a key ends up in a
versioned file. `~/.config/brain.env` sits outside any repo on purpose, and `install.sh` creates
it (mode `600`) if it does not exist.

**Do not put keys in `~/.claude/settings.json`.** The `env` field works, but it does not support
interpolation: the value would land there in the clear, and in this setup that file lives inside
a repo tree. Variables exported by the shell reach Claude Code and its subprocesses anyway, so
`brain.env` covers the same need without the risk.

For the shell to load `brain.env`, you need one line in your rc (`~/.zshrc`, `~/.bashrc`):

```sh
[ -f "$HOME/.config/brain.env" ] && source "$HOME/.config/brain.env"
```

Verify, **in a new terminal** (the variables do not appear in one that is already open):

```sh
printenv GEMINI_API_KEY | wc -c    # > 1 if loaded
```

---

## Gemini — vault graph, semantic recall, image generation

**What it unlocks:** `graphify` (the vault graph), `brain-recall` (recall by meaning, which
degrades to `rg` + `INDEX.md` without a key), and the `nano-banana` plugin.

**Steps:**

1. Go to <https://aistudio.google.com/apikey> and create an API key.
2. Paste it in two places: `GEMINI_API_KEY=` in this repo's `.env`, and
   `export GEMINI_API_KEY=` in `~/.config/brain.env`. If `brain.env` does not exist yet, re-run
   `sh install.sh` and it creates it by reading the `.env`.
3. Open a new terminal.

**Verify:**

```sh
curl -s -o /dev/null -w '%{http_code}\n' \
  "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY"
```

`200` = valid key. `400` or `403` = wrong key or API not enabled on the project.

**Note on nano-banana:** image generation requires **active billing** on the Google Cloud project
the key belongs to. The free tier is zero for those models: the key answers `200` on the model
list and still fails on generation. If you need it, enable billing on the project — creating the
key is not enough.

---

## 21st.dev — the `magic` MCP for UI components

**What it unlocks:** the `mcp__magic__*` tools, which generate and refine UI components.

**Steps:**

1. Create an account at <https://21st.dev> and generate an API key from the console.
2. Write it as `MAGIC_API_KEY=` in this repo's `.env`.
3. Re-run `sh install.sh`, or — if the MCP was already added without a key — replace it:

```sh
claude mcp remove magic
claude mcp add --scope user magic -- npx -y @21st-dev/magic@latest API_KEY=<your-key>
```

**Verify:** `claude mcp list` must show `magic … ✔ Connected`.

**Careful:** if you install without a key, the MCP is still added with the `API_KEY=SET_IN_ENV`
placeholder. It shows up in the list but does not work: that is the symptom of this step being
skipped, not a failure.

---

## Groq — transcription for the `watch` skill

**What it unlocks:** Whisper transcription of videos **without subtitles**. With native subtitles
(almost all of YouTube) `watch` already works without a key; without them it returns only frames.

**Steps:**

1. Create a key at <https://console.groq.com/keys> (the free tier is enough: roughly two hours of
   transcription per hour).
2. Write it into `~/.config/watch/.env`:

```sh
mkdir -p ~/.config/watch
printf 'GROQ_API_KEY=%s\n' '<your-key>' >> ~/.config/watch/.env
chmod 600 ~/.config/watch/.env
```

Alternatively `OPENAI_API_KEY` in the same file: the skill prefers Groq when both are present,
and it is cheaper and faster.

**Verify:** run `/watch` on a video without subtitles. In the report header the source line must
say `whisper (groq)` instead of `none available`.
