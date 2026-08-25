# frozen_string_literal: true

require "test_helper"

# The palette answers one question — may this stream carry escape codes — and it
# has to answer it the same way internal/install/color.go does in the Go repo.
# The two print consecutive lines of the same command, so an operator who turned
# colour off and got half of it back would have been given a puzzle.
class PaletteTest < Minitest::Test
  Palette = McptaskRailsRunner::Palette

  def test_a_pipe_gets_the_text_and_nothing_else
    paint = Palette.for(StringIO.new, env: {})

    refute paint.enabled?
    assert_equal "installed", paint.ok("installed")
    assert_equal "replaced", paint.changed("replaced")
  end

  def test_a_terminal_gets_the_colour_the_meaning_calls_for
    paint = Palette.for(FakeTTY.new, env: {})

    assert_equal "\e[32minstalled\e[0m", paint.ok("installed")
    assert_equal "\e[33mreplaced\e[0m", paint.changed("replaced")
  end

  def test_no_color_silences_a_terminal
    refute Palette.for(FakeTTY.new, env: { "NO_COLOR" => "1" }).enabled?
  end

  # no-color.org says present *and non-empty*, and the distinction matters:
  # exporting NO_COLOR= to undo an earlier export must actually undo it.
  def test_an_empty_no_color_is_not_a_no
    assert Palette.for(FakeTTY.new, env: { "NO_COLOR" => "" }).enabled?
  end

  # The specific lever is set by somebody who knows where this output is going;
  # the general convention is not.
  def test_the_specific_lever_outranks_the_general_convention
    env = { "NO_COLOR" => "1", "MCPTASK_RUNNER_COLOR" => "always" }

    assert Palette.for(FakeTTY.new, env: env).enabled?
  end

  def test_the_specific_lever_also_says_no
    refute Palette.for(FakeTTY.new, env: { "MCPTASK_RUNNER_COLOR" => "never" }).enabled?
  end

  def test_forcing_it_on_reaches_something_that_is_not_a_terminal
    assert Palette.for(StringIO.new, env: { "MCPTASK_RUNNER_COLOR" => "1" }).enabled?
  end

  def test_a_dumb_terminal_is_left_alone
    refute Palette.for(FakeTTY.new, env: { "TERM" => "dumb" }).enabled?
  end

  # CI runs ubuntu and macos, so this branch is never taken anywhere else — and
  # the host it protects is the one that renders escape codes as literal text.
  def test_a_windows_console_has_to_say_it_renders_escape_codes
    Gem.stub(:win_platform?, true) do
      refute Palette.for(FakeTTY.new, env: {}).enabled?
      assert Palette.for(FakeTTY.new, env: { "WT_SESSION" => "abc" }).enabled?
      assert Palette.for(FakeTTY.new, env: { "MCPTASK_RUNNER_COLOR" => "1" }).enabled?
    end
  end

  def test_an_empty_string_is_never_wrapped
    assert_equal "", Palette.for(FakeTTY.new, env: {}).ok("")
  end
end
