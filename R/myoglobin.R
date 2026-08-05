#' Estimate myoglobin redox forms from MiniScan reflectance data
#'
#' Estimates the relative proportions of oxymyoglobin (OMb), deoxymyoglobin
#' (DMb), and metmyoglobin (MMb) using the 2012 AMSA selected-wavelength reflex
#' attenuance equations. The required 473, 525, and 572 nm reflectances are
#' linearly interpolated from the 10 nm reporting intervals produced by a
#' MiniScan.
#'
#' @param data A data frame containing MiniScan spectral reflectance values.
#' @param r470_col,r480_col,r520_col,r530_col,r570_col,r580_col,r700_col Names
#'   of the columns containing reflectance at the indicated wavelengths.
#' @param reflectance_scale Input scale. Use `"percent"` for values such as
#'   `35.2`, or `"proportion"` for values such as `0.352`. The scale is never
#'   inferred automatically. Non-missing values must be greater than zero and
#'   no greater than 100 for `"percent"` or 1 for `"proportion"`.
#' @param bounds How estimates outside 0 to 100 percent are handled. `"warn"`
#'   retains the estimates and emits a warning, `"none"` retains them without
#'   a warning, and `"clamp"` restricts each estimate to the interval from 0
#'   to 100. The `myoglobin_valid` column always describes the estimates before
#'   clamping.
#' @param keep_intermediates Logical. If `TRUE`, append the interpolated
#'   reflectance and calculated reflex attenuance values used in the equations.
#'
#' @return `data` with `omb_pct`, `dmb_pct`, `mmb_pct`,
#'   `myoglobin_sum_pct`, and `myoglobin_valid` appended. Rows with missing
#'   reflectance values return missing estimates. When `keep_intermediates` is
#'   `TRUE`, columns named `mb_r473`, `mb_r525`, `mb_r572`, `mb_r700`,
#'   `mb_a473`, `mb_a525`, `mb_a572`, and `mb_a700` are also appended.
#'
#' @details
#' Reflectance is interpolated before conversion to reflex attenuance. For
#' example, 473 nm reflectance is calculated as 70 percent of the 470 nm value
#' plus 30 percent of the 480 nm value. Reflex attenuance is calculated as
#' `log10(1 / R)`, where `R` is reflectance expressed as a proportion.
#'
#' AMSA originally specifies 730 nm as the reference wavelength, but permits
#' 700 nm or the closest available wavelength when an instrument does not
#' measure at 730 nm. The MiniScan spectral range ends at 700 nm.
#'
#' These calculations estimate relative surface myoglobin proportions. Values
#' outside 0 to 100 percent can occur because of measurement noise or a sample
#' that does not meet the assumptions of the selected-wavelength equations.
#' This function retains the 473 nm equation from the 2012 AMSA guidelines for
#' backward compatibility. The current guidelines use 474 nm; see
#' [myoglobin_ref()] for the calibrated K/S workflow that interpolates 474 nm.
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
#' r473 <- 10^-(0.1 + 0.8736842 * 0.2)
#' r525 <- 10^-0.3
#' r572 <- 10^-(0.1 + 1.195 * 0.2)
#' scans <- data.frame(
#'   sample = "A",
#'   R470 = 100 * r473, R480 = 100 * r473,
#'   R520 = 100 * r525, R530 = 100 * r525,
#'   R570 = 100 * r572, R580 = 100 * r572,
#'   R700 = 100 * 10^-0.1
#' )
#'
#' myoglobin_int(scans, reflectance_scale = "percent")
#'
#' @export
myoglobin_int <- function(
  data,
  r470_col = "R470",
  r480_col = "R480",
  r520_col = "R520",
  r530_col = "R530",
  r570_col = "R570",
  r580_col = "R580",
  r700_col = "R700",
  reflectance_scale = c("percent", "proportion"),
  bounds = c("warn", "none", "clamp"),
  keep_intermediates = FALSE
) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }

  reflectance_scale <- match.arg(reflectance_scale)
  bounds <- match.arg(bounds)
  validate_flag(keep_intermediates, "keep_intermediates")

  column_args <- c(
    r470_col = r470_col,
    r480_col = r480_col,
    r520_col = r520_col,
    r530_col = r530_col,
    r570_col = r570_col,
    r580_col = r580_col,
    r700_col = r700_col
  )
  invisible(Map(validate_column_name, column_args, names(column_args)))

  missing_cols <- setdiff(unname(column_args), names(data))
  if (length(missing_cols) > 0L) {
    stop(
      "Missing required reflectance columns: ",
      paste(unique(missing_cols), collapse = ", "),
      call. = FALSE
    )
  }

  reflectance <- data[unname(column_args)]
  numeric_cols <- vapply(reflectance, is.numeric, logical(1))
  if (!all(numeric_cols)) {
    stop(
      "Reflectance columns must be numeric: ",
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
    stop("Reflectance values must be finite or missing.", call. = FALSE)
  }

  nonpositive <- vapply(
    reflectance,
    function(x) any(x <= 0, na.rm = TRUE),
    logical(1)
  )
  if (any(nonpositive)) {
    stop(
      "Reflectance values must be greater than zero: ",
      paste(names(reflectance)[nonpositive], collapse = ", "),
      call. = FALSE
    )
  }

  validate_reflectance_upper_bound(reflectance, reflectance_scale)

  names(reflectance) <- c("r470", "r480", "r520", "r530", "r570", "r580", "r700")
  if (reflectance_scale == "percent") {
    reflectance <- lapply(reflectance, function(x) x / 100)
  }

  r473 <- interpolate_reflectance(reflectance$r470, reflectance$r480, 0.3)
  r525 <- interpolate_reflectance(reflectance$r520, reflectance$r530, 0.5)
  r572 <- interpolate_reflectance(reflectance$r570, reflectance$r580, 0.2)
  r700 <- reflectance$r700

  estimates <- estimate_myoglobin_attenuance(r473, r525, r572, r700)
  raw_values <- estimates[c("omb_pct", "dmb_pct", "mmb_pct")]
  within_bounds <- do.call(
    cbind,
    lapply(raw_values, function(x) is.na(x) | (x >= 0 & x <= 100))
  )
  complete_estimate <- stats::complete.cases(raw_values)
  valid <- complete_estimate & rowSums(within_bounds) == 3L
  valid[!estimates$complete_input] <- NA

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
    result$mb_r473 <- r473
    result$mb_r525 <- r525
    result$mb_r572 <- r572
    result$mb_r700 <- r700
    result$mb_a473 <- estimates$a473
    result$mb_a525 <- estimates$a525
    result$mb_a572 <- estimates$a572
    result$mb_a700 <- estimates$a700
  }

  result
}

validate_reflectance_upper_bound <- function(
  reflectance,
  reflectance_scale,
  data_name = NULL
) {
  upper_bound <- if (reflectance_scale == "percent") 100 else 1
  above_bound <- vapply(
    reflectance,
    function(x) any(x > upper_bound, na.rm = TRUE),
    logical(1)
  )

  if (any(above_bound)) {
    location <- if (is.null(data_name)) "" else paste0(" in `", data_name, "`")
    stop(
      "Reflectance values", location, " must not exceed ", upper_bound,
      " when `reflectance_scale = \"", reflectance_scale, "\"`: ",
      paste(names(reflectance)[above_bound], collapse = ", "),
      call. = FALSE
    )
  }
}

interpolate_reflectance <- function(lower, upper, fraction) {
  lower + fraction * (upper - lower)
}

estimate_myoglobin_attenuance <- function(r473, r525, r572, r700) {
  a473 <- log10(1 / r473)
  a525 <- log10(1 / r525)
  a572 <- log10(1 / r572)
  a700 <- log10(1 / r700)

  complete_input <- stats::complete.cases(r473, r525, r572, r700)
  denominator <- a525 - a700
  unstable <- complete_input & abs(denominator) <= sqrt(.Machine$double.eps)
  if (any(unstable)) {
    warning(
      sum(unstable),
      " row(s) had an undefined myoglobin calculation because ",
      "A525 - A700 was zero or nearly zero.",
      call. = FALSE
    )
    denominator[unstable] <- NA_real_
  }

  mmb_pct <- (1.395 - (a572 - a700) / denominator) * 100
  dmb_pct <- 2.375 * (1 - (a473 - a700) / denominator) * 100
  omb_pct <- 100 - (mmb_pct + dmb_pct)

  list(
    omb_pct = omb_pct,
    dmb_pct = dmb_pct,
    mmb_pct = mmb_pct,
    a473 = a473,
    a525 = a525,
    a572 = a572,
    a700 = a700,
    complete_input = complete_input
  )
}
