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
  group_var = "treatment",
  x_label = "Time Point",
  title = "L*a*b* Color Changes Over Time"
)
```
`plot_lab_colors()` returns a regular ggplot object, so publication styling can
be supplied directly or added with ggplot2 functions:

``` r
plot_lab_colors(
  data_summary,
  x_var = "time_point",
  group_var = "treatment",
  title = "L*a*b* Color Changes Over Time",
  subtitle = "Instrumental color by treatment",
  caption = "Rectangles show mean CIELAB coordinates",
  base_size = 10,
  border_linewidth = 0.4,
  show_values = "hex"
) +
  ggplot2::theme(plot.title.position = "plot")
```

### Plot preview

![Example L*a*b* color plot across wet-aging durations](man/figures/mmb-plot.png)

*Source:* Main, A. J., Frink, L. M., Hernandez, M. S., O'Quinn, T. G.,
Legako, J. F., Miller, R. K., Nair, M. N., Kerth, C. R., Lancaster, J. M., &
Woerner, D. R. (2026). “Extended Beef Wet-Aging Influences on *Biceps
femoris*, *Gluteus medius* and *Semimembranosus* Palatability.” *Meat and
Muscle Biology, 10*(1), 22594, 1–19.
[https://doi.org/10.22175/mmb.22594](https://doi.org/10.22175/mmb.22594)

## Hue and chroma

Use `lab_chroma()` and `lab_hue()` to calculate CIELAB chroma and hue angle
directly from a\* and b\* coordinates:

``` r
lab_chroma(a = c(18, 12), b = c(12, 8))
lab_hue(a = c(18, 12), b = c(12, 8))
```

For a data frame, `add_lab_metrics()` adds both columns and fits directly into
a dplyr pipeline:

``` r
metric_summary <- my_colorimeter_data |>
  add_lab_metrics(a_col = a, b_col = b) |>
  dplyr::group_by(treatment, time_point) |>
  dplyr::summarise(
    mean_chroma = mean(chroma, na.rm = TRUE),
    mean_hue = mean(hue, na.rm = TRUE),
    .groups = "drop"
  )
```

Quoted column names and custom output names are also supported with `a_col`,
`b_col`, `chroma_col`, and `hue_col`.

Chroma describes the distance from the neutral axis, so larger values indicate
more saturated colors. Hue is returned in degrees from 0 (inclusive) to 360
(exclusive): 0° is red, 90° is yellow, 180° is green, and 270° is blue. A
neutral color (`a* = 0`, `b* = 0`) has zero chroma and an undefined (`NA`) hue.
Set `degrees = FALSE` in `lab_hue()` to return radians instead.

## Myoglobin redox forms

Use `myoglobin_int()` with MiniScan reflectance values to estimate the relative
percentages of oxymyoglobin (OMb), deoxymyoglobin (DMb), and metmyoglobin
(MMb). The function interpolates the required 473, 525, and 572 nm values from
the instrument's 10 nm spectral output and uses 700 nm as the reference:

``` r
miniscan_data <- data.frame(
  sample = "A",
  R470 = 53.1206, R480 = 53.1206,
  R520 = 50.1187, R530 = 50.1187,
  R570 = 45.8142, R580 = 45.8142,
  R700 = 79.4328
)

myoglobin_int(miniscan_data, reflectance_scale = "percent")
```

The input data are retained and `omb_pct`, `dmb_pct`, and `mmb_pct` are
appended, so the result can continue through a dplyr pipeline. Custom column
names are supported through the wavelength-specific `_col` arguments. By
default, estimates outside 0–100% are retained with a warning rather than
silently altered.

For experiments with prepared 100% reference samples, `myoglobin_ref()` uses
the AMSA calibrated K/S method. Supply separate OMb, DMb, and MMb reference
data frames collected with the same MiniScan settings and wavelength columns:

``` r
myoglobin_ref(
  miniscan_data,
  omb_reference = omb_reference_scans,
  dmb_reference = dmb_reference_scans,
  mmb_reference = mmb_reference_scans,
  reflectance_scale = "percent"
)
```

Each reference data frame may contain replicate scans; their K/S ratios are
averaged by default or can be summarized with the median. The calibrated
estimates are independent and are not forced to sum to 100%. Use
`attr(result, "myoglobin_reference_ratios")` to inspect the calibration values
used for a result.

The equations implemented by both functions come from the *AMSA Meat Color
Measurement Guidelines*. `myoglobin_int()` implements the selected-wavelength
reflex-attenuance equations described by AMSA for estimating MMb and DMb and
calculating OMb by difference. `myoglobin_ref()` implements the AMSA calibrated
K/S isobestic-wavelength equations, which require experimentally prepared 100%
OMb, DMb, and MMb reference spectra specific to the product, instrument, and
experimental conditions.

*Reference:* American Meat Science Association. (2012). *AMSA Meat Color
Measurement Guidelines* (revised December 2012). American Meat Science
Association. [View the guidelines](https://meatscience.org/docs/default-source/publications-resources/hot-topics/2012_12_meat_clr_guide.pdf?sfvrsn=d818b8b3_0).

## CIEDE2000 color differences

Use `delta_e_2000()` to calculate perceptual color differences between paired
CIELAB measurements. Inputs are vectorized, and a length-one reference color
can be compared with several samples:

``` r
delta_e_2000(
  l1 = 45, a1 = 18, b1 = 12,
  l2 = c(45, 43, 40),
  a2 = c(18, 16, 14),
  b2 = c(12, 11, 9)
)
```

The implementation follows Sharma, Wu, and Dalal (2005) and supports the
CIEDE2000 lightness, chroma, and hue parametric weighting factors.
[https://doi.org/10.1002/col.20070](https://doi.org/10.1002/col.20070)

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

## Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.
