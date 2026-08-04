# MeatColor

<!-- badges: start -->
[![R-CMD-check](https://github.com/JustSplash8501/MeatColor/actions/workflows/R-CMD-check.yaml/badge.svg?branch=master)](https://github.com/JustSplash8501/MeatColor/actions/workflows/R-CMD-check.yaml)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![Version: 0.1.0](https://img.shields.io/badge/version-0.1.0-blue.svg)](https://github.com/JustSplash8501/MeatColor)
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

An example of how to use the functions in this package:
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
Of note, `plot_lab_colors()` uses the ggplot2 library to build visuals. Because of this, you can easily alter the aesthetics of the plot to fit your needs.

### Plot preview

![Example L*a*b* color plot across wet-aging durations](man/figures/mmb-plot.png)

*Source:* Main, A. J., Frink, L. M., Hernandez, M. S., O'Quinn, T. G.,
Legako, J. F., Miller, R. K., Nair, M. N., Kerth, C. R., Lancaster, J. M., &
Woerner, D. R. (2026). “Extended Beef Wet-Aging Influences on *Biceps
femoris*, *Gluteus medius* and *Semimembranosus* Palatability.” *Meat and
Muscle Biology, 10*(1), 22594, 1–19.
[https://doi.org/10.22175/mmb.22594](https://doi.org/10.22175/mmb.22594)

## Interactive teaching app

Use the hosted [LAB Color Explorer](https://0bl00z-secret.shinyapps.io/meatcolor-lab-explorer/)
as an interactive teaching tool for CIELAB color coordinates. Students can
adjust each value with a slider or numeric input and immediately compare the
coordinates with an sRGB color swatch and hexadecimal color code:

- **L\*** represents lightness, from 0 (black) to 100 (white).
- **a\*** moves from green at negative values to red at positive values.
- **b\*** moves from blue at negative values to yellow at positive values.

![LAB Color Explorer interactive teaching app](man/figures/lab-color-explorer.png)

The app also indicates whether the selected color is within the sRGB gamut,
which helps demonstrate why some CIELAB colors cannot be represented exactly
on a screen. Displayed colors are sRGB approximations and may vary with the
display and its calibration. The teaching app is hosted separately; its source
code is not included in this R package repository.

## Math Logic

A detailed explanation of the math for converting CIELAB through CIEXYZ to
sRGB can be found in the
[conversion formulation](https://github.com/JustSplash8501/MeatColor/blob/master/formulation.md).

## Contributing

Contributions are welcome! To contribute to this package:

Please also review the complete [contribution guide](CONTRIBUTING.md).

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

For questions about using MeatColor, see the [support guide](SUPPORT.md).

## Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.
