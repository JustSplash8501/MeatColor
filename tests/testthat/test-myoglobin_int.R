make_myoglobin_scan <- function(scale = c("proportion", "percent")) {
  scale <- match.arg(scale)
  a700 <- 0.1
  denominator <- 0.2
  reflectance <- c(
    r473 = 10^-(a700 + (1 - 30 / 237.5) * denominator),
    r525 = 10^-(a700 + denominator),
    r572 = 10^-(a700 + (1.395 - 20 / 100) * denominator),
    r700 = 10^-a700
  )
  if (scale == "percent") {
    reflectance <- reflectance * 100
  }

  data.frame(
    sample = "A",
    R470 = reflectance[["r473"]],
    R480 = reflectance[["r473"]],
    R520 = reflectance[["r525"]],
    R530 = reflectance[["r525"]],
    R570 = reflectance[["r572"]],
    R580 = reflectance[["r572"]],
    R700 = reflectance[["r700"]]
  )
}

test_that("myoglobin_int reproduces selected-wavelength AMSA equations", {
  result <- myoglobin_int(
    make_myoglobin_scan("proportion"),
    reflectance_scale = "proportion"
  )

  expect_equal(result$omb_pct, 50, tolerance = 1e-10)
  expect_equal(result$dmb_pct, 30, tolerance = 1e-10)
  expect_equal(result$mmb_pct, 20, tolerance = 1e-10)
  expect_equal(result$myoglobin_sum_pct, 100, tolerance = 1e-10)
  expect_true(result$myoglobin_valid)
  expect_equal(result$sample, "A")
})

test_that("percent and proportion reflectance inputs are equivalent", {
  proportions <- myoglobin_int(
    make_myoglobin_scan("proportion"),
    reflectance_scale = "proportion"
  )
  percentages <- myoglobin_int(
    make_myoglobin_scan("percent"),
    reflectance_scale = "percent"
  )

  output_cols <- c("omb_pct", "dmb_pct", "mmb_pct")
  expect_equal(percentages[output_cols], proportions[output_cols])
})

test_that("myoglobin_int interpolates MiniScan wavelengths before attenuation", {
  scan <- data.frame(
    R470 = 0.40, R480 = 0.50,
    R520 = 0.50, R530 = 0.60,
    R570 = 0.60, R580 = 0.70,
    R700 = 0.80
  )

  result <- myoglobin_int(
    scan,
    reflectance_scale = "proportion",
    bounds = "none",
    keep_intermediates = TRUE
  )

  expect_equal(result$mb_r473, 0.43)
  expect_equal(result$mb_r525, 0.55)
  expect_equal(result$mb_r572, 0.62)
  expect_equal(result$mb_r700, 0.80)
  expect_equal(result$mb_a473, log10(1 / 0.43))
  expect_equal(result$mb_a525, log10(1 / 0.55))
  expect_equal(result$mb_a572, log10(1 / 0.62))
  expect_equal(result$mb_a700, log10(1 / 0.80))
})

test_that("myoglobin_int supports custom reflectance column names", {
  scan <- make_myoglobin_scan("proportion")
  names(scan)[2:8] <- paste0("nm_", c(470, 480, 520, 530, 570, 580, 700))

  result <- myoglobin_int(
    scan,
    r470_col = "nm_470",
    r480_col = "nm_480",
    r520_col = "nm_520",
    r530_col = "nm_530",
    r570_col = "nm_570",
    r580_col = "nm_580",
    r700_col = "nm_700",
    reflectance_scale = "proportion"
  )

  expect_equal(result$omb_pct, 50, tolerance = 1e-10)
})

test_that("missing reflectance produces missing rowwise estimates", {
  scan <- make_myoglobin_scan("proportion")
  scan <- rbind(scan, scan)
  scan$sample <- c("complete", "missing")
  scan$R470[[2]] <- NA_real_

  result <- myoglobin_int(
    scan,
    reflectance_scale = "proportion",
    bounds = "none"
  )

  expect_false(is.na(result$omb_pct[[1]]))
  expect_true(is.na(result$omb_pct[[2]]))
  expect_true(is.na(result$myoglobin_valid[[2]]))
})

test_that("undefined denominators are diagnosed and returned as missing", {
  scan <- data.frame(
    R470 = 0.5, R480 = 0.5,
    R520 = 0.5, R530 = 0.5,
    R570 = 0.5, R580 = 0.5,
    R700 = 0.5
  )

  expect_warning(
    result <- myoglobin_int(
      scan,
      reflectance_scale = "proportion",
      bounds = "none"
    ),
    "A525 - A700"
  )
  expect_true(is.na(result$omb_pct))
  expect_false(result$myoglobin_valid)
})

test_that("out-of-range estimates can be retained, warned about, or clamped", {
  scan <- data.frame(
    R470 = 0.40, R480 = 0.50,
    R520 = 0.50, R530 = 0.60,
    R570 = 0.60, R580 = 0.70,
    R700 = 0.80
  )

  expect_warning(
    warned <- myoglobin_int(scan, reflectance_scale = "proportion"),
    "outside 0 to 100"
  )
  retained <- myoglobin_int(
    scan,
    reflectance_scale = "proportion",
    bounds = "none"
  )
  clamped <- myoglobin_int(
    scan,
    reflectance_scale = "proportion",
    bounds = "clamp"
  )

  expect_equal(warned[c("omb_pct", "dmb_pct", "mmb_pct")],
               retained[c("omb_pct", "dmb_pct", "mmb_pct")])
  expect_true(any(unlist(retained[c("omb_pct", "dmb_pct", "mmb_pct")]) < 0 |
                  unlist(retained[c("omb_pct", "dmb_pct", "mmb_pct")]) > 100))
  expect_true(all(unlist(clamped[c("omb_pct", "dmb_pct", "mmb_pct")]) >= 0))
  expect_true(all(unlist(clamped[c("omb_pct", "dmb_pct", "mmb_pct")]) <= 100))
  expect_false(clamped$myoglobin_valid)
})

test_that("myoglobin_int validates its inputs", {
  scan <- make_myoglobin_scan("proportion")

  expect_error(myoglobin_int(1:7), "must be a data frame")
  expect_error(myoglobin_int(scan[-2]), "Missing required reflectance columns")

  nonnumeric <- scan
  nonnumeric$R470 <- "0.5"
  expect_error(myoglobin_int(nonnumeric), "must be numeric")

  nonpositive <- scan
  nonpositive$R470 <- 0
  expect_error(myoglobin_int(nonpositive), "greater than zero")

  infinite <- scan
  infinite$R470 <- Inf
  expect_error(myoglobin_int(infinite), "finite or missing")

  above_proportion <- scan
  above_proportion$R470 <- 1.01
  expect_error(
    myoglobin_int(above_proportion, reflectance_scale = "proportion"),
    "must not exceed 1"
  )

  above_percent <- make_myoglobin_scan("percent")
  above_percent$R470 <- 100.01
  expect_error(
    myoglobin_int(above_percent, reflectance_scale = "percent"),
    "must not exceed 100"
  )

  expect_error(myoglobin_int(scan, keep_intermediates = NA), "TRUE or FALSE")
  expect_error(myoglobin_int(scan, reflectance_scale = "unknown"), "arg")
  expect_error(myoglobin_int(scan, bounds = "unknown"), "arg")
})
