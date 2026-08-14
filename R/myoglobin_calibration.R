#' Create a reusable myoglobin reference calibration
#'
#' Builds a validated calibration from experimentally prepared oxymyoglobin
#' (OMb), deoxymyoglobin (DMb), and metmyoglobin (MMb) reference spectra. The
#' resulting object can be reused with [stats::predict()] for
#' multiple sample data sets measured with the same instrument setup.
#'
#' @param omb_reference,dmb_reference,mmb_reference Optional data frames
#'   containing one or more replicate spectra for prepared 100 percent OMb,
#'   DMb, and MMb references. Supply all three, or use `reference_data` and
#'   `form_col` instead.
#' @param reference_data Optional single data frame containing all OMb, DMb,
#'   and MMb reference spectra.
#' @param form_col Unquoted or quoted name of the column in `reference_data`
#'   identifying the myoglobin form.
#' @param form_values Named character vector mapping the canonical names
#'   `OMb`, `DMb`, and `MMb` to values in `form_col`.
#' @param r470_col,r480_col,r520_col,r530_col,r570_col,r580_col,r610_col Names
#'   of the reflectance columns at the indicated wavelengths.
#' @param reflectance_scale Input scale shared by the reference and future
#'   sample spectra: `"percent"` or `"proportion"`.
#' @param reference_summary Function used to combine replicate reference
#'   ratios: `"mean"` or `"median"`.
#'
#' @return A `myoglobin_calibration` object containing the original reference
#'   spectra, prepared K/S ratios, summarized calibration ratios, column
#'   mappings, and calibration denominators.
#'
#' @examples
#' reference <- data.frame(
#'   R470 = 20, R480 = 20, R520 = 25, R530 = 25,
#'   R570 = 30, R580 = 30, R610 = 35
#' )
#' calibration <- myoglobin_calibration(
#'   omb_reference = transform(reference, R610 = 45),
#'   dmb_reference = transform(reference, R470 = 30, R480 = 30),
#'   mmb_reference = transform(reference, R570 = 40, R580 = 40),
#'   reflectance_scale = "percent"
#' )
#' calibration
#'
#' combined_references <- rbind(
#'   transform(reference, form = "OMb", R610 = 45),
#'   transform(reference, form = "DMb", R470 = 30, R480 = 30),
#'   transform(reference, form = "MMb", R570 = 40, R580 = 40)
#' )
#' myoglobin_calibration(
#'   reference_data = combined_references,
#'   form_col = form,
#'   reflectance_scale = "percent"
#' )
#'
#' @export
myoglobin_calibration <- function(
  omb_reference = NULL,
  dmb_reference = NULL,
  mmb_reference = NULL,
  r470_col = "R470",
  r480_col = "R480",
  r520_col = "R520",
  r530_col = "R530",
  r570_col = "R570",
  r580_col = "R580",
  r610_col = "R610",
  reflectance_scale = c("percent", "proportion"),
  reference_summary = c("mean", "median"),
  reference_data = NULL,
  form_col = NULL,
  form_values = c(OMb = "OMb", DMb = "DMb", MMb = "MMb")
) {
  reflectance_scale <- match.arg(reflectance_scale)
  reference_summary <- match.arg(reference_summary)
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

  separate_references <- list(
    OMb = omb_reference,
    DMb = dmb_reference,
    MMb = mmb_reference
  )
  form_column <- rlang::enquo(form_col)
  if (is.null(reference_data)) {
    if (!rlang::quo_is_null(form_column)) {
      stop("`form_col` requires `reference_data`.", call. = FALSE)
    }
    missing_references <- names(separate_references)[vapply(
      separate_references,
      is.null,
      logical(1)
    )]
    if (length(missing_references) > 0L) {
      stop(
        "Supply `reference_data` and `form_col`, or all of ",
        "`omb_reference`, `dmb_reference`, and `mmb_reference`.",
        call. = FALSE
      )
    }
    reference_spectra <- separate_references
  } else {
    if (any(!vapply(separate_references, is.null, logical(1)))) {
      stop(
        "Use either `reference_data` or the three separate reference data ",
        "frames, not both.",
        call. = FALSE
      )
    }
    if (rlang::quo_is_null(form_column)) {
      stop("`form_col` is required with `reference_data`.", call. = FALSE)
    }
    reference_spectra <- split_myoglobin_reference_data(
      reference_data,
      form_column,
      form_values
    )
  }

  prepared_references <- Map(
    function(reference, form) {
      prepare_ks_spectra(
        reference,
        column_args,
        reflectance_scale,
        paste0(tolower(form), "_reference")
      )
    },
    reference_spectra,
    names(reference_spectra)
  )

  reference_ratios <- Map(
    function(reference, form) {
      summarize_reference_ratios(reference, form, reference_summary)
    },
    prepared_references,
    names(prepared_references)
  )
  reference_table <- reference_ratio_table(reference_ratios, reference_summary)
  denominators <- myoglobin_calibration_denominators(reference_ratios)
  validate_calibration_denominators(denominators)

  structure(
    list(
      reference_spectra = reference_spectra,
      prepared_references = prepared_references,
      reference_ratios = reference_table,
      columns = column_args,
      reflectance_scale = reflectance_scale,
      reference_summary = reference_summary,
      denominators = denominators
    ),
    class = "myoglobin_calibration"
  )
}

split_myoglobin_reference_data <- function(data, form_column, form_values) {
  if (!is.data.frame(data)) {
    stop("`reference_data` must be a data frame.", call. = FALSE)
  }
  if (nrow(data) == 0L) {
    stop("`reference_data` must contain at least one row.", call. = FALSE)
  }

  expected_forms <- c("OMb", "DMb", "MMb")
  if (
    !is.character(form_values) || length(form_values) != 3L ||
      anyNA(form_values) || any(!nzchar(form_values)) ||
      is.null(names(form_values)) ||
      !setequal(names(form_values), expected_forms) ||
      anyDuplicated(form_values)
  ) {
    stop(
      "`form_values` must be a uniquely valued character vector named ",
      "`OMb`, `DMb`, and `MMb`.",
      call. = FALSE
    )
  }
  form_values <- form_values[expected_forms]
  form_name <- tidy_column_name(form_column, "form_col")
  if (!form_name %in% names(data)) {
    stop("Missing reference form column: ", form_name, call. = FALSE)
  }

  forms <- data[[form_name]]
  if (!is.atomic(forms) || is.list(forms)) {
    stop("`form_col` must identify an atomic column.", call. = FALSE)
  }
  forms <- as.character(forms)
  if (anyNA(forms) || any(!nzchar(forms))) {
    stop("Reference forms must not be missing or empty.", call. = FALSE)
  }
  unexpected <- setdiff(unique(forms), unname(form_values))
  if (length(unexpected) > 0L) {
    stop(
      "Unexpected reference form values: ",
      paste(unexpected, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  missing_forms <- names(form_values)[!form_values %in% forms]
  if (length(missing_forms) > 0L) {
    stop(
      "Missing reference forms: ",
      paste(missing_forms, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  references <- lapply(
    expected_forms,
    function(form) data[forms == form_values[[form]], , drop = FALSE]
  )
  names(references) <- expected_forms
  references
}

#' @rdname myoglobin_calibration
#' @param x A `myoglobin_calibration` object.
#' @param ... Additional arguments, currently ignored.
#' @export
print.myoglobin_calibration <- function(x, ...) {
  cat(
    "<myoglobin_calibration>\n",
    "Scale: ", x$reflectance_scale, "\n",
    "Reference summary: ", x$reference_summary, "\n",
    sep = ""
  )
  print(x$reference_ratios, row.names = FALSE)
  invisible(x)
}

#' Extract summarized myoglobin calibration ratios
#'
#' @param x A `myoglobin_calibration` object.
#'
#' @return A data frame containing the three summarized K/S ratios for each
#'   prepared myoglobin form.
#' @export
myoglobin_calibration_ratios <- function(x) {
  validate_myoglobin_calibration(x)
  x$reference_ratios
}

#' Apply a myoglobin calibration to sample spectra
#'
#' @param object A `myoglobin_calibration` object.
#' @param newdata A data frame containing sample reflectance spectra using the
#'   column mappings and scale stored in `object`.
#' @param bounds How estimates outside 0 to 100 percent are handled. `"warn"`
#'   retains estimates and warns, `"none"` retains them silently, and
#'   `"clamp"` restricts estimates to 0 through 100.
#' @param keep_intermediates Logical. If `TRUE`, append interpolated
#'   reflectance, K/S values, and sample K/S ratios.
#' @param ... Additional arguments, currently ignored.
#'
#' @return `newdata` with myoglobin percentage and validity columns appended.
#'   The summarized calibration ratios are retained in the
#'   `"myoglobin_reference_ratios"` attribute for compatibility with
#'   [myoglobin_ref()].
#'
#' @examples
#' # See myoglobin_calibration() for calibration construction.
#'
#' @export
predict.myoglobin_calibration <- function(
  object,
  newdata,
  bounds = c("warn", "none", "clamp"),
  keep_intermediates = FALSE,
  ...
) {
  validate_myoglobin_calibration(object)
  bounds <- match.arg(bounds)
  validate_flag(keep_intermediates, "keep_intermediates")
  sample_values <- prepare_ks_spectra(
    newdata,
    object$columns,
    object$reflectance_scale,
    "newdata"
  )

  undefined_sample <- sample_values$complete_input & !sample_values$ratio_valid
  if (any(undefined_sample)) {
    warning(
      sum(undefined_sample),
      " row(s) had undefined K/S ratios because K/S525 was zero or nearly zero.",
      call. = FALSE
    )
  }

  ratios <- split_reference_ratio_table(object$reference_ratios)
  omb_pct <- (
    ratios$MMb[["ratio_610_525"]] - sample_values$ratio_610_525
  ) / object$denominators[["OMb"]] * 100
  mmb_pct <- (
    ratios$DMb[["ratio_572_525"]] - sample_values$ratio_572_525
  ) / object$denominators[["MMb"]] * 100
  dmb_pct <- (
    ratios$OMb[["ratio_474_525"]] - sample_values$ratio_474_525
  ) / object$denominators[["DMb"]] * 100

  raw_values <- list(omb_pct = omb_pct, dmb_pct = dmb_pct, mmb_pct = mmb_pct)
  within_bounds <- do.call(
    cbind,
    lapply(raw_values, function(value) is.na(value) | (value >= 0 & value <= 100))
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
    raw_values <- lapply(raw_values, function(value) pmin(pmax(value, 0), 100))
  }

  result <- newdata
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

  attr(result, "myoglobin_reference_ratios") <- object$reference_ratios
  result
}

#' Plot myoglobin calibration diagnostics
#'
#' Shows replicate and summarized K/S ratios for each prepared reference form.
#' The returned object is a regular ggplot object and can be customized with
#' additional ggplot2 layers, scales, and themes.
#'
#' @param x A `myoglobin_calibration` object.
#' @param y Ignored; retained for compatibility with [graphics::plot()].
#' @param ... Additional arguments, currently ignored.
#' @param show_replicates Logical. If `TRUE`, display individual reference
#'   replicate ratios behind the summarized values.
#'
#' @return A ggplot object.
#' @importFrom ggplot2 aes facet_wrap geom_point ggplot labs theme_bw vars
#' @export
plot.myoglobin_calibration <- function(
  x,
  y = NULL,
  ...,
  show_replicates = TRUE
) {
  validate_myoglobin_calibration(x)
  validate_flag(show_replicates, "show_replicates")
  ratio_names <- c("ratio_474_525", "ratio_572_525", "ratio_610_525")
  replicate_data <- do.call(
    rbind,
    lapply(names(x$prepared_references), function(form) {
      reference <- x$prepared_references[[form]]
      do.call(
        rbind,
        lapply(ratio_names, function(ratio) {
          data.frame(
            form = form,
            ratio = ratio,
            value = reference[[ratio]],
            stringsAsFactors = FALSE
          )
        })
      )
    })
  )
  summary_data <- do.call(
    rbind,
    lapply(ratio_names, function(ratio) {
      data.frame(
        form = x$reference_ratios$form,
        ratio = ratio,
        value = x$reference_ratios[[ratio]],
        stringsAsFactors = FALSE
      )
    })
  )
  ratio_labels <- c(
    ratio_474_525 = "K/S 474 / K/S 525",
    ratio_572_525 = "K/S 572 / K/S 525",
    ratio_610_525 = "K/S 610 / K/S 525"
  )
  replicate_data$ratio <- factor(
    replicate_data$ratio,
    levels = ratio_names,
    labels = ratio_labels
  )
  summary_data$ratio <- factor(
    summary_data$ratio,
    levels = ratio_names,
    labels = ratio_labels
  )

  plot <- ggplot2::ggplot(
    summary_data,
    ggplot2::aes(x = .data$form, y = .data$value, color = .data$form)
  )
  if (show_replicates) {
    plot <- plot + ggplot2::geom_point(
      data = replicate_data,
      alpha = 0.45,
      position = ggplot2::position_jitter(width = 0.08, height = 0)
    )
  }
  plot +
    ggplot2::geom_point(size = 3.5, shape = 18) +
    ggplot2::facet_wrap(ggplot2::vars(.data$ratio), scales = "free_y") +
    ggplot2::labs(
      x = NULL,
      y = "K/S ratio",
      color = "Reference form",
      title = "Myoglobin Reference Calibration"
    ) +
    ggplot2::theme_bw()
}

validate_myoglobin_calibration <- function(x) {
  if (!inherits(x, "myoglobin_calibration")) {
    stop("`x` must be a `myoglobin_calibration` object.", call. = FALSE)
  }
}

reference_ratio_table <- function(reference_ratios, summary_method) {
  data.frame(
    form = names(reference_ratios),
    ratio_474_525 = vapply(
      reference_ratios, `[[`, numeric(1), "ratio_474_525"
    ),
    ratio_572_525 = vapply(
      reference_ratios, `[[`, numeric(1), "ratio_572_525"
    ),
    ratio_610_525 = vapply(
      reference_ratios, `[[`, numeric(1), "ratio_610_525"
    ),
    summary = summary_method,
    row.names = NULL
  )
}

split_reference_ratio_table <- function(reference_table) {
  ratios <- split(reference_table, reference_table$form)
  lapply(ratios, function(row) {
    unlist(row[c("ratio_474_525", "ratio_572_525", "ratio_610_525")])
  })
}

myoglobin_calibration_denominators <- function(reference_ratios) {
  c(
    OMb = reference_ratios$MMb[["ratio_610_525"]] -
      reference_ratios$OMb[["ratio_610_525"]],
    DMb = reference_ratios$OMb[["ratio_474_525"]] -
      reference_ratios$DMb[["ratio_474_525"]],
    MMb = reference_ratios$DMb[["ratio_572_525"]] -
      reference_ratios$MMb[["ratio_572_525"]]
  )
}

validate_calibration_denominators <- function(denominators) {
  indistinguishable <-
    !is.finite(denominators) |
    abs(denominators) <= sqrt(.Machine$double.eps)
  if (any(indistinguishable)) {
    stop(
      "Reference spectra do not distinguish the following myoglobin form(s): ",
      paste(names(denominators)[indistinguishable], collapse = ", "),
      ".",
      call. = FALSE
    )
  }
}
