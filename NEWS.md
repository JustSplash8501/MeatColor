# MeatColor 0.1.0

## First release

- Added `lab_to_hex()` to convert CIELAB coordinates to hexadecimal sRGB
  approximations, with explicit handling for out-of-gamut colors.
- Added `summarize_lab()` to calculate mean CIELAB coordinates across one or
  more experimental grouping variables.
- Added `plot_lab_colors()` to visualize summarized measurements as colored
  rectangles using `ggplot2`.
- Added input validation, automated tests, a getting-started vignette, and
  continuous integration across supported R versions and operating systems.
- Documented the CIELAB-to-sRGB conversion assumptions and interpretation
  limits for display colors.
