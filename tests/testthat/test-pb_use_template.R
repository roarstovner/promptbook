test_that("pb_use_template copies the template to the requested path", {
  dir <- withr::local_tempdir()
  dest <- file.path(dir, "codebook.yaml")

  result <- pb_use_template(dest, open = FALSE)

  expect_equal(result, dest)
  expect_true(file.exists(dest))

  # The copy should be a valid promptbook YAML
  pb <- read_promptbook(dest)
  expect_s3_class(pb, "promptbook")
})

test_that("pb_use_template refuses to overwrite by default", {
  dir <- withr::local_tempdir()
  dest <- file.path(dir, "codebook.yaml")
  writeLines("existing content", dest)

  expect_error(
    pb_use_template(dest, open = FALSE),
    "already exists"
  )

  # Original content is untouched
  expect_equal(readLines(dest), "existing content")
})

test_that("pb_use_template overwrites when overwrite = TRUE", {
  dir <- withr::local_tempdir()
  dest <- file.path(dir, "codebook.yaml")
  writeLines("existing content", dest)

  pb_use_template(dest, overwrite = TRUE, open = FALSE)

  # File now contains the template, not the original
  expect_false(any(readLines(dest) == "existing content"))
  expect_s3_class(read_promptbook(dest), "promptbook")
})

test_that("pb_use_template creates missing parent directories", {
  dir <- withr::local_tempdir()
  dest <- file.path(dir, "subdir", "nested", "codebook.yaml")

  pb_use_template(dest, open = FALSE)

  expect_true(file.exists(dest))
})

test_that("pb_use_template validates its arguments", {
  expect_error(pb_use_template(c("a", "b"), open = FALSE), "single non-empty")
  expect_error(pb_use_template("", open = FALSE), "single non-empty")
  expect_error(pb_use_template(NA_character_, open = FALSE), "single non-empty")
  expect_error(pb_use_template("x.yaml", overwrite = NA, open = FALSE), "overwrite")
  expect_error(pb_use_template("x.yaml", open = NA), "open")
})
