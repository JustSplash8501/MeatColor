# MeatColor 0.1.0

- Added treatment-aware rows to `plot_lab_colors()` through `group_var`, with
  explicit detection of ambiguous overlapping observations.
- Added publication-oriented plot controls for typography, facets, borders,
  captions, and optional CIELAB or hexadecimal labels while preserving the
  ability to add ggplot2 layers with `+`.
- Added vectorized `delta_e_2000()` calculations with CIEDE2000 parametric
  weighting factors and validation against the Sharma et al. reference data.
- Added `lab_distances()` S3 objects for all-by-all CIEDE2000 comparisons,
  treatment-level distance summaries, and directly dispatched heatmaps.
- Added vectorized `lab_hue()` and `lab_chroma()` calculations plus the
  pipe-friendly `add_lab_metrics()` data-frame helper.
- Added `myoglobin_int()` to estimate relative OMb, DMb, and MMb percentages
  from MiniScan spectral reflectance using the AMSA selected-wavelength method.
- Added `myoglobin_ref()` to estimate OMb, DMb, and MMb with experiment-specific
  100% reference spectra and the AMSA calibrated K/S method.
- Added reusable `myoglobin_calibration` S3 objects with `print()`, `predict()`,
  ratio extraction, and ggplot calibration diagnostics.
- Added strict finite-value validation for CIELAB inputs and scale-aware upper
  bounds for spectral reflectance inputs.
- Updated myoglobin documentation to distinguish the legacy 2012 473-nm
  equation from the current 474-nm guidance and added the 2023 AMSA reference.

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
