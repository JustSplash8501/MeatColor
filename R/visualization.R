#' Plot LAB color data as colored rectangles
#'
#' Creates a treatment-aware color chart from summarized CIELAB measurements.
#' The returned object is a regular [ggplot2::ggplot()] object, so additional
#' ggplot2 layers, scales, labels, and themes can be added with `+`.
#'
#' @param data A data frame from [summarize_lab()] or a data frame containing
#'   `l_mean`, `a_mean`, `b_mean`, and `color` columns.
#' @param x_var One column name defining the x-axis positions.
#' @param facet_var An optional column name defining plot facets.
#' @param x_label Label for the x-axis.
#' @param title Plot title.
#' @param group_var An optional column name defining separate horizontal rows,
#'   such as treatment. When omitted, each x/facet combination must identify
#'   at most one row.
#' @param group_label Label for the group axis. Defaults to `group_var` when a
#'   group variable is supplied.
#' @param subtitle,caption Optional plot subtitle and caption.
#' @param facet_ncol Optional positive integer giving the number of facet
#'   columns.
#' @param facet_scales Should facet scales be `"fixed"`, `"free"`,
#'   `"free_x"`, or `"free_y"`?
#' @param border_color Rectangle border color. Use `NA` for no border.
#' @param border_linewidth Non-negative rectangle border width.
#' @param base_size Base font size supplied to [ggplot2::theme_bw()].
#' @param axis_text_size,title_size,strip_text_size Font sizes for axis text,
#'   the plot title, and facet-strip text.
#' @param show_values Text to draw inside each rectangle: `"none"`, `"hex"`,
#'   `"lab"`, or `"both"`.
#' @param value_size,value_color Font size and color for values drawn inside
#'   rectangles.
#' @param na_color Fill color used when `color` is missing.
#'
#' @return A ggplot object.
#'
#' @examples
#' color_summary <- data.frame(
#'   treatment = rep(c("Control", "Aged"), each = 2),
#'   day = rep(c("Day 0", "Day 7"), 2),
#'   l_mean = c(45, 43, 46, 42),
#'   a_mean = c(18, 16, 19, 15),
#'   b_mean = c(12, 10, 13, 9)
#' )
#' color_summary$color <- with(
#'   color_summary,
#'   lab_to_hex(l_mean, a_mean, b_mean)
#' )
#'
#' plot_lab_colors(
#'   color_summary,
#'   x_var = "day",
#'   group_var = "treatment",
#'   show_values = "hex"
#' )
#'
#' @importFrom ggplot2 aes element_blank element_text facet_wrap geom_rect geom_text ggplot labs scale_fill_identity scale_x_continuous scale_y_continuous theme theme_bw vars
#' @importFrom dplyr mutate
#' @export
plot_lab_colors <- function(
  data,
  x_var,
  facet_var = NULL,
  x_label = "Time Point",
  title = "L*a*b* Color Plot",
  group_var = NULL,
  group_label = NULL,
  subtitle = NULL,
  caption = NULL,
  facet_ncol = NULL,
  facet_scales = c("fixed", "free", "free_x", "free_y"),
  border_color = "black",
  border_linewidth = 1,
  base_size = 11,
  axis_text_size = base_size,
  title_size = base_size * 1.5,
  strip_text_size = base_size,
  show_values = c("none", "hex", "lab", "both"),
  value_size = 3.5,
  value_color = "black",
  na_color = "grey80"
) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  validate_column_name(x_var, "x_var")
  if (!is.null(facet_var)) {
    validate_column_name(facet_var, "facet_var")
  }
  if (!is.null(group_var)) {
    validate_column_name(group_var, "group_var")
  }

  show_values <- match.arg(show_values)
  facet_scales <- match.arg(facet_scales)

  positive_sizes <- list(
    base_size = base_size,
    axis_text_size = axis_text_size,
    title_size = title_size,
    strip_text_size = strip_text_size,
    value_size = value_size
  )
  valid_sizes <- vapply(
    positive_sizes,
    function(x) {
      is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x) && x > 0
    },
    logical(1)
  )
  if (!all(valid_sizes)) {
    stop("Plot font sizes must be positive finite numbers.", call. = FALSE)
  }
  if (
    !is.numeric(border_linewidth) || length(border_linewidth) != 1L ||
      is.na(border_linewidth) || !is.finite(border_linewidth) ||
      border_linewidth < 0
  ) {
    stop("`border_linewidth` must be a non-negative finite number.", call. = FALSE)
  }
  if (!is.null(facet_ncol)) {
    if (
      !is.numeric(facet_ncol) || length(facet_ncol) != 1L ||
        is.na(facet_ncol) || !is.finite(facet_ncol) ||
        facet_ncol < 1 || facet_ncol %% 1 != 0
    ) {
      stop("`facet_ncol` must be a positive integer or NULL.", call. = FALSE)
    }
    facet_ncol <- as.integer(facet_ncol)
  }

  required_cols <- c("l_mean", "a_mean", "b_mean", "color")
  requested_cols <- c(required_cols, x_var, facet_var, group_var)
  missing_cols <- setdiff(requested_cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(
      "Missing required columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  position_cols <- c(x_var, facet_var, group_var)
  missing_positions <- vapply(
    data[position_cols],
    anyNA,
    logical(1)
  )
  if (any(missing_positions)) {
    stop(
      "Plot position columns must not contain missing values: ",
      paste(position_cols[missing_positions], collapse = ", "),
      call. = FALSE
    )
  }
  if (anyDuplicated(data[position_cols])) {
    if (is.null(group_var)) {
      stop(
        "Multiple rows share an x/facet position. Supply `group_var` to ",
        "display separate treatment rows.",
        call. = FALSE
      )
    }
    stop(
      "Each x/facet/group combination must identify at most one row.",
      call. = FALSE
    )
  }

  x_values <- data[[x_var]]
  if (is.factor(x_values)) {
    x_levels <- levels(droplevels(x_values))
  } else {
    x_levels <- unique(as.character(x_values))
  }

  if (is.null(group_var)) {
    group_levels <- ""
    group_positions <- rep(1L, nrow(data))
  } else {
    group_values <- data[[group_var]]
    if (is.factor(group_values)) {
      group_levels <- levels(droplevels(group_values))
    } else {
      group_levels <- unique(as.character(group_values))
    }
    group_positions <- match(as.character(group_values), group_levels)
  }

  plot_data <- data |>
    dplyr::mutate(
      x_position = match(as.character(.data[[x_var]]), x_levels),
      y_position = group_positions,
      xmin = .data$x_position - 0.5,
      xmax = .data$x_position + 0.5,
      ymin = .data$y_position - 0.5,
      ymax = .data$y_position + 0.5
    )

  complete_lab <- stats::complete.cases(
    plot_data[c("l_mean", "a_mean", "b_mean")]
  )
  lab_label <- rep(NA_character_, nrow(plot_data))
  lab_label[complete_lab] <- sprintf(
    "L* %.1f\na* %.1f\nb* %.1f",
    plot_data$l_mean[complete_lab],
    plot_data$a_mean[complete_lab],
    plot_data$b_mean[complete_lab]
  )
  if (show_values == "hex") {
    plot_data$.value_label <- plot_data$color
  } else if (show_values == "lab") {
    plot_data$.value_label <- lab_label
  } else if (show_values == "both") {
    plot_data$.value_label <- ifelse(
      is.na(plot_data$color) | is.na(lab_label),
      NA_character_,
      paste(plot_data$color, lab_label, sep = "\n")
    )
  }

  y_axis_label <- if (is.null(group_var)) {
    ""
  } else if (is.null(group_label)) {
    group_var
  } else {
    group_label
  }

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
    ggplot2::geom_rect(
      color = border_color,
      linewidth = border_linewidth
    ) +
    ggplot2::scale_fill_identity(na.value = na_color) +
    ggplot2::scale_x_continuous(
      breaks = seq_along(x_levels),
      labels = x_levels,
      expand = c(0, 0)
    ) +
    ggplot2::scale_y_continuous(
      breaks = if (is.null(group_var)) NULL else seq_along(group_levels),
      labels = if (is.null(group_var)) NULL else group_levels,
      expand = c(0, 0)
    ) +
    ggplot2::labs(
      x = x_label,
      y = y_axis_label,
      title = title,
      subtitle = subtitle,
      caption = caption
    ) +
    ggplot2::theme_bw(base_size = base_size) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(size = axis_text_size),
      plot.title = ggplot2::element_text(size = title_size, face = "bold"),
      strip.text = ggplot2::element_text(
        size = strip_text_size,
        color = "black"
      )
    )

  if (is.null(group_var)) {
    p <- p + ggplot2::theme(
      axis.ticks.y = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_blank(),
      axis.title.y = ggplot2::element_blank()
    )
  }

  if (show_values != "none") {
    p <- p + ggplot2::geom_text(
      data = plot_data,
      mapping = ggplot2::aes(
        x = .data$x_position,
        y = .data$y_position,
        label = .data$.value_label
      ),
      inherit.aes = FALSE,
      size = value_size,
      color = value_color,
      lineheight = 0.9
    )
  }

  if (!is.null(facet_var)) {
    p <- p + ggplot2::facet_wrap(
      ggplot2::vars(!!rlang::sym(facet_var)),
      ncol = facet_ncol,
      scales = facet_scales
    )
  }

  p
}
