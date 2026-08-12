# Contributing to MeatColor

Contributions are welcome. Before starting substantial work, open a GitHub
issue so the proposed change and its scientific assumptions can be discussed.

## Reporting a problem

Use the [GitHub issue tracker](https://github.com/JustSplash8501/MeatColor/issues)
and include:

- a minimal reproducible example;
- the output of `sessionInfo()`;
- the expected and observed behavior; and
- relevant colorimeter settings, including color space, illuminant, and
  observer angle when the report concerns color conversion.

Do not include confidential research data or personal information. Replace
sensitive data with a small synthetic example.

## Proposing a change

1. Fork the repository and create a focused branch.
2. Restore the project development environment with `renv::restore()`.
3. Make the smallest change that addresses the issue.
4. Add or update tests and roxygen2 comments in the relevant `R/*.R` file.
5. Regenerate documentation with `roxygen2::roxygenise()`; do not edit
   `NAMESPACE` or files under `man/` directly.
6. Run `testthat::test_local()` followed by a source-package build and
   `R CMD check --as-cran`.
7. Open a pull request describing the motivation, implementation, and any
   scientific or compatibility implications.

Contributions that change numerical behavior should include independently
verifiable reference values and identify the applicable standard or source.

By contributing, you agree that your contribution will be distributed under
the project's MIT license.

## Code of Conduct

Participation in this project is governed by the
[Contributor Covenant, version 2.1](CODE_OF_CONDUCT.md).
Instances of abusive, harassing, or otherwise unacceptable behavior may be
reported privately using the maintainer email listed in the package
`DESCRIPTION` file.
