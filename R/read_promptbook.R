#' Read and validate a promptbook YAML file
#'
#' Reads a YAML file, validates it against the promptbook schema, and returns
#' a structured `promptbook` object. All validation happens here — if this
#' function returns without error, the promptbook is valid.
#'
#' @param path Path to a YAML file.
#' @return A `promptbook` object (S3 class), which is a named list with:
#'   - `$title` — character
#'   - `$version` — character or NULL
#'   - `$description` — character or NULL
#'   - `$author` — character or NULL
#'   - `$prompt` — list with `$system` and `$user`
#'   - `$variables` — list of `pb_variable` objects
#'   - `$groups` — list of group definitions (or NULL)
#'
#' @export
#' @examples
#' path <- system.file("examples", "media_framing.yaml", package = "promptbook")
#' pb <- read_promptbook(path)
#' pb
#' pb$title
#' pb$variables[[1]]$name
read_promptbook <- function(path) {
  if (!is.character(path) || length(path) != 1) {
    cli::cli_abort("{.arg path} must be a single file path.")
  }
  if (!file.exists(path)) {
    cli::cli_abort("File not found: {.path {path}}")
  }

  raw <- yaml::read_yaml(path)
  validate_promptbook(raw)
  new_promptbook(raw)
}

# -- S3 constructor ----------------------------------------------------------

#' Construct a promptbook object from a validated raw list
#' @param raw Named list from `yaml::read_yaml()`, already validated
#' @return A `promptbook` object
#' @noRd
new_promptbook <- function(raw) {
  variables <- lapply(raw$variables, new_pb_variable)

  structure(
    list(
      title       = raw$title,
      version     = raw$version %||% NULL,
      description = raw$description %||% NULL,
      author      = raw$author %||% NULL,
      prompt      = list(
        system = raw$prompt$system,
        user   = raw$prompt$user %||% NULL
      ),
      variables   = variables,
      groups      = raw$groups %||% NULL
    ),
    class = "promptbook"
  )
}

#' Construct a pb_variable object
#' @param var Named list for one variable from the YAML
#' @return A `pb_variable` object with a type-specific subclass
#' @noRd
new_pb_variable <- function(var) {
  type_class <- paste0("pb_", var$type)

  # Apply defaults
  var$label    <- var$label %||% var$name
  var$required <- var$required %||% FALSE
  var$multiple <- var$multiple %||% FALSE

  # Numeric default: integer = TRUE

  if (var$type == "numeric") {
    var$integer <- var$integer %||% TRUE
  }

  # Recursively construct property variables for object type
  if (var$type == "object" && !is.null(var$properties)) {
    var$properties <- lapply(var$properties, new_pb_variable)
  }

  structure(var, class = c(type_class, "pb_variable"))
}

# -- Print methods -----------------------------------------------------------

#' @export
print.promptbook <- function(x, ...) {
  cli::cli_text("# A promptbook: {x$title}")
  if (!is.null(x$version)) {
    cli::cli_text("# Version: {x$version}")
  }

  n_vars <- length(x$variables)
  if (!is.null(x$groups)) {
    n_groups <- length(x$groups)
    cli::cli_text("# Variables: {n_vars} ({n_groups} group{?s})")

    group_info <- vapply(names(x$groups), function(g) {
      model <- x$groups[[g]]$model
      if (!is.null(model)) paste0(g, " (", model, ")") else g
    }, character(1))
    cli::cli_text("# Groups: {paste(group_info, collapse = ', ')}")
  } else {
    cli::cli_text("# Variables: {n_vars}")
  }

  invisible(x)
}

#' @export
print.pb_variable <- function(x, ...) {
  multiple_tag <- if (isTRUE(x$multiple)) " [multiple]" else ""
  group_tag <- if (!is.null(x$group)) paste0(" (group: ", x$group, ")") else ""
  cli::cli_text("<{x$type}{multiple_tag}> {x$name}{group_tag}")
  invisible(x)
}
