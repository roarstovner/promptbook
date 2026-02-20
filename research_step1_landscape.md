# Promptbook — Step 1 Research: Ecosystem Landscape

> Status: complete (2026-02-19)

## Verdict: promptbook is not redundant

No existing R package fills the gap. No existing package in any language unifies:
1. A researcher-written codebook (definitions, examples, scale anchors)
2. A machine-executable LLM prompt specification
3. Portable storage format (cross-language YAML/JSON)
4. Human-readable codebook rendering
5. Batch annotation workflow (rate limiting, caching, progress)
6. Output compatible with `vitals::` for reliability assessment

---

## R ecosystem

| Package | Role | Gap vs promptbook |
|---------|------|-------------------|
| `ellmer` | LLM API client — the execution engine | No persistent codebook artifact; no batch orchestration; no vitals output |
| `mall` | Single-variable LLM column ops (Ollama-first) | One code per API call; no typed schema; no codebook |
| `tidyllm` | Alternative LLM client | Same gaps as ellmer |
| `codebookr` | Generates codebook PDF/HTML from already-coded R data frames | Opposite direction: FROM coded data, not TO LLM prompt |
| `vitals` | LLM output evaluation vs. gold standard | Post-annotation validation only — not annotation itself |
| `rollama`/`ollamar` | Ollama-specific clients | Same gaps as ellmer |

**Can you do it in ~50 lines of plain ellmer?** Yes, for a quick experiment:

```r
library(ellmer)
coding_type <- type_object(
  "Coded article",
  topic    = type_enum("Main topic", values = c("economy", "climate", "health", "other")),
  sentiment = type_integer("Sentiment 1-5")
)
chat <- chat_openai(model = "gpt-4o", system_prompt = "You are a coder...")
results <- data |> mutate(coded = map(text, \(t) chat$extract_data(t, type = coding_type))) |> unnest_wider(coded)
```

**What this 50-line version lacks:**

| Feature | 50-line code | promptbook |
|---|---|---|
| Persistent, shareable codebook file | No | Yes (`.promptbook.yaml`) |
| Cross-language portability | No | Yes (YAML readable from Python, Julia) |
| Human-readable codebook PDF/HTML | No | Yes |
| Per-code definitions, examples, scale anchors | No (type labels only) | Yes |
| Batch processing with rate-limit / backoff | No (sequential) | Yes |
| `vitals::` output compatibility | No | Yes |
| Validation of coded values | No | Yes |
| Provenance log (model, date, prompt version) | No | Yes |

---

## Other languages

### Python — most relevant packages

**`instructor`** (jxnl/instructor, ~9k stars, MIT)
- Patches OpenAI/Anthropic clients to return Pydantic model instances
- Schema = Pydantic class; JSON Schema via `model.model_json_schema()`
- **Proximity: 6/10** — solves structured output elegantly; no codebook, no human rendering, no batch workflow, Python-only

**`outlines`** (dottxt-ai/outlines, ~11k stars, Apache 2.0)
- Constrained generation via FSMs compiled from JSON Schema
- Best for local models; API usage is secondary
- **Proximity: 5/10** — constraint mechanism; no codebook concept

**`guidance`** (microsoft/guidance, ~19k stars, MIT)
- DSL for interleaving LLM generation with program logic; named constrained slots
- **Proximity: 7/10** — named-slot multi-code concept is closest to promptbook in spirit; but codebook is imperative Python code, no serialization format

**`DSPy`** (stanfordnlp/dspy, ~19k stars, MIT)
- Auto-optimizes LLM prompts from examples; Signature = typed I/O spec
- **Proximity: 6/10** — Signature concept is like a codebook; but auto-generated prompts contradict researcher-written codebooks

**`spacy-llm`** (explosion/spacy-llm, ~1k stars, MIT)
- LLM components in spaCy pipelines; YAML config with `label_definitions` per code
- **Proximity: 7/10** — `label_definitions` dict IS a codebook; fixed to spaCy architecture
- **Key pattern to adopt: `label_definitions` per code**

**`LangChain`** (Python/JS, ~93k stars)
- All the pieces, assembled ad hoc; Hub YAML format for prompt storage
- **Proximity: 6/10** — too heavy; no unified codebook+prompt artifact

**Simon Willison's `llm` tool** (Python/CLI, ~6.5k stars, Apache 2.0)
- Named prompt templates stored as YAML: `system:` + `prompt:` + `defaults:`
- **Proximity: 5/10** — clean minimal format; no typed schema
- **Key pattern to adopt: `system:` + `user_template:` YAML split**

**`Label Studio`** (Python/JS, annotation platform)
- XML config with `<Choice value="economy" hint="About economic policy..."/>`
- **Proximity: 7/10** for the concept; `hint` attribute = per-code definition
- **Key pattern to adopt: per-code `definition` field**

### Academic literature

Papers (Gilardi et al. 2023, Ornstein et al. 2022, Mellon & Prosser 2023, Rathje et al. 2023) consistently show: **researchers paste codebook text as plain text into system prompts and manually parse JSON output**. No standard format, massive reinvention across research groups. Confirms the gap.

---

## What to adopt (not port)

| Pattern | Source | How to use in promptbook |
|---------|--------|--------------------------|
| JSON Schema as typed schema format | OpenAI/Anthropic tool-call spec; instructor; outlines | The internal wire format; `ellmer::type_*()` already emits this |
| `label_definitions` per code | spaCy-llm YAML config | Each code in the codebook YAML has a `definition:` field |
| `system:` + `user_template:` split | Simon Willison's `llm` YAML | Separate system instructions from per-text user prompt |
| Per-code `hint`/`definition` | Label Studio XML | `definition:` + `examples:` fields per code |
| Typed fields with descriptions | DSPy Signature | Each code has `type:` + `description:` + constraints |
| Jinja2 `{{variable}}` syntax | PromptFlow, LangChain | Standard template variables in `user_template:` |

---

## Recommended `.promptbook.yaml` schema

```yaml
meta:
  name: "media-climate-coder"
  version: "1.0.0"
  description: "Coding instrument for climate coverage in news media"
  author: "Your Name"
  created: "2025-01-15"
  llm_tested: ["gpt-4o", "claude-3-5-sonnet-20241022"]

prompt:
  system: |
    You are an expert in content analysis of news media.
    Apply the following coding instrument consistently and precisely.
    When uncertain, choose the most prominent theme.
  user_template: |
    Code the following {{text_type}} according to the codebook.

    Text: {{text}}

    Assign all codes defined in the codebook.

codebook:
  - name: topic
    label: "Main topic"
    description: "The primary subject matter of the text"
    type: categorical
    required: true
    categories:
      - value: "economy"
        label: "Economy"
        definition: "Coverage primarily about economic policy, markets, trade, employment"
        examples: ["GDP growth", "unemployment rate", "trade deficit"]
      - value: "climate"
        label: "Climate & environment"
        definition: "Coverage about climate change, environmental policy, natural disasters"
        examples: ["Paris Agreement", "carbon emissions", "wildfires"]
      - value: "other"
        label: "Other"
        definition: "Does not primarily fit any above category"

  - name: sentiment
    label: "Evaluative tone"
    description: "Overall evaluative tone of the coverage"
    type: integer
    required: true
    minimum: 1
    maximum: 5
    scale_labels:
      1: "Very negative / critical"
      3: "Neutral / balanced"
      5: "Very positive / favorable"

  - name: mentions_uncertainty
    label: "Mentions scientific uncertainty"
    description: "Whether the text explicitly mentions scientific uncertainty or debate"
    type: boolean
    required: false
```

---

## Architecture sketch

```
.promptbook.yaml  (source of truth)
     |
     v
read_promptbook()          # parses YAML → R list, class "promptbook"
     |
     +---> as_ellmer_type()     # → ellmer type_object() for extract_data()
     +---> as_human_codebook()  # → HTML/PDF via rmarkdown/quarto
     +---> as_vitals_task()     # → vitals Task for reliability assessment
     |
     v
annotate(pb, data, backend = chat_openai("gpt-4o"), batch_size = 50)
     |
     v
annotation_log   # tibble with one row per text, one col per code
                 # + metadata: model, promptbook_version, timestamp, raw_response
     |
     v
vitals::eval_log()   # reliability vs. human gold standard
```

---

## Next step (issue #3)

Survey complete. Step 2 is to check if any cross-language package is worth porting (vs. designing from scratch). Preliminary verdict from this survey: **design from scratch, adopting the patterns listed above**. The closest candidate for "port" would be the spaCy-llm YAML concept, but its architecture is incompatible with R research workflows.
