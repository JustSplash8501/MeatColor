#' Calculate all pairwise CIEDE2000 distances
#'
#' Builds an object containing a symmetric sample-by-sample distance matrix and
#' the original sample metadata. Unlike [delta_e_2000()], no reference color is
#' needed: every sample is compared with every other sample.
#'
#' @param data A data frame or tibble containing sample identifiers and CIELAB
#'   coordinates.
#' @param sample_id Unquoted or quoted name of the column containing unique,
#'   non-missing sample identifiers.
#' @param l_col,a_col,b_col Unquoted or quoted names of the L*, a*, and b*
#'   columns, respectively. They default to `l`, `a`, and `b`.
#' @param k_l,k_c,k_h Positive CIEDE2000 parametric weighting factors passed to
#'   [delta_e_2000()].
#'
#' @return A `meatcolor_distances` object. Use `as.matrix()` to extract its
#'   symmetric numeric matrix. Missing CIELAB coordinates produce missing
#'   distances.
#'
#' @examples
#' samples <- data.frame(
#'   sample = paste0("S", 1:4),
#'   treatment = rep(c("control", "treated"), each = 2),
#'   l = c(45, 46, 50, 51),
#'   a = c(15, 14, 11, 10),
#'   b = c(10, 11, 8, 9)
#' )
#'
#' distances <- lab_distances(samples, sample_id = sample)
#' distances
#' as.matrix(distances)
#'
#' @export
lab_distances <- function(
  data,
  sample_id,
  l_col = NULL,
  a_col = NULL,
  b_col = NULL,
  k_l = 1,
  k_c = 1,
  k_h = 1
) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  if (nrow(data) == 0L) {
    stop("`data` must contain at least one sample.", call. = FALSE)
  }

  id_name <- tidy_column_name(rlang::enquo(sample_id), "sample_id")
  l_column <- rlang::enquo(l_col)
  a_column <- rlang::enquo(a_col)
  b_column <- rlang::enquo(b_col)
  l_name <- if (rlang::quo_is_null(l_column)) {
    "l"
  } else {
    tidy_column_name(l_column, "l_col")
  }
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
  required <- unique(c(id_name, l_name, a_name, b_name))
  missing_columns <- setdiff(required, names(data))
  if (length(missing_columns) > 0L) {
    stop(
      "Missing required columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  identifiers <- data[[id_name]]
  if (!is.atomic(identifiers) || is.list(identifiers)) {
    stop("`sample_id` must identify an atomic column.", call. = FALSE)
  }
  identifiers <- as.character(identifiers)
  if (anyNA(identifiers) || any(!nzchar(identifiers))) {
    stop("Sample identifiers must not be missing or empty.", call. = FALSE)
  }
  if (anyDuplicated(identifiers)) {
    stop("Sample identifiers must be unique.", call. = FALSE)
  }

  l_values <- data[[l_name]]
  a_values <- data[[a_name]]
  b_values <- data[[b_name]]
  validate_lab_channels(l_values, a_values, b_values)

  sample_count <- nrow(data)
  row_index <- rep(seq_len(sample_count), each = sample_count)
  column_index <- rep(seq_len(sample_count), times = sample_count)
  distances <- delta_e_2000(
    l_values[row_index], a_values[row_index], b_values[row_index],
    l_values[column_index], a_values[column_index], b_values[column_index],
    k_l = k_l,
    k_c = k_c,
    k_h = k_h
  )

  distance_matrix <- matrix(
    distances,
    nrow = sample_count,
    byrow = TRUE,
    dimnames = list(identifiers, identifiers)
  )

  structure(
    list(
      distances = distance_matrix,
      metadata = data,
      sample_id = id_name,
      lab_columns = c(l = l_name, a = a_name, b = b_name),
      weights = c(k_l = k_l, k_c = k_c, k_h = k_h)
    ),
    class = "meatcolor_distances"
  )
}

#' @rdname lab_distances
#' @param x A `meatcolor_distances` object.
#' @param ... Additional arguments, currently ignored.
#' @export
print.meatcolor_distances <- function(x, ...) {
  cat(
    "<meatcolor_distances>\n",
    nrow(x$distances), " samples\n",
    "ID: ", x$sample_id, "\n",
    "CIELAB: ", paste(unname(x$lab_columns), collapse = ", "), "\n",
    sep = ""
  )
  invisible(x)
}

#' Extract a CIEDE2000 distance matrix
#'
#' @param x A `meatcolor_distances` object.
#' @param rownames.force Ignored; retained for compatibility with
#'   [base::as.matrix()].
#' @param ... Additional arguments, currently ignored.
#'
#' @return The symmetric numeric sample distance matrix.
#' @export
as.matrix.meatcolor_distances <- function(x, rownames.force = NA, ...) {
  x$distances
}

#' Summarize CIEDE2000 distances by treatment
#'
#' Joins a sample distance matrix to treatment metadata and averages unique
#' sample pairs within and between treatments. Self-comparisons and the
#' duplicated lower half of the symmetric matrix are excluded.
#'
#' @param x A `meatcolor_distances` object from [lab_distances()] or a symmetric
#'   numeric matrix with matching sample row and column names.
#' @param treatment Unquoted or quoted treatment column in the metadata.
#' @param metadata An optional data frame containing one row per sample. It is
#'   required when `x` is a plain matrix and otherwise defaults to the metadata
#'   stored in `x`.
#' @param sample_id Optional unquoted or quoted sample-identifier column in
#'   `metadata`. It is required for a plain matrix and otherwise defaults to the
#'   identifier column stored in `x`.
#' @param na_rm Logical. If `TRUE`, missing distances are removed when calculating
#'   means and standard deviations.
#'
#' @return A data frame with `treatment_1`, `treatment_2`, `mean_distance`,
#'   `sd_distance`, `n_pairs`, and `n_missing`. Between-treatment combinations
#'   appear once; for example, A-B and B-A are one group.
#'
#' @examples
#' samples <- data.frame(
#'   sample = paste0("S", 1:4),
#'   treatment = rep(c("control", "treated"), each = 2),
#'   l = c(45, 46, 50, 51),
#'   a = c(15, 14, 11, 10),
#'   b = c(10, 11, 8, 9)
#' )
#' distances <- lab_distances(samples, sample_id = sample)
#'
#' summarize_treatment_distances(
#'   distances,
#'   treatment = treatment
#' )
#'
#' @export
summarize_treatment_distances <- function(
  x,
  treatment,
  metadata = NULL,
  sample_id = NULL,
  na_rm = TRUE
) {
  treatment_quo <- rlang::enquo(treatment)
  sample_id_quo <- rlang::enquo(sample_id)
  if (inherits(x, "meatcolor_distances")) {
    distance_matrix <- as.matrix(x)
    if (is.null(metadata)) {
      metadata <- x$metadata
    }
    if (rlang::quo_is_null(sample_id_quo)) {
      sample_id_quo <- rlang::new_quosure(rlang::sym(x$sample_id))
    }
  } else {
    distance_matrix <- x
  }
  validate_distance_matrix(distance_matrix)
  if (!is.data.frame(metadata)) {
    stop(
      "`metadata` must be supplied as a data frame for a plain matrix.",
      call. = FALSE
    )
  }
  validate_flag(na_rm, "na_rm")

  if (rlang::quo_is_null(sample_id_quo)) {
    stop("`sample_id` must be supplied for a plain matrix.", call. = FALSE)
  }
  id_name <- tidy_column_name(sample_id_quo, "sample_id")
  treatment_name <- tidy_column_name(treatment_quo, "treatment")
  missing_columns <- setdiff(c(id_name, treatment_name), names(metadata))
  if (length(missing_columns) > 0L) {
    stop(
      "Missing metadata columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  metadata_ids <- as.character(metadata[[id_name]])
  if (anyNA(metadata_ids) || any(!nzchar(metadata_ids))) {
    stop("Metadata sample identifiers must not be missing or empty.", call. = FALSE)
  }
  if (anyDuplicated(metadata_ids)) {
    stop("Metadata sample identifiers must be unique.", call. = FALSE)
  }

  sample_ids <- rownames(distance_matrix)
  metadata_rows <- match(sample_ids, metadata_ids)
  if (anyNA(metadata_rows)) {
    stop(
      "Missing metadata for samples: ",
      paste(sample_ids[is.na(metadata_rows)], collapse = ", "),
      call. = FALSE
    )
  }

  treatment_column <- metadata[[treatment_name]]
  if (!is.atomic(treatment_column) || is.list(treatment_column)) {
    stop("`treatment` must identify an atomic column.", call. = FALSE)
  }
  sample_treatments <- treatment_column[metadata_rows]
  if (anyNA(sample_treatments)) {
    stop("Treatments must not be missing.", call. = FALSE)
  }
  treatment_levels <- if (is.factor(sample_treatments)) {
    levels(droplevels(sample_treatments))
  } else {
    unique(as.character(sample_treatments))
  }
  sample_treatments <- as.character(sample_treatments)

  pair_index <- which(upper.tri(distance_matrix), arr.ind = TRUE)
  if (nrow(pair_index) == 0L) {
    result <- empty_treatment_summary()
    attr(result, "treatment_levels") <- treatment_levels
    return(result)
  }

  pair_treatment_1 <- sample_treatments[pair_index[, "row"]]
  pair_treatment_2 <- sample_treatments[pair_index[, "col"]]
  first_order <- match(pair_treatment_1, treatment_levels)
  second_order <- match(pair_treatment_2, treatment_levels)
  swap <- first_order > second_order
  if (any(swap)) {
    original_first <- pair_treatment_1[swap]
    pair_treatment_1[swap] <- pair_treatment_2[swap]
    pair_treatment_2[swap] <- original_first
  }
  pair_distances <- distance_matrix[pair_index]

  rows <- list()
  row_number <- 1L
  for (first in seq_along(treatment_levels)) {
    for (second in seq.int(first, length(treatment_levels))) {
      selected <- pair_treatment_1 == treatment_levels[[first]] &
        pair_treatment_2 == treatment_levels[[second]]
      if (!any(selected)) {
        next
      }

      values <- pair_distances[selected]
      complete_values <- values[!is.na(values)]
      summarized_values <- if (na_rm) complete_values else values
      mean_distance <- if (length(summarized_values) == 0L) {
        NA_real_
      } else {
        mean(summarized_values)
      }
      sd_distance <- if (length(summarized_values) < 2L) {
        NA_real_
      } else {
        stats::sd(summarized_values)
      }

      rows[[row_number]] <- data.frame(
        treatment_1 = treatment_levels[[first]],
        treatment_2 = treatment_levels[[second]],
        mean_distance = mean_distance,
        sd_distance = sd_distance,
        n_pairs = length(complete_values),
        n_missing = sum(is.na(values)),
        stringsAsFactors = FALSE
      )
      row_number <- row_number + 1L
    }
  }

  result <- if (length(rows) == 0L) {
    empty_treatment_summary()
  } else {
    do.call(rbind, rows)
  }
  rownames(result) <- NULL
  attr(result, "treatment_levels") <- treatment_levels
  result
}

#' Plot average CIEDE2000 distance between treatments
#'
#' Produces a symmetric heatmap of mean within- and between-treatment distances
#' from a `meatcolor_distances` object or a matrix plus sample metadata.
#'
#' @inheritParams summarize_treatment_distances
#' @param show_values Logical. If `TRUE`, print mean distances in the tiles.
#' @param digits Non-negative integer number of decimal places used in labels.
#' @param low,high Colors used for low and high mean distances.
#' @param na_color Fill color for treatment combinations without usable pairs.
#' @param tile_color Border color for heatmap tiles.
#' @param title Plot title.
#' @param fill_label Fill-legend title.
#'
#' @return A ggplot object. Its data contain the symmetric treatment matrix and
#'   pair counts used in the plot.
#'
#' @examples
#' samples <- data.frame(
#'   sample = paste0("S", 1:4),
#'   treatment = rep(c("control", "treated"), each = 2),
#'   l = c(45, 46, 50, 51),
#'   a = c(15, 14, 11, 10),
#'   b = c(10, 11, 8, 9)
#' )
#' distances <- lab_distances(samples, sample_id = sample)
#'
#' plot_treatment_distances(
#'   distances,
#'   treatment = treatment
#' )
#'
#' # The S3 method provides the shortest interface.
#' plot(distances, treatment = treatment)
#'
#' @importFrom ggplot2 aes coord_equal element_text geom_text geom_tile ggplot labs scale_fill_gradient theme theme_bw
#' @export
plot_treatment_distances <- function(
  x,
  treatment,
  metadata = NULL,
  sample_id = NULL,
  na_rm = TRUE,
  show_values = TRUE,
  digits = 1,
  low = "white",
  high = "#8B0000",
  na_color = "grey90",
  tile_color = "white",
  title = "Mean CIEDE2000 Distance Between Treatments",
  fill_label = "Mean Delta E 00"
) {
  treatment_quo <- rlang::enquo(treatment)
  sample_id_quo <- rlang::enquo(sample_id)
  validate_flag(show_values, "show_values")
  if (
    !is.numeric(digits) || length(digits) != 1L || is.na(digits) ||
      !is.finite(digits) || digits < 0 || digits != floor(digits)
  ) {
    stop("`digits` must be one non-negative integer.", call. = FALSE)
  }

  summary_data <- summarize_treatment_distances(
    x,
    treatment = !!treatment_quo,
    metadata = metadata,
    sample_id = !!sample_id_quo,
    na_rm = na_rm
  )
  treatment_levels <- attr(summary_data, "treatment_levels")
  if (length(treatment_levels) == 0L) {
    stop("No treatments are available to plot.", call. = FALSE)
  }

  reverse_rows <- summary_data$treatment_1 != summary_data$treatment_2
  reverse_data <- summary_data[reverse_rows, , drop = FALSE]
  original_first <- reverse_data$treatment_1
  reverse_data$treatment_1 <- reverse_data$treatment_2
  reverse_data$treatment_2 <- original_first
  symmetric_data <- rbind(
    summary_data,
    reverse_data
  )
  display_data <- expand.grid(
    treatment_1 = treatment_levels,
    treatment_2 = treatment_levels,
    stringsAsFactors = FALSE
  )
  key <- function(first, second) paste(first, second, sep = "\034")
  matched <- match(
    key(display_data$treatment_1, display_data$treatment_2),
    key(symmetric_data$treatment_1, symmetric_data$treatment_2)
  )
  value_columns <- c("mean_distance", "sd_distance", "n_pairs", "n_missing")
  display_data[value_columns] <- symmetric_data[matched, value_columns, drop = FALSE]
  display_data$treatment_1 <- factor(
    display_data$treatment_1,
    levels = treatment_levels
  )
  display_data$treatment_2 <- factor(
    display_data$treatment_2,
    levels = rev(treatment_levels)
  )
  display_data$.distance_label <- ifelse(
    is.na(display_data$mean_distance),
    "",
    formatC(display_data$mean_distance, format = "f", digits = digits)
  )

  plot <- ggplot2::ggplot(
    display_data,
    ggplot2::aes(
      x = .data$treatment_1,
      y = .data$treatment_2,
      fill = .data$mean_distance
    )
  ) +
    ggplot2::geom_tile(color = tile_color) +
    ggplot2::scale_fill_gradient(low = low, high = high, na.value = na_color) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      x = NULL,
      y = NULL,
      fill = fill_label,
      title = title
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )

  if (show_values) {
    plot <- plot + ggplot2::geom_text(ggplot2::aes(label = .data$.distance_label))
  }

  plot
}

#' Plot CIEDE2000 treatment distances
#'
#' @param x A `meatcolor_distances` object.
#' @param y An optional treatment column. This permits the conventional
#'   `plot(x, treatment)` call.
#' @param treatment Unquoted or quoted treatment column in the stored metadata.
#' @param ... Additional arguments passed to [plot_treatment_distances()].
#'
#' @return A ggplot object.
#' @export
plot.meatcolor_distances <- function(x, y = NULL, ..., treatment = NULL) {
  treatment_quo <- rlang::enquo(treatment)
  if (rlang::quo_is_null(treatment_quo)) {
    treatment_quo <- rlang::enquo(y)
  }
  if (rlang::quo_is_null(treatment_quo)) {
    stop("`treatment` must identify a metadata column.", call. = FALSE)
  }

  plot_treatment_distances(x, treatment = !!treatment_quo, ...)
}

validate_distance_matrix <- function(distance_matrix) {
  if (
    !is.matrix(distance_matrix) || !is.numeric(distance_matrix) ||
      nrow(distance_matrix) == 0L || nrow(distance_matrix) != ncol(distance_matrix)
  ) {
    stop("`distance_matrix` must be a square numeric matrix.", call. = FALSE)
  }
  sample_ids <- rownames(distance_matrix)
  if (
    is.null(sample_ids) || is.null(colnames(distance_matrix)) ||
      !identical(sample_ids, colnames(distance_matrix)) ||
      anyNA(sample_ids) || any(!nzchar(sample_ids)) || anyDuplicated(sample_ids)
  ) {
    stop(
      "`distance_matrix` must have matching, unique sample row and column names.",
      call. = FALSE
    )
  }
  if (any(!is.finite(distance_matrix) & !is.na(distance_matrix))) {
    stop("Distances must be finite or missing.", call. = FALSE)
  }
  tolerance <- sqrt(.Machine$double.eps)
  if (any(distance_matrix < -tolerance, na.rm = TRUE)) {
    stop("Distances must be non-negative.", call. = FALSE)
  }
  diagonal <- diag(distance_matrix)
  if (any(abs(diagonal[!is.na(diagonal)]) > tolerance)) {
    stop("The diagonal of `distance_matrix` must be zero or missing.", call. = FALSE)
  }
  if (!identical(is.na(distance_matrix), is.na(t(distance_matrix)))) {
    stop("`distance_matrix` must be symmetric.", call. = FALSE)
  }
  complete <- !is.na(distance_matrix)
  if (any(abs(distance_matrix[complete] - t(distance_matrix)[complete]) > tolerance)) {
    stop("`distance_matrix` must be symmetric.", call. = FALSE)
  }
}

empty_treatment_summary <- function() {
  data.frame(
    treatment_1 = character(),
    treatment_2 = character(),
    mean_distance = numeric(),
    sd_distance = numeric(),
    n_pairs = integer(),
    n_missing = integer(),
    stringsAsFactors = FALSE
  )
}
