# frozen_string_literal: true

# Rake surface kept identical to the legacy mcptask_runner gem, so migrating
# a customer is only a Gemfile line swap. Every task delegates 1:1 to the
# bundled Go CLI via Kernel#exec — the binary's exit code and signal handling
# reach the caller unchanged, and nothing runs after the delegation line.
#
# Two of them delegate to the installed copy instead of the bundled one. install
# and update are the tasks that generate the scheduled job, and the job runs
# whichever binary generated it: pointing it inside this gem would have it die
# at the next `bundle update`, which deletes that directory. Everything else
# runs the binary the Gemfile pins, which is what a foreground rake invocation
# should do.

require "mcptask_rails_runner"

namespace :mcptask_runner do
  desc "Install skills, permissions, token and scheduled job into this project"
  task :install do
    McptaskRailsRunner::Binary.exec_installed!("init")
  end

  desc "Refresh bundled skills and helpers"
  task :update do
    McptaskRailsRunner::Binary.exec_installed!("update")
  end

  desc "File a bug against the project with the last run log attached"
  task :bug_report do
    McptaskRailsRunner::Binary.exec!("bug-report")
  end

  desc "Print runner version and resolved configuration"
  task :version do
    McptaskRailsRunner::Binary.exec!("version")
  end

  namespace :manual do
    {
      once: "once",
      once_dry: "once_dry",
      today: "today",
      daily: "daily",
      review: "review",
      reviews: "reviews",
      workflow: "workflow",
      queue: "queue_manual"
    }.each do |task_name, mode|
      desc "Run the work loop in #{mode} mode"
      task task_name do
        McptaskRailsRunner::Binary.exec!("run", mode)
      end
    end

    desc "Work a single story in manual mode"
    task :story, [:story_id] do |_t, args|
      id = McptaskRailsRunner.piece_id!(args[:story_id], "story_id", "mcptask_runner:manual:story[123]")
      McptaskRailsRunner::Binary.exec!("run", "story_manual", "--story-id", id)
    end

    desc "Work a single task in manual mode"
    task :task, [:task_id] do |_t, args|
      id = McptaskRailsRunner.piece_id!(args[:task_id], "task_id", "mcptask_runner:manual:task[123]")
      McptaskRailsRunner::Binary.exec!("run", "task_manual", "--task-id", id)
    end
  end

  namespace :auto do
    desc "Run the work loop in once_auto_squash mode"
    task :once do
      McptaskRailsRunner::Binary.exec!("run", "once_auto_squash")
    end

    namespace :squash do
      desc "Run the work loop in today_auto_squash mode"
      task :today do
        McptaskRailsRunner::Binary.exec!("run", "today_auto_squash")
      end

      desc "Run the work loop in queue_auto_squash mode"
      task :queue do
        McptaskRailsRunner::Binary.exec!("run", "queue_auto_squash")
      end

      desc "Work a single story in auto-squash mode"
      task :story, [:story_id] do |_t, args|
        id = McptaskRailsRunner.piece_id!(args[:story_id], "story_id", "mcptask_runner:auto:squash:story[123]")
        McptaskRailsRunner::Binary.exec!("run", "story_auto_squash", "--story-id", id)
      end

      desc "Work a single task in auto-squash mode"
      task :task, [:task_id] do |_t, args|
        id = McptaskRailsRunner.piece_id!(args[:task_id], "task_id", "mcptask_runner:auto:squash:task[123]")
        McptaskRailsRunner::Binary.exec!("run", "task_auto_squash", "--task-id", id)
      end
    end
  end
end
