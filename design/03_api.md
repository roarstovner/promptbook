# Promptbook User-Facing API

> Design issue #3 · 2026-02-20

## Design goals

1. **Minimal surface area** — few functions, each with a clear purpose
2. **Novice-friendly** — a researcher with basic R skills goes from YAML to annotated data in under 10 lines
3. **Composable with ellmer** — power users drop down to ellmer at any point
4. **Pipe-friendly** — works naturally with `|>` but doesn't require it

## Function overview

| Function | Purpose | Returns |
|---|---|---|
| `read_promptbook()` | Read and validate a YAML file | `promptbook` object |
| `pb_type()` | Convert to `ellmer::type_object()` | `TypeObject` |
| `pb_annotate()` | Annotate a data frame | tibble with coded columns |
| `pb_render()` | Render human-readable codebook | file path (side effect: writes document) |
| `pb_as_labelled()` | Convert results to haven-labelled columns | tibble with `haven::labelled()` columns |

Five exported functions. That's the whole package API for v1.

## `read_promptbook()`

Reads a YAML file, validates it against the schema, and returns a structured R object.

```r
read_promptbook(path)
```

**Arguments**:
- `path` — Path to a YAML file

**Returns**: A `promptbook` object (S3 class), which is a named list with:
- `$title` — character
- `$version` — character or NULL
- `$description` — character or NULL
- `$author` — character or NULL
- `$prompt` — list with `$system` and `$user`
- `$variables` — list of `pb_variable` objects
- `$groups` — list of group definitions (or NULL)

The `promptbook` object has a `print()` method that shows a compact summary.

**Validation**: All validation (see design/02_yaml_schema.md) happens here. Errors are reported with clear messages pointing to the problematic field. Warnings are emitted for non-fatal issues (e.g., missing category descriptions, >20 ungrouped variables).

**Example**:

```r
pb <- read_promptbook("media_framing.yaml")
pb
#> # A promptbook: Media Framing Codebook
#> # Version: 1.0.0
#> # Variables: 8 (2 groups)
#> # Groups: basic (haiku), framing (sonnet)
```

### Accessor convenience

The `promptbook` object is a plain list — users access fields with `$`. No need for accessor functions:

```r
pb$title
#> [1] "Media Framing Codebook"

pb$prompt$system
#> [1] "You are an expert content analyst..."

pb$variables[[1]]$name
#> [1] "topic"
```

## `pb_type()`

Converts a promptbook (or a subset of its variables) to an `ellmer::type_object()`. This is the core technical bridge between the YAML schema and ellmer's structured data extraction.

```r
pb_type(promptbook, variables = NULL, group = NULL)
```

**Arguments**:
- `promptbook` — A `promptbook` object
- `variables` — Character vector of variable names to include. Default: all variables.
- `group` — Character scalar. If supplied, include only variables in this group. Cannot be combined with `variables`.

**Returns**: An `ellmer::TypeObject` — the exact object you'd pass to `chat$chat_structured(type = ...)`.

**Details**:

Each variable is converted according to the mapping in design/02_yaml_schema.md:

| YAML type | `multiple` | ellmer type |
|---|---|---|
| `categorical` | no | `type_enum()` |
| `categorical` | yes | `type_array(type_enum())` |
| `numeric` | no | `type_integer()` / `type_number()` |
| `text` | no | `type_string()` |
| `text` | yes | `type_array(type_string())` |
| `boolean` | no | `type_boolean()` |
| `object` | no | `type_object()` |
| `object` | yes | `type_array(type_object())` |

The `description` passed to each `type_*()` is constructed from the variable's YAML fields (description + categories/labels/min/max). The `required` field maps directly to the `required` argument of each type function.

**Example** — power user workflow:

```r
pb <- read_promptbook("media_framing.yaml")

# Get the type for all variables
type <- pb_type(pb)

# Or just one group
type_basic <- pb_type(pb, group = "basic")

# Use directly with ellmer
chat <- chat_anthropic(model = "claude-haiku-4-5-20251001")
chat$set_system_prompt(pb$prompt$system)

result <- chat$chat_structured(
  glue::glue(pb$prompt$user, text = my_article),
  type = type_basic
)
```

This is the escape hatch: researchers who need full control over the chat (custom turns, tool use, thinking, etc.) use `pb_type()` and `pb$prompt` directly with ellmer. `pb_annotate()` is sugar on top of this.

## `pb_annotate()`

The main convenience function. Takes data + promptbook, handles grouping, per-model dispatch, and result reassembly.

```r
pb_annotate(
  data,
  promptbook,
  text = text,
  chat = chat_anthropic(),
  method = c("parallel", "batch", "sequential"),
  ...
)
```

**Arguments**:
- `data` — A data frame containing the text to annotate
- `promptbook` — A `promptbook` object (or a path to a YAML file, which will be read automatically)
- `text` — <[`tidy-select`]> Column(s) to interpolate into the prompt template. Defaults to a column named `text`. For promptbooks with multiple placeholders (e.g., `{title}` and `{abstract}`), pass the corresponding columns. Uses tidy-select for column selection but the function does not depend on dplyr.
- `chat` — An ellmer chat object to use as a template. This determines the provider and default model. For groups or variables with `model` overrides, `pb_annotate()` creates new chat objects with the specified model. Defaults to `chat_anthropic()`.
- `method` — How to process rows:
  - `"parallel"` (default) — uses `ellmer::parallel_chat_structured()`. Fast, costs standard rate.
  - `"batch"` — uses `ellmer::batch_chat_structured()`. 50% cheaper, up to 24h wait. Only works with OpenAI and Anthropic.
  - `"sequential"` — processes one row at a time with `chat$chat_structured()`. Useful for debugging.
- `...` — Additional arguments passed to the underlying ellmer function (e.g., `max_active`, `rpm` for parallel; `path`, `wait` for batch).

**Returns**: The input `data` with new columns appended — one column per variable in the promptbook, properly typed (see Result column typing below).

**Processing logic**:

1. **Group variables** by `(group, model)`. Variables in the same group with the same model are extracted in one call. Variables with a per-variable `model` override that differs from the group model form a separate extraction call.

2. **For each (group, model) combination**:
   - Build the `type_object()` for that subset of variables (via `pb_type()`)
   - Build the prompts by interpolating the user template with each row's text column(s)
   - Create a chat object with the appropriate model and the system prompt
   - Dispatch to the chosen method (parallel/batch/sequential)

3. **Reassemble**: Column-bind results from all extraction calls back onto the original data frame.

4. **Type columns**: Convert raw LLM output to proper R types (factors, integers, list-columns, etc.) based on the YAML schema.

**Result column typing**:

| YAML type | `multiple` | R column type |
|---|---|---|
| `categorical` | no | `factor` (levels = category values, labels = category labels) |
| `categorical` | yes | list-column of `character` |
| `numeric` | no | `integer` (or `double` if `integer: false`) |
| `text` | no | `character` |
| `text` | yes | list-column of `character` |
| `boolean` | no | `logical` |
| `object` | no | list-column of named `list` |
| `object` | yes | list-column of `tibble` |

**Example** — typical workflow:

```r
library(promptbook)

pb <- read_promptbook("media_framing.yaml")
articles <- readr::read_csv("articles.csv")

# Annotate with defaults (parallel, Anthropic)
results <- pb_annotate(articles, pb, text = article_text)

# The result is a tibble with all original columns plus coded variables
results$topic      # factor
results$sentiment  # integer
results$actors     # list-column of tibbles
```

**Example** — batch processing:

```r
results <- pb_annotate(
  articles, pb,
  text = article_text,
  method = "batch",
  path = "batch_results.json"
)
```

**Example** — different provider:

```r
results <- pb_annotate(
  articles, pb,
  text = article_text,
  chat = chat_openai(model = "gpt-4.1")
)
```

### The `text` argument

The `text` argument uses tidy-select semantics (via `tidyselect::eval_select()`) for column identification, but promptbook does not depend on dplyr. This works because tidyselect is a lightweight standalone package.

For the common case — a single column with a single `{text}` placeholder — the user just names the column:

```r
pb_annotate(data, pb, text = article_text)
```

For multiple placeholders (e.g., `{title}` and `{abstract}`), the user passes the corresponding columns:

```r
# User template: "Title: {title}\n\nAbstract: {abstract}"
pb_annotate(data, pb, text = c(title, abstract))
```

Column names are matched to placeholder names in the user template. If the YAML has `{text}`, any single column works. If the YAML has `{title}` and `{abstract}`, the selected columns must include columns named `title` and `abstract`.

### Per-model dispatch

When variables have different model assignments (via `model` on the variable or group), `pb_annotate()` creates separate chat objects for each model. The `chat` argument serves as a template — its provider and configuration are preserved, only the model changes.

For example, with the media framing codebook:
- Group `basic` (model: haiku) → one `parallel_chat_structured()` call with haiku for `topic`, `sentiment`, `topics_all`, `has_data`
- Group `framing` (model: sonnet) → one `parallel_chat_structured()` call with sonnet for `frame`, `source_diversity`, `key_quote`, `actors`

Each group shares the same system prompt but extracts only its own variables.

### Progress reporting

`pb_annotate()` uses `cli::cli_progress_bar()` to report progress. With method `"parallel"`, progress is per-group (since `parallel_chat_structured()` handles per-row parallelism internally). With method `"sequential"`, progress is per-row.

```
Annotating 500 articles...
✔ Group 'basic' (haiku): 500/500 [12s]
✔ Group 'framing' (sonnet): 500/500 [45s]
```

## `pb_render()`

Renders the promptbook as a human-readable codebook document.

```r
pb_render(promptbook, output = NULL, format = c("html", "typst"))
```

**Arguments**:
- `promptbook` — A `promptbook` object (or path to YAML)
- `output` — Output file path. If NULL, generates a default name based on the promptbook title.
- `format` — Output format. Default: `"html"`.

**Returns**: The output file path (invisibly). Side effect: writes the rendered document.

**Details**: Uses a Quarto template bundled with the package. The rendered codebook includes:
- Title, version, author, description
- Each variable with its label, description, type, and categories/scale
- Group structure (if defined)
- The system prompt (optionally, controlled by a parameter)

This is designed for paper appendices and for sharing with human coders. The output is self-contained (single HTML file or PDF).

**Example**:

```r
pb <- read_promptbook("media_framing.yaml")
pb_render(pb, "codebook.html")
```

> Note: Full design of the renderer is deferred to design issue #5.

## `pb_as_labelled()`

Converts annotation results to haven-labelled columns for SPSS/Stata export.

```r
pb_as_labelled(data, promptbook)
```

**Arguments**:
- `data` — A data frame with annotation results (as returned by `pb_annotate()`)
- `promptbook` — A `promptbook` object (used to look up value labels and variable labels)

**Returns**: The input data frame with coded columns converted to `haven::labelled()` format:
- `categorical` → integer-coded with value labels
- `numeric` with `labels` → integer with value labels
- `boolean` → integer (0/1) with "No"/"Yes" labels
- `text` → unchanged (character)
- `object` → skipped with a message

Variable labels (from `label` field) are attached to all converted columns.

**Dependency**: haven is in `Suggests`. `pb_as_labelled()` checks for haven at runtime and gives a clear install instruction if missing.

**Example**:

```r
results <- pb_annotate(articles, pb, text = article_text)

# Convert for SPSS export
labelled_results <- pb_as_labelled(results, pb)
haven::write_sav(labelled_results, "coded_articles.sav")
```

## Complete workflow examples

### Minimal (10 lines)

```r
library(promptbook)

pb <- read_promptbook("media_framing.yaml")
articles <- read.csv("articles.csv")
results <- pb_annotate(articles, pb, text = article_text)

# results is a data frame with all original columns + coded variables
table(results$topic)
mean(results$sentiment)
```

### Power user (ellmer composability)

```r
library(promptbook)
library(ellmer)

pb <- read_promptbook("media_framing.yaml")

# Use pb_type() for just the basic codes
type_basic <- pb_type(pb, group = "basic")

# Full control over the chat
chat <- chat_anthropic(
  model = "claude-haiku-4-5-20251001",
  system_prompt = pb$prompt$system,
  params = params(max_tokens = 1024)
)

# Process a single article
result <- chat$chat_structured(
  paste("Code this article:", my_article),
  type = type_basic
)
```

### Batch processing (large dataset, 50% cheaper)

```r
library(promptbook)

pb <- read_promptbook("media_framing.yaml")
articles <- arrow::read_parquet("articles.parquet")

results <- pb_annotate(
  articles, pb,
  text = article_text,
  method = "batch",
  path = "annotation_batch.json"
)
```

### SPSS export

```r
library(promptbook)

pb <- read_promptbook("media_framing.yaml")
results <- pb_annotate(articles, pb, text = article_text)
labelled <- pb_as_labelled(results, pb)
haven::write_sav(labelled, "coded_articles.sav")
```

## Naming conventions

All exported functions use the `pb_` prefix except `read_promptbook()`, which follows the `read_*()` convention common in the R ecosystem (`readr::read_csv()`, `yaml::read_yaml()`, `readxl::read_excel()`).

The `pb_` prefix:
- Groups all functions under one autocomplete namespace
- Is short (2 characters + underscore)
- Avoids conflicts with other packages

## What's NOT in the API

- **No `pb_validate()`** — validation happens inside `read_promptbook()`. A separate validation function adds surface area without adding value; if you can read it, it's valid.
- **No `pb_write()`** — researchers write YAML by hand (or copy from examples). Programmatic YAML generation is an anti-pattern for this audience.
- **No `pb_merge()`** — multi-file composition is deferred to v2 and will be handled as an argument to `read_promptbook()`.
- **No `pb_compare()`** — comparing codebook versions is a git diff.
- **No caching or retry logic** — out of scope per design/01_scope.md.

## S3 class design

### `promptbook` class

```r
# Constructor (internal)
new_promptbook <- function(title, version, description, author, prompt, variables, groups) {
  structure(
    list(
      title = title,
      version = version,
      description = description,
      author = author,
      prompt = prompt,
      variables = variables,
      groups = groups
    ),
    class = "promptbook"
  )
}
```

**Methods**:
- `print.promptbook()` — compact summary (title, version, variable count, groups)
- `format.promptbook()` — for use in cli messages

### `pb_variable` class

Each variable in `$variables` is a `pb_variable` object (a named list with class). This is internal — users interact with it as a list. The class exists to support `print()` and internal dispatch.

## Dependencies

| Package | Type | Purpose |
|---|---|---|
| yaml | Imports | YAML parsing |
| ellmer | Imports | Type construction and LLM dispatch |
| cli | Imports | User-facing messages, progress bars |
| glue | Imports | Prompt template interpolation |
| rlang | Imports | Tidy evaluation for `text` argument, error handling |
| tidyselect | Imports | Column selection for `text` argument |
| haven | Suggests | `pb_as_labelled()` |
| quarto | Suggests | `pb_render()` |
| tibble | Imports | Result construction (tibble output) |

Note: tidyselect + rlang are lightweight and widely installed. They provide the column selection semantics without depending on dplyr.

## Open questions resolved

- **How many functions?** Five. Minimal surface area with clear separation of concerns.
- **Pipe-friendliness?** `pb_annotate()` takes data as first argument, returns data — works with `|>`. Other functions take promptbook as first argument for consistency.
- **Naming?** `read_promptbook()` follows `read_*()` convention; everything else uses `pb_` prefix.
- **Composability with ellmer?** `pb_type()` returns a standard `TypeObject`; `pb$prompt$system` is a plain string. Power users can ignore `pb_annotate()` entirely.
- **Per-model dispatch?** `pb_annotate()` groups by (group, model) and creates separate chat objects per model.

## Open questions remaining

- **`text` argument design**: Should `text` use tidy-select or a simpler approach (bare column name or string)? Tidy-select handles the multi-placeholder case elegantly but adds a dependency. A simpler approach: `text = "article_text"` (string) or `text = c(title = "title_col", abstract = "abstract_col")` (named vector). → Revisit during implementation.
- **Progress for batch method**: `batch_chat_structured()` is inherently asynchronous. How should `pb_annotate()` report progress for multi-group batch annotation? → Revisit during implementation.
- **Error handling for partial failures**: If one group succeeds but another fails, should `pb_annotate()` return partial results? ellmer's `on_error` parameter provides some control. → Revisit during implementation (issue #4).
