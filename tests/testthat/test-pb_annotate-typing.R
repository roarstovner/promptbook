# Helpers to create minimal pb_variable objects for testing
make_categorical_var <- function(name = "topic",
                                 values = c("a", "b", "c"),
                                 labels = NULL,
                                 multiple = FALSE,
                                 required = FALSE) {
  labels <- labels %||% values
  cats <- Map(function(v, l) list(value = v, label = l), values, labels)
  structure(
    list(
      name = name,
      type = "categorical",
      description = "test",
      categories = unname(cats),
      multiple = multiple,
      required = required,
      label = name
    ),
    class = c("pb_categorical", "pb_variable")
  )
}

make_numeric_var <- function(name = "score", integer = TRUE, required = FALSE) {
  structure(
    list(
      name = name,
      type = "numeric",
      description = "test",
      integer = integer,
      required = required,
      label = name
    ),
    class = c("pb_numeric", "pb_variable")
  )
}

make_text_var <- function(name = "quote", multiple = FALSE, required = FALSE) {
  structure(
    list(
      name = name,
      type = "text",
      description = "test",
      multiple = multiple,
      required = required,
      label = name
    ),
    class = c("pb_text", "pb_variable")
  )
}

make_boolean_var <- function(name = "flag", required = FALSE) {
  structure(
    list(
      name = name,
      type = "boolean",
      description = "test",
      required = required,
      label = name
    ),
    class = c("pb_boolean", "pb_variable")
  )
}

make_object_var <- function(name = "obj", multiple = FALSE, required = FALSE) {
  structure(
    list(
      name = name,
      type = "object",
      description = "test",
      multiple = multiple,
      required = required,
      label = name
    ),
    class = c("pb_object", "pb_variable")
  )
}

# -- pb_type_column: categorical -----------------------------------------------

test_that("categorical -> factor with correct levels and labels", {
  var <- make_categorical_var(
    values = c("economy", "health", "politics"),
    labels = c("Economic impacts", "Public health", "Political process")
  )
  x <- c("economy", "health", "politics", "economy")
  result <- pb_type_column(x, var)
  expect_s3_class(result, "factor")
  expect_equal(levels(result), c("Economic impacts", "Public health", "Political process"))
  expect_equal(as.character(result), c("Economic impacts", "Public health", "Political process", "Economic impacts"))
})

test_that("categorical + multiple -> list-column pass-through", {
  var <- make_categorical_var(multiple = TRUE)
  x <- list(c("a", "b"), c("c"), character(0))
  result <- pb_type_column(x, var)
  expect_identical(result, x)
})

# -- pb_type_column: numeric ---------------------------------------------------

test_that("numeric (integer: true) -> integer vector", {
  var <- make_numeric_var(integer = TRUE)
  x <- c(1, 2, 3)
  result <- pb_type_column(x, var)
  expect_type(result, "integer")
  expect_equal(result, c(1L, 2L, 3L))
})

test_that("numeric (integer: false) -> double vector", {
  var <- make_numeric_var(integer = FALSE)
  x <- c(1.5, 2.7, 3.1)
  result <- pb_type_column(x, var)
  expect_type(result, "double")
  expect_equal(result, c(1.5, 2.7, 3.1))
})

# -- pb_type_column: boolean ---------------------------------------------------

test_that("boolean -> logical vector", {
  var <- make_boolean_var()
  x <- c(TRUE, FALSE, TRUE)
  result <- pb_type_column(x, var)
  expect_type(result, "logical")
  expect_equal(result, c(TRUE, FALSE, TRUE))
})

# -- pb_type_column: text ------------------------------------------------------

test_that("text -> character vector", {
  var <- make_text_var()
  x <- c("hello", "world")
  result <- pb_type_column(x, var)
  expect_type(result, "character")
  expect_equal(result, c("hello", "world"))
})

test_that("text + multiple -> list-column pass-through", {
  var <- make_text_var(multiple = TRUE)
  x <- list(c("a", "b"), c("c"))
  result <- pb_type_column(x, var)
  expect_identical(result, x)
})

# -- pb_type_column: object ----------------------------------------------------

test_that("object (single) -> list-column pass-through", {
  var <- make_object_var(multiple = FALSE)
  x <- list(list(a = 1, b = 2), list(a = 3, b = 4))
  result <- pb_type_column(x, var)
  expect_identical(result, x)
})

test_that("object + multiple -> list-column pass-through", {
  var <- make_object_var(multiple = TRUE)
  x <- list(
    data.frame(name = "Alice", age = 30),
    data.frame(name = c("Bob", "Carol"), age = c(25, 35))
  )
  result <- pb_type_column(x, var)
  expect_identical(result, x)
})

# -- NA handling ---------------------------------------------------------------

test_that("NA handling for non-required categorical", {
  var <- make_categorical_var(
    values = c("a", "b"),
    labels = c("Label A", "Label B"),
    required = FALSE
  )
  x <- c("a", NA, "b")
  result <- pb_type_column(x, var)
  expect_s3_class(result, "factor")
  expect_true(is.na(result[2]))
  expect_equal(as.character(result[1]), "Label A")
  expect_equal(as.character(result[3]), "Label B")
})

# -- pb_type_columns -----------------------------------------------------------

test_that("pb_type_columns applies typing to all columns in a data frame", {
  topic_var <- make_categorical_var(
    name = "topic",
    values = c("a", "b"),
    labels = c("Label A", "Label B")
  )
  score_var <- make_numeric_var(name = "score", integer = TRUE)

  df <- data.frame(topic = c("a", "b"), score = c(1.0, 2.0),
                   stringsAsFactors = FALSE)

  all_vars <- list(topic_var, score_var)
  result <- pb_type_columns(df, all_vars, c("topic", "score"))

  expect_s3_class(result$topic, "factor")
  expect_equal(levels(result$topic), c("Label A", "Label B"))
  expect_type(result$score, "integer")
})

# -- pb_reassemble -------------------------------------------------------------

test_that("pb_reassemble cbinds step results onto original data, returns tibble", {
  original <- data.frame(id = 1:3, text = c("a", "b", "c"),
                         stringsAsFactors = FALSE)
  step1 <- data.frame(topic = c("x", "y", "z"), stringsAsFactors = FALSE)
  step2 <- data.frame(score = c(1L, 2L, 3L))

  result <- pb_reassemble(original, list(step1, step2))
  expect_s3_class(result, "tbl_df")
  expect_equal(ncol(result), 4)
  expect_equal(names(result), c("id", "text", "topic", "score"))
  expect_equal(result$id, 1:3)
  expect_equal(result$topic, c("x", "y", "z"))
  expect_equal(result$score, c(1L, 2L, 3L))
})
