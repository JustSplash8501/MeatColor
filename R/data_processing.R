#' Convert LAB color values to hexadecimal colors
#'
#' @param l L* values
#' @param a a* values
#' @param b b* values
#' @param fixup Logical. If `TRUE`, out-of-gamut colors are corrected to the
#'   closest displayable sRGB color. Defaults to `FALSE`.
#'
#' @return A character vector of hexadecimal colors
#' @importFrom colorspace hex LAB
#' @export
lab_to_hex <- function(l, a, b, fixup = FALSE) {
  colors <- colorspace::hex(colorspace::LAB(l, a, b), fixup = fixup)

  if (!fixup && any(is.na(colors))) {
    warning(
      "out-of-gamut LAB colors detected. Use fixup = TRUE to resolve NA values",
      call. = FALSE
    )
  }

  colors
}

#' Summarize LAB color data
#'
#' @param data A data frame containing LAB color measurements
#' @param group_vars Character vector of column names to group by
#' @param l_col Name of the L* column (default "l")
#' @param a_col Name of the a* column (default "a")
#' @param b_col Name of the b* column (default "b")
#' @param fixup Logical. If `TRUE`, out-of-gamut colors are corrected to the
#'   closest displayable sRGB color. Defaults to `FALSE`.
#'
#' @return A data frame with mean LAB values and hex colors
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
  data_summary <- data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_vars))) |>
    dplyr::summarize(
      l_mean = mean(.data[[l_col]], na.rm = TRUE),
      a_mean = mean(.data[[a_col]], na.rm = TRUE),
      b_mean = mean(.data[[b_col]], na.rm = TRUE),
      .groups = "drop"
    )

  data_summary |>
    dplyr::mutate(
      color = lab_to_hex(.data$l_mean, .data$a_mean, .data$b_mean, fixup = fixup)
    )
}
