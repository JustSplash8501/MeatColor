#' Estimate myoglobin forms using calibrated K/S references
#'
#' Estimates relative oxymyoglobin (OMb), deoxymyoglobin (DMb), and
#' metmyoglobin (MMb) percentages with the calibrated K/S isobestic-wavelength
#' method described in the AMSA Meat Color Measurement Guidelines. Separate
#' experimentally prepared reference spectra representing 100 percent OMb,
#' DMb, and MMb are required.
#'
#' @param data A data frame containing sample MiniScan spectral reflectance.
#' @param omb_reference,dmb_reference,mmb_reference Data frames containing
#'   reflectance scans of experimentally prepared 100 percent OMb, DMb, and
#'   MMb reference samples. Each data frame may contain one or more replicate
#'   scans and must use the same wavelength column names as `data`.
#' @param r470_col,r480_col,r520_col,r530_col,r570_col,r580_col,r610_col Names
#'   of the columns containing reflectance at the indicated wavelengths.
#' @param reflectance_scale Input scale shared by the samples and references.
#'   Use `"percent"` for values such as `35.2`, or `"proportion"` for values
#'   such as `0.352`. The scale is never inferred automatically. Non-missing
#'   values must be greater than zero and no greater than 100 for `"percent"`
#'   or 1 for `"proportion"`.
#' @param reference_summary How replicate reference ratios are summarized.
#'   The default is `"mean"`; `"median"` is available for a robust summary.
#' @param bounds How estimates outside 0 to 100 percent are handled. `"warn"`
#'   retains the estimates and emits a warning, `"none"` retains them without
#'   a warning, and `"clamp"` restricts each estimate to the interval from 0
#'   to 100. The `myoglobin_valid` column always describes the estimates before
#'   clamping.
#' @param keep_intermediates Logical. If `TRUE`, append interpolated
#'   reflectance, K/S values, and sample K/S ratios.
#'
#' @return `data` with `omb_pct`, `dmb_pct`, `mmb_pct`,
#'   `myoglobin_sum_pct`, and `myoglobin_valid` appended. The three estimates
#'   are calibrated independently and therefore are not forced to total 100.
#'   Rows with missing required reflectance return missing estimates. The
#'   summarized calibration values are attached as the
#'   `"myoglobin_reference_ratios"` attribute regardless of
#'   `keep_intermediates`.
#'
#' @details
#' MiniScan reflectance at 474, 525, and 572 nm is linearly interpolated from
#' the instrument's 10 nm output before conversion to K/S. Reflectance at
#' 610 nm is used directly. K/S is calculated as `(1 - R)^2 / (2 * R)`, where
#' `R` is reflectance expressed as a proportion.
#'
#' The calibrated ratios are K/S474 divided by K/S525 for DMb, K/S572 divided
#' by K/S525 for MMb, and K/S610 divided by K/S525 for OMb. Reference values
#' should be prepared from the same product and experiment and measured using
#' the same instrument, standardization, and packaging-film conditions as the
#' samples.
#'
#' This calibrated K/S procedure is distinct from the Krzywicki selected-
#' wavelength reflex-attenuance method implemented by [myoglobin_int()].
#'
#' @references
#' American Meat Science Association. (2012). *Meat Color Measurement
#' Guidelines*. Champaign, Illinois, USA.
#' \url{https://meatscience.org/docs/default-source/publications-resources/hot-topics/2012_12_meat_clr_guide.pdf}
#'
#' King, D. A., et al. (2023). American Meat Science Association Guidelines for
#' Meat Color Measurement. *Meat and Muscle Biology*, 6(4), 1-81.
#' \doi{10.22175/mmb.12473}
#'
#' @examples
#' # One sample and one prepared spectrum for each reference form.
#' sample_scan <- data.frame(
#'   R470 = 20, R480 = 20, R520 = 25, R530 = 25,
#'   R570 = 30, R580 = 30, R610 = 35
#' )
#' omb_ref <- transform(sample_scan, R470 = 18, R480 = 18, R610 = 45)
#' dmb_ref <- transform(sample_scan, R470 = 30, R480 = 30, R570 = 22, R580 = 22)
#' mmb_ref <- transform(sample_scan, R570 = 40, R580 = 40, R610 = 22)
#'
#' myoglobin_ref(
#'   sample_scan,
#'   omb_reference = omb_ref,
#'   dmb_reference = dmb_ref,
#'   mmb_reference = mmb_ref,
#'   reflectance_scale = "percent",
#'   bounds = "none"
#' )
#'
#' @export
myoglobin_ref <- function(
  data,
  omb_reference,
  dmb_reference,
  mmb_reference,
  r470_col = "R470",
  r480_col = "R480",
  r520_col = "R520",
  r530_col = "R530",
  r570_col = "R570",
  r580_col = "R580",
  r610_col = "R610",
  reflectance_scale = c("percent", "proportion"),
  reference_summary = c("mean", "median"),
  bounds = c("warn", "none", "clamp"),
  keep_intermediates = FALSE
) {
  reflectance_scale <- match.arg(reflectance_scale)
  reference_summary <- match.arg(reference_summary)
  bounds <- match.arg(bounds)
  validate_flag(keep_intermediates, "keep_intermediates")

  column_args <- c(
    r470_col = r470_col,
    r480_col = r480_col,
    r520_col = r520_col,
    r530_col = r530_col,
    r570_col = r570_col,
    r580_col = r580_col,
    r610_col = r610_col
  )
  invisible(Map(validate_column_name, column_args, names(column_args)))

  sample_values <- prepare_ks_spectra(
    data,
    column_args,
    reflectance_scale,
    "data"
  )
  reference_data <- list(
    OMb = prepare_ks_spectra(
      omb_reference,
      column_args,
      reflectance_scale,
      "omb_reference"
    ),
    DMb = prepare_ks_spectra(
      dmb_reference,
      column_args,
      reflectance_scale,
      "dmb_reference"
    ),
    MMb = prepare_ks_spectra(
      mmb_reference,
      column_args,
      reflectance_scale,
      "mmb_reference"
    )
  )

  undefined_sample <- sample_values$complete_input & !sample_values$ratio_valid
  if (any(undefined_sample)) {
    warning(
      sum(undefined_sample),
      " row(s) had undefined K/S ratios because K/S525 was zero or nearly zero.",
      call. = FALSE
    )
  }

  reference_ratios <- lapply(
    names(reference_data),
    function(form) {
      summarize_reference_ratios(
        reference_data[[form]],
        form,
        reference_summary
      )
    }
  )
  names(reference_ratios) <- names(reference_data)

  omb_denominator <-
    reference_ratios$MMb[["ratio_610_525"]] -
    reference_ratios$OMb[["ratio_610_525"]]
  mmb_denominator <-
    reference_ratios$DMb[["ratio_572_525"]] -
    reference_ratios$MMb[["ratio_572_525"]]
  dmb_denominator <-
    reference_ratios$OMb[["ratio_474_525"]] -
    reference_ratios$DMb[["ratio_474_525"]]

  calibration_denominators <- c(
    OMb = omb_denominator,
    DMb = dmb_denominator,
    MMb = mmb_denominator
  )
  indistinguishable <-
    !is.finite(calibration_denominators) |
    abs(calibration_denominators) <= sqrt(.Machine$double.eps)
  if (any(indistinguishable)) {
    stop(
      "Reference spectra do not distinguish the following myoglobin form(s): ",
      paste(names(calibration_denominators)[indistinguishable], collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  omb_pct <- (
    reference_ratios$MMb[["ratio_610_525"]] - sample_values$ratio_610_525
  ) / omb_denominator * 100
  mmb_pct <- (
    reference_ratios$DMb[["ratio_572_525"]] - sample_values$ratio_572_525
  ) / mmb_denominator * 100
  dmb_pct <- (
    reference_ratios$OMb[["ratio_474_525"]] - sample_values$ratio_474_525
  ) / dmb_denominator * 100

  raw_values <- list(omb_pct = omb_pct, dmb_pct = dmb_pct, mmb_pct = mmb_pct)
  within_bounds <- do.call(
    cbind,
    lapply(raw_values, function(x) is.na(x) | (x >= 0 & x <= 100))
  )
  complete_estimate <- stats::complete.cases(raw_values)
  valid <- complete_estimate & rowSums(within_bounds) == 3L
  valid[!sample_values$complete_input] <- NA

  outside_bounds <- complete_estimate & !valid
  if (any(outside_bounds) && bounds == "warn") {
    warning(
      sum(outside_bounds),
      " row(s) produced myoglobin estimates outside 0 to 100 percent; ",
      "the estimates were retained.",
      call. = FALSE
    )
  }

  if (bounds == "clamp") {
    raw_values <- lapply(raw_values, function(x) pmin(pmax(x, 0), 100))
  }

  result <- data
  result$omb_pct <- raw_values$omb_pct
  result$dmb_pct <- raw_values$dmb_pct
  result$mmb_pct <- raw_values$mmb_pct
  result$myoglobin_sum_pct <- result$omb_pct + result$dmb_pct + result$mmb_pct
  result$myoglobin_valid <- valid

  if (keep_intermediates) {
    result$mb_r474 <- sample_values$r474
    result$mb_r525 <- sample_values$r525
    result$mb_r572 <- sample_values$r572
    result$mb_r610 <- sample_values$r610
    result$mb_ks474 <- sample_values$ks474
    result$mb_ks525 <- sample_values$ks525
    result$mb_ks572 <- sample_values$ks572
    result$mb_ks610 <- sample_values$ks610
    result$mb_ratio_474_525 <- sample_values$ratio_474_525
    result$mb_ratio_572_525 <- sample_values$ratio_572_525
    result$mb_ratio_610_525 <- sample_values$ratio_610_525
  }

  reference_table <- data.frame(
    form = names(reference_ratios),
    ratio_474_525 = vapply(
      reference_ratios,
      `[[`,
      numeric(1),
      "ratio_474_525"
    ),
    ratio_572_525 = vapply(
      reference_ratios,
      `[[`,
      numeric(1),
      "ratio_572_525"
    ),
    ratio_610_525 = vapply(
      reference_ratios,
      `[[`,
      numeric(1),
      "ratio_610_525"
    ),
    summary = reference_summary,
    row.names = NULL
  )
  attr(result, "myoglobin_reference_ratios") <- reference_table

  result
}

prepare_ks_spectra <- function(data, column_args, reflectance_scale, data_name) {
  if (!is.data.frame(data)) {
    stop("`", data_name, "` must be a data frame.", call. = FALSE)
  }
  if (nrow(data) == 0L) {
    stop("`", data_name, "` must contain at least one row.", call. = FALSE)
  }

  missing_cols <- setdiff(unname(column_args), names(data))
  if (length(missing_cols) > 0L) {
    stop(
      "`", data_name, "` is missing required reflectance columns: ",
      paste(unique(missing_cols), collapse = ", "),
      call. = FALSE
    )
  }

  reflectance <- data[unname(column_args)]
  numeric_cols <- vapply(reflectance, is.numeric, logical(1))
  if (!all(numeric_cols)) {
    stop(
      "Reflectance columns in `", data_name, "` must be numeric: ",
      paste(names(reflectance)[!numeric_cols], collapse = ", "),
      call. = FALSE
    )
  }

  invalid_finite <- vapply(
    reflectance,
    function(x) any(!is.finite(x) & !is.na(x)),
    logical(1)
  )
  if (any(invalid_finite)) {
    stop(
      "Reflectance values in `", data_name, "` must be finite or missing.",
      call. = FALSE
    )
  }

  nonpositive <- vapply(
    reflectance,
    function(x) any(x <= 0, na.rm = TRUE),
    logical(1)
  )
  if (any(nonpositive)) {
    stop(
      "Reflectance values in `", data_name, "` must be greater than zero: ",
      paste(names(reflectance)[nonpositive], collapse = ", "),
      call. = FALSE
    )
  }

  validate_reflectance_upper_bound(reflectance, reflectance_scale, data_name)

  names(reflectance) <- c("r470", "r480", "r520", "r530", "r570", "r580", "r610")
  if (reflectance_scale == "percent") {
    reflectance <- lapply(reflectance, function(x) x / 100)
  }

  r474 <- interpolate_reflectance(reflectance$r470, reflectance$r480, 0.4)
  r525 <- interpolate_reflectance(reflectance$r520, reflectance$r530, 0.5)
  r572 <- interpolate_reflectance(reflectance$r570, reflectance$r580, 0.2)
  r610 <- reflectance$r610

  ks474 <- reflectance_to_ks(r474)
  ks525 <- reflectance_to_ks(r525)
  ks572 <- reflectance_to_ks(r572)
  ks610 <- reflectance_to_ks(r610)
  complete_input <- stats::complete.cases(r474, r525, r572, r610)
  ratio_valid <- complete_input & abs(ks525) > sqrt(.Machine$double.eps)
  ratio_denominator <- ks525
  ratio_denominator[!ratio_valid] <- NA_real_

  list(
    r474 = r474,
    r525 = r525,
    r572 = r572,
    r610 = r610,
    ks474 = ks474,
    ks525 = ks525,
    ks572 = ks572,
    ks610 = ks610,
    ratio_474_525 = ks474 / ratio_denominator,
    ratio_572_525 = ks572 / ratio_denominator,
    ratio_610_525 = ks610 / ratio_denominator,
    complete_input = complete_input,
    ratio_valid = ratio_valid
  )
}

reflectance_to_ks <- function(reflectance) {
  (1 - reflectance)^2 / (2 * reflectance)
}

summarize_reference_ratios <- function(reference, form, summary_method) {
  ratio_names <- c("ratio_474_525", "ratio_572_525", "ratio_610_525")
  complete_ratios <- stats::complete.cases(reference[ratio_names])
  if (!any(complete_ratios)) {
    stop(
      "The `", tolower(form),
      "_reference` data do not contain a complete, valid reference scan.",
      call. = FALSE
    )
  }
  if (any(!complete_ratios)) {
    warning(
      sum(!complete_ratios),
      " incomplete or undefined row(s) were excluded from the ",
      form,
      " reference summary.",
      call. = FALSE
    )
  }

  summary_function <- if (summary_method == "mean") mean else stats::median
  vapply(
    reference[ratio_names],
    function(x) summary_function(x[complete_ratios]),
    numeric(1)
  )
}
