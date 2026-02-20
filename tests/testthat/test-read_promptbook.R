# Helper: write a YAML string to a temp file and return the path
write_yaml_temp <- function(yaml_string, envir = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".yaml", .local_envir = envir)
  writeLines(yaml_string, path)
  path
}

# Minimal valid YAML for quick tests
minimal_yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "You are a coder."
variables:
  - name: topic
    type: categorical
    description: "The topic"
    categories:
      - value: "a"
      - value: "b"
'

# -- Happy path: media_framing.yaml -----------------------------------------

test_that("read_promptbook parses media_framing.yaml correctly", {
  pb <- read_promptbook(test_path("fixtures", "media_framing.yaml"))

  expect_s3_class(pb, "promptbook")
  expect_equal(pb$title, "Media Framing Codebook")
  expect_equal(pb$version, "1.0.0")
  expect_equal(pb$author, "Jane Researcher")
  expect_type(pb$description, "character")

  # Prompt

  expect_type(pb$prompt$system, "character")
  expect_type(pb$prompt$user, "character")
  expect_match(pb$prompt$user, "\\{text\\}")

  # Variables
  expect_length(pb$variables, 8)
  expect_s3_class(pb$variables[[1]], "pb_variable")
  expect_s3_class(pb$variables[[1]], "pb_categorical")
  expect_equal(pb$variables[[1]]$name, "topic")

  # Groups
  expect_named(pb$groups, c("basic", "framing"))
  expect_equal(pb$groups$basic$model, "haiku")
})

test_that("all variable types are correctly subclassed", {
  pb <- read_promptbook(test_path("fixtures", "media_framing.yaml"))

  classes <- vapply(pb$variables, function(v) class(v)[1], character(1))
  expect_true("pb_categorical" %in% classes)
  expect_true("pb_numeric" %in% classes)
  expect_true("pb_boolean" %in% classes)
  expect_true("pb_text" %in% classes)
  expect_true("pb_object" %in% classes)
})

test_that("defaults are applied correctly", {
  pb <- read_promptbook(test_path("fixtures", "media_framing.yaml"))

  # label defaults to name when not provided (all in fixture have labels)
  # required defaults to FALSE
  topic <- pb$variables[[1]]
  expect_false(topic$required)

  # multiple defaults to FALSE
  sentiment <- pb$variables[[2]]
  expect_false(sentiment$multiple)

  # numeric integer defaults to TRUE
  expect_true(sentiment$integer)

  # multiple = TRUE preserved
  topics_all <- pb$variables[[3]]
  expect_true(topics_all$multiple)
})

test_that("object properties are pb_variable objects", {
  pb <- read_promptbook(test_path("fixtures", "media_framing.yaml"))

  actors <- pb$variables[[8]]
  expect_s3_class(actors, "pb_object")
  expect_length(actors$properties, 3)
  expect_s3_class(actors$properties[[1]], "pb_text")
  expect_s3_class(actors$properties[[2]], "pb_categorical")
})

# -- Minimal valid YAML ------------------------------------------------------

test_that("minimal valid YAML parses without error", {
  path <- write_yaml_temp(minimal_yaml)
  expect_no_error(suppressWarnings(read_promptbook(path)))
})

# -- File path validation ----------------------------------------------------

test_that("read_promptbook errors on non-existent file", {
  expect_error(read_promptbook("nonexistent.yaml"), "File not found")
})

test_that("read_promptbook errors on non-string path", {
  expect_error(read_promptbook(42), "single file path")
})

# -- Missing required top-level fields ---------------------------------------

test_that("missing schema_version errors", {
  yaml <- '
title: "Test"
prompt:
  system: "Test"
variables:
  - name: x
    type: text
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "schema_version.*required")
})

test_that("missing title errors", {
  yaml <- '
schema_version: 1
prompt:
  system: "Test"
variables:
  - name: x
    type: text
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(suppressWarnings(read_promptbook(path)), "title.*required")
})

test_that("missing prompt.system errors", {
  yaml <- '
schema_version: 1
title: "Test"
prompt:
  user: "Code this: {text}"
variables:
  - name: x
    type: text
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(suppressWarnings(read_promptbook(path)), "prompt\\.system.*required")
})

# -- Invalid schema_version --------------------------------------------------

test_that("non-integer schema_version errors", {
  yaml <- '
schema_version: "one"
title: "Test"
prompt:
  system: "Test"
variables:
  - name: x
    type: text
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "schema_version.*positive integer")
})

test_that("negative schema_version errors", {
  yaml <- '
schema_version: -1
title: "Test"
prompt:
  system: "Test"
variables:
  - name: x
    type: text
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "schema_version.*positive integer")
})

test_that("unsupported schema_version errors", {
  yaml <- '
schema_version: 2
title: "Test"
prompt:
  system: "Test"
variables:
  - name: x
    type: text
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(suppressWarnings(read_promptbook(path)), "schema_version.*1.*supported")
})

# -- Variable validation -----------------------------------------------------

test_that("missing variable name errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - type: text
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "name.*required")
})

test_that("missing variable type errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "type.*required")
})

test_that("missing variable description errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: text
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "description.*required")
})

test_that("invalid variable type errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: enum
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "type.*must be one of")
})

test_that("invalid R name errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: "bad name!"
    type: text
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "not a valid R name")
})

test_that("name starting with number is invalid", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: "1topic"
    type: text
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "not a valid R name")
})

test_that("duplicate variable names error", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: text
    description: "First"
  - name: x
    type: text
    description: "Second"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "Duplicate variable names")
})

# -- Categorical validation --------------------------------------------------

test_that("categorical without categories errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: categorical
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "categories.*required")
})

test_that("category without value errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: categorical
    description: "A var"
    categories:
      - label: "A"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "value.*required")
})

# -- Multiple on invalid types -----------------------------------------------

test_that("multiple on boolean errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: boolean
    description: "A var"
    multiple: true
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "multiple.*only valid for")
})

test_that("multiple on numeric errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: numeric
    description: "A var"
    multiple: true
    min: 1
    max: 5
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "multiple.*only valid for")
})

# -- Object validation ------------------------------------------------------

test_that("object without properties errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: object
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "properties.*required")
})

test_that("nested object errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: object
    description: "A var"
    properties:
      - name: inner
        type: object
        description: "Nested"
        properties:
          - name: deep
            type: text
            description: "Deep"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "nested objects are not allowed")
})

test_that("object property with group errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: object
    description: "A var"
    properties:
      - name: inner
        type: text
        description: "A prop"
        group: basic
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "group.*not allowed on object properties")
})

test_that("object property with model errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: object
    description: "A var"
    properties:
      - name: inner
        type: text
        description: "A prop"
        model: haiku
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "model.*not allowed on object properties")
})

# -- Numeric labels validation -----------------------------------------------

test_that("numeric labels out of range errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: numeric
    description: "A scale"
    min: 1
    max: 5
    labels:
      0: "Too low"
      3: "Middle"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "labels.*outside")
})

# -- Group cross-reference ---------------------------------------------------

test_that("undefined group reference errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: text
    description: "A var"
    group: nonexistent
groups:
  basic:
    label: "Basic"
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "Undefined group")
})

test_that("variables can use group without groups section", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: text
    description: "A var"
    group: mygroup
'
  path <- write_yaml_temp(yaml)
  expect_no_error(read_promptbook(path))
})

# -- Warnings ----------------------------------------------------------------

test_that("missing version warns", {
  yaml <- '
schema_version: 1
title: "Test"
prompt:
  system: "Test"
variables:
  - name: x
    type: text
    description: "A var"
'
  path <- write_yaml_temp(yaml)
  expect_warning(read_promptbook(path), "version.*missing")
})

test_that("categorical missing descriptions warns", {
  path <- write_yaml_temp(minimal_yaml)
  expect_warning(read_promptbook(path), "missing.*description")
})

test_that("numeric without min/max warns", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables:
  - name: x
    type: numeric
    description: "A scale"
'
  path <- write_yaml_temp(yaml)
  expect_warning(read_promptbook(path), "min.*max")
})

# -- Print methods -----------------------------------------------------------

test_that("print.promptbook produces expected output", {
  pb <- read_promptbook(test_path("fixtures", "media_framing.yaml"))
  expect_snapshot(print(pb))
})

test_that("print.pb_variable produces expected output", {
  pb <- read_promptbook(test_path("fixtures", "media_framing.yaml"))
  expect_snapshot({
    print(pb$variables[[1]])  # categorical
    print(pb$variables[[2]])  # numeric
    print(pb$variables[[3]])  # categorical multiple
    print(pb$variables[[4]])  # boolean
    print(pb$variables[[7]])  # text
    print(pb$variables[[8]])  # object multiple
  })
})

# -- No variables at all -----------------------------------------------------

test_that("empty variables list errors", {
  yaml <- '
schema_version: 1
title: "Test"
version: "0.1.0"
prompt:
  system: "Test"
variables: []
'
  path <- write_yaml_temp(yaml)
  expect_error(read_promptbook(path), "at least one variable")
})
