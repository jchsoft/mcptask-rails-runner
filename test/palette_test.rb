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
    assert_equal "✓ installed", paint.done("installed")
    assert_equal "! replaced", paint.warning("replaced")
    assert_equal "✗ failed", paint.refusal("failed")
  end

  def test_a_terminal_gets_the_colour_the_meaning_calls_for
    paint = Palette.for(FakeTTY.new, env: {})

    assert_equal "\e[32m✓ installed\e[0m", paint.done("installed")
    assert_equal "\e[33m! replaced\e[0m", paint.warning("replaced")
    assert_equal "\e[31m✗ failed\e[0m", paint.refusal("failed")
  end

  # The Story's decided codes: orange only when the terminal says it has 256
  # colours, else the plain yellow every terminal has.
  def test_orange_when_the_terminal_reports_256_colours
    paint = Palette.for(FakeTTY.new, env: { "TERM" => "xterm-256color" })

    assert_equal "\e[38;5;208m! replaced\e[0m", paint.warning("replaced")
  end

  def test_orange_when_colorterm_is_set
    paint = Palette.for(FakeTTY.new, env: { "COLORTERM" => "truecolor" })

    assert_equal "\e[38;5;208m! replaced\e[0m", paint.warning("replaced")
  end

  def test_an_empty_colorterm_and_a_16_colour_term_get_yellow
    paint = Palette.for(FakeTTY.new, env: { "COLORTERM" => "", "TERM" => "xterm" })

    assert_equal "\e[33m! replaced\e[0m", paint.warning("replaced")
  end

  def test_the_weights
    paint = Palette.for(FakeTTY.new, env: {})

    assert_equal "\e[1mhead\e[0m", paint.bold("head")
    assert_equal "\e[2mnote\e[0m", paint.dim("note")
    assert_equal "head", Palette.for(StringIO.new, env: {}).bold("head")
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
    assert_equal "", Palette.for(FakeTTY.new, env: {}).bold("")
  end
end
