# Passaggi manuali

`install.sh` fa tutto ciò che è automatizzabile. Resta fuori solo ciò che richiede un
account, una chiave o un'impostazione lato servizio: nessuno script può crearli al posto tuo.

Questo file è scritto per essere **letto da Claude Code**: se sei l'utente, aprilo e chiedi
al tuo Claude di seguirlo. Ogni sezione dice cosa ottieni, dove prenderlo, dove scriverlo e
come verificare che abbia funzionato.

---

## Exa — ricerca web e fetch (connector claude.ai)

**Cosa dà:** i tool `mcp__claude_ai_Exa__web_search_exa` e `web_fetch_exa`, cioè ricerca web
e lettura pagine di qualità migliore del fetch base.

**Perché non lo installa lo script:** Exa non è un MCP locale. È un **connector a livello di
account claude.ai**, non vive in `~/.claude.json` e `claude mcp add` non lo può creare. Si
attiva una volta sull'account e segue il tuo login su ogni macchina.

**Passi:**

1. Apri claude.ai con l'account che usi in Claude Code e vai in **Settings → Connectors**
   (di norma <https://claude.ai/settings/connectors>).
2. Cerca **Exa** nella lista dei connector disponibili e premi **Connect**.
3. Autorizza quando il browser lo chiede.
4. Torna al terminale e riavvia Claude Code (il connector si carica all'avvio della sessione).

**Verifica:**

```sh
claude mcp list
```

Deve comparire una riga `claude.ai Exa: https://mcp.exa.ai/mcp - ✔ Connected`. Il prefisso
`claude.ai` è normale: indica appunto che arriva dall'account e non dalla config locale.

**Se non compare:** stai usando un account diverso da quello loggato in Claude Code
(`claude auth status` per controllare quale), oppure il connector non è disponibile sul tuo
piano.

---

## Dove vivono i segreti (leggere prima delle sezioni sotto)

Due posti, e nessuno dei due è `settings.json`:

| File | Quando viene letto | Cosa ci va |
|---|---|---|
| `.env` di questa repo | **all'installazione**, da `install.sh` | le chiavi che servono a costruire la config (`CONTEXT7_API_KEY`, `MAGIC_API_KEY`, `GEMINI_API_KEY`) |
| `~/.config/brain.env` | **a runtime**, dalla shell e dagli hook del vault | `GEMINI_API_KEY` e i modelli graphify |

`.env` è nella prima riga del `.gitignore` e c'è un test che fallisce se una chiave finisce
nei file versionati. `~/.config/brain.env` sta fuori da qualsiasi repo di proposito, ed è
`install.sh` a crearlo (a `600`) se non esiste.

**Non mettere chiavi in `~/.claude/settings.json`.** Il campo `env` funziona, ma non
supporta interpolazione: ci finirebbe il valore in chiaro, e su questa configurazione quel
file vive dentro l'albero di un repo. Le variabili esportate dalla shell arrivano comunque
a Claude Code e ai suoi sottoprocessi, quindi `brain.env` copre lo stesso bisogno senza il
rischio.

Perché la shell carichi `brain.env`, serve una riga nel tuo rc (`~/.zshrc`, `~/.bashrc`):

```sh
[ -f "$HOME/.config/brain.env" ] && source "$HOME/.config/brain.env"
```

Verifica, **in un terminale nuovo** (le variabili non compaiono in quello già aperto):

```sh
printenv GEMINI_API_KEY | wc -c    # > 1 se caricata
```

---

## Gemini — grafo del vault, recall semantico, generazione immagini

**Cosa sblocca:** `graphify` (il grafo del vault), `brain-recall` (il recall per significato,
che senza chiave degrada su `rg` + `INDEX.md`), e il plugin `nano-banana`.

**Passi:**

1. Vai su <https://aistudio.google.com/apikey> e crea una API key.
2. Incollala in due posti: `GEMINI_API_KEY=` nel `.env` di questa repo, e
   `export GEMINI_API_KEY=` in `~/.config/brain.env`. Se `brain.env` non esiste ancora,
   rilancia `sh install.sh` e lo crea da solo leggendo il `.env`.
3. Apri un terminale nuovo.

**Verifica:**

```sh
curl -s -o /dev/null -w '%{http_code}\n' \
  "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY"
```

`200` = chiave valida. `400` o `403` = chiave errata o API non abilitata sul progetto.

**Nota su nano-banana:** la generazione di immagini richiede il **billing attivo** sul
progetto Google Cloud a cui appartiene la key. Il free tier è a zero per quei modelli: la
key risponde `200` sull'elenco modelli e fallisce comunque sulla generazione. Se ti serve,
attiva la fatturazione dal progetto, non basta creare la key.

---

## 21st.dev — MCP `magic` per i componenti UI

**Cosa sblocca:** i tool `mcp__magic__*`, che generano e raffinano componenti UI.

**Passi:**

1. Crea un account su <https://21st.dev> e genera una API key dalla console.
2. Scrivila come `MAGIC_API_KEY=` nel `.env` di questa repo.
3. Rilancia `sh install.sh`, oppure — se l'MCP è già stato aggiunto senza chiave — sostituiscilo:

```sh
claude mcp remove magic
claude mcp add --scope user magic -- npx -y @21st-dev/magic@latest API_KEY=<la-tua-key>
```

**Verifica:** `claude mcp list` deve mostrare `magic … ✔ Connected`.

**Attenzione:** se installi senza chiave, l'MCP viene comunque aggiunto con il placeholder
`API_KEY=SET_IN_ENV`. Compare nell'elenco ma non funziona: è il sintomo di questo passaggio
saltato, non un guasto.

---

## Groq — trascrizione per la skill `watch`

**Cosa sblocca:** la trascrizione Whisper dei video **senza sottotitoli**. Con i sottotitoli
nativi (quasi tutto YouTube) `watch` funziona già senza chiave; senza, torna solo i frame.

**Passi:**

1. Crea una key su <https://console.groq.com/keys> (il free tier basta: circa due ore di
   trascrizione l'ora).
2. Scrivila in `~/.config/watch/.env`:

```sh
mkdir -p ~/.config/watch
printf 'GROQ_API_KEY=%s\n' '<la-tua-key>' >> ~/.config/watch/.env
chmod 600 ~/.config/watch/.env
```

In alternativa `OPENAI_API_KEY` nello stesso file: la skill preferisce Groq quando ci sono
entrambe, ed è più economica e veloce.

**Verifica:** lancia `/watch` su un video senza sottotitoli. Nell'intestazione del report la
riga della sorgente deve dire `whisper (groq)` invece di `none available`.
