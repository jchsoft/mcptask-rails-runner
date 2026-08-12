# mcptask-rails-runner

Rails distribution of the [mcptask.online](https://mcptask.online) autonomous
runner. A thin Ruby wrapper around the `mcptask_runner` Go binary: the gem
ships the platform-specific binary inside itself (`libexec/`) and exposes the
same rake tasks as the legacy `mcptask_runner` gem, delegating 1:1 to the CLI.

One gem version carries exactly one binary version — `mcptask-rails-runner
X.Y.Z` contains the binary from the `vX.Y.Z` release of
[jchsoft/mcptask-releases](https://github.com/jchsoft/mcptask-releases).

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

Then `bundle install` and carry on; every `rake mcptask_runner:*` invocation,
LaunchAgent and shell alias keeps working. Your existing
`config/mcptask_runner.yml`, `.mcp.json` and `.claude/` setup are read by the
Go binary as-is. The only legacy task without a counterpart is
`mcptask_runner:prepare:permissions` — permission sync is part of
`mcptask_runner:install` now.

## Tasks

| Task | Delegates to |
|---|---|
| `mcptask_runner:install` | `mcptask_runner init` |
| `mcptask_runner:update` | `mcptask_runner update` |
| `mcptask_runner:bug_report` | `mcptask_runner bug-report` |
| `mcptask_runner:version` | `mcptask_runner version` |
| `mcptask_runner:manual:once` (`once_dry`, `today`, `daily`, `review`, `reviews`, `workflow`, `queue`) | `mcptask_runner run <mode>` |
| `mcptask_runner:manual:story[123]` / `manual:task[123]` | `run story_manual --story-id 123` / `run task_manual --task-id 123` |
| `mcptask_runner:auto:once` | `run once_auto_squash` |
| `mcptask_runner:auto:squash:today` (`queue`, `story[123]`, `task[123]`) | `run <mode>_auto_squash` |

`verbose=true` and `ignore_quota=true` environment variables are honored by
the binary itself, exactly as before.

## Supported platforms

Platform gems exist for `arm64-darwin`, `x86_64-darwin`, `arm64-linux`,
`x86_64-linux` and `x64-mingw-ucrt`. On anything else bundler falls back to
the binary-less `ruby` platform gem, which fails at run time with
instructions: install the binary from
[mcptask-releases](https://github.com/jchsoft/mcptask-releases) (or via
`install.sh` / npm `@mcptask/cli`) and point `MCPTASK_RUNNER_BIN` at it. The
same variable also serves offline or air-gapped installs.

The wrapper always executes the binary through an absolute path inside the
gem, never through PATH — the binary shares its name with the legacy tooling,
and a PATH lookup could pick up the wrong install.

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
