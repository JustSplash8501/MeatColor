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
2. Make the smallest change that addresses the issue.
3. Add or update tests and documentation.
4. Run `devtools::document()`, `devtools::test()`, and
   `devtools::check(args = "--as-cran")`.
5. Open a pull request describing the motivation, implementation, and any
   scientific or compatibility implications.

Contributions that change numerical behavior should include independently
verifiable reference values and identify the applicable standard or source.

By contributing, you agree that your contribution will be distributed under
the project's MIT license.

## Code of Conduct

Participation in this project is governed by the
[Contributor Covenant, version 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).
Instances of abusive, harassing, or otherwise unacceptable behavior may be
reported privately using the maintainer email listed in the package
`DESCRIPTION` file.
