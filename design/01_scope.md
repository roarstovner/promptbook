# Promptbook — Project Scope

> Design issue #1 · 2026-02-20

## What promptbook is

An R package that treats a **coding instrument** (codebook + prompt instructions) as a single, versionable YAML artifact, and provides helpers to:

1. **Read** the YAML into R as a validated, structured object
2. **Convert** code definitions to `ellmer::type_object()` for structured LLM output
3. **Render** the codebook as a human-readable document (for appendices, human coders, review)

The primary audience is **novice-to-intermediate R programmers** in the social sciences. The API must be simple, discoverable, and forgiving.

## What promptbook is NOT

- **Not a workflow engine** — no pipeline DSL, no caching, no retry logic. `pb_annotate()` dispatches to ellmer but does not replace or wrap ellmer's execution model.

## Core components

| Component | Status | Notes |
|---|---|---|
| YAML schema for coding instruments | **In scope** | Single source of truth for the codebook |
| `read_promptbook()` → validated R object | **In scope** | Validates YAML against schema |
| R object → `ellmer::type_object()` | **In scope** | Core technical value of the package. Supports nested `object` type for structured multi-field extraction (e.g., array of actors with name/role/stance) |
| Codebook → human-readable document | **In scope** | For paper appendices, human coders |
| Run-level provenance/logging | **In scope (light)** | Investigate what ellmer returns; goal is simple per-run metadata (model, prompt version, timestamp), not per-row |
| Multi-file codebooks | **In scope (v2)** | Large instruments (20+ codes, long definitions) need splitting; design mechanism later |
| YAML validation on read | **In scope** | Catch errors early: missing categories, type mismatches, etc. |
| `pb_annotate()` convenience function | **In scope** | Takes data + promptbook, groups variables by model, dispatches extraction calls to ellmer, reassembles results. Handles the mechanical complexity of multi-model, multi-group annotation |
| Per-variable model config in YAML | **In scope** | E.g., haiku for simple categorical codes, sonnet-with-thinking for complex interpretive ones |
| Variable grouping | **In scope** | Variables can be grouped for separate extraction calls — needed both for per-model dispatch and to stay within structured output limits (~24 params) |
| Result column typing | **In scope** | `pb_annotate()` returns properly typed columns: factors (with levels/labels from categories), integer/double, logical, character. List-columns for `multiple: true` variables. Nested `object` types produce list-columns of tibbles |
| Haven-labelled output | **In scope (optional)** | `pb_as_labelled()` converts results to `haven::labelled()` columns with value labels and variable labels. Enables clean SPSS/Stata export. Uses haven if installed (suggests, not imports) |
| Inter-rater reliability metrics | **Out of scope** | Use irr/irrCAC directly on results |
| Model evaluation (vitals) | **Out of scope** | Category mismatch — vitals does LLM eval, not inter-rater reliability |
| Prompt engineering/optimization | **Out of scope** | |
| Data storage/database integration | **Out of scope** | |

## Key technical constraint: structured output limits

Modern context windows (128K–1M tokens) easily handle long prompts and many variables. The bottleneck is **structured output complexity**:

- Claude enforces a limit of ~24 optional parameters per schema
- Accuracy degrades with more fields (20 variables in one call is worse than 5×4 calls), especially on smaller models (Haiku, local)
- ellmer embeds variable descriptions in the type schema — long descriptions add to schema complexity

**Design implication**: Promptbook should support **variable grouping** — splitting 20 variables into multiple extraction calls (e.g., by group or by model). This can be manual (specified in YAML) or automatic. This further motivates `pb_annotate()`: handling multi-call extraction is exactly the kind of tedious-but-mechanical work a convenience function should do.

## Usage pattern: sequential/conditional annotation

Multi-pass annotation (e.g., "code cognitive demand first, then code detail variables only for demanding segments") requires no special package support. Researchers use multiple promptbooks with standard R filtering between calls. This is a documentation example, not a feature.

**Context-dependent coding** (second pass sees first pass's output via stateful chat) is feasible with plain ellmer (~15 lines). Deferred to a future version — can be done with manual ellmer code in the meantime. If added later, prefer an intent-based API (e.g., `depends_on` in YAML or `context =` argument) over mechanism-based naming (`_sequential`).

## Open questions (to resolve in later design issues)

- **Provenance**: What metadata does ellmer return per extraction? Do we need to capture anything beyond what ellmer already provides? (→ issue #4)
- **Per-variable model dispatch**: How does `pb_annotate()` handle variables with different models? One extraction call per model group? Sequential or parallel? (→ issue #3, #4)
- **Multi-file mechanism**: Custom YAML `!include` tag vs. R-level composition in `read_promptbook()`. (→ issue #2)
- **Render backend**: Quarto partial, standalone HTML, or codebookr integration? (→ issue #5)

## Design principles

1. **Novice-friendly**: A researcher with basic R skills should be able to go from YAML file to annotated data in under 10 lines of code.
2. **Single source of truth**: The YAML file *is* the codebook. No duplication between prompt and documentation.
3. **Composable with ellmer**: Power users can use `pb_type()` and `pb$system_prompt` directly with ellmer. `pb_annotate()` is a convenience layer, not a replacement.
4. **Minimal dependencies**: Avoid tidyverse dependency. Use base R + yaml + ellmer.
5. **Versionable**: YAML files live in version control alongside analysis code. Changes to the coding instrument are trackable.
