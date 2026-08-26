# Changelog

The version number tracks the `mcptask_runner` binary the gem ships, so the
entries below describe wrapper changes only. Binary changes are listed in the
[mcptask-releases](https://github.com/jchsoft/mcptask-releases/releases)
release notes for the same tag.

## Unreleased

No wrapper changes. The binary change below is written down now rather than at
tag time, because tag time is exactly where the entries for 0.3.17 and 0.3.18
were lost.

Binary changes waiting for a version:

- A deploy of mcptask.online now costs one attempt instead of the working day.
  While the site is being deployed the MCP server is unreachable for minutes and
  then comes back by itself. The runner used to spend its entire recovery budget
  inside about forty seconds — a child dies in ten, five seconds between
  restarts, two restarts — so all three attempts lost the same race before the
  server could possibly be back, and the run ended with `error`. That status is
  what ends the day, so one deploy could end a day that had already completed
  eighteen tasks.

  The two situations that reach that path are now told apart where they are
  detected, rather than by reading the message afterwards. A deferred tool that
  never loaded is the child's own miss: it keeps its two fast restarts and still
  ends in an error, because it is not going to fix itself. An outage gets six
  restarts at twelve times the wait — about six minutes, which spans a deploy —
  and when that runs out it ends the way a stall does: a verdict the loop
  carries on from, the task left `in_progress` for the next triage, and no bug
  piece, because a deploy is not a defect anybody can fix. The wait keeps the
  heartbeat going, so a card watched through a deploy says the runner is waiting
  rather than falling silent.

  Like every binary fix, it reaches a host only once that host runs the new
  binary — `mcptask_runner update --self` — and until then a deploy goes on
  costing the day.

## 0.3.20

No wrapper changes. Full notes in
[mcptask-releases v0.3.20](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.20).

**Upgrading:** run `mcptask_runner update --self` on each host, and do it for
this one rather than at leisure — the fix below can only reach a runner that is
running the new binary, and the situation it fixes keeps happening until then. A
daily process picks the new copy up at its night swap, but only once that copy
is on disk. The project bump alone still changes nothing about what the 08:00
job runs.

Binary changes carried by this version:

- A piece assigned to somebody else while this runner is working it now stops
  the child, instead of being worked to the end by a runner it no longer belongs
  to. The dashboard socket has always carried both halves of an assignment —
  "given to you" cut an idle wait short, and "given to somebody else" reached
  nothing — so a task moved between two agents was picked up by its new owner
  while its old one carried on: two agents on one piece, the same branch name
  pushed twice, two sets of efforts logged. The runner now abandons the piece,
  says so, and goes back to the queue for one that is still its own. It is not a
  reason to stop the day, and the piece is deliberately not set aside: the queue
  has already stopped offering it, and it stays workable if it is handed back.
- The run log is coloured as it is read, and the file itself stays plain. The
  two lines that matter in a wall of uniform text — the ones `Warn` and `Error`
  already mark with a glyph — are painted red and yellow, a child's stderr is
  yellow, and the `[Component]` tags, cost lines and phase separators are dimmed
  so the shape of a run is visible in a scroll. Only what the runner itself
  marked is coloured; guessing a severity from the wording would be wrong on the
  day it mattered. Nothing is written to the file, which is what bug reports
  attach and what people grep. `runner-log --paint` is the same filter over
  stdin, so `tail -f any.log | runner-log --paint` works for a log read some
  other way.

## 0.3.19

**Upgrading:** `bundle update mcptask-rails-runner` in each project for the
wrapper change, and `mcptask_runner update --self` on each host for the binary
ones — the installed copy is per machine, so the project bump alone does not
change what the 08:00 job runs. Both binary changes below are prompt text sent
to the child, so they take effect on the next run the updated binary starts;
there is nothing to migrate.

- The line `Binary.install!` prints just before it hands over with `exec` is
  coloured like everything the binary prints after it: green for a first
  install and for the same version laid down again, yellow for replacing an
  older copy, for keeping a newer one, and for `MCPTASK_RUNNER_BIN` diverting
  the install. Until now it was the last grey line on the screen, sitting in
  front of a coloured wall and looking like the least important thing there
  while being the only line that reports a binary was replaced.

  The palette is a deliberate copy of the binary's own rather than a second
  opinion — `MCPTASK_RUNNER_COLOR` first and winning both ways, then
  `NO_COLOR`, then `TERM=dumb`, then whether the stream is a terminal, and on
  Windows the terminal has to advertise ANSI. Both halves of
  `rake mcptask_runner:update` now answer that question the same way, and a
  redirect or a pipe still gets exactly the bytes it got before.

Binary changes carried by this version:

- Every numbered workflow step that does real work now carries its own "LOG
  PROGRESS NOW" line, and each one names the `TaskUpdate` that closes the same
  step's todo item. A run on 2026-08-25 opened its pull request having logged
  nothing at all, while its plan moved on the dashboard the whole time: three
  anchors sat on the auto-squash spine, the seven steps between them said
  nothing about logging, and the three manual workflows had no anchor anywhere
  — only the block that sits past the last numbered step, which is the
  arrangement already known not to get read. Hanging the log on the call the
  child does make reliably is what ties the effort trail to the plan.
- The child is told to search inside the project directory and never to run
  `find /` or `find ~`. That walk enters macOS's protected folders, and the
  permission dialog it raises names mcptask_runner and blocks the call until it
  times out — at 08:02 there is nobody there to answer it. The instruction
  names where to look instead: `bundle show` / `gem which` for Ruby, `go env
  GOMODCACHE` for Go.

## 0.3.18

No wrapper changes. Full notes in
[mcptask-releases v0.3.18](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.18).

**Upgrading:** run `mcptask_runner update --self` on each host. Both changes
below are binary behaviour, and the first of them is visible in the output of
the very command that installs it — so the run that replaces the binary is
still grey, and every run after it is not.

Binary changes carried by this version:

- The install and update output is coloured, so the one row that needs a look
  no longer reads exactly like the thirty that do not: green for up-to-date
  and added, yellow for updated and force-updated, red for conflict-skipped,
  dimmed section tags, and warnings in red on stderr. It is decided per stream
  and only when the stream is really a terminal, so a pipe, a redirect and a
  launchd log get the bytes they always got; `MCPTASK_RUNNER_COLOR` and
  `NO_COLOR` override.
- A child's process group is remembered when the child starts, so anything it
  leaves behind is still reachable after it exits. A process group outlives
  its leader, but the kernel can no longer name that group once the leader has
  been reaped — and the kill path used to ask at kill time, get nothing, and
  signal a bare pid that no longer resolved. Anything a child started and then
  exited on went on running: a dev server, a backgrounded command, a watcher.
  Nothing raised, so nothing ever reported it. This had shipped in every
  version of the runner there has ever been.

## 0.3.17

No wrapper changes, and no entry was written here at the time. Full notes in
[mcptask-releases v0.3.17](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.17).

Nothing an operator can observe changed in the binary either. The release
carried one refactor — the event stream's assignment callback moved to a
setter so that a caller supplying its own stream gets it too — which leaves
production behaviour identical and exists so the path cannot break silently
under test. Everything else in it was the chaos stress harness, which does not
ship in the binary.

## 0.3.16

No wrapper changes. Full notes in
[mcptask-releases v0.3.16](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.16).

**Upgrading:** run `mcptask_runner update --self` on each host. Everything in
this release is binary behaviour and no new skills or helpers ship with it, so
plain `mcptask_runner update` has nothing to do here. The binary that runs at
08:00 lives in `~/.mcptask/bin` and is replaced by `--self`, never by
`bundle update`.

Binary changes carried by this version:

- The runner card on the dashboard is filled in rather than sparse. It names
  the binary drawing it, says how a finished run went, counts out the retries
  the CLI is riding out, links the pull request a run has just opened, and
  says what an MCP tool call is acting on instead of arriving as a bare tool
  name. A task forked inside a subagent reaches the card too, and the
  notification that ends it is no longer thrown away.
- A card whose stream goes quiet keeps saying the last thing it knew instead
  of emptying out, and the TODO list fills in on Opus and Sonnet as well.
- An idle wait ends the moment mcptask.online says this runner has been given
  a piece, rather than sitting out the rest of the interval.
- A stop on the daily quota says which quota and how many hours it means —
  `worked_today=8.2h of per_day=8h`. The hours are the user's day rather than
  this run's, so a runner that idled all morning could stop on a budget it
  never touched, and the old line gave a reader nothing to tell those apart
  with. The same line now distinguishes a spent budget from an endpoint that
  never answered, and a stop caused by a failed task no longer claims to be a
  quota stop.
- The reconnect notice in the event stream names what closed the socket.

## 0.3.15

No wrapper changes, and no entry was written here at the time. Full notes in
[mcptask-releases v0.3.15](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.15).

## 0.3.14

No wrapper changes. Full notes in
[mcptask-releases v0.3.14](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.14).

**Upgrading:** run `mcptask_runner update --self` on each host. This release
changes loop behaviour inside the binary and ships no new skills or helpers, so
plain `mcptask_runner update` has nothing to do here. The binary that runs at
08:00 lives in `~/.mcptask/bin` and is replaced by `--self`, never by
`bundle update`.

Binary changes carried by this version:

- A queue that has stayed empty for half an hour is now asked about every half
  hour rather than every five minutes. `waiting_strategy.short_wait_minutes`
  remains what the operator configured for the first rounds — it is the right
  answer in the minutes just after a task finishes — and once those short waits
  add up to one `long_wait_minutes`, the long wait takes over until there is
  work again. On the installer's 5 and 30 that is 21 idle rounds across an
  eight-hour afternoon instead of 96, and as many pairs of rows in the
  dashboard's activity feed.
- The quota check made after an empty round no longer ends the day on a silent
  `break` — the log says why the runner stopped. Daily mode's "will wait 1 hour
  before retry" names the wait it actually takes.

## 0.3.13

No wrapper changes. Full notes in
[mcptask-releases v0.3.13](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.13).

**Upgrading:** run `mcptask_runner update` in each project after the binary
upgrade — this release ships a new helper (`runner-log`) and rewritten config
sections, and nothing installs those for you.

Binary changes carried by this version:

- The loop asks `GET /api/:account/pieces/next` before paying for a triage
  session; an empty queue is `no_more_tasks` without a model. Until
  mcptask.online ships the endpoint (task #11691) the 404 falls through to
  triage exactly as before.
- The configured end of workday is the one hard stop, checked after a task
  finishes — and there is no default any more.
- The skip list outlives the process: a restart does not re-pick what today
  already declined. `failure`, `task_already_started`, `merge_failed`,
  `merge_unverified` and `out_of_scope` set the task aside for the day instead
  of stopping.
- `respect_working_hours` is read from the user profile once at startup.
- A guard of the runner's own that did not hold files a bug piece instead of
  a log line.
- `runner-log`, the helper an operator types to tail the current run; the
  install ends with a summary of every config section the runner reads.

## 0.3.12

No wrapper changes. Full notes in
[mcptask-releases v0.3.12](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.12).

**Upgrading:** run `mcptask_runner update` in each project after the binary
upgrade. Nothing does it for you, so without that step the fixes below stay
installed nowhere — the helpers in `~/.claude/bin` and the skills in each
project's `.claude/skills/` keep whatever version they already had. No `--force`
is needed, including on hosts whose skills carry a rewritten model name.

- **The guard against running the test suite directly had stopped guarding.**
  `check_test_lock` refuses a direct `bin/ci` while another agent's suite holds
  the global lock. It looked for pidfiles in a flat directory that nothing has
  written in a long time, so its "pidfile missing and the lock is over ten
  seconds old" check matched every lock there has ever been: each one read as
  stale and the command went through. The guard worked for the first ten seconds
  of a lock's life and never again. The path is now rebuilt from the lock's own
  project, the way the shell helper beside it already did it. A lock that names
  no project is no longer guessed to be dead either — a holder that cannot be
  located is not a holder that can be verified.

- **The refusal now says what to do instead.** Declining to touch a lock owned
  by another working directory was correct for a live one and a dead end for a
  dead one, and a prohibition with nowhere to go is what got the lock bypassed
  in the first place: an agent told not to interfere ran the suite unlocked.
  It now names the way out — a stale lock is reaped by `acquire` itself,
  whatever directory owns it. Ownership also compares normalised paths, so the
  same checkout reached through a symlink, a trailing slash or a subdirectory
  stops looking foreign, while a linked worktree stays correctly distinct.

- **Two failures in taking the lock, both silent.** The directory that
  serialises the moment of acquiring had no staleness handling, so an acquire
  killed midway left it behind for good and wedged every later run behind a lock
  reported as `unknown` — which the orchestrator cannot wait on, so it spun to
  its retry cap and called the lock stuck while naming nothing to delete. And a
  lockfile missing its `PID=` line killed `acquire` outright before the staleness
  check could reap it, leaving a blank error and a malformed lock that every
  retry hit again.

- **Bundled skills no longer declare a `model:`.** A model name written into
  `.claude/skills/` can only be right for one backend, and that directory is
  read by two: the runner's child process and whoever opens the same project in
  a session of their own. Whichever way it was written it was wrong for one of
  them, and wrong silently, because the CLI returns its model error as the
  skill's own result and the agent above reads that as the answer. Each fork now
  runs on its session's own model; `context: fork` is untouched, and that is
  what actually keeps a fork's output out of the parent's context.

- **A SIGTERM is not a failed attempt, so the runner announces no retry.**

## 0.3.11

No wrapper changes. Full notes in
[mcptask-releases v0.3.11](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.11).

- **A role that ignores working hours is no longer stopped by its hour goal.**
  A runner configured to work until 23:00 was being killed mid-task at 18:15,
  and the setting everyone reached for was the wrong one: `end_of_workday_hour`
  only governs how long an idle loop waits for a new task, and never touches a
  task already running. What ended the day was the daily hour quota, which reads
  `today.hour_goal` from mcptask.online and stops once the hours worked reach
  it. The `respect_working_hours` flag on the user's role reads like the switch
  that turns this off, and it never was — it decides where a logged effort lands
  on the timeline, nothing more. The quota guard now reads the flag from
  `time_status` and, when the role has opted out, neither the spent budget nor a
  zero-budget weekend stops the loop. A poll that does not answer still fails
  closed: no answer from the endpoint is not permission to run. Nothing changes
  until the server ships the field, because an absent flag keeps its old
  meaning.

- **A disabled fetch tool is a detour, not the end of the day.** Triage treated
  an unavailable piece-fetch tool as a terminal condition and ended the run,
  which turned one missing MCP tool into a whole idle day.

## 0.3.10

No wrapper changes. Full notes in
[mcptask-releases v0.3.10](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.10).

- **The bundled helpers find Ruby on a machine that does not use rvm.** A Mac
  mini managing Ruby with rbenv got the system 2.6 for every test and CI run, and
  the binstubs died before printing anything worth reading. The helper was written
  where rvm was: it looked for `.ruby-version` in the current directory only,
  probed three fixed paths under the home directory, and matched on what those
  directories were named. None of that covers the case rbenv actually fails on —
  the shell these helpers run in is neither interactive nor a login shell, and
  rbenv, asdf and mise all install themselves from a line in `~/.zshrc` that such
  a shell never reads. They now ask each manager where it keeps the pinned
  version, fall back to its documented layout when the manager itself is
  unreachable, cover rvm, rbenv, asdf, mise, chruby, frum and Homebrew alike, and
  confirm each candidate by asking that interpreter its version rather than
  trusting a directory name. Which interpreter a run got is recorded in its log
  header, and a pinned version the machine does not have says so instead of
  failing later somewhere else.

- **The shipped permission baseline no longer names one developer's home
  directory.** It granted read access to `/Users/josefchmel/.rvm` literally,
  which on anybody else's machine grants nothing. The paths are relative to the
  home directory now, and the other version managers are in the list.

## 0.3.9

No wrapper changes. Full notes in
[mcptask-releases v0.3.9](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.9).

- **A ticket the runner declines as too large no longer ends the working day.**
  Reading a bug report and concluding that it is a multi-day feature is a fair
  judgement to reach, but the only word the runner had for it was "failure" — and
  "failure" stops the loop. One such call, made 96 seconds into a run, exited the
  process at 10:17 with seven hours of the day left: exit code zero, a clean run
  in the scheduler's record, and nothing anywhere to say a day had been given up
  over one oversized ticket. The judgement now has an outcome of its own. The
  agent writes its scope assessment on the piece, logs the analysis as the work it
  was, blocks the ticket so triage stops offering it, and the loop moves to the
  next task. A second refusal of the same ticket does still stop the loop —
  that means the block did not take — and it says so rather than exiting quietly.

- **A task belonging to a different project is discarded instead of worked.** The
  runner never checked that the piece triage picked came from the project named in
  CLAUDE.md. Upstream, one runner's answer was reaching every connected client, so
  a runner installed for one project picked up another project's task and set
  about it. Triage now reports which project the piece it fetched belongs to, and
  a mismatch is thrown away.

- **One launcher log file per run, instead of one that grows forever.** Nothing
  ever truncated the per-project log: 401 MB across projects on one machine, 277 MB
  of it in a single file, and diagnosing a run meant locating its start marker
  inside all of that. Each run gets its own file now, pruned at 30 days or 500 MB
  per project, whichever bites first. Existing installs keep appending to their old
  file until install is re-run, and that file is left alone rather than deleted —
  the disk space is the operator's to reclaim.

- **The installer says which account a scheduled job will authenticate as.** On a
  host carrying more than one mcptask account, regenerating a job could silently
  swap its identity: nothing failed, nothing was logged as wrong, and the work
  landed on the wrong dashboard until somebody decoded the token by hand.

- **The bundled skills follow the mcptask parameter renames.** The MCP tools are
  moving to names that state which id form each parameter carries. The skills ship
  the new names now with the old ones kept as a transitional note, so a host that
  updates before the server change still matches whichever names its own server
  currently expects.

## 0.3.8

No wrapper changes. Full notes in
[mcptask-releases v0.3.8](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.8).

- **A run that merged its PR no longer reports none of the work it did.** The
  auto-squash prompt stated its progress-logging cadence in a block after the
  last numbered step; an agent working that fourteen-step spine for half an hour
  never came back to it. One task ran 36 minutes, completed every step, merged,
  and logged nothing — the effort only reached the dashboard because a later pass
  re-picked the task. Each milestone is now named at the step where it falls due,
  the CI-failed path gets a logging point it never had, and a resumed session
  keeps the cadence instead of losing it with the rest of the workflow.

- **The end of the working day is a setting rather than a constant.** The runner
  stopped at 18:00 no matter what; the installer now asks, and `--until` sets it
  per run.

## 0.3.7

No wrapper changes. Full notes in
[mcptask-releases v0.3.7](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.7).

- **0.3.6 only ever reached one platform — 0.3.7 is that release, delivered.**
  rubygems.org was in the middle of an outage while 0.3.6 was being pushed. The
  six platform gems go up one at a time; `aarch64-linux` landed and the next push
  got a 503, which took the rest of the release down with it. Re-running did not
  help either: rubygems refuses to repush a version that already exists, so the
  job died on the gem it had sent and never reached the five it had not. Every
  platform gets 0.3.7; on `aarch64-linux`, 0.3.6 already carries the same binary.

  The release job now asks rubygems which gems it already has and skips those, so
  a release interrupted half way can be finished by running it again.

## 0.3.6

No wrapper changes. Full notes in
[mcptask-releases v0.3.6](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.6).

- **The scheduled job stops running a binary its project has already replaced.**
  `rake mcptask_runner:*` has always installed the gem's bundled binary over
  `~/.mcptask/bin/mcptask_runner` when it was newer; the launchd/systemd job was
  the one path that skipped it, because the generated launcher execs that
  installed copy directly. An unattended host would pull main, run
  `bundle install` while working a task, never call `mcptask_runner:update`, and
  sit on a stale runner indefinitely. A scheduled run now reads the project's own
  `Gemfile.lock`, and if it names a newer wrapper than the running binary, it
  installs that gem's copy and re-runs on it.

  This is not a download. The runner still never fetches a release on its own —
  it only honours the version already merged and installed on purpose. Set
  `MCPTASK_NO_ADOPT=1` to keep a host's binary pinned regardless.

  Note the ordering: the already-installed binary is the one that decides whether
  to adopt, so a host starts keeping itself current only once it is running 0.3.6
  or later. Hosts on 0.3.5 and older need one `rake mcptask_runner:update` by hand
  first.

## 0.3.5

No wrapper changes — this release carries a new binary. Full notes in
[mcptask-releases v0.3.5](https://github.com/jchsoft/mcptask-releases/releases/tag/v0.3.5);
what a host running the scheduled job will notice:

- **A run that overflows its context now reports what it produced.** A task
  whose pull request was already open was being called `error` with "task
  exceeds token limit". That filed a bug piece for work that had shipped, and
  because the quota decider stops a day on any error, one nearly-finished task
  ended the rest of the day's runs. It now reports `overflow_pr_open`, the task
  stays in progress, and the loop carries on to the next one.
- **The session that replaces an overflowed one is told how to survive.** The
  in-process restart used to get one sentence of encouragement while the
  cross-process handoff carried the whole context budget; both now get the same
  rules, plus a measured account of where the previous session's window went —
  which file it re-read ten times, which edit kept missing.
- **The runner now logs what each attempt cost.** One `[context_cost]` line per
  attempt: tool calls, tool output in kB, files read whole, ranged reads, failed
  edits. Diagnosing the run that prompted all of the above meant grepping 1.3 MB
  of stream by hand.
- **Hosts pinned to a non-Claude model get their dashboard todo list back.** On
  third-party models behind a local proxy the child never called `TodoWrite`, so
  the card rendered empty; the instruction is now explicit for those hosts and
  stays out of the way for Claude's own models, which do it natively.

## 0.3.4

The install stops taking things away from the host it is setting up. All three
of these were in every release up to and including 0.3.3.

- **A project's own token variable survives.** `init` replaced the whole
  `mcptask-online` entry in `.mcp.json` with one hardcoding
  `Bearer ${MCPTASK_TOKEN}` — on every install, not only `--force`. A project
  naming its own variable, and so its own mcptask.online account, was quietly
  moved onto whatever account `MCPTASK_TOKEN` happened to hold. That does not
  fail: it succeeds as the wrong user, and every task, effort and bug lands on
  somebody else's dashboard, with the scheduled job carrying that token to 08:00.
- **A token living inside `.mcp.json` is no longer deleted.** The legacy gem's
  installer wrote tokens into an `env` block on the entry, which makes it the
  shape a migrating host arrives in. Replacing the entry removed the only copy —
  nothing else had it, because a token that already resolves is deliberately left
  alone — and the job then got `SET_MCPTASK_TOKEN_HERE` with nothing left to
  re-resolve, so re-running could not repair it. Such an entry is now left exactly
  as it is, and the install says so.
- **An unparseable `.mcp.json` is refused, not replaced.** It used to be treated
  as absent, which deleted every other MCP server configured in it. One trailing
  comma was enough, and a project that already runs a coding CLI with servers of
  its own is the normal case. The install now names the file and the parse error;
  `--force` moves it aside to `.mcp.json.bak` and writes a fresh one.

## 0.3.3

- The bundled skills now ask for the model the host actually has. Eight of them
  — `ci-start`, `ci-wait`, `test-start`, `test-wait`, `wait-unlock`, `discover`,
  `memory-search`, `mcptask-read` — ship declaring `model: haiku`, and on a
  project whose `models:` are pinned away from Anthropic that alias is not
  redirected by `ANTHROPIC_DEFAULT_HAIKU_MODEL`: the coding CLI resolves a
  skill's own `model:` against its built-in table, asks for
  `claude-haiku-4-5-20251001`, and gets a 404. The skill then hands the error
  text back **as its result**, which the agent above reads as the skill's answer
  and works on regardless. One host had been running that way for as long as its
  models had been pinned — no CI started, no tests run, nothing discovered — with
  every run reporting success. `install` and `update` now rewrite that line to
  the pinned `primitive`, and say which model the forks will use.
- The scheduled job's time is asked for instead of being 08:00 and unspoken.
  `--at HH:MM` or `MCPTASK_RUN_AT` answers it without a terminal; a value that is
  not a time of day is refused rather than rounded down to the default. The time
  is printed either way — it used to live in the generated file and nowhere else.
- The install says how to run the job once by hand, so the first evidence that a
  host works does not have to arrive the next weekday morning.
- On macOS a re-install boots the old job out by service target
  (`gui/$(id -u)/<label>`) rather than by plist path. The path form answers
  `Boot-out failed: 5: Input/output error` where the target form answers
  `3: No such process`, and only one of those can be acted on.

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
