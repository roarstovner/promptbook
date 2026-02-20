# Internal validation functions for promptbook YAML
# All functions are called from read_promptbook() and are not exported.

#' Validate a parsed promptbook list
#'
#' @param raw Named list from `yaml::read_yaml()`
#' @return Invisibly returns `raw` if valid; otherwise aborts with an error
#' @noRd
validate_promptbook <- function(raw) {
  validate_top_level(raw)
  validate_variables(raw$variables)
  validate_groups(raw)
  invisible(raw)
}

# -- Top-level fields --------------------------------------------------------

validate_top_level <- function(raw) {
  # schema_version
  if (is.null(raw$schema_version)) {
    cli::cli_abort("{.field schema_version} is required.")
  }
  if (!is_scalar_integerish(raw$schema_version) || raw$schema_version < 1) {
    cli::cli_abort(
      "{.field schema_version} must be a positive integer, not {.val {raw$schema_version}}."
    )
  }
  if (raw$schema_version != 1L) {
    cli::cli_abort(
      "Only {.field schema_version} {.val 1} is supported, not {.val {raw$schema_version}}."
    )
  }


  # title
  if (is.null(raw$title)) {
    cli::cli_abort("{.field title} is required.")
  }
  if (!is.character(raw$title) || length(raw$title) != 1) {
    cli::cli_abort("{.field title} must be a single string.")
  }

  # prompt
  if (is.null(raw$prompt)) {
    cli::cli_abort("{.field prompt} is required.")
  }
  if (is.null(raw$prompt$system)) {
    cli::cli_abort("{.field prompt.system} is required.")
  }
  if (!is.character(raw$prompt$system) || length(raw$prompt$system) != 1) {
    cli::cli_abort("{.field prompt.system} must be a single string.")
  }
  if (!is.null(raw$prompt$user)) {
    if (!is.character(raw$prompt$user) || length(raw$prompt$user) != 1) {
      cli::cli_abort("{.field prompt.user} must be a single string.")
    }
  }

  # version warning
  if (is.null(raw$version)) {
    cli::cli_warn("{.field version} is missing. Consider adding a version string.")
  }
}

# -- Variables ---------------------------------------------------------------

validate_variables <- function(variables) {
  if (is.null(variables) || length(variables) == 0) {
    cli::cli_abort("{.field variables} must contain at least one variable.")
  }

  names_seen <- character()
  for (i in seq_along(variables)) {
    validate_variable(variables[[i]], i)
    names_seen <- c(names_seen, variables[[i]]$name)
  }

  # Check for duplicate names

  dupes <- names_seen[duplicated(names_seen)]
  if (length(dupes) > 0) {
    cli::cli_abort("Duplicate variable names: {.val {unique(dupes)}}.")
  }
}

validate_variable <- function(var, i) {
  prefix <- paste0("variables[[", i, "]]")

  # name
  if (is.null(var$name)) {
    cli::cli_abort("{.field {prefix}$name} is required.")
  }
  if (!is.character(var$name) || length(var$name) != 1) {
    cli::cli_abort("{.field {prefix}$name} must be a single string.")
  }
  if (make.names(var$name) != var$name) {
    cli::cli_abort(
      "{.field {prefix}$name} ({.val {var$name}}) is not a valid R name."
    )
  }

  # type
  valid_types <- c("categorical", "numeric", "text", "boolean", "object")
  if (is.null(var$type)) {
    cli::cli_abort("{.field {prefix}$type} is required.")
  }
  if (!var$type %in% valid_types) {
    cli::cli_abort(
      "{.field {prefix}$type} must be one of {.val {valid_types}}, not {.val {var$type}}."
    )
  }

  # description
  if (is.null(var$description)) {
    cli::cli_abort("{.field {prefix}$description} is required.")
  }

  # multiple
  if (!is.null(var$multiple)) {
    if (!is.logical(var$multiple) || length(var$multiple) != 1) {
      cli::cli_abort("{.field {prefix}$multiple} must be TRUE or FALSE.")
    }
    if (isTRUE(var$multiple) && !var$type %in% c("categorical", "text", "object")) {
      cli::cli_abort(
        "{.field {prefix}$multiple} is only valid for categorical, text, and object types, not {.val {var$type}}."
      )
    }
  }

  # required
  if (!is.null(var$required)) {
    if (!is.logical(var$required) || length(var$required) != 1) {
      cli::cli_abort("{.field {prefix}$required} must be TRUE or FALSE.")
    }
  }

  # Type-specific validation
  switch(var$type,
    categorical = validate_categorical(var, prefix),
    numeric     = validate_numeric(var, prefix),
    text        = validate_text(var, prefix),
    boolean     = validate_boolean(var, prefix),
    object      = validate_object(var, prefix)
  )
}

# -- Type-specific validators ------------------------------------------------

validate_categorical <- function(var, prefix) {
  if (is.null(var$categories) || length(var$categories) == 0) {
    cli::cli_abort("{.field {prefix}$categories} is required for categorical variables.")
  }
  for (j in seq_along(var$categories)) {
    cat <- var$categories[[j]]
    if (is.null(cat$value)) {
      cli::cli_abort(
        "{.field {prefix}$categories[[{j}]]$value} is required."
      )
    }
  }

  # Warning: missing category descriptions
  missing_desc <- vapply(var$categories, function(cat) is.null(cat$description), logical(1))
  if (any(missing_desc)) {
    cli::cli_warn(
      "Variable {.val {var$name}}: {sum(missing_desc)} categor{?y/ies} missing {.field description}. Category descriptions improve LLM accuracy."
    )
  }
}

validate_numeric <- function(var, prefix) {
  if (!is.null(var$min) && !is.numeric(var$min)) {
    cli::cli_abort("{.field {prefix}$min} must be numeric.")
  }
  if (!is.null(var$max) && !is.numeric(var$max)) {
    cli::cli_abort("{.field {prefix}$max} must be numeric.")
  }
  if (!is.null(var$integer)) {
    if (!is.logical(var$integer) || length(var$integer) != 1) {
      cli::cli_abort("{.field {prefix}$integer} must be TRUE or FALSE.")
    }
  }

  # Validate labels
  if (!is.null(var$labels)) {
    label_keys <- names(var$labels)
    numeric_keys <- suppressWarnings(as.numeric(label_keys))
    if (any(is.na(numeric_keys))) {
      cli::cli_abort(
        "{.field {prefix}$labels} keys must be numeric."
      )
    }
    if (!is.null(var$min) && !is.null(var$max)) {
      out_of_range <- numeric_keys < var$min | numeric_keys > var$max
      if (any(out_of_range)) {
        bad <- label_keys[out_of_range]
        cli::cli_abort(
          "{.field {prefix}$labels} keys {.val {bad}} are outside [{var$min}, {var$max}]."
        )
      }
    }
  }

  # Warning: missing min/max
  if (is.null(var$min) || is.null(var$max)) {
    cli::cli_warn(
      "Variable {.val {var$name}}: numeric variable without {.field min}/{.field max}. The LLM may return unexpected values."
    )
  }

  # multiple not valid for numeric
  if (isTRUE(var$multiple)) {
    cli::cli_abort(
      "{.field {prefix}$multiple} is only valid for categorical, text, and object types, not {.val numeric}."
    )
  }
}

validate_text <- function(var, prefix) {
  # No extra required fields
}

validate_boolean <- function(var, prefix) {
  # multiple not allowed for boolean
  if (isTRUE(var$multiple)) {
    cli::cli_abort(
      "{.field {prefix}$multiple} is only valid for categorical, text, and object types, not {.val boolean}."
    )
  }
}

validate_object <- function(var, prefix) {
  if (is.null(var$properties) || length(var$properties) == 0) {
    cli::cli_abort("{.field {prefix}$properties} is required for object variables.")
  }

  prop_names <- character()
  for (j in seq_along(var$properties)) {
    prop <- var$properties[[j]]
    prop_prefix <- paste0(prefix, "$properties[[", j, "]]")

    # name
    if (is.null(prop$name)) {
      cli::cli_abort("{.field {prop_prefix}$name} is required.")
    }
    if (make.names(prop$name) != prop$name) {
      cli::cli_abort(
        "{.field {prop_prefix}$name} ({.val {prop$name}}) is not a valid R name."
      )
    }

    # type
    if (is.null(prop$type)) {
      cli::cli_abort("{.field {prop_prefix}$type} is required.")
    }
    scalar_types <- c("categorical", "numeric", "text", "boolean")
    if (!prop$type %in% scalar_types) {
      if (prop$type == "object") {
        cli::cli_abort(
          "{.field {prop_prefix}$type}: nested objects are not allowed. Object properties must be scalar types."
        )
      }
      cli::cli_abort(
        "{.field {prop_prefix}$type} must be one of {.val {scalar_types}}, not {.val {prop$type}}."
      )
    }

    # description
    if (is.null(prop$description)) {
      cli::cli_abort("{.field {prop_prefix}$description} is required.")
    }

    # group/model not allowed on properties
    if (!is.null(prop$group)) {
      cli::cli_abort("{.field {prop_prefix}$group} is not allowed on object properties.")
    }
    if (!is.null(prop$model)) {
      cli::cli_abort("{.field {prop_prefix}$model} is not allowed on object properties.")
    }

    # Type-specific validation for properties
    if (prop$type == "categorical") {
      validate_categorical(prop, prop_prefix)
    } else if (prop$type == "numeric") {
      validate_numeric(prop, prop_prefix)
    }

    prop_names <- c(prop_names, prop$name)
  }

  # Duplicate property names
  dupes <- prop_names[duplicated(prop_names)]
  if (length(dupes) > 0) {
    cli::cli_abort(
      "Duplicate property names in {.field {prefix}}: {.val {unique(dupes)}}."
    )
  }
}

# -- Groups ------------------------------------------------------------------

validate_groups <- function(raw) {
  variables <- raw$variables
  groups_def <- raw$groups

  # Collect group references from variables
  var_groups <- vapply(
    variables,
    function(v) if (is.null(v$group)) NA_character_ else v$group,
    character(1)
  )
  unique_var_groups <- unique(var_groups[!is.na(var_groups)])

  if (!is.null(groups_def)) {
    defined_groups <- names(groups_def)

    # All variable group references must match a defined group
    undefined <- setdiff(unique_var_groups, defined_groups)
    if (length(undefined) > 0) {
      cli::cli_abort(c(
        "Undefined group{cli::qty(length(undefined))}{?s} referenced by variables: {.val {undefined}}.",
        i = "Defined groups: {.val {defined_groups}}."
      ))
    }
  }

  # Warning: >20 variables without groups
  n_ungrouped <- sum(is.na(var_groups))
  total_vars <- length(variables)
  if (total_vars > 20 && n_ungrouped > 0) {
    cli::cli_warn(
      "{total_vars} variables with {n_ungrouped} ungrouped. Consider using groups to stay within structured output limits (~24 parameters)."
    )
  }
}

# -- Helpers -----------------------------------------------------------------

#' Check if a value is a scalar integer-like number
#' @noRd
is_scalar_integerish <- function(x) {
  is.numeric(x) && length(x) == 1 && !is.na(x) && x == trunc(x)
}
