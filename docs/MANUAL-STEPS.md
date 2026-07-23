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

## Chiavi API

Le sezioni per `magic` (21st.dev), `nano-banana` (Gemini) e `watch` (Groq/OpenAI) arrivano
qui. Finché non ci sono, quei componenti si installano ma restano inerti.
