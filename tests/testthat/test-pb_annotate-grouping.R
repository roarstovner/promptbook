# Helper: read fixtures
read_media <- function() {
  suppressWarnings(
    read_promptbook(test_path("fixtures", "media_framing.yaml"))
  )
}

read_ungrouped <- function() {
  read_promptbook(test_path("fixtures", "ungrouped.yaml"))
}

read_override <- function() {
  suppressWarnings(
    read_promptbook(test_path("fixtures", "model_override.yaml"))
  )
}

# -- pb_execution_plan() -----------------------------------------------------

test_that("media_framing produces two execution steps", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)
  expect_length(plan, 2)
})

test_that("each step has group, model, variables, type fields", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)
  for (step in plan) {
    expect_named(step, c("group", "model", "variables", "type"),
                 ignore.order = TRUE)
  }
})

test_that("basic group gets 4 variables with model fast", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)
  basic <- Filter(function(s) s$group == "basic", plan)
  expect_length(basic, 1)
  basic <- basic[[1]]
  expect_equal(basic$model, "fast")
  expect_setequal(basic$variables, c("topic", "sentiment", "topics_all", "has_data"))
})

test_that("framing group gets 4 variables with model strong", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)

  framing <- Filter(function(s) s$group == "framing", plan)
  expect_length(framing, 1)
  framing <- framing[[1]]
  expect_equal(framing$model, "strong")
  expect_setequal(framing$variables, c("frame", "source_diversity", "key_quote", "actors"))
})

test_that("type objects have properties matching step variable names", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)
  for (step in plan) {
    prop_names <- names(step$type@properties)
    expect_setequal(prop_names, step$variables)
  }
})

test_that("ungrouped variables go to .default group with NULL model", {
  pb <- read_ungrouped()
  plan <- pb_execution_plan(pb)
  expect_length(plan, 1)
  step <- plan[[1]]
  expect_equal(step$group, ".default")
  expect_null(step$model)
  expect_setequal(step$variables, c("topic", "sentiment"))
})

test_that("per-variable model override splits group into separate steps", {
  pb <- read_override()
  plan <- pb_execution_plan(pb)
  # sentiment has model: strong, overriding group model: fast

  # So basic group splits into fast step and strong step
  expect_length(plan, 2)

  fast_step <- Filter(function(s) identical(s$model, "fast"), plan)
  expect_length(fast_step, 1)
  expect_setequal(fast_step[[1]]$variables, c("topic", "frame"))

  strong_step <- Filter(function(s) identical(s$model, "strong"), plan)
  expect_length(strong_step, 1)
  expect_equal(strong_step[[1]]$variables, "sentiment")
})

# -- pb_resolve_chat() -------------------------------------------------------

test_that("single Chat errors when models are needed", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)
  # Create a mock Chat-like object
  mock_chat <- structure(list(), class = "Chat")
  expect_error(
    pb_resolve_chat(mock_chat, plan, "system prompt"),
    "fast.*strong|strong.*fast"
  )
})

test_that("named list errors on missing model", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)
  mock_fast <- structure(list(), class = "Chat")
  expect_error(
    pb_resolve_chat(list(fast = mock_fast), plan, "system prompt"),
    "strong"
  )
})

test_that("single Chat works when no models needed", {
  pb <- read_ungrouped()
  plan <- pb_execution_plan(pb)
  # Create a real-ish mock with clone and set_system_prompt
  mock_chat <- list(
    clone = function(deep = FALSE) {
      list(
        set_system_prompt = function(value) NULL,
        clone = function(deep = FALSE) NULL
      )
    },
    set_system_prompt = function(value) NULL
  )
  class(mock_chat) <- "Chat"

  result <- pb_resolve_chat(mock_chat, plan, "system prompt")
  expect_length(result, 1)
})

test_that("named list matches models to steps", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)

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

  chats <- list(fast = make_mock(), strong = make_mock())
  result <- pb_resolve_chat(chats, plan, "system prompt")
  expect_length(result, 2)
})
