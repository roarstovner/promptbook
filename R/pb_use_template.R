#' Copy the starter promptbook YAML into your project
#'
#' Copies the bundled template at
#' `inst/templates/promptbook.yaml` to a path in your project, giving you
#' a ready-to-edit starting point for a new coding instrument. This is the
#' recommended way to begin a new promptbook.
#'
#' @param path Destination path for the template. Defaults to
#'   `"codebook.yaml"` in the current working directory.
#' @param overwrite Logical. If `FALSE` (the default), the function refuses
#'   to overwrite an existing file. Set to `TRUE` to replace it.
#' @param open Logical. If `TRUE` (the default in interactive sessions),
#'   open the new file in your editor via [usethis::edit_file()] when the
#'   `usethis` package is installed.
#'
#' @return The destination path, invisibly.
#' @export
#' @examples
#' \dontrun{
#' pb_use_template()
#' pb_use_template("codebooks/sentiment.yaml")
#' }
pb_use_template <- function(path = "codebook.yaml",
                            overwrite = FALSE,
                            open = rlang::is_interactive()) {
  if (!is.character(path) || length(path) != 1 || is.na(path) || !nzchar(path)) {
    cli::cli_abort("{.arg path} must be a single non-empty file path.")
  }
  if (!is.logical(overwrite) || length(overwrite) != 1 || is.na(overwrite)) {
    cli::cli_abort("{.arg overwrite} must be `TRUE` or `FALSE`.")
  }
  if (!is.logical(open) || length(open) != 1 || is.na(open)) {
    cli::cli_abort("{.arg open} must be `TRUE` or `FALSE`.")
  }

  template <- system.file("templates", "promptbook.yaml", package = "promptbook")
  if (!nzchar(template)) {
    cli::cli_abort(
      "Template file not found. Is the {.pkg promptbook} package installed correctly?"
    )
  }

  if (file.exists(path) && !overwrite) {
    cli::cli_abort(c(
      "File already exists: {.path {path}}",
      i = "Set {.code overwrite = TRUE} to replace it."
    ))
  }

  parent <- dirname(path)
  if (!dir.exists(parent)) {
    dir.create(parent, recursive = TRUE)
  }

  ok <- file.copy(template, path, overwrite = overwrite)
  if (!isTRUE(ok)) {
    cli::cli_abort("Failed to copy template to {.path {path}}.")
  }

  cli::cli_alert_success("Wrote promptbook template to {.path {path}}.")
  cli::cli_alert_info(
    "Edit this file, then load it with {.code read_promptbook({.str {path}})}."
  )

  if (open && rlang::is_installed("usethis")) {
    usethis::edit_file(path)
  }

  invisible(path)
}
