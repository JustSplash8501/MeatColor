# MeatColor

<!-- badges: start -->
[![R-CMD-check](https://github.com/JustSplash8501/MeatColor/workflows/R-CMD-check/badge.svg)](https://github.com/JustSplash8501/MeatColor/actions) 
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental) 
[![CRAN status](https://www.r-pkg.org/badges/version/MeatColor)](https://CRAN.R-project.org/package=MeatColor) 
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

The goal of MeatColor is to simplify the visualization of colorimeter data for research purposes.

## Installation

You can install the development version of MeatColor from [GitHub](https://github.com/JustSplash8501/MeatColor) with:
``` r
# install.packages("pak")
pak::pak("JustSplash8501/MeatColor")
```

## Example

This is a basic example which shows you how to solve a common problem:
``` r
library(MeatColor)

# Summarize LAB color data by grouping variables
data_summary <- summarize_lab(
  data = my_colorimeter_data,
  group_vars = c("treatment", "time_point")
)

# Create visualization
plot_lab_colors(
  data = data_summary,
  x_var = "time_point",
  facet_var = "treatment",
  x_label = "Time Point",
  title = "L*a*b* Color Changes Over Time"
)
```

## Contributing

Contributions are welcome! To contribute to this package:

1. **Fork the repository** - Click the "Fork" button at the top right of the [GitHub page](https://github.com/JustSplash8501/MeatColor)

2. **Clone your fork** locally:
```bash
   git clone https://github.com/YOUR_USERNAME/MeatColor.git
   cd MeatColor
```

3. **Create a new branch** for your feature or bug fix:
```bash
   git checkout -b my-new-feature
```

4. **Make your changes** and commit them:
```bash
   git add .
   git commit -m "Add new feature"
```

5. **Push to your fork**:
```bash
   git push origin my-new-feature
```

6. **Submit a Pull Request** - Go to the original repository and click "New Pull Request"

### Development Guidelines

- Write tests for new functions using `testthat`
- Document all functions using roxygen2 comments
- Run `devtools::check()` before submitting to ensure the package builds cleanly
- Follow the existing code style

### Reporting Issues

Found a bug or have a feature request? Please [open an issue](https://github.com/JustSplash8501/MeatColor/issues) on GitHub.

## Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.
