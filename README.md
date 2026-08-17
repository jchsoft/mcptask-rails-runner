# mcptask-rails-runner

Rails distribution of the [mcptask.online](https://mcptask.online) autonomous
runner, and the way a Rails app installs it. A thin Ruby wrapper around the
`mcptask_runner` Go binary: the gem ships the platform-specific binary inside
itself (`libexec/`) and exposes the same rake tasks as the legacy
`mcptask_runner` gem, delegating 1:1 to the CLI.

The legacy gem is retired. It gets critical fixes only, and it stays in
existence as the reference implementation the Go runner's conformance suite
measures against; everything new is written in Go. What you gain by moving:
Linux and Windows hosts, a scheduled job with no bundler in its path, and a
handful of places where the old implementation was simply wrong (its token
resolution read a different half of `.mcp.json` in each of three places, and
its stream reader died mid-run on an API error envelope).

One gem version carries exactly one binary version — `mcptask-rails-runner
X.Y.Z` contains the binary from the `vX.Y.Z` release of
[jchsoft/mcptask-releases](https://github.com/jchsoft/mcptask-releases).

`mcptask_runner:install` and `:update` copy that binary out of the gem to
`~/.mcptask/bin/mcptask_runner` and run it from there. The scheduled job runs
that copy, because a job pointing inside a gem directory dies at the next
`bundle update` — at 08:00, in a log nobody reads. So the pin is per project:
the Gemfile decides what a foreground `rake mcptask_runner:*` runs, while the
machine has one installed binary however many projects it carries, and the
newest version any of them offers is the one that stays. Install and update
print which version they wrote, and never replace a newer installed binary
with an older one.

## Requirements

- Ruby >= 3.0, Rails >= 6.0
- [Claude Code](https://claude.com/claude-code) CLI
- An mcptask.online account

## Installation

```ruby
# Gemfile
gem "mcptask-rails-runner"
```

```bash
bundle install
bundle exec rake mcptask_runner:install
```

## Migrating from the legacy mcptask_runner gem

The rake surface is identical — the migration is one Gemfile line:

```diff
- gem "mcptask_runner", git: "git@github.com:jchsoft/mcptask_runner.git"
+ gem "mcptask-rails-runner"
```

Then:

```bash
bundle install
FORCE=1 bundle exec rake mcptask_runner:install
```

Re-running install is what regenerates the scheduled job. The legacy launcher
runs `bundle exec rake` and logs the active version by grepping `Gemfile.lock`
for the old gem name — neither survives the rename, so a job left as it is
keeps working but stops recording what it ran. The regenerated one execs
`~/.mcptask/bin/mcptask_runner` directly, with no bundler in the 08:00 path.

Every `rake mcptask_runner:*` invocation and shell alias keeps working
unchanged. Your existing
`config/mcptask_runner.yml`, `.mcp.json` and `.claude/` setup are read by the
Go binary as-is. The only legacy task without a counterpart is
`mcptask_runner:prepare:permissions` — permission sync is part of
`mcptask_runner:install` now.

## Tasks

| Task | Delegates to |
|---|---|
| `mcptask_runner:install` | `mcptask_runner init` (from `~/.mcptask/bin`) |
| `mcptask_runner:update` | `mcptask_runner update` (from `~/.mcptask/bin`) |
| `mcptask_runner:bug_report` | `mcptask_runner bug-report` |
| `mcptask_runner:version` | `mcptask_runner version` |
| `mcptask_runner:manual:once` (`once_dry`, `today`, `daily`, `review`, `reviews`, `workflow`, `queue`) | `mcptask_runner run <mode>` |
| `mcptask_runner:manual:story[123]` / `manual:task[123]` | `run story_manual --story-id 123` / `run task_manual --task-id 123` |
| `mcptask_runner:auto:once` | `run once_auto_squash` |
| `mcptask_runner:auto:squash:today` (`queue`, `story[123]`, `task[123]`) | `run <mode>_auto_squash` |

`verbose=true` and `ignore_quota=true` environment variables are honored by
the binary itself, exactly as before.

## Supported platforms

Platform gems exist for `arm64-darwin`, `x86_64-darwin`, `aarch64-linux`,
`x86_64-linux` and `x64-mingw-ucrt`. On anything else bundler falls back to
the binary-less `ruby` platform gem, which fails at run time with
instructions: install the binary from
[mcptask-releases](https://github.com/jchsoft/mcptask-releases) (or via
`install.sh` / npm `@mcptask/cli`) and point `MCPTASK_RUNNER_BIN` at it. The
same variable also serves offline or air-gapped installs.

The wrapper always executes the binary through an absolute path — inside the
gem for the run tasks, `~/.mcptask/bin` for install and update — and never
through PATH: the binary shares its name with the legacy tooling, and a PATH
lookup could pick up the wrong install. `MCPTASK_RUNNER_BIN` overrides both,
and install leaves `~/.mcptask/bin` untouched while it is set.

## Development

```bash
bundle install
bundle exec rake test          # unit tests (binary resolution + task mapping)
bin/fetch-binaries             # stage release binaries into tmp/binaries/
bundle exec rake package:all   # build all platform gems into pkg/
```

## Releasing

Releases are cut by tagging: bump `lib/mcptask_rails_runner/version.rb` to
match an existing `mcptask-releases` tag, push a matching `vX.Y.Z` tag, and
the Release workflow downloads the binaries (sha256-verified), builds the
platform gems and publishes them to rubygems.org through OIDC trusted
publishing. See `.github/workflows/release.yml`.

One-time setup on rubygems.org, before the first tag can publish anything —
the gem name has to exist as a trusted-publisher entry:

1. Sign in on rubygems.org, open **Profile → Trusted publishers → Create**.
2. For a gem that has never been pushed, use **Create a pending trusted
   publisher** with gem name `mcptask-rails-runner`; for an existing gem, add
   the publisher on the gem's own page.
3. Repository owner `jchsoft`, repository name `mcptask-rails-runner`,
   workflow filename `release.yml`, environment empty.

No API key is stored anywhere: `rubygems/configure-rubygems-credentials`
exchanges the workflow's OIDC token for a short-lived credential at push time.
The same model as the npm publish in the Go repository.

## License

MIT
