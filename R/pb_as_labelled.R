#' Convert annotation results to haven-labelled columns
#'
#' Converts coded columns from [pb_annotate()] to [haven::labelled()] format
#' for export to SPSS or Stata. Categorical variables become integer-coded
#' with value labels, booleans become 0/1, and variable labels are attached
#' from the promptbook.
#'
#' @param data A data frame with annotation results (as returned by
#'   [pb_annotate()]).
#' @param promptbook A `promptbook` object (or a path to a YAML file).
#'
#' @return The input data frame with coded columns converted to
#'   `haven::labelled()` format. Object and list-column variables are skipped
#'   with a message.
#'
#' @export
pb_as_labelled <- function(data, promptbook) {
  rlang::check_installed("haven", reason = "to convert columns to labelled format.")

  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }

  if (is.character(promptbook) && length(promptbook) == 1) {
    promptbook <- read_promptbook(promptbook)
  }
  if (!inherits(promptbook, "promptbook")) {
    cli::cli_abort(
      "{.arg promptbook} must be a {.cls promptbook} object or a path to a YAML file."
    )
  }

  for (var in promptbook$variables) {
    nm <- var$name
    if (!nm %in% names(data)) next

    # Skip list-column types (multiple, object)
    if (isTRUE(var$multiple) || var$type == "object") {
      cli::cli_inform("{.var {nm}} skipped (not supported by labelled format).")
      next
    }

    data[[nm]] <- pb_labelled_column(data[[nm]], var)
  }

  data
}

#' Convert a single column to haven-labelled format
#'
#' S3 generic dispatching on variable class.
#'
#' @param x Column vector.
#' @param var A `pb_variable` object.
#' @return Converted column.
#' @noRd
pb_labelled_column <- function(x, var) {
  UseMethod("pb_labelled_column", var)
}

#' @noRd
pb_labelled_column.pb_categorical <- function(x, var) {
  # Factor → integer codes with value labels
  # pb_type_column.pb_categorical creates factors with levels = values,
  # labels = category labels, so as.integer() gives 1-based codes matching
  # category order
  labels <- vapply(var$categories, function(cat) cat$label %||% cat$value, character(1))

  int_codes <- as.integer(x)

  # Build named value labels: label_text = integer_position
  value_labels <- stats::setNames(seq_along(labels), labels)
  value_labels <- as.integer(value_labels)
  names(value_labels) <- labels

  haven::labelled(int_codes, labels = value_labels, label = var$label)
}

#' @noRd
pb_labelled_column.pb_numeric <- function(x, var) {
  if (!is.null(var$labels) && length(var$labels) > 0) {
    # Build value labels: label_text = integer_value
    label_values <- as.integer(names(var$labels))
    label_names <- as.character(var$labels)
    value_labels <- stats::setNames(label_values, label_names)

    haven::labelled(x, labels = value_labels, label = var$label)
  } else {
    # No value labels — just attach variable label
    attr(x, "label") <- var$label
    x
  }
}

#' @noRd
pb_labelled_column.pb_boolean <- function(x, var) {
  int_val <- as.integer(x)
  haven::labelled(int_val, labels = c("No" = 0L, "Yes" = 1L), label = var$label)
}

#' @noRd
pb_labelled_column.pb_text <- function(x, var) {
  attr(x, "label") <- var$label
  x
}
