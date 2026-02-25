
# promptbook

<!-- badges: start -->
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

Documented, reproducible, reusable data annotation with LLMs.

promptbook lets you define a coding instrument as a structured YAML file ---
the **promptbook** --- and apply it to datasets using large language models
via [ellmer](https://ellmer.tidyverse.org). The same YAML file drives the
LLM prompts, a human-readable codebook, and properly typed R output.

## Installation

``` r
# install.packages("pak")
pak::pak("robast/promptbook")
```

## Quick start

**1. Write a promptbook YAML file** with your coding instrument:

``` yaml
schema_version: 1
title: "Sentiment Codebook"

prompt:
  system: |
    You are an expert content analyst. Code the text according
    to the variables below.

variables:
  - name: sentiment
    label: "Overall sentiment"
    description: "The overall evaluative tone. Use the full scale."
    type: numeric
    min: 1
    max: 5
    labels:
      1: "Very negative"
      3: "Neutral"
      5: "Very positive"

  - name: topic
    label: "Primary topic"
    description: "The dominant topic of the text."
    type: categorical
    categories:
      - value: "economy"
        label: "Economic impacts"
      - value: "health"
        label: "Public health"
      - value: "environment"
        label: "Environmental impacts"
```

**2. Read and annotate:**

``` r
library(promptbook)
library(ellmer)

pb <- read_promptbook("codebook.yaml")

articles <- data.frame(
  id   = 1:100,
  text = my_article_texts
)

results <- articles |>
  pb_annotate(pb, chat = chat_anthropic())

results$sentiment  # integer
results$topic      # factor
```

That's it. `pb_annotate()` handles prompt interpolation, structured output
schemas, variable grouping, per-model dispatch, and result typing.

## Why promptbook?

Research workflows need a coding instrument that serves multiple purposes:
LLM prompts, human codebooks, documentation for paper appendices. Without
promptbook, these tend to drift apart. With promptbook, the YAML file is
the **single source of truth** --- change it once, and everything updates.

Key features:

- **Five variable types**: `categorical`, `numeric`, `text`, `boolean`,
  and `object`. (Use `multiple: true` for arrays)
- **Variable grouping**: LLMs struggle with many variables; use `group` to split
  variables across separate LLM calls
- **Per-model dispatch**: Use fast/cheap models for simple codes and
  stronger models for complex ones
- **Properly typed output**: Factors with ordered levels, integers,
  list-columns for multi-valued variables
- **Human-readable codebook**: Render the same YAML as an HTML or PDF
  document for appendices or human coders
- **Labelled results and SPSS/Stata export**: Convert results to haven-labelled format

## API overview

| Function | Purpose |
|---|---|
| `read_promptbook()` | Read and validate a YAML file |
| `pb_annotate()` | Annotate a data frame using the promptbook |
| `pb_type()` | Convert to an `ellmer::type_object()` for direct use with ellmer |
| `pb_render()` | Render a human-readable codebook (HTML or PDF) |
| `pb_as_labelled()` | Convert results to haven-labelled columns for SPSS/Stata |

## Variable grouping and per-model dispatch

For large instruments or when different codes need different models, assign
variables to groups:

``` yaml
variables:
  - name: topic
    group: basic
    # ...
  - name: frame
    group: framing
    # ...

groups:
  basic:
    model: fast
  framing:
    model: strong
```

`pb_annotate()` dispatches one extraction call per group, using the
specified model for each:

``` r
chat <- list(
  fast   = chat_anthropic(model = "claude-haiku"),
  strong = chat_anthropic(model = "claude-sonnet")
)

results <- pb_annotate(articles, pb, chat)
```

## Power-user workflow

If you need full control over the chat (custom turns, tool use, thinking),
use `pb_type()` directly with ellmer:

``` r
library(ellmer)

pb <- read_promptbook("codebook.yaml")
type <- pb_type(pb, group = "basic")

chat <- chat_anthropic(system_prompt = pb$prompt$system)
result <- chat$chat_structured(
  paste("Code this article:", article_text),
  type = type
)
```

## Rendering a codebook

Generate a self-contained HTML or PDF codebook from the same YAML:

``` r
pb_render(pb, "codebook.html")
pb_render(pb, "codebook.pdf", format = "typst")
```

## Labelled results and SPSS/Stata export

``` r
labelled_results <- pb_as_labelled(results, pb)
haven::write_sav(labelled_results, "coded_articles.sav")
```
