# Changelog

The version number tracks the `mcptask_runner` binary the gem ships, so the
entries below describe wrapper changes only. Binary changes are listed in the
[mcptask-releases](https://github.com/jchsoft/mcptask-releases/releases)
release notes for the same tag.

## 0.2.4

- First release. Thin Rails wrapper around the `mcptask_runner` Go binary,
  with the rake surface of the legacy `mcptask_runner` gem kept unchanged so
  migrating is a one-line Gemfile edit.
- Platform gems for `arm64-darwin`, `x86_64-darwin`, `arm64-linux`,
  `x86_64-linux` and `x64-mingw-ucrt`; the `ruby` fallback gem explains how to
  supply a binary through `MCPTASK_RUNNER_BIN`.
