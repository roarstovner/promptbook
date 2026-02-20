# Promptbook — Step 2 Research: YAML Schema Patterns & ellmer Integration

> Status: Complete (2026-02-20)
>
> Research goal: Understand existing annotation/codebook schemas and how ellmer's type system works, to inform the promptbook YAML schema design.

---

## Executive Summary

Three key findings:

1. **Field structures are remarkably consistent** across all annotation tools (Label Studio, Prodigy, spacy-llm, Argilla): each code/category has a `name`, `label`/`title`, `description`/`definition`, and optional `examples` or `help_text`.

2. **ellmer's type system is straightforward and maps cleanly to JSON Schema**:
   - `type_enum()` for categorical variables (becomes JSON `enum` array)
   - `type_number()`, `type_integer()`, `type_string()`, `type_boolean()` for scalars
   - `type_array()` for vectors and arrays of objects
   - `type_object()` groups named values (→ named lists in R)

3. **Structured output constraints are the critical bottleneck**: Claude/other APIs enforce ~24 optional parameters per schema call, which motivates variable grouping in the promptbook YAML.

---

## 1. Existing Annotation Tools: Common Schema Patterns

### Label Studio (XML-based)

**File format:** XML configuration

**Key structure:**
```xml
<View>
  <Text name="text_obj" value="$text"/>
  <Choices name="topic" toName="text_obj">
    <Choice value="economy">Economy</Choice>
    <Choice value="climate">Climate</Choice>
  </Choices>
</View>
```

**Key patterns:**
- `<Object>` tags reference data fields with `$variable_name` syntax
- `<Choice>` tags define category options with `value` attributes
- `toName` attribute links controls to objects
- Per-option labels are just text nodes (no separate definition field)

**For promptbook:** The structure is Web-UI focused, less relevant for LLM-oriented schemas. But the `$variable_name` template syntax is worth noting.

---

### Prodigy (YAML/JSON-based recipes)

**File format:** Python recipe returns YAML/JSON config; also supports `prodigy.json` settings

**Key structure:**
```yaml
config:
  blocks:
    - label: "Main topic"
      options:
        - { value: "economy", text: "Economy" }
        - { value: "climate", text: "Climate" }
```

**Key patterns:**
- Configuration is returned programmatically from recipes, not static files
- `blocks` are dicts with label and options
- Each option has `value` and `text` fields
- Settings files use YAML/JSON for project-wide config (database, API keys)

**For promptbook:** Prodigy favors programmatic config over static schemas. Less structured for what we need. But the `value`/`text` split (code vs. display label) is a useful pattern.

---

### spacy-llm (TOML/INI config)

**File format:** TOML/INI configuration file

**Key structure:**
```toml
[components.llm.task]
@llm_tasks = "spacy.TextCat.v2"
labels = ["COMPLIMENT", "INSULT"]

[components.llm.task.label_definitions]
"COMPLIMENT" = "a polite expression of praise or admiration."
"INSULT" = "a disrespectful or scornfully abusive remark or act."
```

**Key patterns:**
- `label_definitions` dictionary: keys are category names, values are description strings
- Descriptions are freeform text; best practice is brief description + examples + counter-examples
- Tied to spaCy pipeline architecture (registry decorators, task classes)
- Good practice: definitions include examples inline as text

**For promptbook (ADOPT):** The `label_definitions` pattern is cleaner and more LLM-friendly than Label Studio. We should adopt a per-category `definition` field.

---

### Argilla (Python API + YAML runtime)

**File format:** Primarily Python API, runtime config in YAML; datasets defined programmatically

**Key structure (Python):**
```python
Field(name="text", title="Text")
Question(name="sentiment", title="Sentiment", values=[
  QuestionValue(value="positive", text="Positive"),
  QuestionValue(value="negative", text="Negative"),
])
```

**Key patterns:**
- Programmatic definition with Field / Question classes
- Each question has `values` (list of QuestionValue objects)
- Each value has `value` (code) and `text` (display label)
- Optional `description` field per question

**For promptbook:** Similar to Prodigy: programmatic-first design. The `Field` / `Question` split is interesting but not directly applicable to YAML.

---

### Summary of Cross-Tool Patterns

| Pattern | Who uses it | Recommendation for promptbook |
|---------|------------|-------------------------------|
| Per-category `value` (code) + `label` (display name) | All tools | **ADOPT**: Required fields |
| Per-category `definition` or `description` | spacy-llm, Argilla, Label Studio hints | **ADOPT**: Optional but encouraged |
| Per-category `examples` | spacy-llm best practice | **ADOPT**: Optional list of strings |
| Per-category `help_text` or `hint` | Label Studio UI focus | **ADOPT as `definition`**: conflates UI and LLM purpose |
| Nested arrays of codes/options | All tools | **ADOPT**: `categories` array for categorical variables |
| Scale labels (e.g., 1="Very negative", 3="Neutral") | N/A in these tools | **DESIGN**: Relevant for integer scales; Argilla uses `values` but not for numbers |
| Required/optional flags per field | Argilla | **ADOPT**: `required: true/false` at variable level |
| Per-variable metadata (version, author) | None | **DESIGN**: Useful for research; defer to v2 |

---

## 2. ellmer's Type System and JSON Schema Mapping

### Core Type Functions

ellmer provides a clean, composable type API that maps to JSON Schema:

| ellmer function | JSON Schema | R output | Use case |
|-----------------|------------|---------|----------|
| `type_enum(values = c("a", "b"))` | `"enum": ["a", "b"]` | factor-like | Categorical codes |
| `type_string()` | `"type": "string"` | character | Free-text descriptions |
| `type_integer()` | `"type": "integer"` | numeric | Count codes, scales |
| `type_number()` | `"type": "number"` | numeric | Continuous scales (rare) |
| `type_boolean()` | `"type": "boolean"` | logical | Binary yes/no flags |
| `type_array(type_string())` | `"type": "array", "items": {type_string_schema}` | character vector | Tags, multiple selections |
| `type_object(name = ..., field1 = type_enum(...), field2 = type_integer(...))` | `"type": "object", "properties": {...}` | named list → data frame | Multi-field extraction |

### Constraints and Descriptions

ellmer supports passing **descriptions** to type functions (shown in prompts):

```r
type_object(
  "Coded article",
  topic = type_enum(
    "Main topic",
    values = c("economy", "climate", "health")
  ),
  sentiment = type_integer(
    "Sentiment 1-5 (1=very negative, 5=very positive)",
    minimum = 1,
    maximum = 5
  )
)
```

### JSON Schema Limitations (Claude API)

[Anthropic's Structured Outputs](https://platform.claude.com/docs/build-with-claude/structured-outputs) enforce these constraints:

**Unsupported:**
- Recursive schemas
- Numerical constraints (`minimum`, `maximum`, `multipleOf`)
- String constraints (`minLength`, `maxLength`)
- Array constraints beyond `minItems: 0 or 1`
- `additionalProperties: true` (must be `false`)

**Supported:**
- `enum` (strings, numbers, bools, nulls)
- `const`
- `anyOf`, `allOf` (limited)
- `$ref`, `$def`
- `required`, `additionalProperties: false`
- String formats: `date-time`, `date`, `email`, `uri`, `uuid`

**Implication for promptbook:** Numerical constraints (e.g., `minimum: 1, maximum: 5`) cannot be encoded in the schema passed to Claude. Instead:
1. Include constraints in the description: `"Sentiment (1-5: 1=very negative, 5=very positive)"`
2. Validate post-hoc in R with `pb_validate()`
3. Use the ellmer SDK's constraint embedding in descriptions (Python/TypeScript do this automatically)

---

## 3. Variable Grouping and the 24-Parameter Bottleneck

### The Constraint

**Structured output schema complexity limits** (per API call):
- **24 optional parameters** across all schemas
- **20 strict tools** per request
- **16 parameters with union types** (`anyOf` or type arrays)

### Why It Matters

A typical research codebook has **10-20 variables**. Sending all of them to the LLM in a single `type_object()` call:
- Exceeds 24 optional parameters (if all are optional)
- Degrades accuracy on smaller models (Haiku, local)
- Creates a large, complex schema that takes time to compile

### Solution: Variable Grouping

The YAML schema should support grouping variables into **"groups"** or **"extraction_batches"**, each with:
- A subset of 3-5 variables
- (Optional) assignment to a specific model

**Example:**

```yaml
variables:
  - name: topic
    group: "basic"
    # ... (topic definition)

  - name: sentiment
    group: "basic"
    # ... (sentiment definition)

  - name: evidence_quality
    group: "complex"
    model: "claude-opus-4-6"  # Use stronger model for this one
    # ... (complex judgment)

  - name: uncertainty_level
    group: "complex"
    model: "claude-opus-4-6"
    # ... (complex judgment)
```

`pb_annotate()` would then:
1. Split data into extraction calls by group
2. Per group, use the assigned model (or default)
3. Extract each group separately
4. Reassemble into final annotated data frame

---

## 4. Recommended Promptbook YAML Schema

Building on the patterns above and the landscape research from Step 1, here's the refined schema:

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
    You are an expert content analyst specializing in media coverage.
    Apply the coding instrument with precision and consistency.
    When uncertain, choose the most defensible code.

  user_template: |
    Code the following {{text_type}} according to the codebook below.

    {{text}}

    Provide all codes as specified.

variables:
  # Basic categorical variable
  - name: topic
    label: "Main topic"
    description: "The primary subject matter of the text"
    type: categorical
    required: true
    group: "basic"
    categories:
      - value: "economy"
        label: "Economy"
        definition: "Coverage primarily about economic policy, markets, trade, employment"
        examples:
          - "GDP growth"
          - "unemployment rate"
          - "trade deficit"
      - value: "climate"
        label: "Climate & environment"
        definition: "Coverage about climate change, environmental policy, natural disasters"
        examples:
          - "Paris Agreement"
          - "carbon emissions"
          - "wildfires"
      - value: "other"
        label: "Other"
        definition: "Does not primarily fit any above category"

  # Integer scale variable
  - name: sentiment
    label: "Evaluative tone"
    description: "Overall evaluative tone toward the topic"
    type: integer
    required: true
    group: "basic"
    minimum: 1
    maximum: 5
    scale_labels:
      1: "Very negative / critical"
      2: "Somewhat negative"
      3: "Neutral / balanced"
      4: "Somewhat positive"
      5: "Very positive / favorable"

  # Boolean variable
  - name: mentions_uncertainty
    label: "Mentions scientific uncertainty"
    description: "Whether the text explicitly mentions scientific uncertainty or debate"
    type: boolean
    required: false
    group: "detail"

  # Complex judgment variable (use stronger model)
  - name: evidence_quality
    label: "Quality of evidence presented"
    description: "Assessment of whether the text cites specific data, peer-reviewed research, or relies on speculation"
    type: categorical
    required: false
    group: "complex"
    model: "claude-opus-4-6"
    categories:
      - value: "specific_data"
        label: "Specific data/research cited"
        definition: "Names specific studies, statistics, or scientific findings"
      - value: "general_claim"
        label: "General assertion without evidence"
        definition: "Makes claims without citing specific sources"
      - value: "mixed"
        label: "Mixed or unclear"
        definition: "Combination of cited evidence and unsupported claims"

# Define groups for separate extraction calls
groups:
  basic:
    description: "Fast, simple codes suitable for any model"
  detail:
    description: "Optional detail variables"
  complex:
    description: "Complex judgments requiring stronger model"
    model: "claude-opus-4-6"  # Default model for this group
```

### Schema Field Definitions

**Top level:**
- `meta`: Metadata about the codebook (name, version, author, tested models)
- `prompt`: System and user prompt templates with `{{variable}}` Jinja2 syntax
- `variables`: Array of variable definitions
- `groups`: (Optional) Grouping definitions for extraction batches

**Per variable:**
- `name`: Identifier (snake_case); used as output column name
- `label`: Short human-readable label (used in prompts, documentation)
- `description`: Longer explanation of what this code captures
- `type`: One of `categorical`, `integer`, `number`, `string`, `boolean`
- `required`: Whether this code must be present (true/false)
- `group`: (Optional) Group name for batch extraction; default to single group
- `model`: (Optional) LLM model to use for this variable; overrides group default
- `categories` (if type=categorical):
  - `value`: Code value (what the LLM assigns)
  - `label`: Display name
  - `definition`: Detailed definition of this category
  - `examples`: (Optional) List of example texts or phrases
- `scale_labels` (if type=integer): Dict mapping numeric values to text anchors
- `minimum`, `maximum` (if type=integer/number): Range; noted in description if not supported by API

---

## 5. Technical Implementation Path

### ellmer Integration

**Goal:** Convert promptbook variables → `ellmer::type_object()` call

**Function signature:**
```r
pb_type <- function(pb) {
  # Returns a type_object ready for ellmer::chat$extract_data()
  # Each variable becomes a parameter in the object
  # Descriptions are embedded in type functions
  # Unsupported constraints (minimum/maximum) are noted in descriptions
}
```

**Example:** Given the YAML above, `pb_type(pb)` would return:

```r
type_object(
  "Coded media article",
  topic = type_enum(
    "Main topic: economy, climate, or other",
    values = c("economy", "climate", "other")
  ),
  sentiment = type_integer(
    "Evaluative tone (1=very negative, 5=very positive)"
  ),
  mentions_uncertainty = type_boolean(
    "Does the text mention scientific uncertainty?"
  ),
  evidence_quality = type_enum(
    "Quality of evidence: specific_data, general_claim, or mixed",
    values = c("specific_data", "general_claim", "mixed")
  )
)
```

### Multiple Extraction Calls (Variable Grouping)

**Goal:** `pb_annotate()` splits variables by group and handles multiple extraction calls

```r
pb_annotate <- function(pb, data, model_fn, batch_size = 50) {
  # 1. Identify groups and their models from pb$groups
  # 2. For each group:
  #    a. Call pb_type() with just that group's variables
  #    b. Call ellmer's extract_data() with the subset type
  #    c. Collect results
  # 3. Join results back to original data
  # 4. Return annotated data frame with one column per variable + metadata
}
```

### Validation

**Goal:** `pb_validate()` ensures output codes match the codebook

```r
pb_validate <- function(pb, results) {
  # For each categorical variable, check that output values are in allowed set
  # For integer variables, check range (minimum/maximum)
  # Return list of errors or invisible(results) if valid
}
```

---

## 6. Key Design Decisions for promptbook Schema

1. **Adopt `categories` array pattern** from all existing tools; clean and familiar

2. **Use `definition` + `examples`** (spacy-llm pattern) rather than vague `hint`; LLM-friendly

3. **Support `group` + `model` assignments** to handle both variable batching and per-model dispatch

4. **Encode constraints in descriptions** since JSON Schema doesn't support `minimum`/`maximum` in structured outputs

5. **Use Jinja2 `{{variable}}` syntax** in prompts (standard in PromptFlow, LangChain, Simon Willison's llm)

6. **Make groups optional** (single group default); encourages simple codebooks to stay simple

7. **Avoid recursive / complex nested structures**; keep schema depth ≤ 3 levels

8. **Include `meta.llm_tested`** to document which models have been validated on this codebook

---

## 7. Next Steps (Issues #3, #4, #5)

1. **Issue #3**: Implement `read_promptbook()` to parse YAML and validate against this schema
2. **Issue #4**: Implement `pb_type()` to convert validated promptbook → `ellmer::type_object()`
3. **Issue #5**: Implement `pb_annotate()` with variable grouping and per-model dispatch
4. **Issue #6**: Design human-readable codebook rendering (Quarto/HTML/PDF)

---

## References & Sources

- [ellmer Structured Data](https://ellmer.tidyverse.org/articles/structured-data.html)
- [Anthropic Claude Structured Outputs](https://platform.claude.com/docs/build-with-claude/structured-outputs)
- [Label Studio Documentation](https://labelstud.io/guide/setup)
- [spacy-llm Large Language Models](https://spacy.io/usage/large-language-models)
- [Prodigy Documentation](https://prodi.gy/docs)
- [Argilla Documentation](https://docs.argilla.io)
