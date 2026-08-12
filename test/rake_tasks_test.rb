# frozen_string_literal: true

require "test_helper"
require "rake"

class RakeTasksTest < Minitest::Test
  RAKE_FILE = File.expand_path("../lib/tasks/mcptask_runner.rake", __dir__)

  def setup
    @rake = Rake::Application.new
    Rake.application = @rake
    load RAKE_FILE

    @calls = []
    calls = @calls
    @original = McptaskRailsRunner::Binary.method(:exec!)
    McptaskRailsRunner::Binary.define_singleton_method(:exec!) { |*args| calls << args }
  end

  def teardown
    McptaskRailsRunner::Binary.define_singleton_method(:exec!, @original)
  end

  def invoke(name, *args)
    @rake[name].invoke(*args)
    @calls.last
  end

  DELEGATIONS = {
    "mcptask_runner:install" => %w[init],
    "mcptask_runner:update" => %w[update],
    "mcptask_runner:bug_report" => %w[bug-report],
    "mcptask_runner:version" => %w[version],
    "mcptask_runner:manual:once" => %w[run once],
    "mcptask_runner:manual:once_dry" => %w[run once_dry],
    "mcptask_runner:manual:today" => %w[run today],
    "mcptask_runner:manual:daily" => %w[run daily],
    "mcptask_runner:manual:review" => %w[run review],
    "mcptask_runner:manual:reviews" => %w[run reviews],
    "mcptask_runner:manual:workflow" => %w[run workflow],
    "mcptask_runner:manual:queue" => %w[run queue_manual],
    "mcptask_runner:auto:once" => %w[run once_auto_squash],
    "mcptask_runner:auto:squash:today" => %w[run today_auto_squash],
    "mcptask_runner:auto:squash:queue" => %w[run queue_auto_squash]
  }.freeze

  DELEGATIONS.each do |task_name, argv|
    define_method("test_#{task_name.tr(':', '_')}_delegates") do
      assert_equal argv, invoke(task_name)
    end
  end

  def test_manual_story_passes_id
    assert_equal %w[run story_manual --story-id 123], invoke("mcptask_runner:manual:story", "123")
  end

  def test_manual_task_passes_id
    assert_equal %w[run task_manual --task-id 42], invoke("mcptask_runner:manual:task", "42")
  end

  def test_auto_squash_story_passes_id
    assert_equal %w[run story_auto_squash --story-id 7], invoke("mcptask_runner:auto:squash:story", "7")
  end

  def test_auto_squash_task_passes_id
    assert_equal %w[run task_auto_squash --task-id 9], invoke("mcptask_runner:auto:squash:task", "9")
  end

  def test_story_without_id_raises
    assert_raises(ArgumentError) { invoke("mcptask_runner:manual:story") }
  end

  def test_story_with_garbage_id_raises
    assert_raises(ArgumentError) { invoke("mcptask_runner:manual:story", "abc") }
  end

  def test_task_with_zero_id_raises
    assert_raises(ArgumentError) { invoke("mcptask_runner:manual:task", "0") }
  end

  def test_legacy_task_names_all_present
    legacy = %w[
      mcptask_runner:install mcptask_runner:update mcptask_runner:bug_report
      mcptask_runner:manual:once mcptask_runner:manual:once_dry mcptask_runner:manual:today
      mcptask_runner:manual:daily mcptask_runner:manual:review mcptask_runner:manual:reviews
      mcptask_runner:manual:workflow mcptask_runner:manual:queue
      mcptask_runner:manual:story mcptask_runner:manual:task
      mcptask_runner:auto:once mcptask_runner:auto:squash:today mcptask_runner:auto:squash:queue
      mcptask_runner:auto:squash:story mcptask_runner:auto:squash:task
    ]
    legacy.each { |name| assert @rake.lookup(name), "missing legacy task #{name}" }
  end
end
