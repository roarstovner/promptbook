# Helper: read the fixture once, suppressing expected validation warnings
read_fixture <- function() {
  suppressWarnings(
    read_promptbook(test_path("fixtures", "media_framing.yaml"))
  )
}

# -- Input validation ---------------------------------------------------------

test_that("pb_type() errors on non-promptbook input", {
  expect_error(pb_type(list()), "promptbook")
})

test_that("pb_type() errors when variables and group both specified", {
  pb <- read_fixture()
  expect_error(
    pb_type(pb, variables = "topic", group = "basic"),
    "cannot both be specified"
  )
})

test_that("pb_type() errors on unknown variable names", {
  pb <- read_fixture()
  expect_error(pb_type(pb, variables = "nonexistent"), "Unknown variable")
})

test_that("pb_type() errors on unknown group", {
  pb <- read_fixture()
  expect_error(pb_type(pb, group = "nonexistent"), "No variables found")
})

# -- Basic output structure ---------------------------------------------------

test_that("pb_type() returns a TypeObject for all variables", {
  pb <- read_fixture()
  type <- pb_type(pb)
  expect_s3_class(type, "ellmer::TypeObject")
})

test_that("pb_type() filters by group", {
  pb <- read_fixture()
  type_basic <- pb_type(pb, group = "basic")
  props <- names(type_basic@properties)
  expect_setequal(props, c("topic", "sentiment", "topics_all", "has_data"))
})

test_that("pb_type() filters by variable names", {
  pb <- read_fixture()
  type_sub <- pb_type(pb, variables = c("topic", "sentiment"))
  props <- names(type_sub@properties)
  expect_setequal(props, c("topic", "sentiment"))
})

# -- Categorical type ---------------------------------------------------------

test_that("categorical variable maps to TypeEnum", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = "topic")
  topic <- type@properties$topic
  expect_s3_class(topic, "ellmer::TypeEnum")
  expect_true("economy" %in% topic@values)
  expect_true("politics" %in% topic@values)
})

test_that("categorical description includes category info", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = "topic")
  desc <- type@properties$topic@description
  expect_match(desc, "Categories:")
  expect_match(desc, "economy = Economic impacts")
})

# -- Numeric type -------------------------------------------------------------

test_that("numeric variable maps to TypeBasic integer", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = "sentiment")
  sentiment <- type@properties$sentiment
  expect_s3_class(sentiment, "ellmer::TypeBasic")
})

test_that("numeric description includes scale info with labels", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = "sentiment")
  desc <- type@properties$sentiment@description
  expect_match(desc, "Scale:")
  expect_match(desc, "1 \\(Very negative\\)")
  expect_match(desc, "5 \\(Very positive\\)")
})

test_that("numeric without labels gets range description", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = "source_diversity")
  desc <- type@properties$source_diversity@description
  expect_match(desc, "Range:")
  expect_match(desc, "0 to 10")
})

# -- Boolean type -------------------------------------------------------------

test_that("boolean variable maps to TypeBasic", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = "has_data")
  has_data <- type@properties$has_data
  expect_s3_class(has_data, "ellmer::TypeBasic")
})

# -- Text type ----------------------------------------------------------------

test_that("text variable maps to TypeBasic string", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = "key_quote")
  key_quote <- type@properties$key_quote
  expect_s3_class(key_quote, "ellmer::TypeBasic")
})

# -- multiple: true -----------------------------------------------------------

test_that("categorical with multiple:true maps to TypeArray of TypeEnum", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = "topics_all")
  topics <- type@properties$topics_all
  expect_s3_class(topics, "ellmer::TypeArray")
  expect_s3_class(topics@items, "ellmer::TypeEnum")
})

# -- Object type --------------------------------------------------------------

test_that("object with multiple:true maps to TypeArray of TypeObject", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = "actors")
  actors <- type@properties$actors
  expect_s3_class(actors, "ellmer::TypeArray")
  expect_s3_class(actors@items, "ellmer::TypeObject")
  expect_true("actor_name" %in% names(actors@items@properties))
  expect_true("actor_type" %in% names(actors@items@properties))
  expect_true("stance" %in% names(actors@items@properties))
})

test_that("object properties have correct types", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = "actors")
  actor_props <- type@properties$actors@items@properties

  # actor_name is text -> TypeBasic (string)
  expect_s3_class(actor_props$actor_name, "ellmer::TypeBasic")
  # actor_type is categorical -> TypeEnum
  expect_s3_class(actor_props$actor_type, "ellmer::TypeEnum")
  # stance is categorical -> TypeEnum
  expect_s3_class(actor_props$stance, "ellmer::TypeEnum")
})

# -- Required -----------------------------------------------------------------

test_that("required defaults propagate correctly", {
  pb <- read_fixture()
  type <- pb_type(pb, variables = c("topic", "key_quote"))

  # Both default to required = FALSE
  expect_false(type@properties$topic@required)
  expect_false(type@properties$key_quote@required)
})
