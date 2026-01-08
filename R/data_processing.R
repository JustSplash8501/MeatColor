#' Summarize LAB color data
#'
#' @param data A data frame containing LAB color measurements
#' @param group_vars Character vector of column names to group by
#' @param l_col Name of the L* column (default "l")
#' @param a_col Name of the a* column (default "a")
#' @param b_col Name of the b* column (default "b")
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
  b_col = "b"
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
      color = colorspace::hex(colorspace::LAB(l_mean, a_mean, b_mean))
    )
}
