test_samples <- data.frame(
  sample = paste0("S", 1:4),
  treatment = rep(c("control", "treated"), each = 2),
  lightness = c(45, 46, 50, 51),
  redness = c(15, 14, 11, 10),
  yellowness = c(10, 11, 8, 9)
)

test_that("lab_distances compares all samples and preserves identifiers", {
  result <- lab_distances(
    test_samples,
    sample_id = sample,
    l_col = lightness,
    a_col = redness,
    b_col = yellowness
  )

  expect_s3_class(result, "meatcolor_distances")
  matrix_result <- as.matrix(result)
  expect_equal(dim(matrix_result), c(4, 4))
  expect_equal(rownames(matrix_result), test_samples$sample)
  expect_equal(colnames(matrix_result), test_samples$sample)
  expect_equal(matrix_result, t(matrix_result), tolerance = 1e-12)
  expect_equal(unname(diag(matrix_result)), rep(0, 4))
  expect_equal(
    matrix_result["S1", "S3"],
    delta_e_2000(45, 15, 10, 50, 11, 8)
  )
})

test_that("lab_distances supports quoted columns and missing LAB values", {
  samples <- test_samples
  samples$lightness[[2]] <- NA_real_

  result <- as.matrix(lab_distances(
    samples,
    "sample",
    "lightness",
    "redness",
    "yellowness"
  ))

  expect_true(all(is.na(result["S2", ])))
  expect_true(all(is.na(result[, "S2"])))
  expect_false(is.na(result["S1", "S3"]))
})

test_that("lab_distances validates sample data", {
  duplicated <- test_samples
  duplicated$sample[[2]] <- "S1"
  expect_error(
    lab_distances(duplicated, sample, lightness, redness, yellowness),
    "must be unique"
  )

  missing_id <- test_samples
  missing_id$sample[[1]] <- NA_character_
  expect_error(
    lab_distances(missing_id, sample, lightness, redness, yellowness),
    "must not be missing"
  )

  expect_error(
    lab_distances(test_samples, missing, lightness, redness, yellowness),
    "Missing required columns"
  )
})

test_that("summarize_treatment_distances averages unique sample pairs", {
  distances <- matrix(
    c(
      0, 2, 4, 6,
      2, 0, 3, 5,
      4, 3, 0, 1,
      6, 5, 1, 0
    ),
    nrow = 4,
    byrow = TRUE,
    dimnames = list(paste0("S", 1:4), paste0("S", 1:4))
  )
  shuffled_metadata <- test_samples[c(3, 1, 4, 2), ]

  result <- summarize_treatment_distances(
    distances,
    treatment = treatment,
    metadata = shuffled_metadata,
    sample_id = sample
  )

  expect_equal(result$treatment_1, c("control", "control", "treated"))
  expect_equal(result$treatment_2, c("control", "treated", "treated"))
  expect_equal(result$mean_distance, c(2, 4.5, 1))
  expect_equal(result$n_pairs, c(1L, 4L, 1L))
  expect_equal(result$n_missing, c(0L, 0L, 0L))
})

test_that("treatment summaries report and optionally propagate missing pairs", {
  distances <- lab_distances(
    transform(test_samples, lightness = replace(lightness, 2, NA_real_)),
    sample,
    lightness,
    redness,
    yellowness
  )

  removed <- summarize_treatment_distances(
    distances,
    treatment = treatment
  )
  propagated <- summarize_treatment_distances(
    distances,
    treatment = treatment,
    na_rm = FALSE
  )

  between <- removed$treatment_1 == "control" & removed$treatment_2 == "treated"
  expect_equal(removed$n_pairs[between], 2L)
  expect_equal(removed$n_missing[between], 2L)
  expect_false(is.na(removed$mean_distance[between]))
  expect_true(is.na(propagated$mean_distance[between]))
})

test_that("summarize_treatment_distances validates matrices and metadata", {
  distances <- matrix(0, nrow = 2, ncol = 2)
  dimnames(distances) <- list(c("S1", "S2"), c("S1", "S2"))
  asymmetric <- distances
  asymmetric[1, 2] <- 1
  expect_error(
    summarize_treatment_distances(
      asymmetric,
      treatment,
      metadata = test_samples,
      sample_id = sample
    ),
    "must be symmetric"
  )

  incomplete_metadata <- test_samples[test_samples$sample != "S2", ]
  expect_error(
    summarize_treatment_distances(
      distances,
      treatment,
      metadata = incomplete_metadata,
      sample_id = sample
    ),
    "Missing metadata for samples: S2"
  )
})

test_that("plot_treatment_distances returns a symmetric ggplot heatmap", {
  distances <- lab_distances(
    test_samples,
    sample,
    lightness,
    redness,
    yellowness
  )
  heatmap <- plot_treatment_distances(
    distances,
    treatment = treatment,
    digits = 2
  )

  expect_s3_class(heatmap, "ggplot")
  expect_equal(nrow(heatmap$data), 4)
  expect_equal(
    heatmap$data$mean_distance[heatmap$data$treatment_1 == "control" &
      heatmap$data$treatment_2 == "treated"],
    heatmap$data$mean_distance[heatmap$data$treatment_1 == "treated" &
      heatmap$data$treatment_2 == "control"]
  )
  expect_length(heatmap$layers, 2)

  expect_s3_class(plot(distances, treatment = treatment), "ggplot")
  expect_s3_class(plot(distances, treatment), "ggplot")
})
