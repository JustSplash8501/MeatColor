validate_flag <- function(value, name) {
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    stop("`", name, "` must be either TRUE or FALSE.", call. = FALSE)
  }
}

validate_lab_channels <- function(l, a, b) {
  channels <- list(l = l, a = a, b = b)
  numeric_channels <- vapply(channels, is.numeric, logical(1))
  if (!all(numeric_channels)) {
    stop(
      "`l`, `a`, and `b` must all be numeric vectors.",
      call. = FALSE
    )
  }

  lengths <- lengths(channels)
  if (any(lengths == 0L)) {
    stop("`l`, `a`, and `b` must not be empty.", call. = FALSE)
  }

  output_length <- max(lengths)
  if (any(lengths != 1L & lengths != output_length)) {
    stop(
      "`l`, `a`, and `b` must have equal lengths or be length one.",
      call. = FALSE
    )
  }

  invalid_finite <- vapply(
    channels,
    function(x) any(!is.finite(x) & !is.na(x)),
    logical(1)
  )
  if (any(invalid_finite)) {
    stop("`l`, `a`, and `b` must be finite or missing.", call. = FALSE)
  }
}

validate_column_name <- function(value, name) {
  if (!is.character(value) || length(value) != 1L || is.na(value) || !nzchar(value)) {
    stop("`", name, "` must be one non-empty column name.", call. = FALSE)
  }
}

mean_or_na <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}

#' Convert LAB color values to hexadecimal colors
#'
#' @param l Numeric L* values. Values must be finite or missing.
#' @param a Numeric a* values. Values must be finite or missing.
#' @param b Numeric b* values. Values must be finite or missing.
#' @param fixup Logical. If `TRUE`, out-of-gamut colors are corrected to the
#'   closest displayable sRGB color. Defaults to `FALSE`.
#'
#' @return A character vector of hexadecimal colors
#'
#' @examples
#' lab_to_hex(l = c(45, 55), a = c(15, 10), b = c(10, -5))
#'
#' # Missing coordinates remain missing.
#' lab_to_hex(l = c(45, NA), a = 15, b = 10)
#' @importFrom colorspace hex LAB
#' @export
lab_to_hex <- function(l, a, b, fixup = FALSE) {
  validate_flag(fixup, "fixup")
  validate_lab_channels(l, a, b)

  colors <- colorspace::hex(colorspace::LAB(l, a, b), fixup = fixup)

  output_length <- max(lengths(list(l, a, b)))
  complete_input <- stats::complete.cases(
    rep_len(l, output_length),
    rep_len(a, output_length),
    rep_len(b, output_length)
  )
  out_of_gamut <- is.na(colors) & complete_input

  if (!fixup && any(out_of_gamut)) {
    warning(
      "out-of-gamut LAB colors detected. Use fixup = TRUE to resolve NA values",
      call. = FALSE
    )
  }

  colors
}

#' Summarize LAB color data
#'
#' @param data A data frame containing numeric LAB color measurements. LAB
#'   values must be finite or missing.
#' @param group_vars Character vector of column names to group by
#' @param l_col Name of the L* column (default "l")
#' @param a_col Name of the a* column (default "a")
#' @param b_col Name of the b* column (default "b")
#' @param fixup Logical. If `TRUE`, out-of-gamut colors are corrected to the
#'   closest displayable sRGB color. Defaults to `FALSE`.
#'
#' @return A data frame with mean LAB values and hex colors
#'
#' @examples
#' measurements <- data.frame(
#'   treatment = c("control", "control", "treated", "treated"),
#'   l = c(44, 46, 48, 50),
#'   a = c(16, 14, 13, 11),
#'   b = c(10, 12, 9, 11)
#' )
#'
#' measurements |>
#'   summarize_lab(group_vars = "treatment")
#' @importFrom dplyr group_by summarize mutate
#' @importFrom colorspace hex LAB
#' @export
summarize_lab <- function(
  data,
  group_vars,
  l_col = "l",
  a_col = "a",
  b_col = "b",
  fixup = FALSE
) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  if (!is.character(group_vars) || anyNA(group_vars) || any(!nzchar(group_vars))) {
    stop("`group_vars` must be a character vector of column names.", call. = FALSE)
  }
  validate_column_name(l_col, "l_col")
  validate_column_name(a_col, "a_col")
  validate_column_name(b_col, "b_col")
  validate_flag(fixup, "fixup")

  requested_cols <- unique(c(group_vars, l_col, a_col, b_col))
  missing_cols <- setdiff(requested_cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(
      "Missing required columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  lab_cols <- c(l_col, a_col, b_col)
  numeric_cols <- vapply(data[lab_cols], is.numeric, logical(1))
  if (!all(numeric_cols)) {
    stop(
      "LAB measurement columns must be numeric: ",
      paste(lab_cols[!numeric_cols], collapse = ", "),
      call. = FALSE
    )
  }

  data_summary <- data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_vars))) |>
    dplyr::summarize(
      l_mean = mean_or_na(.data[[l_col]]),
      a_mean = mean_or_na(.data[[a_col]]),
      b_mean = mean_or_na(.data[[b_col]]),
      .groups = "drop"
    )

  data_summary |>
    dplyr::mutate(
      color = lab_to_hex(.data$l_mean, .data$a_mean, .data$b_mean, fixup = fixup)
    )
}
