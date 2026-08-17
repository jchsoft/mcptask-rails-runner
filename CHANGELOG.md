# Changelog

The version number tracks the `mcptask_runner` binary the gem ships, so the
entries below describe wrapper changes only. Binary changes are listed in the
[mcptask-releases](https://github.com/jchsoft/mcptask-releases/releases)
release notes for the same tag.

## 0.3.0

- The Go runner is the runner: this gem is the Rails distribution, and the
  legacy `mcptask_runner` gem is retired to critical fixes and its role as the
  conformance suite's reference implementation.

- The ARM Linux platform gem is named `aarch64-linux`, which is the platform
  such hosts actually resolve. 0.2.4 published it as `arm64-linux`, which
  matches nothing: every Graviton server, ARM CI runner and Docker container on
  Apple Silicon fell back to the binary-less `ruby` gem and failed at run time.
  That gem stays published and unreachable.
- `mcptask_runner:install` and `:update` copy the binary out of the gem to
  `~/.mcptask/bin/mcptask_runner` and run it from there, so the scheduled job
  they generate survives the next `bundle update` — which deletes the gem
  directory the job used to point into. They print which version they wrote and
  never replace a newer installed binary with an older one. Migrating hosts
  should re-run install once, with `FORCE=1`, to regenerate the job.

## 0.2.4

- First release. Thin Rails wrapper around the `mcptask_runner` Go binary,
  with the rake surface of the legacy `mcptask_runner` gem kept unchanged so
  migrating is a one-line Gemfile edit.
- Platform gems for `arm64-darwin`, `x86_64-darwin`, `arm64-linux`,
  `x86_64-linux` and `x64-mingw-ucrt`; the `ruby` fallback gem explains how to
  supply a binary through `MCPTASK_RUNNER_BIN`.
