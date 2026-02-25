# -- pb_build_prompts ---------------------------------------------------------

test_that("single {text} placeholder interpolated with column values", {
  template <- "Code this: {text}"
  data <- data.frame(text = c("article one", "article two"),
                     stringsAsFactors = FALSE)
  text_cols <- c(text = 1L)
  result <- pb_build_prompts(template, data, text_cols)
  expect_equal(result, c("Code this: article one", "Code this: article two"))
})

test_that("multiple placeholders interpolated correctly", {
  template <- "Title: {title}\n\nAbstract: {abstract}"
  data <- data.frame(title = c("T1", "T2"), abstract = c("A1", "A2"),
                     stringsAsFactors = FALSE)
  text_cols <- c(title = 1L, abstract = 2L)
  result <- pb_build_prompts(template, data, text_cols)
  expect_equal(result[1], "Title: T1\n\nAbstract: A1")
  expect_equal(result[2], "Title: T2\n\nAbstract: A2")
})

test_that("error when placeholder not found in text columns", {
  template <- "Code: {missing_col}"
  data <- data.frame(text = "hi", stringsAsFactors = FALSE)
  text_cols <- c(text = 1L)
  expect_error(
    pb_build_prompts(template, data, text_cols),
    "missing_col"
  )
})

test_that("NULL user template defaults to {text}", {
  data <- data.frame(text = c("hello", "world"), stringsAsFactors = FALSE)
  text_cols <- c(text = 1L)
  result <- pb_build_prompts(NULL, data, text_cols)
  expect_equal(result, c("hello", "world"))
})

# -- pb_resolve_text_cols -----------------------------------------------------

test_that("bare column name resolved via tidyselect", {
  data <- data.frame(text = "hi", other = 1, stringsAsFactors = FALSE)
  quo <- rlang::quo(text)
  result <- pb_resolve_text_cols(data, quo)
  expect_equal(result, c(text = 1L))
})

test_that("multiple columns via c()", {
  data <- data.frame(title = "T", abstract = "A", x = 1,
                     stringsAsFactors = FALSE)
  quo <- rlang::quo(c(title, abstract))
  result <- pb_resolve_text_cols(data, quo)
  expect_equal(result, c(title = 1L, abstract = 2L))
})

test_that("error on non-existent column", {
  data <- data.frame(text = "hi", stringsAsFactors = FALSE)
  quo <- rlang::quo(nonexistent)
  expect_error(pb_resolve_text_cols(data, quo))
})

# -- pb_dispatch (mock-based) -------------------------------------------------

test_that("method='parallel' calls parallel_chat_structured", {
  called <- FALSE
  local_mocked_bindings(
    parallel_chat_structured = function(chat, prompts, ...) {
      called <<- TRUE
      data.frame(x = 1)
    },
    .package = "ellmer"
  )
  mock_chat <- structure(list(), class = "Chat")
  mock_type <- structure(list(), class = "ellmer::TypeObject")
  result <- pb_dispatch(mock_chat, "prompt", mock_type, "parallel")
  expect_true(called)
})

test_that("method='batch' calls batch_chat_structured", {
  called <- FALSE
  local_mocked_bindings(
    batch_chat_structured = function(chat, prompts, ...) {
      called <<- TRUE
      data.frame(x = 1)
    },
    .package = "ellmer"
  )
  mock_chat <- structure(list(), class = "Chat")
  mock_type <- structure(list(), class = "ellmer::TypeObject")
  result <- pb_dispatch(mock_chat, "prompt", mock_type, "batch")
  expect_true(called)
})

test_that("method='sequential' calls chat$chat_structured per row", {
  call_count <- 0
  mock_chat <- list(
    clone = function(deep = FALSE) {
      list(chat_structured = function(...) {
        call_count <<- call_count + 1
        list(x = call_count)
      })
    }
  )
  class(mock_chat) <- "Chat"
  mock_type <- structure(list(), class = "ellmer::TypeObject")
  result <- pb_dispatch(mock_chat, c("p1", "p2", "p3"), mock_type, "sequential")
  expect_equal(call_count, 3)
})

test_that("invalid method errors", {
  mock_chat <- structure(list(), class = "Chat")
  mock_type <- structure(list(), class = "ellmer::TypeObject")
  expect_error(
    pb_dispatch(mock_chat, "prompt", mock_type, "invalid"),
    "invalid"
  )
})

# -- pb_annotate() orchestrator -----------------------------------------------

test_that("pb_annotate accepts path string for promptbook", {
  path <- test_path("fixtures", "media_framing.yaml")
  data <- data.frame(text = "test article", stringsAsFactors = FALSE)

  make_mock <- function() {
    obj <- list(
      clone = function(deep = FALSE) {
        c <- list(set_system_prompt = function(value) NULL)
        class(c) <- "Chat"
        c
      },
      set_system_prompt = function(value) NULL
    )
    class(obj) <- "Chat"
    obj
  }

  # Mock pb_dispatch to avoid actual LLM calls
  local_mocked_bindings(
    pb_dispatch = function(chat, prompts, type, method, ...) {
      # Return a 1-row data frame with the right column names
      prop_names <- names(type@properties)
      row <- stats::setNames(
        as.list(rep(NA, length(prop_names))),
        prop_names
      )
      as.data.frame(row, stringsAsFactors = FALSE)
    }
  )

  result <- suppressWarnings(
    pb_annotate(data, path, chat = list(fast = make_mock(), strong = make_mock()))
  )
  expect_s3_class(result, "tbl_df")
  # Should have original column + annotation columns

  expect_true("text" %in% names(result))
  expect_true("topic" %in% names(result))
})

test_that("pb_annotate errors on non-promptbook, non-path input", {
  data <- data.frame(text = "hi", stringsAsFactors = FALSE)
  expect_error(
    pb_annotate(data, 42, chat = NULL),
    "promptbook"
  )
})
