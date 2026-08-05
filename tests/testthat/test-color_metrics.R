test_that("lab_chroma calculates standard CIELAB chroma", {
  expect_equal(lab_chroma(a = 3, b = 4), 5)
  expect_equal(lab_chroma(a = c(0, 3, -3), b = c(0, 4, -4)), c(0, 5, 5))
})

test_that("lab_hue identifies all four CIELAB hue quadrants", {
  result <- lab_hue(
    a = c(1, 0, -1, 0),
    b = c(0, 1, 0, -1)
  )

  expect_equal(result, c(0, 90, 180, 270), tolerance = 1e-12)
})

test_that("lab_hue can return radians", {
  expect_equal(
    lab_hue(a = c(1, 0, -1, 0), b = c(0, 1, 0, -1), degrees = FALSE),
    c(0, pi / 2, pi, 3 * pi / 2),
    tolerance = 1e-12
  )
})

test_that("color metrics are vectorized and recycle scalar inputs", {
  expect_equal(lab_chroma(a = c(3, 6), b = 4), c(5, sqrt(52)))
  expect_equal(lab_hue(a = c(1, -1), b = 1), c(45, 135))
})

test_that("color metrics propagate missing values", {
  expect_equal(lab_chroma(a = c(3, NA), b = 4), c(5, NA_real_))
  expect_equal(lab_hue(a = c(1, NA), b = 0), c(0, NA_real_))
})

test_that("lab_hue returns missing values for neutral colors", {
  expect_true(is.na(lab_hue(a = 0, b = 0)))
  expect_equal(lab_chroma(a = 0, b = 0), 0)
})

test_that("color metrics validate their inputs", {
  expect_error(lab_chroma(a = "3", b = 4), "must both be numeric")
  expect_error(lab_hue(a = numeric(), b = 0), "must not be empty")
  expect_error(
    lab_chroma(a = 1:2, b = 1:3),
    "equal lengths or be length one"
  )
  expect_error(lab_hue(a = Inf, b = 0), "finite or missing")
  expect_error(lab_hue(a = 1, b = 0, degrees = NA), "TRUE or FALSE")
})

test_that("add_lab_metrics adds metrics using default columns", {
  measurements <- data.frame(
    treatment = c("Control", "Treatment"),
    a = c(3, 0),
    b = c(4, -1)
  )

  result <- add_lab_metrics(measurements)

  expect_s3_class(result, "data.frame")
  expect_equal(names(result), c("treatment", "a", "b", "chroma", "hue"))
  expect_equal(result$chroma, c(5, 1))
  expect_equal(result$hue, c(atan2(4, 3) * 180 / pi, 270))
})

test_that("add_lab_metrics supports quoted and custom column names", {
  measurements <- data.frame(a_star = c(1, -1), b_star = c(1, 1))

  result <- add_lab_metrics(
    measurements,
    a_col = "a_star",
    b_col = "b_star",
    chroma_col = "c_star",
    hue_col = "h_angle",
    degrees = FALSE
  )

  expect_equal(result$c_star, rep(sqrt(2), 2))
  expect_equal(result$h_angle, c(pi / 4, 3 * pi / 4))
})

test_that("add_lab_metrics works with grouped dplyr data", {
  measurements <- data.frame(
    treatment = c("A", "A", "B"),
    a = c(3, 0, -3),
    b = c(4, 1, -4)
  ) |>
    dplyr::group_by(.data$treatment)

  result <- add_lab_metrics(measurements)

  expect_s3_class(result, "grouped_df")
  expect_equal(result$chroma, c(5, 1, 5))
  expect_equal(dplyr::group_vars(result), "treatment")
})

test_that("add_lab_metrics supports immediate grouped statistics", {
  result <- data.frame(
    treatment = c("A", "A", "B"),
    a = c(3, 0, 0),
    b = c(4, 2, 1)
  ) |>
    add_lab_metrics() |>
    dplyr::group_by(.data$treatment) |>
    dplyr::summarize(mean_chroma = mean(.data$chroma), .groups = "drop")

  expect_equal(result$mean_chroma, c(3.5, 1))
})

test_that("add_lab_metrics validates dataframe columns and output names", {
  measurements <- data.frame(a = 1, b = 1)

  expect_error(add_lab_metrics(list(a = 1, b = 1)), "must be a data frame")
  expect_error(
    add_lab_metrics(measurements, a_col = missing),
    "Missing required columns: missing"
  )
  expect_error(
    add_lab_metrics(measurements, chroma_col = "metric", hue_col = "metric"),
    "must be different names"
  )
  expect_error(
    add_lab_metrics(measurements, chroma_col = "a"),
    "must not overwrite"
  )
})
