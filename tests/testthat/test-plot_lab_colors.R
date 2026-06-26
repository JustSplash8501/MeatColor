# Test data
test_summary <- data.frame(
  product = rep(c("A", "B"), each = 3),
  time_point = rep(1:3, times = 2),
  l_mean = c(45, 47, 46, 44, 46, 45),
  a_mean = c(15, 16, 15.5, 16, 17, 16.5),
  b_mean = c(10, 11, 10.5, 11, 12, 11.5),
  color = c("#D4A89A", "#D9B0A3", "#D6AC9E", "#D2A696", "#D7AE9F", "#D4AA98")
)

test_that("plot_lab_colors returns a ggplot object", {
  p <- plot_lab_colors(test_summary, x_var = "time_point")

  expect_s3_class(p, "ggplot")
})

test_that("plot_lab_colors works without faceting", {
  p <- plot_lab_colors(test_summary, x_var = "time_point")

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
  p <- plot_lab_colors(test_summary, x_var = "time_point")

  # Check for geom_rect layer
  layer_geoms <- sapply(p$layers, function(x) class(x$geom)[1])
  expect_true("GeomRect" %in% layer_geoms)
})

test_that("plot_lab_colors uses identity scale for colors", {
  p <- plot_lab_colors(test_summary, x_var = "time_point")

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
    test_summary,
    x_var = "time_point",
    x_label = custom_x,
    title = custom_title
  )

  expect_equal(p$labels$title, custom_title)
  expect_equal(p$labels$x, custom_x)
})

test_that("plot_lab_colors can be modified with additional ggplot layers", {
  p <- plot_lab_colors(test_summary, x_var = "time_point") +
    ggplot2::labs(caption = "Test caption")

  expect_equal(p$labels$caption, "Test caption")
})

test_that("plot_lab_colors errors with missing required column", {
  bad_summary <- test_summary[, c("product", "time_point")]

  expect_error(plot_lab_colors(bad_summary, x_var = "time_point"))
})

test_that("plot_lab_colors handles factor conversion correctly", {
  test_summary_char <- test_summary
  test_summary_char$time_point <- as.character(test_summary_char$time_point)

  p <- plot_lab_colors(test_summary_char, x_var = "time_point")

  expect_s3_class(p, "ggplot")
})
