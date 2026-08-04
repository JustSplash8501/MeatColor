#' Plot LAB color data as colored rectangles
#'
#' @param data Data frame from summarize_lab() or with l_mean, a_mean, b_mean, color columns
#' @param x_var Column name for x-axis grouping (e.g., "time_point")
#' @param facet_var Optional column name for faceting (e.g., "product")
#' @param x_label Label for x-axis
#' @param title Plot title
#'
#' @return A ggplot object
#' @importFrom ggplot2 ggplot aes geom_rect scale_fill_identity scale_x_continuous scale_y_continuous labs facet_wrap theme_bw theme element_blank element_text
#' @importFrom dplyr mutate
#' @export
plot_lab_colors <- function(
  data,
  x_var,
  facet_var = NULL,
  x_label = "Time Point",
  title = "L*a*b* Color Plot"
) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  validate_column_name(x_var, "x_var")
  if (!is.null(facet_var)) {
    validate_column_name(facet_var, "facet_var")
  }

  required_cols <- c("l_mean", "a_mean", "b_mean", "color")
  requested_cols <- c(required_cols, x_var, facet_var)
  missing_cols <- setdiff(requested_cols, names(data))
  if (length(missing_cols) > 0) {
    stop(
      "Missing required columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }
  if (anyNA(data[[x_var]])) {
    stop("`x_var` must not contain missing values.", call. = FALSE)
  }

  x_values <- data[[x_var]]
  if (is.factor(x_values)) {
    x_levels <- levels(droplevels(x_values))
  } else {
    x_levels <- unique(as.character(x_values))
  }

  plot_data <- data |>
    dplyr::mutate(
      ymin = 0.5,
      ymax = 1.5,
      x_position = match(as.character(.data[[x_var]]), x_levels),
      xmin = .data$x_position - 0.5,
      xmax = .data$x_position + 0.5
    )

  # Base plot
  p <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      xmin = .data$xmin,
      xmax = .data$xmax,
      ymin = .data$ymin,
      ymax = .data$ymax,
      fill = .data$color
    )
  ) +
    ggplot2::geom_rect(color = "black", linewidth = 1) +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_x_continuous(
      breaks = seq_along(x_levels),
      labels = x_levels,
      expand = c(0, 0)
    ) +
    ggplot2::scale_y_continuous(expand = c(0, 0)) +
    ggplot2::labs(x = x_label, y = "", title = title) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor.y = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = 20),
      axis.ticks.y = ggplot2::element_blank(),
      axis.title.y = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(size = 40, face = "bold"),
      strip.text = ggplot2::element_text(size = 20, color = "black")
    )

  # Add faceting if specified
  if (!is.null(facet_var)) {
    p <- p + ggplot2::facet_wrap(
      ggplot2::vars(!!rlang::sym(facet_var))
    )
  }

  p
}
