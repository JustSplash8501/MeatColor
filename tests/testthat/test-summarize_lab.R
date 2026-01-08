# Test data
test_data <- data.frame(
  product = rep(c("A", "B"), each = 6),
  treatment = rep(c("Control", "Treated"), each = 3, times = 2),
  time_point = rep(1:3, times = 4),
  l = c(45, 47, 46, 50, 52, 51, 44, 46, 45, 49, 51, 50),
  a = c(15, 16, 15.5, 14, 15, 14.5, 16, 17, 16.5, 15, 16, 15.5),
  b = c(10, 11, 10.5, 9, 10, 9.5, 11, 12, 11.5, 10, 11, 10.5)
)

test_that("summarize_lab works with basic input", {
  result <- summarize_lab(test_data, group_vars = c("product", "treatment"))

  expect_s3_class(result, "data.frame")
  expect_true("l_mean" %in% names(result))
  expect_true("a_mean" %in% names(result))
  expect_true("b_mean" %in% names(result))
  expect_true("color" %in% names(result))
  expect_equal(nrow(result), 4) # 2 products × 2 treatments
})

test_that("summarize_lab handles single grouping variable", {
  result <- summarize_lab(test_data, group_vars = "product")

  expect_equal(nrow(result), 2)
  expect_true(all(
    c("product", "l_mean", "a_mean", "b_mean", "color") %in% names(result)
  ))
})

test_that("summarize_lab handles multiple grouping variables", {
  result <- summarize_lab(
    test_data,
    group_vars = c("product", "treatment", "time_point")
  )

  expect_equal(nrow(result), 12) # 2 × 2 × 3
})

test_that("summarize_lab handles NA values correctly", {
  test_data_na <- test_data
  test_data_na$l[1] <- NA
  test_data_na$a[2] <- NA

  result <- summarize_lab(test_data_na, group_vars = "product")

  expect_false(any(is.na(result$l_mean)))
  expect_false(any(is.na(result$a_mean)))
  expect_false(any(is.na(result$b_mean)))
})

test_that("summarize_lab works with custom column names", {
  test_data_custom <- test_data
  names(test_data_custom)[names(test_data_custom) == "l"] <- "L_star"
  names(test_data_custom)[names(test_data_custom) == "a"] <- "a_star"
  names(test_data_custom)[names(test_data_custom) == "b"] <- "b_star"

  result <- summarize_lab(
    test_data_custom,
    group_vars = "product",
    l_col = "L_star",
    a_col = "a_star",
    b_col = "b_star"
  )

  expect_true("color" %in% names(result))
})

test_that("summarize_lab returns valid hex colors", {
  result <- summarize_lab(test_data, group_vars = "product")

  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", result$color)))
})

test_that("summarize_lab errors with missing columns", {
  bad_data <- test_data[, c("product", "treatment")]

  expect_error(summarize_lab(bad_data, group_vars = "product"))
})
