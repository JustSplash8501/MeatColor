# MeatColor 0.1.0

- Added treatment-aware rows to `plot_lab_colors()` through `group_var`, with
  explicit detection of ambiguous overlapping observations.
- Added publication-oriented plot controls for typography, facets, borders,
  captions, and optional CIELAB or hexadecimal labels while preserving the
  ability to add ggplot2 layers with `+`.
- Added vectorized `delta_e_2000()` calculations with CIEDE2000 parametric
  weighting factors and validation against the Sharma et al. reference data.

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
