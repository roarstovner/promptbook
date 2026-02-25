#' Render a promptbook as a human-readable codebook
#'
#' Renders a promptbook as a self-contained HTML or PDF (via Typst) document,
#' suitable for paper appendices and sharing with human coders.
#'
#' @param promptbook A `promptbook` object (from [read_promptbook()]) or a path
#'   to a YAML file.
#' @param output Output file path. If `NULL`, generates a default name from the
#'   promptbook title in the current working directory.
#' @param format Output format: `"html"` (default) or `"typst"` (PDF).
#'
#' @return The output file path (invisibly). Side effect: writes the rendered
#'   document.
#'
#' @export
#' @examples
#' path <- system.file("examples", "media_framing.yaml", package = "promptbook")
#' pb <- read_promptbook(path)
#' if (interactive()) {
#'   pb_render(pb, "codebook.html")
#' }
pb_render <- function(promptbook, output = NULL, format = c("html", "typst")) {
  if (is.character(promptbook) && length(promptbook) == 1) {
    promptbook <- read_promptbook(promptbook)
  }
  if (!inherits(promptbook, "promptbook")) {
    cli::cli_abort("{.arg promptbook} must be a {.cls promptbook} object or a path to a YAML file.")
  }

  format <- match.arg(format)

  if (is.null(output)) {
    slug <- gsub("[^a-zA-Z0-9]+", "_", tolower(promptbook$title))
    slug <- gsub("_+$", "", slug)
    ext <- if (format == "html") ".html" else ".pdf"
    output <- paste0(slug, ext)
  }

  pb_render_qmd(promptbook, output, format)
}

#' Render a .qmd string via quarto
#' @noRd
pb_render_qmd <- function(promptbook, output, format) {
  rlang::check_installed("quarto", reason = "to render codebook documents")
  qmd_content <- pb_qmd(promptbook, format)

  tmpdir <- tempfile("pb_render_")
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

  qmd_path <- file.path(tmpdir, "codebook.qmd")
  writeLines(qmd_content, qmd_path)

  quarto::quarto_render(qmd_path, output_format = format)

  # Find the rendered file
  rendered_ext <- if (format == "html") ".html" else ".pdf"
  rendered <- file.path(tmpdir, paste0("codebook", rendered_ext))

  if (!file.exists(rendered)) {
    cli::cli_abort("Rendering failed: output file not found.")
  }

  output <- normalizePath(output, mustWork = FALSE)
  file.copy(rendered, output, overwrite = TRUE)
  invisible(output)
}

# -- QMD generation (pure functions, fully testable) --------------------------

#' Build the full .qmd string
#' @param promptbook A `promptbook` object.
#' @param format `"html"` or `"typst"`.
#' @return A single character string with valid .qmd content.
#' @noRd
pb_qmd <- function(promptbook, format) {
  parts <- c(
    pb_qmd_header(promptbook, format),
    "",
    pb_qmd_metadata(promptbook),
    pb_qmd_variables(promptbook),
    pb_qmd_system_prompt(promptbook)
  )
  paste(parts, collapse = "\n")
}

#' Build YAML front matter
#' @noRd
pb_qmd_header <- function(pb, format) {
  lines <- c("---", paste0('title: "', pb$title, '"'))

  if (!is.null(pb$version)) {
    lines <- c(lines, paste0('subtitle: "Version ', pb$version, '"'))
  }
  if (!is.null(pb$author)) {
    lines <- c(lines, paste0('author: "', pb$author, '"'))
  }

  if (format == "html") {
    lines <- c(lines, "format:", "  html:", "    embed-resources: true")
  } else {
    lines <- c(lines, "format:", "  typst: default")
  }

  lines <- c(lines, "---")
  paste(lines, collapse = "\n")
}

#' Build description paragraph
#' @noRd
pb_qmd_metadata <- function(pb) {
  if (is.null(pb$description)) return("")
  trimws(pb$description)
}

#' Build the variables section
#' @noRd
pb_qmd_variables <- function(pb) {
  if (!is.null(pb$groups)) {
    pb_qmd_variables_grouped(pb)
  } else {
    pb_qmd_variables_ungrouped(pb)
  }
}

#' @noRd
pb_qmd_variables_grouped <- function(pb) {
  parts <- character()

  for (group_name in names(pb$groups)) {
    group <- pb$groups[[group_name]]
    parts <- c(parts, paste0("## ", group$label))
    if (!is.null(group$description)) {
      parts <- c(parts, "", group$description)
    }
    parts <- c(parts, "")

    group_vars <- Filter(
      function(v) identical(v$group, group_name),
      pb$variables
    )
    for (v in group_vars) {
      parts <- c(parts, pb_qmd_variable(v, level = 3), "")
    }
  }

  paste(parts, collapse = "\n")
}

#' @noRd
pb_qmd_variables_ungrouped <- function(pb) {
  parts <- c("## Variables", "")
  for (v in pb$variables) {
    parts <- c(parts, pb_qmd_variable(v, level = 3), "")
  }
  paste(parts, collapse = "\n")
}

# -- Per-variable rendering (S3 generic) --------------------------------------

#' Render a single variable as QMD
#' @param var A `pb_variable` object.
#' @param level Heading level (integer).
#' @return Character string of QMD content.
#' @noRd
pb_qmd_variable <- function(var, level) {
  UseMethod("pb_qmd_variable")
}

#' @noRd
pb_qmd_variable.pb_categorical <- function(var, level) {
  hashes <- strrep("#", level)
  lines <- c(
    paste0(hashes, " ", var$label, " (`", var$name, "`)"),
    "",
    trimws(var$description)
  )

  if (isTRUE(var$multiple)) {
    lines <- c(lines, "", "*Multiple values allowed.*")
  }

  # Categories table
  lines <- c(lines, "", "| Value | Label | Description |", "|---|---|---|")
  for (cat in var$categories) {
    label <- cat$label %||% cat$value
    desc <- cat$description %||% ""
    lines <- c(lines, paste0("| ", cat$value, " | ", label, " | ", trimws(desc), " |"))
  }

  paste(lines, collapse = "\n")
}

#' @noRd
pb_qmd_variable.pb_numeric <- function(var, level) {
  hashes <- strrep("#", level)
  lines <- c(
    paste0(hashes, " ", var$label, " (`", var$name, "`)"),
    "",
    trimws(var$description)
  )

  # Type info
  type_str <- "**Type:** numeric"
  if (isTRUE(var$integer)) {
    type_str <- paste0(type_str, " (integer)")
  }
  if (!is.null(var$min) && !is.null(var$max)) {
    type_str <- paste0(type_str, ", range: ", var$min, "\u2013", var$max)
  }
  lines <- c(lines, "", type_str)

  # Labels table
  if (!is.null(var$labels)) {
    lines <- c(lines, "", "| Value | Label |", "|---|---|")
    for (key in names(var$labels)) {
      lines <- c(lines, paste0("| ", key, " | ", var$labels[[key]], " |"))
    }
  }

  paste(lines, collapse = "\n")
}

#' @noRd
pb_qmd_variable.pb_boolean <- function(var, level) {
  hashes <- strrep("#", level)
  lines <- c(
    paste0(hashes, " ", var$label, " (`", var$name, "`)"),
    "",
    trimws(var$description),
    "",
    "**Type:** boolean"
  )
  paste(lines, collapse = "\n")
}

#' @noRd
pb_qmd_variable.pb_text <- function(var, level) {
  hashes <- strrep("#", level)
  lines <- c(
    paste0(hashes, " ", var$label, " (`", var$name, "`)"),
    "",
    trimws(var$description),
    "",
    "**Type:** text"
  )

  if (isTRUE(var$multiple)) {
    lines <- c(lines, "", "*Multiple values allowed.*")
  }

  paste(lines, collapse = "\n")
}

#' @noRd
pb_qmd_variable.pb_object <- function(var, level) {
  hashes <- strrep("#", level)
  lines <- c(
    paste0(hashes, " ", var$label, " (`", var$name, "`)"),
    "",
    trimws(var$description)
  )

  if (isTRUE(var$multiple)) {
    lines <- c(lines, "", "*Multiple values allowed.*")
  }

  # Properties table
  lines <- c(lines, "", "| Property | Type | Description |", "|---|---|---|")
  for (prop in var$properties) {
    lines <- c(lines, paste0("| ", prop$name, " | ", prop$type, " | ", trimws(prop$description), " |"))
  }

  paste(lines, collapse = "\n")
}

# -- System prompt section ----------------------------------------------------

#' Render the system prompt section
#' @noRd
pb_qmd_system_prompt <- function(pb) {
  lines <- c(
    "## System Prompt",
    "",
    "```",
    trimws(pb$prompt$system),
    "```"
  )
  paste(lines, collapse = "\n")
}
