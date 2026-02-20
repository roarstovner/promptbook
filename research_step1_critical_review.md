# Promptbook — Critical Review: Should it be built?

> Date: 2026-02-19

## Summary

The gap is **real but narrow**. The strongest counter-argument is that promptbook's value might be better delivered as a **convention** (YAML spec + blog post + Quarto template) rather than a **package**.

---

## 1. The R ecosystem has moved — the gap is narrower than claimed

The landscape research (2026-02-19) may already be stale on key points:

- **ellmer** has likely added `batch_chat_structured()` / parallel batch features. The "no batch orchestration" claim needs verification against current ellmer.
- **mall** may now support multi-provider and parallel processing.
- **vitals** is on CRAN as a real evaluation framework.
- **LLMR** and **tidyllm** have added structured output and batch features.

The original six-point gap may have shrunk to two or three points.

## 2. The strongest argument: "convention, not code"

Today's workflow is roughly:

```r
library(ellmer)
codebook <- yaml::read_yaml("my_codebook.yaml")
my_type <- type_object(
  topic = type_enum(codebook$codes$topic$values, codebook$codes$topic$description),
  sentiment = type_integer(codebook$codes$sentiment$description)
)
chat <- chat_openai(system_prompt = codebook$system_prompt)
results <- parallel_chat_structured(chat, my_data$text, type = my_type)
```

That's ~10 lines. The value promptbook adds over this:

- Automatic YAML-to-`type_object()` conversion
- Human-readable codebook rendering
- Provenance metadata

Is that enough to justify a package? Or would a **blog post + YAML schema spec + Quarto template** serve the same purpose with zero maintenance burden?

A package must track ellmer's fast-moving API, handle CRAN checks, and support edge cases. A convention has no maintenance cost.

## 3. vitals integration is a category error

The research claims output "compatible with vitals:: for reliability assessment." But:

- **vitals** does LLM evaluation (is the model getting the right answer?), not inter-rater reliability (do the human and LLM agree?)
- Social scientists need **Krippendorff's alpha** / **Cohen's kappa** (from `irr::` or `irrCAC::`), which work on any data frame
- No special package integration is needed for reliability — it's just a matrix of coder-by-item ratings

This conflation weakens the value proposition. One of the six claimed gaps isn't a real gap.

## 4. YAML may be the wrong authoring format

R researchers work in `.R` / `.qmd`. A codebook-as-code API:

```r
pb <- promptbook(
  code("topic", type = "categorical",
       definition = "The primary subject",
       categories = c(economy = "About economic policy...",
                      climate = "About climate change..."))
)
```

would be more discoverable, auto-completable, and testable than YAML. The portability argument (Python can read YAML) is speculative — it only matters if cross-language adoption happens, which requires a community that doesn't exist yet.

## 5. Target audience is small but growing

LLM-as-coder papers are exploding (Gilardi, Rathje, "Codebook LLMs" in Political Analysis, "Just Read the Codebook" at COLING 2025). R remains strong in political science and communication studies. The audience exists, but it's unclear if it's large enough to sustain a package.

## 6. What IS still valid

The research correctly identifies that:

- No package in any language unifies codebook + prompt + rendering as a single artifact
- Academic researchers reinvent the wheel massively (pasting codebook text as plain strings)
- The composable pieces exist but aren't connected
- The YAML schema design is genuinely well thought out

---

## Gap reassessment

| Claimed gap | Still a gap? |
|---|---|
| Persistent codebook artifact | **Yes** — genuine, unaddressed |
| Machine-executable prompt spec | **Partially** — ellmer `type_object()` covers this |
| Portable YAML format | **Yes** — but speculative value without cross-language community |
| Human-readable codebook rendering | **Yes** — genuine, unaddressed |
| Batch annotation workflow | **Probably not** — ellmer likely covers this now |
| vitals compatibility | **Category error** — vitals does eval, not inter-rater reliability |

## The real question

**Is this a package or a blog post?** The residual value (YAML→type_object conversion, codebook rendering, provenance logging) might be better served by a published YAML spec + Quarto template + example script. Zero maintenance, immediate usability.

If you still want to build a package, the scope should be much smaller than envisioned: just the YAML↔ellmer bridge and the codebook renderer. Don't wrap batch processing (let ellmer handle it). Don't promise vitals integration (it's a category mismatch). Don't build a workflow orchestrator.

---

## Relevant academic literature

- "Codebook LLMs" — Political Analysis (Cambridge)
- "Scaling Hermeneutics" — EPJ Data Science 2025
- "Just Read the Codebook" — COLING 2025
- Gilardi et al. 2023, Rathje et al. 2023, Mellon & Prosser 2023

## Next steps if proceeding

1. Verify current ellmer batch/parallel capabilities against claims
2. Decide: package vs. convention (blog post + YAML spec + Quarto template)
3. If package: scope down to YAML↔ellmer bridge + codebook renderer only
4. Replace "vitals compatibility" with "irr/irrCAC compatibility" or drop it entirely
