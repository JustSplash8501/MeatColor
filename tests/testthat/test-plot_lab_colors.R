# Test data
test_summary <- data.frame(
  product = rep(c("A", "B"), each = 3),
  time_point = rep(1:3, times = 2),
  l_mean = c(45, 47, 46, 44, 46, 45),
  a_mean = c(15, 16, 15.5, 16, 17, 16.5),
  b_mean = c(10, 11, 10.5, 11, 12, 11.5),
  color = c("#D4A89A", "#D9B0A3", "#D6AC9E", "#D2A696", "#D7AE9F", "#D4AA98")
)
single_summary <- test_summary[1:3, ]

test_that("plot_lab_colors returns a ggplot object", {
  p <- plot_lab_colors(single_summary, x_var = "time_point")

  expect_s3_class(p, "ggplot")
})

test_that("plot_lab_colors works without faceting", {
  p <- plot_lab_colors(single_summary, x_var = "time_point")

  expect_s3_class(p, "ggplot")
  expect_null(p$facet$params$facets)
})

test_that("plot_lab_colors works with faceting", {
  p <- plot_lab_colors(
    test_summary,
    x_var = "time_point",
    facet_var = "product"
  )

  expect_s3_class(p, "ggplot")
  expect_false(is.null(p$facet$params$facets))
})

test_that("plot_lab_colors uses correct layers", {
  p <- plot_lab_colors(single_summary, x_var = "time_point")

  # Check for geom_rect layer
  layer_geoms <- sapply(p$layers, function(x) class(x$geom)[1])
  expect_true("GeomRect" %in% layer_geoms)
})

test_that("plot_lab_colors uses identity scale for colors", {
  p <- plot_lab_colors(single_summary, x_var = "time_point")

  # Check that scale_fill_identity is used
  expect_true(
    any(c("ScaleFillIdentity", "ScaleDiscreteIdentity") %in%
      class(p$scales$get_scales("fill")))
  )
})

test_that("plot_lab_colors applies custom labels", {
  custom_title <- "My Custom Title"
  custom_x <- "My X Label"

  p <- plot_lab_colors(
    single_summary,
    x_var = "time_point",
    x_label = custom_x,
    title = custom_title
  )

  expect_equal(p$labels$title, custom_title)
  expect_equal(p$labels$x, custom_x)
})

test_that("plot_lab_colors can be modified with additional ggplot layers", {
  p <- plot_lab_colors(single_summary, x_var = "time_point") +
    ggplot2::labs(caption = "Test caption")

  expect_equal(p$labels$caption, "Test caption")
})

test_that("plot_lab_colors errors with missing required column", {
  bad_summary <- test_summary[, c("product", "time_point")]

  expect_error(plot_lab_colors(bad_summary, x_var = "time_point"))
})

test_that("plot_lab_colors handles factor conversion correctly", {
  test_summary_char <- single_summary
  test_summary_char$time_point <- as.character(test_summary_char$time_point)

  p <- plot_lab_colors(test_summary_char, x_var = "time_point")

  expect_s3_class(p, "ggplot")
})

test_that("plot_lab_colors keeps positions and labels aligned", {
  unordered <- test_summary[c(2, 1), ]

  p <- plot_lab_colors(unordered, x_var = "time_point")
  x_scale <- p$scales$get_scales("x")

  expect_equal(p$data$x_position, c(1L, 2L))
  expect_equal(x_scale$breaks, 1:2)
  expect_equal(x_scale$labels, c("2", "1"))
})

test_that("plot_lab_colors respects explicit factor order", {
  factored <- test_summary[1:2, ]
  factored$time_point <- factor(
    factored$time_point,
    levels = c("2", "1")
  )

  p <- plot_lab_colors(factored, x_var = "time_point")
  x_scale <- p$scales$get_scales("x")

  expect_equal(p$data$x_position, c(2L, 1L))
  expect_equal(x_scale$labels, c("2", "1"))
})

test_that("plot_lab_colors validates column selectors", {
  expect_error(
    plot_lab_colors(test_summary, x_var = "missing"),
    "Missing required columns: missing"
  )
  expect_error(
    plot_lab_colors(test_summary, x_var = "time_point", facet_var = "missing"),
    "Missing required columns: missing"
  )
  expect_error(
    plot_lab_colors(test_summary, x_var = c("time_point", "product")),
    "x_var"
  )
})

test_that("plot_lab_colors does not evaluate facet expressions", {
  expect_error(
    plot_lab_colors(
      test_summary,
      x_var = "time_point",
      facet_var = "stop('facet expression executed')"
    ),
    "Missing required columns"
  )
})

test_that("plot_lab_colors rejects missing x-axis values", {
  missing_x <- single_summary
  missing_x$time_point[1] <- NA

  expect_error(
    plot_lab_colors(missing_x, x_var = "time_point"),
    "Plot position columns must not contain missing values"
  )
})

test_that("plot_lab_colors separates treatment rows", {
  grouped <- test_summary
  names(grouped)[names(grouped) == "product"] <- "treatment"

  p <- plot_lab_colors(
    grouped,
    x_var = "time_point",
    group_var = "treatment",
    group_label = "Treatment"
  )
  y_scale <- p$scales$get_scales("y")

  expect_s3_class(p, "ggplot")
  expect_equal(p$data$y_position, rep(1:2, each = 3))
  expect_equal(y_scale$labels, c("A", "B"))
  expect_equal(p$labels$y, "Treatment")
})

test_that("plot_lab_colors rejects ambiguous overplotting", {
  expect_error(
    plot_lab_colors(test_summary, x_var = "time_point"),
    "Supply `group_var`"
  )

  duplicated_group <- test_summary[c(1, 1), ]
  expect_error(
    plot_lab_colors(
      duplicated_group,
      x_var = "time_point",
      group_var = "product"
    ),
    "x/facet/group combination"
  )
})

test_that("plot_lab_colors respects explicit treatment order", {
  grouped <- test_summary
  grouped$product <- factor(grouped$product, levels = c("B", "A"))

  p <- plot_lab_colors(
    grouped,
    x_var = "time_point",
    group_var = "product"
  )

  expect_equal(p$data$y_position, rep(c(2L, 1L), each = 3))
  expect_equal(p$scales$get_scales("y")$labels, c("B", "A"))
})

test_that("plot_lab_colors exposes publication controls", {
  p <- plot_lab_colors(
    test_summary,
    x_var = "time_point",
    facet_var = "product",
    subtitle = "Instrumental color",
    caption = "Mean CIELAB values",
    facet_ncol = 1,
    facet_scales = "free_x",
    border_color = "grey20",
    border_linewidth = 0.4,
    base_size = 10,
    axis_text_size = 9,
    title_size = 14,
    strip_text_size = 11
  )

  expect_equal(p$labels$subtitle, "Instrumental color")
  expect_equal(p$labels$caption, "Mean CIELAB values")
  expect_equal(p$facet$params$ncol, 1L)
  expect_equal(p$facet$params$free$x, TRUE)
  expect_equal(p$layers[[1]]$geom_params$lineend, "butt")
  expect_equal(p$layers[[1]]$aes_params$colour, "grey20")
  expect_equal(p$layers[[1]]$aes_params$linewidth, 0.4)
})

test_that("plot_lab_colors can label rectangles", {
  p_hex <- plot_lab_colors(
    single_summary,
    x_var = "time_point",
    show_values = "hex"
  )
  p_lab <- plot_lab_colors(
    single_summary,
    x_var = "time_point",
    show_values = "lab"
  )

  expect_length(p_hex$layers, 2)
  expect_equal(p_hex$layers[[2]]$data$.value_label, single_summary$color)
  expect_match(p_lab$layers[[2]]$data$.value_label[[1]], "L\\* 45.0")
})

test_that("plot_lab_colors validates publication controls", {
  expect_error(
    plot_lab_colors(single_summary, "time_point", base_size = 0),
    "font sizes"
  )
  expect_error(
    plot_lab_colors(single_summary, "time_point", border_linewidth = -1),
    "border_linewidth"
  )
  expect_error(
    plot_lab_colors(single_summary, "time_point", facet_ncol = 1.5),
    "facet_ncol"
  )
})
