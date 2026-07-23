# Prior art prima di costruire

Gradino che manca alla scala di `ponytail`, che si ferma a "una dipendenza già installata
lo risolve".

**Prima di scrivere da zero una capacità non banale** — parser, client di protocollo, layer
di integrazione, CLI, pipeline, algoritmo con letteratura alle spalle — una ricerca sola:
esiste già una libreria nell'ecosistema del progetto (`context7`), o un repo GitHub / CLI /
MCP / skill che fa quel lavoro? Riporta in una riga cosa hai trovato e la scelta: riusare,
adattare, o costruire comunque perché il fit è cattivo. **Verificare è obbligatorio,
adottare no.**

Salta per bugfix, refactor, glue specifico del dominio e qualsiasi cosa sotto ~50 righe:
lì la ricerca costa più di quanto risparmia.
