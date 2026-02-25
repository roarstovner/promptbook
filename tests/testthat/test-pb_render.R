# Helper: read fixtures, suppressing expected validation warnings
read_fixture <- function(name = "media_framing.yaml") {
  suppressWarnings(
    read_promptbook(test_path("fixtures", name))
  )
}

# -- Input validation ---------------------------------------------------------

test_that("pb_render() errors on non-promptbook input", {
  expect_error(pb_render(list()), "promptbook")
})

test_that("pb_render() accepts a YAML path", {
  # Should not error on input validation (will fail at quarto step)
  path <- test_path("fixtures", "media_framing.yaml")
  # Use a mock to prevent actual rendering
  local_mocked_bindings(
    pb_render_qmd = function(...) "dummy.html",
    .package = "promptbook"
  )
  expect_no_error(suppressWarnings(pb_render(path, format = "html")))
})

test_that("pb_render() validates format argument", {
  pb <- read_fixture()
  local_mocked_bindings(
    pb_render_qmd = function(...) "dummy.html",
    .package = "promptbook"
  )
  expect_no_error(pb_render(pb, format = "html"))
  expect_no_error(pb_render(pb, format = "typst"))
  expect_error(pb_render(pb, format = "docx"), "should be one of")
})

# -- YAML header --------------------------------------------------------------

test_that("pb_qmd_header() includes title and html self-contained", {
  pb <- read_fixture()
  hdr <- pb_qmd_header(pb, "html")
  expect_match(hdr, "title:", fixed = TRUE)
  expect_match(hdr, "Media Framing Codebook", fixed = TRUE)
  expect_match(hdr, "embed-resources: true", fixed = TRUE)
  expect_match(hdr, "html:", fixed = TRUE)
})

test_that("pb_qmd_header() includes subtitle when version present", {
  pb <- read_fixture()
  hdr <- pb_qmd_header(pb, "html")
  expect_match(hdr, "subtitle:", fixed = TRUE)
  expect_match(hdr, "1.0.0", fixed = TRUE)
})

test_that("pb_qmd_header() omits subtitle when version is NULL", {
  pb <- read_fixture()
  pb$version <- NULL
  hdr <- pb_qmd_header(pb, "html")
  expect_no_match(hdr, "subtitle:")
})

test_that("pb_qmd_header() includes author when present", {
  pb <- read_fixture()
  hdr <- pb_qmd_header(pb, "html")
  expect_match(hdr, "author:", fixed = TRUE)
  expect_match(hdr, "Jane Researcher", fixed = TRUE)
})

test_that("pb_qmd_header() omits author when NULL", {
  pb <- read_fixture()
  pb$author <- NULL
  hdr <- pb_qmd_header(pb, "html")
  expect_no_match(hdr, "author:")
})

test_that("pb_qmd_header() generates typst format block", {
  pb <- read_fixture()
  hdr <- pb_qmd_header(pb, "typst")
  expect_match(hdr, "typst:", fixed = TRUE)
  expect_no_match(hdr, "html:")
})

# -- Metadata -----------------------------------------------------------------

test_that("pb_qmd_metadata() renders description", {
  pb <- read_fixture()
  md <- pb_qmd_metadata(pb)
  expect_match(md, "climate policy", fixed = TRUE)
})

test_that("pb_qmd_metadata() returns empty string when description is NULL", {
  pb <- read_fixture()
  pb$description <- NULL
  md <- pb_qmd_metadata(pb)
  expect_equal(md, "")
})

# -- Variable rendering: categorical ------------------------------------------

test_that("pb_qmd_variable() renders categorical with heading, description, table", {
  pb <- read_fixture()
  topic <- pb$variables[[1]]  # topic
  out <- pb_qmd_variable(topic, level = 3)
  # Heading with label and name
  expect_match(out, "### Primary topic", fixed = TRUE)
  expect_match(out, "`topic`", fixed = TRUE)
  # Description
  expect_match(out, "dominant topic", fixed = TRUE)
  # Categories table header
  expect_match(out, "| Value | Label | Description |", fixed = TRUE)
  # A specific row

  expect_match(out, "economy", fixed = TRUE)
  expect_match(out, "Economic impacts", fixed = TRUE)
})

test_that("pb_qmd_variable() shows 'multiple' note for categorical", {
  pb <- read_fixture()
  topics_all <- pb$variables[[3]]  # topics_all, multiple: true
  out <- pb_qmd_variable(topics_all, level = 3)
  expect_match(out, "multiple", ignore.case = TRUE)
})

# -- Variable rendering: numeric -----------------------------------------------

test_that("pb_qmd_variable() renders numeric with range and labels", {
  pb <- read_fixture()
  sentiment <- pb$variables[[2]]  # sentiment
  out <- pb_qmd_variable(sentiment, level = 3)
  expect_match(out, "### Overall policy sentiment", fixed = TRUE)
  expect_match(out, "`sentiment`", fixed = TRUE)
  # Range
  expect_match(out, "1", fixed = TRUE)
  expect_match(out, "5", fixed = TRUE)
  # Labels table
  expect_match(out, "Very negative", fixed = TRUE)
  expect_match(out, "Very positive", fixed = TRUE)
})

test_that("pb_qmd_variable() shows integer flag for numeric", {
  pb <- read_fixture()
  source_div <- pb$variables[[6]]  # source_diversity, integer: true
  out <- pb_qmd_variable(source_div, level = 3)
  expect_match(out, "integer", ignore.case = TRUE)
})

# -- Variable rendering: boolean -----------------------------------------------

test_that("pb_qmd_variable() renders boolean with type line", {
  pb <- read_fixture()
  has_data <- pb$variables[[4]]  # has_data
  out <- pb_qmd_variable(has_data, level = 3)
  expect_match(out, "### Contains quantitative data", fixed = TRUE)
  expect_match(out, "`has_data`", fixed = TRUE)
  expect_match(out, "boolean", ignore.case = TRUE)
})

# -- Variable rendering: text --------------------------------------------------

test_that("pb_qmd_variable() renders text with type line", {
  pb <- read_fixture()
  key_quote <- pb$variables[[7]]  # key_quote
  out <- pb_qmd_variable(key_quote, level = 3)
  expect_match(out, "### Most representative quote", fixed = TRUE)
  expect_match(out, "`key_quote`", fixed = TRUE)
  expect_match(out, "text", ignore.case = TRUE)
})

test_that("pb_qmd_variable() shows 'multiple' note for text when applicable", {
  # Create a minimal text variable with multiple: true
  var <- structure(
    list(
      name = "keywords",
      label = "Keywords",
      description = "Relevant keywords",
      type = "text",
      multiple = TRUE,
      required = FALSE
    ),
    class = c("pb_text", "pb_variable")
  )
  out <- pb_qmd_variable(var, level = 3)
  expect_match(out, "multiple", ignore.case = TRUE)
})

# -- Variable rendering: object ------------------------------------------------

test_that("pb_qmd_variable() renders object with properties table", {
  pb <- read_fixture()
  actors <- pb$variables[[8]]  # actors
  out <- pb_qmd_variable(actors, level = 3)
  expect_match(out, "### Named actors", fixed = TRUE)
  expect_match(out, "`actors`", fixed = TRUE)
  # Properties table
  expect_match(out, "| Property | Type | Description |", fixed = TRUE)
  expect_match(out, "actor_name", fixed = TRUE)
  expect_match(out, "actor_type", fixed = TRUE)
  expect_match(out, "stance", fixed = TRUE)
})

test_that("pb_qmd_variable() shows 'multiple' note for object", {
  pb <- read_fixture()
  actors <- pb$variables[[8]]  # actors, multiple: true
  out <- pb_qmd_variable(actors, level = 3)
  expect_match(out, "multiple", ignore.case = TRUE)
})

# -- Group structure -----------------------------------------------------------

test_that("pb_qmd_variables() renders groups with headings for grouped pb", {
  pb <- read_fixture()
  out <- pb_qmd_variables(pb)
  # Group headings at level 2
  expect_match(out, "## Basic codes", fixed = TRUE)
  expect_match(out, "## Framing analysis", fixed = TRUE)
  # Group descriptions
  expect_match(out, "Straightforward codes", fixed = TRUE)
  # Variables at level 3
  expect_match(out, "### Primary topic", fixed = TRUE)
  expect_match(out, "### Dominant frame", fixed = TRUE)
})

test_that("pb_qmd_variables() renders ungrouped pb with Variables heading", {
  pb <- read_fixture("ungrouped.yaml")
  out <- pb_qmd_variables(pb)
  expect_match(out, "## Variables", fixed = TRUE)
  # Variables at level 3
  expect_match(out, "### ", fixed = TRUE)
})

# -- System prompt -------------------------------------------------------------

test_that("pb_qmd_system_prompt() renders heading and fenced code block", {
  pb <- read_fixture()
  out <- pb_qmd_system_prompt(pb)
  expect_match(out, "## System Prompt", fixed = TRUE)
  expect_match(out, "```", fixed = TRUE)
  expect_match(out, "expert content analyst", fixed = TRUE)
})

# -- Full assembly -------------------------------------------------------------

test_that("pb_qmd() contains all expected sections for media_framing", {
  pb <- read_fixture()
  qmd <- pb_qmd(pb, "html")
  # Header
  expect_match(qmd, "title:", fixed = TRUE)
  # Metadata
  expect_match(qmd, "climate policy", fixed = TRUE)
  # Groups
  expect_match(qmd, "## Basic codes", fixed = TRUE)
  expect_match(qmd, "## Framing analysis", fixed = TRUE)
  # Variables
  expect_match(qmd, "### Primary topic", fixed = TRUE)
  expect_match(qmd, "### Dominant frame", fixed = TRUE)
  # System prompt
  expect_match(qmd, "## System Prompt", fixed = TRUE)
})

test_that("pb_qmd() snapshot", {
  pb <- read_fixture()
  expect_snapshot(cat(pb_qmd(pb, "html")))
})

# -- Integration: actual rendering (skip if quarto not available) ---------------

test_that("pb_render() produces HTML file and returns path invisibly", {
  skip_if_not_installed("quarto")
  skip_if_not(quarto::quarto_available(), "Quarto CLI not available")

  pb <- read_fixture()
  outdir <- withr::local_tempdir()
  outfile <- file.path(outdir, "codebook.html")

  result <- pb_render(pb, output = outfile, format = "html")
  expect_true(file.exists(outfile))
  expect_equal(result, outfile)
  # Returns invisibly
  expect_invisible(pb_render(pb, output = file.path(outdir, "codebook2.html")))
})

test_that("pb_render() generates default output name", {
  skip_if_not_installed("quarto")
  skip_if_not(quarto::quarto_available(), "Quarto CLI not available")

  pb <- read_fixture()
  outdir <- withr::local_tempdir()
  withr::local_dir(outdir)

  result <- pb_render(pb, format = "html")
  expect_true(file.exists(result))
  expect_match(basename(result), "\\.html$")
})
