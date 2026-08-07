# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `:ComposePreview` renders every `@Preview` in the current buffer and opens the
  result in a browser.
- `:ComposePreviewLog` opens the log, which records each step, the Gradle command
  that ran, and the full Gradle output on failure.
- `:checkhealth compose-preview` verifies Java, the Kotlin treesitter parser, the
  external tools, and the downloaded toolchain.
- Build variants are detected from the Gradle tasks a project defines, so
  projects with product flavors work without configuration.
- `@PreviewParameter` providers are resolved and every value they produce is
  rendered as its own card.
- The built-in multipreview annotations `@PreviewLightDark`, `@PreviewFontScale`,
  `@PreviewDynamicColors` and `@PreviewScreenSizes` are expanded.
- `@Preview` attributes written as constants, hex literals or `or` expressions
  are resolved to the numbers the renderer expects.
- Gradle is retried with a Java 21+ JDK when a build fails because the project
  requires a newer JVM.
