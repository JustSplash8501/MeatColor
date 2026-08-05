reflectance_from_ks <- function(ks) {
  1 + ks - sqrt(ks * (ks + 2))
}

make_ks_scan <- function(ratio_474, ratio_572, ratio_610, scale = "proportion") {
  values <- c(
    r474 = reflectance_from_ks(ratio_474),
    r525 = reflectance_from_ks(1),
    r572 = reflectance_from_ks(ratio_572),
    r610 = reflectance_from_ks(ratio_610)
  )
  if (scale == "percent") {
    values <- values * 100
  }

  data.frame(
    R470 = values[["r474"]],
    R480 = values[["r474"]],
    R520 = values[["r525"]],
    R530 = values[["r525"]],
    R570 = values[["r572"]],
    R580 = values[["r572"]],
    R610 = values[["r610"]]
  )
}

make_ks_references <- function(scale = "proportion") {
  list(
    omb = make_ks_scan(0.8, 0.5, 0.2, scale),
    dmb = make_ks_scan(0.3, 0.9, 0.5, scale),
    mmb = make_ks_scan(0.5, 0.2, 0.8, scale)
  )
}

test_that("myoglobin calibrations are reusable S3 objects", {
  references <- make_ks_references()
  calibration <- myoglobin_calibration(
    references$omb,
    references$dmb,
    references$mmb,
    reflectance_scale = "proportion"
  )

  expect_s3_class(calibration, "myoglobin_calibration")
  expect_equal(calibration$reflectance_scale, "proportion")
  expect_equal(names(calibration$reference_spectra), c("OMb", "DMb", "MMb"))
  expect_equal(
    myoglobin_calibration_ratios(calibration)$ratio_610_525,
    c(0.2, 0.5, 0.8),
    tolerance = 1e-10
  )
  expect_output(print(calibration), "<myoglobin_calibration>", fixed = TRUE)
})

test_that("predict applies a calibration without separate references", {
  references <- make_ks_references()
  calibration <- myoglobin_calibration(
    references$omb,
    references$dmb,
    references$mmb,
    reflectance_scale = "proportion"
  )
  sample <- make_ks_scan(0.675, 0.655, 0.56)
  sample$sample <- "A"

  result <- predict(calibration, newdata = sample, keep_intermediates = TRUE)

  expect_equal(result$omb_pct, 40, tolerance = 1e-10)
  expect_equal(result$dmb_pct, 25, tolerance = 1e-10)
  expect_equal(result$mmb_pct, 35, tolerance = 1e-10)
  expect_equal(result$sample, "A")
  expect_true("mb_ratio_610_525" %in% names(result))
  expect_equal(
    attr(result, "myoglobin_reference_ratios"),
    myoglobin_calibration_ratios(calibration)
  )
})

test_that("calibration plots are customizable ggplot objects", {
  references <- make_ks_references()
  references <- lapply(references, function(reference) rbind(reference, reference))
  calibration <- myoglobin_calibration(
    references$omb,
    references$dmb,
    references$mmb,
    reflectance_scale = "proportion"
  )

  diagnostic <- plot(calibration)
  expect_s3_class(diagnostic, "ggplot")
  expect_equal(nrow(diagnostic$data), 9)
  expect_length(diagnostic$layers, 2)
  expect_s3_class(plot(calibration, show_replicates = FALSE), "ggplot")
})

test_that("myoglobin_ref reproduces calibrated K/S equations", {
  references <- make_ks_references()
  sample <- make_ks_scan(0.675, 0.655, 0.56)
  sample$sample <- "A"

  result <- myoglobin_ref(
    sample,
    omb_reference = references$omb,
    dmb_reference = references$dmb,
    mmb_reference = references$mmb,
    reflectance_scale = "proportion"
  )

  expect_equal(result$omb_pct, 40, tolerance = 1e-10)
  expect_equal(result$dmb_pct, 25, tolerance = 1e-10)
  expect_equal(result$mmb_pct, 35, tolerance = 1e-10)
  expect_equal(result$myoglobin_sum_pct, 100, tolerance = 1e-10)
  expect_true(result$myoglobin_valid)
  expect_equal(result$sample, "A")
})

test_that("percent and proportion K/S workflows are equivalent", {
  proportion_refs <- make_ks_references("proportion")
  percent_refs <- make_ks_references("percent")

  proportion_result <- myoglobin_ref(
    make_ks_scan(0.675, 0.655, 0.56, "proportion"),
    proportion_refs$omb,
    proportion_refs$dmb,
    proportion_refs$mmb,
    reflectance_scale = "proportion"
  )
  percent_result <- myoglobin_ref(
    make_ks_scan(0.675, 0.655, 0.56, "percent"),
    percent_refs$omb,
    percent_refs$dmb,
    percent_refs$mmb,
    reflectance_scale = "percent"
  )

  expect_equal(percent_result$omb_pct, proportion_result$omb_pct)
  expect_equal(percent_result$dmb_pct, proportion_result$dmb_pct)
  expect_equal(percent_result$mmb_pct, proportion_result$mmb_pct)
})

test_that("myoglobin_ref interpolates reflectance before K/S conversion", {
  references <- make_ks_references()
  sample <- data.frame(
    R470 = 0.40, R480 = 0.50,
    R520 = 0.50, R530 = 0.60,
    R570 = 0.60, R580 = 0.70,
    R610 = 0.80
  )

  result <- myoglobin_ref(
    sample,
    references$omb,
    references$dmb,
    references$mmb,
    reflectance_scale = "proportion",
    bounds = "none",
    keep_intermediates = TRUE
  )

  expect_equal(result$mb_r474, 0.44)
  expect_equal(result$mb_r525, 0.55)
  expect_equal(result$mb_r572, 0.62)
  expect_equal(result$mb_r610, 0.80)
  expect_equal(result$mb_ks474, (1 - 0.44)^2 / (2 * 0.44))
  expect_equal(result$mb_ks525, (1 - 0.55)^2 / (2 * 0.55))
  expect_equal(
    result$mb_ratio_474_525,
    result$mb_ks474 / result$mb_ks525
  )
})

test_that("replicate references are summarized and reported", {
  references <- make_ks_references()
  references <- lapply(references, function(x) rbind(x, x))

  result <- myoglobin_ref(
    make_ks_scan(0.675, 0.655, 0.56),
    references$omb,
    references$dmb,
    references$mmb,
    reflectance_scale = "proportion",
    reference_summary = "median"
  )

  calibration <- attr(result, "myoglobin_reference_ratios")
  expect_equal(calibration$form, c("OMb", "DMb", "MMb"))
  expect_equal(calibration$summary, rep("median", 3))
  expect_equal(calibration$ratio_610_525, c(0.2, 0.5, 0.8), tolerance = 1e-10)
})

test_that("incomplete reference replicates are excluded with a warning", {
  references <- make_ks_references()
  references$omb <- rbind(references$omb, references$omb)
  references$omb$R470[[2]] <- NA_real_

  expect_warning(
    result <- myoglobin_ref(
      make_ks_scan(0.675, 0.655, 0.56),
      references$omb,
      references$dmb,
      references$mmb,
      reflectance_scale = "proportion"
    ),
    "excluded from the OMb reference"
  )
  expect_equal(result$omb_pct, 40, tolerance = 1e-10)
})

test_that("missing sample reflectance produces missing rowwise estimates", {
  references <- make_ks_references()
  sample <- make_ks_scan(0.675, 0.655, 0.56)
  sample <- rbind(sample, sample)
  sample$R470[[2]] <- NA_real_

  result <- myoglobin_ref(
    sample,
    references$omb,
    references$dmb,
    references$mmb,
    reflectance_scale = "proportion",
    bounds = "none"
  )

  expect_false(is.na(result$omb_pct[[1]]))
  expect_true(is.na(result$omb_pct[[2]]))
  expect_true(is.na(result$myoglobin_valid[[2]]))
})

test_that("undefined sample ratios and unusable references are diagnosed", {
  references <- make_ks_references()
  sample <- make_ks_scan(0.675, 0.655, 0.56)
  sample$R520 <- 1
  sample$R530 <- 1

  expect_warning(
    result <- myoglobin_ref(
      sample,
      references$omb,
      references$dmb,
      references$mmb,
      reflectance_scale = "proportion",
      bounds = "none"
    ),
    "K/S525"
  )
  expect_true(is.na(result$omb_pct))
  expect_false(result$myoglobin_valid)

  expect_error(
    myoglobin_ref(
      make_ks_scan(0.675, 0.655, 0.56),
      references$omb,
      references$dmb,
      references$dmb,
      reflectance_scale = "proportion"
    ),
    "do not distinguish"
  )
})

test_that("myoglobin_ref validates data and reference inputs", {
  references <- make_ks_references()
  sample <- make_ks_scan(0.675, 0.655, 0.56)

  expect_error(
    myoglobin_ref(1:7, references$omb, references$dmb, references$mmb),
    "`data` must be a data frame"
  )
  expect_error(
    myoglobin_ref(sample, numeric(), references$dmb, references$mmb),
    "`omb_reference` must be a data frame"
  )
  expect_error(
    myoglobin_ref(sample[-1], references$omb, references$dmb, references$mmb),
    "missing required reflectance columns"
  )

  nonpositive <- sample
  nonpositive$R470 <- 0
  expect_error(
    myoglobin_ref(nonpositive, references$omb, references$dmb, references$mmb),
    "greater than zero"
  )

  above_proportion <- sample
  above_proportion$R470 <- 1.01
  expect_error(
    myoglobin_ref(
      above_proportion,
      references$omb,
      references$dmb,
      references$mmb,
      reflectance_scale = "proportion"
    ),
    "must not exceed 1"
  )

  percent_references <- make_ks_references("percent")
  invalid_reference <- percent_references$omb
  invalid_reference$R470 <- 100.01
  expect_error(
    myoglobin_ref(
      make_ks_scan(0.675, 0.655, 0.56, "percent"),
      invalid_reference,
      percent_references$dmb,
      percent_references$mmb,
      reflectance_scale = "percent"
    ),
    "in `omb_reference` must not exceed 100"
  )

  expect_error(
    myoglobin_ref(
      sample,
      references$omb,
      references$dmb,
      references$mmb,
      reference_summary = "mode"
    ),
    "arg"
  )
})
