# -- helpers ------------------------------------------------------------------

# Minimal promptbook builder for testing
make_test_pb <- function(variables, groups = NULL) {
  structure(
    list(
      title = "Test",
      version = NULL,
      description = NULL,
      author = NULL,
      prompt = list(system = "test", user = "{text}"),
      variables = variables,
      groups = groups
    ),
    class = "promptbook"
  )
}

make_var <- function(name, type, label = name, multiple = FALSE, ...) {
  type_class <- paste0("pb_", type)
  var <- list(name = name, type = type, label = label, required = FALSE,
              multiple = multiple, ...)
  structure(var, class = c(type_class, "pb_variable"))
}

# -- Step 1: haven not installed → clear error --------------------------------

test_that("pb_as_labelled() errors when haven is not installed", {
  local_mocked_bindings(
    check_installed = function(pkg, ...) {
      if (pkg == "haven") {
        cli::cli_abort("Package {.pkg haven} is required.")
      }
    },
    .package = "rlang"
  )
  pb <- make_test_pb(list(make_var("x", "text")))
  df <- data.frame(x = "hello")
  expect_error(pb_as_labelled(df, pb), "haven")
})

# -- Step 2: no matching variables → data unchanged ---------------------------

test_that("pb_as_labelled() returns data unchanged when no pb variables match", {
  pb <- make_test_pb(list(make_var("x", "text")))
  df <- data.frame(unrelated = 1:3)
  result <- pb_as_labelled(df, pb)
  expect_identical(result, df)
})

# -- Step 3: categorical → labelled integer -----------------------------------

test_that("categorical variable becomes labelled integer with value labels", {
  cats <- list(
    list(value = "economy", label = "Economic impacts"),
    list(value = "health", label = "Public health"),
    list(value = "politics", label = "Political process")
  )
  var <- make_var("topic", "categorical", label = "Primary topic",
                  categories = cats)
  pb <- make_test_pb(list(var))

  df <- data.frame(
    topic = factor(c("economy", "health", "politics"),
                   levels = c("economy", "health", "politics"),
                   labels = c("Economic impacts", "Public health", "Political process"))
  )

  result <- pb_as_labelled(df, pb)

  expect_s3_class(result$topic, "haven_labelled")
  expect_type(unclass(result$topic), "integer")
  # Value labels: named integer → label
  expected_labels <- c("Economic impacts" = 1L, "Public health" = 2L,
                       "Political process" = 3L)
  expect_equal(attr(result$topic, "labels"), expected_labels)
})

test_that("categorical handles NA values", {
  cats <- list(
    list(value = "a", label = "A"),
    list(value = "b", label = "B")
  )
  var <- make_var("x", "categorical", label = "X", categories = cats)
  pb <- make_test_pb(list(var))

  df <- data.frame(
    x = factor(c("a", NA, "b"), levels = c("a", "b"), labels = c("A", "B"))
  )

  result <- pb_as_labelled(df, pb)
  expect_equal(as.integer(is.na(unclass(result$x))), c(0L, 1L, 0L))
})

# -- Step 4: numeric with labels → labelled integer ---------------------------

test_that("numeric with labels becomes labelled integer", {
  var <- make_var("sentiment", "numeric", label = "Overall sentiment",
                  integer = TRUE, min = 1, max = 5,
                  labels = list("1" = "Very negative", "2" = "Somewhat negative",
                                "3" = "Neutral", "4" = "Somewhat positive",
                                "5" = "Very positive"))
  pb <- make_test_pb(list(var))

  df <- data.frame(sentiment = c(1L, 3L, 5L))

  result <- pb_as_labelled(df, pb)

  expect_s3_class(result$sentiment, "haven_labelled")
  expected_labels <- c("Very negative" = 1L, "Somewhat negative" = 2L,
                       "Neutral" = 3L, "Somewhat positive" = 4L,
                       "Very positive" = 5L)
  expect_equal(attr(result$sentiment, "labels"), expected_labels)
})

# -- Step 5: numeric without labels → unchanged (but gets variable label) -----

test_that("numeric without labels is unchanged except for variable label", {
  var <- make_var("score", "numeric", label = "Score", integer = TRUE,
                  min = 0, max = 100)
  pb <- make_test_pb(list(var))

  df <- data.frame(score = c(42L, 78L))

  result <- pb_as_labelled(df, pb)

  # Should NOT be haven_labelled (no value labels to add)
  expect_false(inherits(result$score, "haven_labelled"))
  expect_equal(as.integer(result$score), c(42L, 78L))
  # But should have variable label
  expect_equal(attr(result$score, "label"), "Score")
})

# -- Step 6: boolean → labelled 0/1 ------------------------------------------

test_that("boolean becomes labelled integer 0/1", {
  var <- make_var("has_data", "boolean", label = "Contains data")
  pb <- make_test_pb(list(var))

  df <- data.frame(has_data = c(TRUE, FALSE, NA))

  result <- pb_as_labelled(df, pb)

  expect_s3_class(result$has_data, "haven_labelled")
  expect_type(unclass(result$has_data), "integer")
  expect_equal(as.integer(unclass(result$has_data)), c(1L, 0L, NA_integer_))
  expect_equal(attr(result$has_data, "labels"), c("No" = 0L, "Yes" = 1L))
})

# -- Step 7: text → unchanged ------------------------------------------------

test_that("text variable is unchanged except for variable label", {
  var <- make_var("quote", "text", label = "Key quote")
  pb <- make_test_pb(list(var))

  df <- data.frame(quote = c("hello", "world"), stringsAsFactors = FALSE)

  result <- pb_as_labelled(df, pb)

  expect_type(result$quote, "character")
  expect_equal(as.character(result$quote), c("hello", "world"))
  expect_equal(attr(result$quote, "label"), "Key quote")
})

# -- Step 8: object → skipped with message ------------------------------------

test_that("object variable is skipped with informational message", {
  var <- make_var("actors", "object", label = "Actors", multiple = TRUE,
                  properties = list())
  pb <- make_test_pb(list(var))

  df <- data.frame(x = 1:2)
  df$actors <- list(data.frame(a = 1), data.frame(a = 2))

  expect_message(
    result <- pb_as_labelled(df, pb),
    "actors.*skipped"
  )
  # Column unchanged

  expect_identical(result$actors, df$actors)
})

test_that("non-multiple object is also skipped", {
  var <- make_var("detail", "object", label = "Detail",
                  properties = list())
  pb <- make_test_pb(list(var))

  df <- data.frame(x = 1:2)
  df$detail <- list(list(a = 1), list(a = 2))

  expect_message(
    result <- pb_as_labelled(df, pb),
    "detail.*skipped"
  )
})

# -- Step 9: variable labels attached ----------------------------------------

test_that("variable labels are attached to all converted columns", {
  cats <- list(
    list(value = "a", label = "A"),
    list(value = "b", label = "B")
  )
  vars <- list(
    make_var("cat_var", "categorical", label = "A categorical",
             categories = cats),
    make_var("num_var", "numeric", label = "A numeric", integer = TRUE,
             min = 1, max = 5,
             labels = list("1" = "Low", "5" = "High")),
    make_var("bool_var", "boolean", label = "A boolean"),
    make_var("txt_var", "text", label = "A text")
  )
  pb <- make_test_pb(vars)

  df <- data.frame(
    cat_var = factor("a", levels = c("a", "b"), labels = c("A", "B")),
    num_var = 3L,
    bool_var = TRUE,
    txt_var = "hi",
    stringsAsFactors = FALSE
  )

  result <- pb_as_labelled(df, pb)

  expect_equal(attr(result$cat_var, "label"), "A categorical")
  expect_equal(attr(result$num_var, "label"), "A numeric")
  expect_equal(attr(result$bool_var, "label"), "A boolean")
  expect_equal(attr(result$txt_var, "label"), "A text")
})

# -- Step 10: multiple (list-column) → skipped --------------------------------

test_that("categorical with multiple = TRUE is skipped with message", {
  cats <- list(
    list(value = "a", label = "A"),
    list(value = "b", label = "B")
  )
  var <- make_var("topics", "categorical", label = "Topics",
                  multiple = TRUE, categories = cats)
  pb <- make_test_pb(list(var))

  df <- data.frame(x = 1:2)
  df$topics <- list(c("a", "b"), c("a"))

  expect_message(
    result <- pb_as_labelled(df, pb),
    "topics.*skipped"
  )
  expect_identical(result$topics, df$topics)
})

test_that("text with multiple = TRUE is skipped with message", {
  var <- make_var("quotes", "text", label = "Quotes", multiple = TRUE)
  pb <- make_test_pb(list(var))

  df <- data.frame(x = 1:2)
  df$quotes <- list(c("a", "b"), c("c"))

  expect_message(
    result <- pb_as_labelled(df, pb),
    "quotes.*skipped"
  )
})

# -- Input validation ---------------------------------------------------------

test_that("pb_as_labelled() errors on non-data-frame input", {
  pb <- make_test_pb(list(make_var("x", "text")))
  expect_error(pb_as_labelled("not a df", pb), "data frame")
})

test_that("pb_as_labelled() errors on non-promptbook input", {
  df <- data.frame(x = 1)
  expect_error(pb_as_labelled(df, 42), "promptbook")
})

test_that("pb_as_labelled() accepts path string for promptbook", {
  path <- system.file("examples", "media_framing.yaml", package = "promptbook")
  skip_if(path == "", message = "Example YAML not found")

  df <- data.frame(topic = factor("economy", levels = "economy"))
  # Should not error on reading
  expect_no_error(pb_as_labelled(df, path))
})
