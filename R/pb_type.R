#' Convert a promptbook to an ellmer type object
#'
#' Converts a promptbook (or a subset of its variables) to an
#' [ellmer::type_object()]. This is the core technical bridge between the
#' YAML schema and ellmer's structured data extraction.
#'
#' Each variable is converted according to its type:
#'
#' | YAML type | `multiple` | ellmer type |
#' |---|---|---|
#' | `categorical` | no | `type_enum()` |
#' | `categorical` | yes | `type_array(type_enum())` |
#' | `numeric` | no | `type_integer()` / `type_number()` |
#' | `text` | no | `type_string()` |
#' | `text` | yes | `type_array(type_string())` |
#' | `boolean` | no | `type_boolean()` |
#' | `object` | no | `type_object()` |
#' | `object` | yes | `type_array(type_object())` |
#'
#' @param promptbook A `promptbook` object as returned by [read_promptbook()].
#' @param variables Character vector of variable names to include. Default:
#'   all variables. Cannot be combined with `group`.
#' @param group Character scalar. If supplied, include only variables in this
#'   group. Cannot be combined with `variables`.
#'
#' @return An `ellmer::TypeObject` — the exact object you'd pass to
#'   `chat$chat_structured(type = ...)`.
#'
#' @export
#' @examples
#' path <- system.file("examples", "media_framing.yaml", package = "promptbook")
#' pb <- read_promptbook(path)
#'
#' # All variables
#' type <- pb_type(pb)
#'
#' # Only one group
#' type_basic <- pb_type(pb, group = "basic")
#'
#' # Specific variables
#' type_sub <- pb_type(pb, variables = c("topic", "sentiment"))
pb_type <- function(promptbook, variables = NULL, group = NULL) {
  if (!inherits(promptbook, "promptbook")) {
    cli::cli_abort("{.arg promptbook} must be a {.cls promptbook} object.")
  }
  if (!is.null(variables) && !is.null(group)) {
    cli::cli_abort("{.arg variables} and {.arg group} cannot both be specified.")
  }

  vars <- promptbook$variables

  if (!is.null(variables)) {
    if (!is.character(variables)) {
      cli::cli_abort("{.arg variables} must be a character vector.")
    }
    var_names <- vapply(vars, function(v) v$name, character(1))
    unknown <- setdiff(variables, var_names)
    if (length(unknown) > 0) {
      cli::cli_abort("Unknown variable{?s}: {.val {unknown}}.")
    }
    vars <- vars[var_names %in% variables]
  }

  if (!is.null(group)) {
    if (!is.character(group) || length(group) != 1) {
      cli::cli_abort("{.arg group} must be a single string.")
    }
    vars <- Filter(function(v) identical(v$group, group), vars)
    if (length(vars) == 0) {
      cli::cli_abort("No variables found in group {.val {group}}.")
    }
  }

  # Convert each variable to an ellmer type and collect as named list
  type_args <- lapply(vars, pb_var_to_type)
  names(type_args) <- vapply(vars, function(v) v$name, character(1))

  rlang::inject(ellmer::type_object(!!!type_args))
}

# -- S3 generic for variable-to-type conversion ------------------------------

#' Convert a pb_variable to an ellmer type
#' @param var A `pb_variable` object
#' @return An ellmer type object
#' @keywords internal
#' @export
pb_var_to_type <- function(var) {
  UseMethod("pb_var_to_type")
}

#' @export
pb_var_to_type.pb_categorical <- function(var) {
  desc <- build_categorical_description(var)
  values <- vapply(var$categories, function(cat) cat$value, character(1))
  inner <- ellmer::type_enum(values, desc, required = var$required)
  if (isTRUE(var$multiple)) {
    ellmer::type_array(inner, description = desc, required = var$required)
  } else {
    inner
  }
}

#' @export
pb_var_to_type.pb_numeric <- function(var) {
  desc <- build_numeric_description(var)
  if (isTRUE(var$integer)) {
    ellmer::type_integer(desc, required = var$required)
  } else {
    ellmer::type_number(desc, required = var$required)
  }
}

#' @export
pb_var_to_type.pb_text <- function(var) {
  inner <- ellmer::type_string(var$description, required = var$required)
  if (isTRUE(var$multiple)) {
    ellmer::type_array(inner, description = var$description, required = var$required)
  } else {
    inner
  }
}

#' @export
pb_var_to_type.pb_boolean <- function(var) {
  ellmer::type_boolean(var$description, required = var$required)
}

#' @export
pb_var_to_type.pb_object <- function(var) {
  # Convert each property recursively
  prop_types <- lapply(var$properties, pb_var_to_type)
  names(prop_types) <- vapply(var$properties, function(p) p$name, character(1))

  inner <- rlang::inject(ellmer::type_object(
    .description = var$description,
    !!!prop_types
  ))

  if (isTRUE(var$multiple)) {
    ellmer::type_array(inner, description = var$description, required = var$required)
  } else {
    inner
  }
}

# -- Description builders ----------------------------------------------------

#' Build enriched description for categorical variables
#'
#' Appends category information to the base description.
#' Format: "Base desc. Categories: value = label (description); ..."
#' @noRd
build_categorical_description <- function(var) {
  parts <- vapply(var$categories, function(cat) {
    label <- cat$label %||% cat$value
    if (!is.null(cat$description)) {
      paste0(cat$value, " = ", label, " (", trimws(cat$description), ")")
    } else if (label != cat$value) {
      paste0(cat$value, " = ", label)
    } else {
      cat$value
    }
  }, character(1))

  paste0(trimws(var$description), " Categories: ", paste(parts, collapse = "; "), ".")
}

#' Build enriched description for numeric variables
#'
#' Appends scale/range information to the base description.
#' If labels exist: "Base desc. Scale: min (label) to max (label)."
#' Otherwise: "Base desc. Range: min to max."
#' @noRd
build_numeric_description <- function(var) {
  desc <- trimws(var$description)

  if (is.null(var$min) && is.null(var$max)) {
    return(desc)
  }

  if (!is.null(var$labels) && !is.null(var$min) && !is.null(var$max)) {
    min_label <- var$labels[[as.character(var$min)]]
    max_label <- var$labels[[as.character(var$max)]]
    if (!is.null(min_label) && !is.null(max_label)) {
      return(paste0(desc, " Scale: ", var$min, " (", min_label, ") to ", var$max, " (", max_label, ")."))
    }
  }

  if (!is.null(var$min) && !is.null(var$max)) {
    return(paste0(desc, " Range: ", var$min, " to ", var$max, "."))
  }

  if (!is.null(var$min)) {
    return(paste0(desc, " Minimum: ", var$min, "."))
  }

  paste0(desc, " Maximum: ", var$max, ".")
}
