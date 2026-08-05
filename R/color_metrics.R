#' Calculate CIELAB chroma
#'
#' Calculates CIELAB chroma (C*ab) from a* and b* coordinates. Inputs are
#' vectorized, and a length-one input is recycled to match the other input.
#'
#' @param a Numeric vector of a* coordinates.
#' @param b Numeric vector of b* coordinates.
#'
#' @return A numeric vector of non-negative CIELAB chroma values. Missing
#'   coordinates produce missing results.
#'
#' @examples
#' lab_chroma(a = 3, b = 4)
#' lab_chroma(a = c(20, 10), b = 5)
#'
#' @export
lab_chroma <- function(a, b) {
  channels <- recycle_ab_channels(a, b)
  sqrt(channels$a^2 + channels$b^2)
}

#' Calculate CIELAB hue angle
#'
#' Calculates the CIELAB hue angle (hab) from a* and b* coordinates using
#' `atan2()`, with angles normalized to one complete positive rotation. Hue is
#' undefined when both coordinates are zero, so neutral colors return `NA`.
#'
#' @param a Numeric vector of a* coordinates.
#' @param b Numeric vector of b* coordinates.
#' @param degrees Logical. If `TRUE` (the default), return degrees from 0
#'   (inclusive) to 360 (exclusive). If `FALSE`, return radians from 0
#'   (inclusive) to 2*pi (exclusive).
#'
#' @return A numeric vector of CIELAB hue angles. Missing coordinates and
#'   neutral colors produce missing results.
#'
#' @details
#' In degrees, 0 corresponds to the positive a* (red) axis, 90 to positive b*
#' (yellow), 180 to negative a* (green), and 270 to negative b* (blue).
#'
#' @examples
#' lab_hue(a = c(1, 0, -1, 0), b = c(0, 1, 0, -1))
#' lab_hue(a = 1, b = 1, degrees = FALSE)
#'
#' @export
lab_hue <- function(a, b, degrees = TRUE) {
  validate_flag(degrees, "degrees")
  channels <- recycle_ab_channels(a, b)

  chroma <- sqrt(channels$a^2 + channels$b^2)
  hue <- atan2(channels$b, channels$a) %% (2 * pi)
  hue[chroma == 0] <- NA_real_

  if (degrees) {
    hue <- hue * 180 / pi
  }

  hue
}

#' Add CIELAB hue and chroma columns to a data frame
#'
#' Adds row-wise CIELAB chroma and hue-angle calculations to a data frame. The
#' function works as a dplyr-style pipeline verb and preserves data-frame,
#' tibble, and grouping classes.
#'
#' @param data A data frame or tibble containing a* and b* coordinates.
#' @param a_col,b_col Unquoted or quoted names of the a* and b* columns. When
#'   `NULL`, the defaults, columns named `a` and `b` are used.
#' @param chroma_col,hue_col Names for the new output columns. Defaults to
#'   `"chroma"` and `"hue"`.
#' @param degrees Logical. Passed to [lab_hue()]; `TRUE` returns degrees and
#'   `FALSE` returns radians.
#'
#' @return `data` with numeric chroma and hue columns appended. Existing
#'   columns are preserved.
#'
#' @examples
#' measurements <- data.frame(
#'   treatment = c("Control", "Treatment"),
#'   a = c(18, 12),
#'   b = c(12, 8)
#' )
#'
#' add_lab_metrics(measurements)
#' add_lab_metrics(measurements, a_col = "a", b_col = "b")
#'
#' @export
add_lab_metrics <- function(
  data,
  a_col = NULL,
  b_col = NULL,
  chroma_col = "chroma",
  hue_col = "hue",
  degrees = TRUE
) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }

  a_column <- rlang::enquo(a_col)
  b_column <- rlang::enquo(b_col)
  a_name <- if (rlang::quo_is_null(a_column)) {
    "a"
  } else {
    tidy_column_name(a_column, "a_col")
  }
  b_name <- if (rlang::quo_is_null(b_column)) {
    "b"
  } else {
    tidy_column_name(b_column, "b_col")
  }
  validate_column_name(chroma_col, "chroma_col")
  validate_column_name(hue_col, "hue_col")
  validate_flag(degrees, "degrees")

  missing_cols <- setdiff(c(a_name, b_name), names(data))
  if (length(missing_cols) > 0L) {
    stop(
      "Missing required columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  if (chroma_col == hue_col) {
    stop("`chroma_col` and `hue_col` must be different names.", call. = FALSE)
  }

  output_collisions <- intersect(c(chroma_col, hue_col), c(a_name, b_name))
  if (length(output_collisions) > 0L) {
    stop(
      "Output columns must not overwrite the selected a* or b* columns: ",
      paste(output_collisions, collapse = ", "),
      call. = FALSE
    )
  }

  data[[chroma_col]] <- lab_chroma(data[[a_name]], data[[b_name]])
  data[[hue_col]] <- lab_hue(data[[a_name]], data[[b_name]], degrees = degrees)
  data
}

tidy_column_name <- function(column, argument) {
  tryCatch(
    rlang::as_name(column),
    error = function(error) {
      stop(
        "`", argument, "` must be one unquoted or quoted column name.",
        call. = FALSE
      )
    }
  )
}

recycle_ab_channels <- function(a, b) {
  channels <- list(a = a, b = b)
  numeric_channels <- vapply(channels, is.numeric, logical(1))
  if (!all(numeric_channels)) {
    stop("`a` and `b` must both be numeric vectors.", call. = FALSE)
  }

  channel_lengths <- lengths(channels)
  if (any(channel_lengths == 0L)) {
    stop("`a` and `b` must not be empty.", call. = FALSE)
  }

  output_length <- max(channel_lengths)
  if (any(channel_lengths != 1L & channel_lengths != output_length)) {
    stop(
      "`a` and `b` must have equal lengths or be length one.",
      call. = FALSE
    )
  }

  invalid_finite <- vapply(
    channels,
    function(x) any(!is.finite(x) & !is.na(x)),
    logical(1)
  )
  if (any(invalid_finite)) {
    stop("`a` and `b` must be finite or missing.", call. = FALSE)
  }

  lapply(channels, rep_len, length.out = output_length)
}
