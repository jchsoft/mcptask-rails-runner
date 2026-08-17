# Changelog

The version number tracks the `mcptask_runner` binary the gem ships, so the
entries below describe wrapper changes only. Binary changes are listed in the
[mcptask-releases](https://github.com/jchsoft/mcptask-releases/releases)
release notes for the same tag.

## 0.3.2

- A token `mcptask_runner:install` provisions now reaches the scheduled job it
  generates in the same run. It did not: the token was written to a shell export
  file that only the next login shell reads — and launchd reads none — so the job
  got `SET_MCPTASK_TOKEN_HERE` and refused to start at 08:00, even after
  re-running with `FORCE=1`. That took two installs and a new terminal in
  between, and nothing said so.
- A job written with a placeholder now says it **will not start**, and names both
  ways to fix it. The old wording read as a note and went unnoticed.
- Re-installing prints how to *reload* the job rather than how to activate it:
  launchd and systemd hold their own copy of a loaded job, so rewriting the file
  changes nothing — including the token — until it is reloaded.
- The install says where the run log is and how to follow it, how to stop a run
  that is going on, and how to switch the job off. On Windows the activation
  command gained `/F`, without which a re-install printed a command that fails.

## 0.3.1

- `mcptask_runner:install` no longer asks for mcptask.online credentials on a
  host whose token already resolves — from `.mcp.json` or the environment. It
  says which one it found and where, and leaves it alone; set `MCPTASK_EMAIL`
  and `MCPTASK_PASSWORD` to replace it deliberately. Where there really is no
  token, the step now says whose account it wants, that the password is
  exchanged once and never stored, which file the token lands in, and that the
  runner will not start without one.
- The release workflow waits for the Go binaries instead of failing when the two
  tags are pushed minutes apart.

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
