#' Annotate a data frame using a promptbook
#'
#' The main convenience function for the promptbook package. Takes a data
#' frame and a promptbook, handles variable grouping by (group, model),
#' dispatches to ellmer for LLM extraction, and returns properly typed columns.
#'
#' @param data A data frame containing the text to annotate.
#' @param promptbook A `promptbook` object (from [read_promptbook()]) or a
#'   path to a YAML file.
#' @param chat A single [ellmer::Chat] object or a named list of Chat objects
#'   keyed by model name. Required unless no model overrides exist in the
#'   promptbook.
#' @param text <[`tidy-select`][tidyselect::language]> Column(s) containing
#'   the text to annotate. Defaults to `text`.
#' @param method One of `"parallel"`, `"sequential"`, or `"batch"`.
#'   Controls how prompts are sent to the LLM.
#' @param ... Additional arguments passed to the ellmer dispatch function.
#'
#' @return A tibble with the original columns plus new columns for each
#'   promptbook variable, properly typed:
#'   - Categorical variables become factors (or list-columns if `multiple: true`)
#'   - Numeric variables become integers (or doubles if `integer: false`)
#'   - Text variables become character (or list-columns if `multiple: true`)
#'   - Boolean variables become logical
#'   - Object variables become list-columns
#'
#' @export
#' @examples
#' path <- system.file("examples", "media_framing.yaml", package = "promptbook")
#' pb <- read_promptbook(path)
#'
#' \dontrun{
#' library(ellmer)
#'
#' # Single model (no groups/model overrides)
#' chat <- chat_anthropic(model = "claude-sonnet")
#' result <- pb_annotate(articles, pb, chat)
#'
#' # Multiple models (matching promptbook groups)
#' chat <- list(
#'   fast   = chat_anthropic(model = "claude-haiku"),
#'   strong = chat_anthropic(model = "claude-sonnet")
#' )
#' result <- pb_annotate(articles, pb, chat)
#'
#' # Sequential for debugging
#' result <- pb_annotate(articles, pb, chat, method = "sequential")
#'
#' # Multiple text columns
#' result <- pb_annotate(articles, pb, chat, text = c(title, abstract))
#' }
pb_annotate <- function(data,
                        promptbook,
                        chat,
                        text = text,
                        method = c("parallel", "sequential", "batch"),
                        ...) {
  method <- match.arg(method)

  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }

  # Accept path or promptbook object
  if (is.character(promptbook) && length(promptbook) == 1) {
    promptbook <- read_promptbook(promptbook)
  }
  if (!inherits(promptbook, "promptbook")) {
    cli::cli_abort(
      "{.arg promptbook} must be a {.cls promptbook} object or a path to a YAML file."
    )
  }

  # Resolve text columns
  text_quo <- rlang::enquo(text)
  text_cols <- pb_resolve_text_cols(data, text_quo)

  # Build execution plan

  plan <- pb_execution_plan(promptbook)

  # Resolve chat objects for each step
  system_prompt <- promptbook$prompt$system
  chats <- pb_resolve_chat(chat, plan, system_prompt)

  # Build prompts
  user_template <- promptbook$prompt$user
  prompts <- pb_build_prompts(user_template, data, text_cols)

  # Dispatch each step and collect results
  step_results <- vector("list", length(plan))
  for (i in seq_along(plan)) {
    step <- plan[[i]]
    raw_result <- pb_dispatch(chats[[i]], prompts, step$type, method, ...)
    step_results[[i]] <- pb_type_columns(raw_result, promptbook$variables, step$variables)
  }

  # Reassemble
  pb_reassemble(data, step_results)
}


# -- Execution plan -----------------------------------------------------------

#' Build an execution plan from a promptbook
#'
#' Groups variables by (group, model) key and builds a TypeObject for each
#' step. Pure logic, no LLM calls.
#'
#' @param promptbook A `promptbook` object.
#' @return A list of steps, each with `group`, `model`, `variables`, `type`.
#' @noRd
pb_execution_plan <- function(promptbook) {
  vars <- promptbook$variables
  groups_def <- promptbook$groups

  # For each variable, determine (group, model) key
  keys <- vapply(vars, function(v) {
    grp <- v$group %||% ".default"
    # Model: variable-level overrides group-level
    if (!is.null(v$model)) {
      mdl <- v$model
    } else if (!is.null(groups_def) && !is.null(groups_def[[grp]])) {
      mdl <- groups_def[[grp]]$model %||% ""
    } else {
      mdl <- ""
    }
    paste0(grp, "\t", mdl)
  }, character(1))

  # Group variables into buckets
  unique_keys <- unique(keys)
  steps <- vector("list", length(unique_keys))
  for (i in seq_along(unique_keys)) {
    key <- unique_keys[[i]]
    parts <- strsplit(key, "\t", fixed = TRUE)[[1]]
    grp <- parts[1]
    mdl <- if (length(parts) < 2 || parts[2] == "") NULL else parts[2]

    var_indices <- which(keys == key)
    var_names <- vapply(vars[var_indices], function(v) v$name, character(1))

    type <- pb_type(promptbook, variables = var_names)

    steps[[i]] <- list(
      group = grp,
      model = mdl,
      variables = var_names,
      type = type
    )
  }

  steps
}


# -- Chat resolution ----------------------------------------------------------

#' Resolve chat objects for each step in the execution plan
#'
#' @param chat A single Chat object or a named list of Chat objects.
#' @param plan Execution plan from `pb_execution_plan()`.
#' @param system_prompt System prompt to set on each chat clone.
#' @return A list of Chat objects, one per step.
#' @noRd
pb_resolve_chat <- function(chat, plan, system_prompt) {
  # Collect all required model names
  models_needed <- unique(unlist(lapply(plan, function(s) s$model)))
  models_needed <- models_needed[!is.null(models_needed)]

  if (inherits(chat, "Chat")) {
    # Single Chat: only valid when no models needed
    if (length(models_needed) > 0) {
      cli::cli_abort(c(
        "Promptbook requires models: {.val {models_needed}}.",
        i = "Pass {.code chat = list({paste(models_needed, '= ...', collapse = ', ')})}."
      ))
    }
    # Clone for each step, set system prompt
    lapply(plan, function(step) {
      cloned <- chat$clone(deep = FALSE)
      cloned$set_system_prompt(system_prompt)
      cloned
    })
  } else if (is.list(chat) && !is.null(names(chat))) {
    # Named list: match by model name
    missing <- setdiff(models_needed, names(chat))
    if (length(missing) > 0) {
      cli::cli_abort(c(
        "Missing chat object{?s} for model{?s}: {.val {missing}}.",
        i = "Provide {.code chat = list({paste(missing, '= ...', collapse = ', ')})}."
      ))
    }
    lapply(plan, function(step) {
      if (is.null(step$model)) {
        # No model specified - use first chat in list
        base <- chat[[1]]
      } else {
        base <- chat[[step$model]]
      }
      cloned <- base$clone(deep = FALSE)
      cloned$set_system_prompt(system_prompt)
      cloned
    })
  } else {
    cli::cli_abort(
      "{.arg chat} must be a {.cls Chat} object or a named list of {.cls Chat} objects."
    )
  }
}


# -- Text column resolution ---------------------------------------------------

#' Resolve text columns using tidyselect
#'
#' @param data A data frame.
#' @param text_quo A quosure from the `text` argument.
#' @return An integer vector of column positions.
#' @noRd
pb_resolve_text_cols <- function(data, text_quo) {
  pos <- tidyselect::eval_select(text_quo, data, error_call = rlang::caller_env())
  if (length(pos) == 0) {
    cli::cli_abort("No text columns found matching {.arg text} selection.")
  }
  pos
}


# -- Prompt building ----------------------------------------------------------

#' Build prompts by interpolating text columns into user template
#'
#' @param user_template User template string with `{placeholder}` syntax,
#'   or NULL (defaults to `"{text}"`).
#' @param data A data frame.
#' @param text_cols Named integer vector of column positions (from tidyselect).
#' @return A list of character strings, one per row.
#' @noRd
pb_build_prompts <- function(user_template, data, text_cols) {
  if (is.null(user_template)) {
    user_template <- "{text}"
  }

  # Extract placeholder names from template
  placeholders <- regmatches(
    user_template,
    gregexpr("\\{([^}]+)\\}", user_template)
  )[[1]]
  placeholders <- gsub("[{}]", "", placeholders)

  # Check that all placeholders can be resolved from text_cols
  col_names <- names(text_cols)
  missing <- setdiff(placeholders, col_names)
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "Placeholder{?s} not found in text columns: {.val {missing}}.",
      i = "Available text columns: {.val {col_names}}."
    ))
  }

  # Build a data frame of just the text columns for glue
  text_data <- data[, text_cols, drop = FALSE]

  vapply(seq_len(nrow(data)), function(i) {
    env <- list2env(as.list(text_data[i, , drop = FALSE]), parent = emptyenv())
    as.character(glue::glue(user_template, .envir = env))
  }, character(1))
}


# -- Dispatch -----------------------------------------------------------------

#' Dispatch prompts to ellmer
#'
#' @param chat A Chat object (already cloned with system prompt set).
#' @param prompts Character vector of prompts.
#' @param type An ellmer TypeObject.
#' @param method One of "parallel", "sequential", "batch".
#' @param ... Additional arguments.
#' @return A data frame of raw results from ellmer.
#' @noRd
pb_dispatch <- function(chat, prompts, type, method, ...) {
  prompts_list <- as.list(prompts)
  switch(method,
    parallel = ellmer::parallel_chat_structured(chat, prompts_list, type = type, ...),
    batch = ellmer::batch_chat_structured(chat, prompts_list, type = type, ...),
    sequential = {
      results <- vector("list", length(prompts_list))
      for (i in seq_along(prompts_list)) {
        cloned <- chat$clone(deep = FALSE)
        results[[i]] <- cloned$chat_structured(prompts_list[[i]], type = type)
      }
      do.call(rbind, lapply(results, as.data.frame))
    },
    cli::cli_abort("Unknown method: {.val {method}}.")
  )
}


# -- Column typing ------------------------------------------------------------

#' Type a single column based on its variable definition
#'
#' S3 generic dispatching on the variable's class.
#'
#' @param x A vector (column from ellmer result).
#' @param var A `pb_variable` object.
#' @return A properly typed vector.
#' @noRd
pb_type_column <- function(x, var) {
  UseMethod("pb_type_column", var)
}

#' @noRd
pb_type_column.pb_categorical <- function(x, var) {
  if (isTRUE(var$multiple)) {
    return(x)  # pass-through list-column
  }
  values <- vapply(var$categories, function(cat) cat$value, character(1))
  labels <- vapply(var$categories, function(cat) cat$label %||% cat$value, character(1))
  factor(x, levels = values, labels = labels)
}

#' @noRd
pb_type_column.pb_numeric <- function(x, var) {
  if (isTRUE(var$integer)) {
    as.integer(x)
  } else {
    as.double(x)
  }
}

#' @noRd
pb_type_column.pb_text <- function(x, var) {
  if (isTRUE(var$multiple)) {
    return(x)  # pass-through list-column
  }
  as.character(x)
}

#' @noRd
pb_type_column.pb_boolean <- function(x, var) {
  as.logical(x)
}

#' @noRd
pb_type_column.pb_object <- function(x, var) {
  x  # pass-through (ellmer handles conversion)
}


#' Apply column typing to a data frame
#'
#' @param df Data frame of raw results from ellmer.
#' @param all_variables List of all pb_variable objects from the promptbook.
#' @param var_names Character vector of variable names in this step.
#' @return Data frame with properly typed columns.
#' @noRd
pb_type_columns <- function(df, all_variables, var_names) {
  # Build lookup of variable objects by name
  var_lookup <- stats::setNames(all_variables, vapply(all_variables, function(v) v$name, character(1)))

  for (nm in var_names) {
    if (nm %in% names(df)) {
      df[[nm]] <- pb_type_column(df[[nm]], var_lookup[[nm]])
    }
  }
  df
}


#' Reassemble step results onto the original data
#'
#' @param original Original data frame.
#' @param step_results List of data frames, one per execution step.
#' @return A tibble with original columns plus annotation columns.
#' @noRd
pb_reassemble <- function(original, step_results) {
  result <- original
  for (step_df in step_results) {
    result <- cbind(result, step_df)
  }
  tibble::as_tibble(result)
}
