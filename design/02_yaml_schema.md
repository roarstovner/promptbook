# Promptbook YAML Schema Design

> Design issue #2 · 2026-02-20

## Design goals

1. **Human-authored** — researchers write this by hand; readability and simplicity matter more than machine convenience
2. **Single source of truth** — the YAML contains everything needed to generate both a human codebook and an `ellmer::type_object()` schema
3. **Maps cleanly to ellmer** — each variable maps to one `type_*()` call; the top-level structure maps to `type_object()`
4. **Versionable** — the file lives in version control alongside analysis code

## Schema overview

```yaml
# ---- metadata ----
schema_version: 1
title: "Media Framing Codebook"
version: "1.2.0"
description: >
  Coding instrument for newspaper coverage of climate policy.
  Developed for the EXAMPLE project (Grant #12345).
author: "Jane Researcher"

# ---- prompt instructions ----
prompt:
  system: |
    You are an expert content analyst. You will be given a newspaper
    article and must code it according to the codebook below.
    Be conservative: if unsure, choose the most neutral category.
  user: |
    Code the following article:

    {text}

# ---- variables ----
variables:
  - name: topic
    label: "Primary topic"
    description: >
      The dominant topic of the article. Choose the single best fit.
    type: categorical
    categories:
      - value: "economy"
        label: "Economic impacts"
        description: "Focus on costs, jobs, GDP, trade effects"
      - value: "health"
        label: "Public health"
        description: "Focus on health outcomes, disease, mortality"
      - value: "environment"
        label: "Environmental impacts"
        description: "Focus on ecosystems, biodiversity, pollution"
      - value: "politics"
        label: "Political process"
        description: "Focus on legislation, elections, party positions"
    group: basic
    required: true  # default is false; set true when LLM must always provide a value

  - name: sentiment
    label: "Overall sentiment"
    description: >
      The overall evaluative tone toward the policy. Use the full
      scale; reserve 3 for genuinely neutral articles.
    type: numeric
    min: 1
    max: 5
    labels:
      1: "Very negative"
      2: "Somewhat negative"
      3: "Neutral"
      4: "Somewhat positive"
      5: "Very positive"
    group: basic

  - name: frame
    label: "Dominant frame"
    description: >
      The primary interpretive frame used in the article.
    type: categorical
    categories:
      - value: "conflict"
        label: "Conflict"
      - value: "consequence"
        label: "Economic consequence"
      - value: "human_interest"
        label: "Human interest"
      - value: "morality"
        label: "Morality"
      - value: "responsibility"
        label: "Responsibility attribution"
    group: framing
    model: sonnet

  - name: key_quote
    label: "Key quote"
    description: >
      The most representative direct quote from the article.
      Return empty string if no direct quotes are present.
    type: text
    group: framing
    required: false

  - name: topics_mentioned
    label: "All topics mentioned"
    description: >
      All topics that receive substantial coverage in the article.
      Select all that apply.
    type: categorical
    multiple: true
    categories:
      - value: "economy"
        label: "Economic impacts"
      - value: "health"
        label: "Public health"
      - value: "environment"
        label: "Environmental impacts"
      - value: "politics"
        label: "Political process"
    group: basic

  - name: has_data
    label: "Contains statistical data"
    description: "Whether the article cites any quantitative data or statistics."
    type: boolean
    group: basic

  - name: actors
    label: "Political actors"
    description: >
      All political actors quoted or whose positions are described.
    type: object
    multiple: true
    properties:
      - name: actor_name
        type: text
        description: "Full name as mentioned in the article"
      - name: role
        type: categorical
        description: "The actor's role"
        categories:
          - value: "politician"
          - value: "expert"
          - value: "activist"
          - value: "citizen"
          - value: "other"
      - name: stance
        type: categorical
        description: "The actor's stance on the policy discussed"
        categories:
          - value: "support"
          - value: "oppose"
          - value: "neutral"
          - value: "unclear"
    group: framing

# ---- groups (optional) ----
groups:
  basic:
    label: "Basic codes"
    description: "Simple codes that can be assigned quickly"
    model: haiku
  framing:
    label: "Framing analysis"
    description: "More complex interpretive codes"
    model: sonnet
```

## Field reference

### Top-level metadata

| Field | Required | Description |
|---|---|---|
| `schema_version` | yes | Integer schema version (currently `1`). Used by `read_promptbook()` to handle future schema changes. |
| `title` | yes | Human-readable title for the coding instrument |
| `version` | no | Semantic version string for the codebook itself (e.g., `"1.2.0"`) |
| `description` | no | Longer description; appears in rendered codebook |
| `author` | no | Author name(s) |

`schema_version` is for the promptbook file format itself — it tells `read_promptbook()` how to parse the file. `version` is for the codebook content — it tracks the researcher's revisions to the coding instrument. The other fields are for documentation and provenance only. None of these affect LLM behavior.

### `prompt`

| Field | Required | Description |
|---|---|---|
| `system` | yes | System prompt sent to the LLM. Should contain general instructions for the annotation task. |
| `user` | no | User message template. Must contain `{text}` as a placeholder for the text to be coded. If omitted, a default template is used. |

The system prompt is the researcher's main lever for controlling LLM behavior. Variable descriptions are embedded automatically in the structured output schema (via ellmer), so they do not need to be repeated in the prompt — but the prompt can reference them for emphasis or clarification.

**Design decision — `{text}` placeholder**: We use a single `{text}` placeholder in the user template. This keeps the common case trivial. Researchers who need multiple input fields (e.g., title + abstract) can use `{title}` and `{abstract}` and pass named columns in `pb_annotate()`. The placeholder syntax uses single braces for readability (not `{{glue}}` style); we use `glue::glue()` or simple `gsub()` under the hood.

### `variables`

Each variable in the list defines one code to be assigned.

| Field | Required | Type | Description |
|---|---|---|---|
| `name` | yes | string | Machine-readable name; becomes the column name in output. Must be a valid R name. |
| `label` | no | string | Human-readable label for codebook rendering. Defaults to `name` if omitted. |
| `description` | yes | string | Definition of the variable. Sent to the LLM as the type description and printed in the human codebook. This is the single source of truth. |
| `type` | yes | string | One of: `categorical`, `numeric`, `text`, `boolean`, `object` |
| `multiple` | no | logical | If `true`, the LLM returns an array of values instead of a single value. Default: `false`. Only valid for `categorical`, `text`, and `object`. See [Arrays](#arrays-multiple-true). |
| `required` | no | logical | Whether the LLM must provide a value. Default: `false`. When `false`, the LLM may return `null`, which becomes `NA` in R. When `true`, the LLM is forced to produce a value — use this only when a code truly must always be assigned, as it can cause hallucination when the data doesn't fit. |
| `group` | no | string | Group name for batched extraction. Variables in the same group are extracted in one LLM call. |
| `model` | no | string | Model override for this variable. If set, overrides the group-level model. |

#### Type-specific fields

**`categorical`** — maps to `ellmer::type_enum()`

| Field | Required | Description |
|---|---|---|
| `categories` | yes | List of category objects |
| `categories[].value` | yes | Machine-readable value (returned by LLM, appears in data) |
| `categories[].label` | no | Human-readable label for codebook. Defaults to `value`. |
| `categories[].description` | no | Definition of this category. Sent to LLM in the enum description and printed in codebook. |

**`numeric`** — maps to `ellmer::type_integer()` or `ellmer::type_number()`

| Field | Required | Description |
|---|---|---|
| `min` | no | Minimum value (included in description; not enforced by JSON schema) |
| `max` | no | Maximum value (included in description; not enforced by JSON schema) |
| `integer` | no | If `true`, maps to `type_integer()`. Default: `true` (most coding scales are integer). |
| `labels` | no | Named map of value → label (e.g., `1: "Very negative"`). Included in description for the LLM and in the codebook. |

**`text`** — maps to `ellmer::type_string()`

No additional fields. The `description` tells the LLM what to write.

**`boolean`** — maps to `ellmer::type_boolean()`

No additional fields.

**`object`** — maps to `ellmer::type_object()`

| Field | Required | Description |
|---|---|---|
| `properties` | yes | List of sub-variable definitions. Each property uses the same field structure as a top-level variable (`name`, `type`, `description`, etc.) except that `group` and `model` are not allowed on properties. |

Object variables define a structured record with named fields. Combined with `multiple: true`, they represent an array of records — this maps to `type_array(type_object(...))` in ellmer, which returns a tibble. A non-`multiple` object is a single record (a named list in R).

Properties can use any scalar type (`categorical`, `numeric`, `text`, `boolean`) but not nested `object` types. One level of nesting is sufficient for content analysis use cases and keeps the YAML readable.

**Example**:

```yaml
- name: sources
  label: "Sources cited"
  description: "All sources quoted or cited in the article"
  type: object
  multiple: true
  properties:
    - name: source_name
      type: text
      description: "Name of the person or organization"
    - name: source_type
      type: categorical
      description: "Type of source"
      categories:
        - value: "official"
          label: "Government/official"
        - value: "expert"
          label: "Academic/expert"
        - value: "industry"
          label: "Industry/business"
        - value: "civil_society"
          label: "NGO/civil society"
        - value: "citizen"
          label: "Ordinary citizen"
    - name: is_quoted
      type: boolean
      description: "Whether the source is directly quoted (vs. paraphrased)"
```

### Arrays (`multiple: true`)

Variables of type `categorical`, `text`, or `object` can be modified with `multiple: true` to indicate the LLM should return an array of values rather than a single value. This maps to `ellmer::type_array(type_*())`.

`multiple: true` is not valid for `numeric` or `boolean` — these have no clear content analysis use case and their array semantics (empty arrays, required + multiple) would be confusing.

**Use cases**:
- `categorical` + `multiple: true` → "select all that apply" (maps to `type_array(type_enum(...))`)
- `text` + `multiple: true` → "list all X" (maps to `type_array(type_string())`)
- `object` + `multiple: true` → "extract all records" (maps to `type_array(type_object(...))`) — see [Object type](#object--maps-to-ellmertype_object)

**Example**:

```yaml
- name: topics_mentioned
  label: "All topics mentioned"
  description: "Select all topics that receive substantial coverage."
  type: categorical
  multiple: true
  categories:
    - value: "economy"
    - value: "health"
    - value: "environment"

- name: named_entities
  label: "Named entities"
  description: "All people, organizations, or places mentioned by name."
  type: text
  multiple: true
```

**In R output**: `multiple: true` variables produce list-columns. For `categorical` and `text`, each cell contains a character vector. For `object`, each cell contains a tibble (since ellmer converts arrays of objects to tibbles). This matches how R handles multi-valued observations in data frames.

### `groups` (optional)

Groups control how variables are batched into separate LLM calls. If no groups are defined, all variables are extracted in a single call (subject to the ~24 parameter limit).

| Field | Required | Description |
|---|---|---|
| `<group_name>.label` | no | Human-readable label |
| `<group_name>.description` | no | Description of the group's purpose |
| `<group_name>.model` | no | Default model for variables in this group |

**Grouping rules**:
- Variables without a `group` field go into a default (unnamed) group
- A variable's `model` field overrides its group's `model`
- `pb_annotate()` dispatches one extraction call per (group × model) combination

## Mapping to ellmer types

The conversion is straightforward:

| YAML `type` | `multiple` | ellmer function | Notes |
|---|---|---|---|
| `categorical` | no | `type_enum(values, description)` | `values` = category values; `description` includes category labels/descriptions |
| `categorical` | yes | `type_array(type_enum(values, description))` | "Select all that apply" |
| `numeric` | no | `type_integer(description)` | Description includes min/max/labels |
| `numeric` (integer: false) | no | `type_number(description)` | Rare; for continuous scales |
| `text` | no | `type_string(description)` | |
| `text` | yes | `type_array(type_string(description))` | "List all X" |
| `boolean` | no | `type_boolean(description)` | |
| `object` | no | `type_object(prop1 = type_*(), ...)` | Properties map to named type arguments |
| `object` | yes | `type_array(type_object(...))` | Returns tibble; "extract all records" |

The description passed to ellmer is **constructed** from the variable's `description` plus type-specific fields. For example, a numeric variable with `min: 1, max: 5` and labels gets a description like:

> The overall evaluative tone toward the policy. Use the full scale; reserve 3 for genuinely neutral articles. Scale: 1 (Very negative) to 5 (Very positive).

For categorical variables, the category descriptions are appended:

> The dominant topic of the article. Choose the single best fit. Categories: economy = Economic impacts (Focus on costs, jobs, GDP, trade effects); health = Public health (Focus on health outcomes, disease, mortality); ...

This means the YAML `description` field does double duty: it's printed in the human codebook AND sent to the LLM, ensuring consistency.

## Result column typing

The YAML schema contains enough information to fully specify R column types for annotation results. This eliminates the need for manual type conversion and ensures consistency between the codebook definition and the resulting data.

### Base R types (built into `pb_annotate()`)

| YAML type | `multiple` | R column type | Details |
|---|---|---|---|
| `categorical` | no | `factor` | Levels = `categories[].value`, labels = `categories[].label` |
| `categorical` | yes | list-column of `character` | Each cell is a character vector; values constrained to category values |
| `numeric` | no | `integer` (or `double`) | `integer` by default; `double` when `integer: false` |
| `text` | no | `character` | |
| `text` | yes | list-column of `character` | |
| `boolean` | no | `logical` | |
| `object` | no | list-column of named `list` | Each cell is a single named list (rare use case) |
| `object` | yes | list-column of `tibble` | Each cell is a tibble with one row per extracted record |

The factor conversion is particularly valuable: category order in the YAML determines factor level order, which controls plotting order in ggplot2 and table presentation. Researchers define this once in the YAML and it propagates everywhere.

### Haven-labelled output (`pb_as_labelled()`)

For researchers who work with SPSS or Stata, `pb_as_labelled()` converts results to `haven::labelled()` columns:

| YAML type | haven output | Details |
|---|---|---|
| `categorical` | `labelled(integer, labels)` | Integer-coded with value labels from `categories[].value` → `categories[].label` |
| `numeric` with `labels` | `labelled(integer, labels)` | Value labels from the `labels` map (e.g., `1 = "Very negative"`) |
| `numeric` without `labels` | `integer` / `double` | No labelling needed |
| `text` | `character` | No labelling needed |
| `boolean` | `labelled(integer, c(No = 0L, Yes = 1L))` | Standard SPSS boolean convention |
| `object` | — | Not supported by `pb_as_labelled()`. Object/list-column variables are skipped with a message. |

Variable labels (from the `label` field) are attached to all columns via `haven::labelled()`.

**Dependency strategy**: haven is listed in `Suggests`, not `Imports`. `pb_as_labelled()` checks for haven at runtime and gives a clear error if not installed. This keeps the base package lightweight.

**No YAML changes needed**: All information required for column typing is already present in the schema (types, categories with values/labels, numeric labels, min/max). This is a pure implementation concern.

## Multi-file support (v2)

For large instruments (20+ variables, long definitions), a single YAML file becomes unwieldy. The preferred mechanism for v2 is **R-level composition** rather than custom YAML tags:

```r
pb <- read_promptbook("main.yaml", variables = c("groups/basic.yaml", "groups/framing.yaml"))
```

This avoids `!include` custom YAML tags, which require a custom loader and make the YAML non-portable. R-level composition is simpler to implement, easier to debug (error messages point to specific files), and keeps the YAML files as standard YAML.

This is deferred — for v1, all variables live in one file.

## Validation rules

`read_promptbook()` validates the YAML on load. Errors are reported with clear messages pointing to the problematic field.

**Required fields**: `schema_version`, `title`, `prompt.system`, and for each variable: `name`, `type`, `description`.

**Type checks**:
- `schema_version` must be a positive integer
- `type` must be one of: `categorical`, `numeric`, `text`, `boolean`, `object`
- `multiple` must be logical if present; only valid for `categorical`, `text`, `object`
- `categorical` variables must have `categories` with at least one entry
- Each category must have a `value`
- `object` variables must have `properties` with at least one entry; properties follow the same validation rules as top-level variables (except `group` and `model` are not allowed)
- `object` properties cannot themselves be of type `object` (no deep nesting)
- `name` must be a valid R name (`make.names(name) == name`)
- `group` references must be consistent: if a `groups` section is defined, all `group` values must match a key in it; if no `groups` section is defined but variables use `group`, all `group` values must be spelled consistently (validated by collecting unique values)
- Numeric `labels` keys must be numeric; if `min`/`max` are set, label keys must fall within `[min, max]`

**Warnings** (non-fatal):
- Variables without `group` when total variable count > 20 (risk of hitting structured output limits)
- Numeric variables without `min`/`max` (LLM may return unexpected values)
- Missing `version` field
- Categorical variables where any category is missing a `description` (LLM accuracy depends heavily on category descriptions)

## Design decisions and rationale

### Why `categorical` instead of `enum`?

Social science researchers think in terms of "categorical variables," not "enums." The YAML should use the researcher's vocabulary, not the programmer's. The mapping to `type_enum()` is an implementation detail.

### Why flat variable list instead of nested groups?

A flat list with a `group` tag is easier to scan, reorder, and edit than deeply nested YAML. Groups are defined separately (in the `groups` section) to avoid repeating group-level config for each variable.

### Why `value` + `label` for categories?

`value` is what appears in the data and is returned by the LLM. `label` is for human readability. This mirrors factor levels vs. labels in R, and codebook conventions in survey research. Many researchers will use the same string for both (and `label` defaults to `value`), but the distinction matters when values need to be short identifiers.

### Why include `min`/`max` if JSON schema can't enforce them?

They serve two purposes: (1) they're included in the LLM description as guidance, and (2) they enable post-hoc validation in R. The YAML is the single source of truth for both.

### Why `multiple: true` instead of a separate `array` type?

Researchers think "select all that apply," not "array of enums." Making `multiple` a modifier on existing types keeps the type vocabulary small (4 types) and familiar. It also means the YAML for a single-select vs. multi-select categorical variable differs by exactly one line, which makes the relationship obvious. Under the hood, `multiple: true` wraps the inner type in `ellmer::type_array()`.

### Why single-brace `{text}` instead of `{{text}}`?

Single braces are more readable for non-programmers. The risk of collision with literal braces in prompts is minimal. If needed, we can escape with `\{`.

### Why `required` defaults to `false`?

With `required = TRUE`, ellmer (and the underlying JSON schema) forces the LLM to produce a value even when the data doesn't support one. The ellmer structured data vignette demonstrates this explicitly: the LLM invents names for "I like apples" and ages for "What time is it?" In content analysis, a hallucinated code is worse than a missing value. Defaulting to `false` means missing data produces `NA` in R, which researchers already know how to handle. Variables that truly must always be coded (e.g., a primary topic) can set `required: true` explicitly.

### Why `title` instead of `name` at the top level?

The `name` field on variables is a machine identifier (column name). Using `name` at the top level for a human-readable title creates confusion — especially for novices who might expect top-level `name` to behave like variable `name`. `title` is unambiguous and matches conventions in academic publishing and document metadata.

### Why `schema_version`?

The YAML schema will evolve. Without a version marker, `read_promptbook()` cannot distinguish between a v1 file missing a new required field and a v2 file using new syntax. `schema_version` is cheap to add now and critical for forward compatibility. It is separate from `version`, which tracks the researcher's codebook content revisions.

### Why `object` type?

Content analysis frequently requires extracting structured records — named entities (name, type, context), source citations (author, claim, evidence), actors (name, role, stance). Without `object`, researchers must flatten these into parallel `text + multiple` and `categorical + multiple` variables with no structural link between fields. The `object` type maps directly to `ellmer::type_object()`, and `object + multiple` maps to `type_array(type_object(...))` which ellmer converts to a tibble. This is a natural extension of the existing type system.

Properties are limited to scalar types (no nested objects) to keep the YAML readable and avoid deep nesting that would confuse novice users. One level of structure handles all common content analysis use cases.

### Why restrict `multiple` to categorical, text, and object?

`boolean + multiple` has no meaningful content analysis interpretation (a list of true/false values?). `numeric + multiple` is theoretically possible but has no clear use case — if you need multiple numeric values, an `object` with a numeric property is more expressive and self-documenting. Restricting `multiple` keeps the type system predictable and avoids undefined semantics around empty arrays and required-ness for types where arrays don't make sense.
