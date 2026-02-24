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

test_that("basic group gets 4 variables with model haiku", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)
  basic <- Filter(function(s) s$group == "basic", plan)
  expect_length(basic, 1)
  basic <- basic[[1]]
  expect_equal(basic$model, "haiku")
  expect_setequal(basic$variables, c("topic", "sentiment", "topics_all", "has_data"))
})

test_that("framing group gets 4 variables with model sonnet", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)

  framing <- Filter(function(s) s$group == "framing", plan)
  expect_length(framing, 1)
  framing <- framing[[1]]
  expect_equal(framing$model, "sonnet")
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
  # sentiment has model: sonnet, overriding group model: haiku

  # So basic group splits into haiku step and sonnet step
  expect_length(plan, 2)

  haiku_step <- Filter(function(s) identical(s$model, "haiku"), plan)
  expect_length(haiku_step, 1)
  expect_setequal(haiku_step[[1]]$variables, c("topic", "frame"))

  sonnet_step <- Filter(function(s) identical(s$model, "sonnet"), plan)
  expect_length(sonnet_step, 1)
  expect_equal(sonnet_step[[1]]$variables, "sentiment")
})

# -- pb_resolve_chat() -------------------------------------------------------

test_that("single Chat errors when models are needed", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)
  # Create a mock Chat-like object
  mock_chat <- structure(list(), class = "Chat")
  expect_error(
    pb_resolve_chat(mock_chat, plan, "system prompt"),
    "haiku.*sonnet|sonnet.*haiku"
  )
})

test_that("named list errors on missing model", {
  pb <- read_media()
  plan <- pb_execution_plan(pb)
  mock_haiku <- structure(list(), class = "Chat")
  expect_error(
    pb_resolve_chat(list(haiku = mock_haiku), plan, "system prompt"),
    "sonnet"
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

  chats <- list(haiku = make_mock(), sonnet = make_mock())
  result <- pb_resolve_chat(chats, plan, "system prompt")
  expect_length(result, 2)
})
