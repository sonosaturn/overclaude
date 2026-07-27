# Prior art before building

The rung missing from `ponytail`'s ladder, which stops at "a dependency already installed
solves it".

**Before writing a non-trivial capability from scratch** — a parser, a protocol client, an
integration layer, a CLI, a pipeline, an algorithm with literature behind it — do one search:
is there already a library in the project's ecosystem (`context7`), or a GitHub repo / CLI /
MCP / skill that does that job? Report in one line what you found and the call: reuse, adapt,
or build anyway because the fit is bad. **Checking is mandatory, adopting is not.**

Skip it for bugfixes, refactors, domain-specific glue and anything under ~50 lines: there the
search costs more than it saves.
