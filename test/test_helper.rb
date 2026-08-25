# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "stringio"
require "mcptask_rails_runner"

# A capture buffer that claims to be a terminal, which is the only way to see
# what a terminal would have been sent. A plain StringIO answers false, and that
# is what keeps every other test in this suite asserting on plain text.
class FakeTTY < StringIO
  def tty?
    true
  end
end

module ColourEnv
  # Runs the block with the colour levers cleared, so a variable exported in the
  # developer's own shell cannot decide whether these tests pass.
  def with_colour_env(overrides = {})
    names = %w[MCPTASK_RUNNER_COLOR NO_COLOR TERM]
    saved = names.to_h { |name| [name, ENV[name]] }
    names.each { |name| ENV.delete(name) }
    overrides.each { |name, value| ENV[name] = value }
    yield
  ensure
    saved.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end
end
