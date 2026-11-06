# frozen_string_literal: true

module McptaskRailsRunner
  # Colour and shape for the lines this gem prints before it hands the process
  # over.
  #
  # `rake mcptask_runner:install` opens with Binary.install!'s line, and
  # everything after it is the Go binary's init screen. That screen has a fixed
  # set of line kinds (Story 14828): a green check for what is done, an orange
  # bang for an exception the run goes on after, a red cross plus the step to
  # take for one that stops it. This gem's own line is the first line of that
  # screen, so it speaks the same kinds, in the same glyphs and codes.
  #
  # The rules here are copied from internal/ansi/ansi.go and
  # internal/install/color.go in the Go repo rather than invented — same
  # colours, same levers, same "a terminal and nowhere else". Two halves of one
  # command that disagreed about what NO_COLOR means would be a puzzle, not a
  # feature.
  class Palette
    RESET  = "\e[0m"
    BOLD   = "\e[1m"
    DIM    = "\e[2m"
    RED    = "\e[31m"
    GREEN  = "\e[32m"
    YELLOW = "\e[33m"
    ORANGE = "\e[38;5;208m"

    DONE_GLYPH    = "✓"
    WARNING_GLYPH = "!"
    REFUSAL_GLYPH = "✗"

    # Values of MCPTASK_RUNNER_COLOR that settle the question, either way.
    FORCE_ON  = %w[1 true always force].freeze
    FORCE_OFF = %w[0 false never].freeze

    # Terminals that turn escape codes on for themselves and say so. A Windows
    # console renders them only once virtual-terminal processing is switched on
    # for its handle, and this gem is not going to call into Win32 for a
    # convenience — so anything not on this list gets plain text, and
    # MCPTASK_RUNNER_COLOR=1 is the way in for a console the list has not heard
    # of.
    WINDOWS_ANSI_HINTS = %w[WT_SESSION ANSICON ConEmuANSI TERM].freeze

    # for decides how one stream should be written to.
    def self.for(out, env: ENV)
      new(enabled: enabled?(out, env), orange: orange?(env))
    end

    # Orange is a 256-colour code. A terminal that does not say it has them gets
    # the yellow every terminal has, rather than a code it may render as
    # something else.
    def self.orange?(env)
      env["TERM"].to_s.include?("256color") || !env["COLORTERM"].to_s.empty?
    end

    # MCPTASK_RUNNER_COLOR is asked first and wins both ways, because it is the
    # specific answer: whoever set it knows where this output is going. NO_COLOR
    # is the general convention (no-color.org) — present and non-empty means no
    # colour, from anything.
    def self.enabled?(out, env)
      specific = env["MCPTASK_RUNNER_COLOR"].to_s.downcase
      return true if FORCE_ON.include?(specific)
      return false if FORCE_OFF.include?(specific)
      return false unless env["NO_COLOR"].to_s.empty?
      return false if env["TERM"] == "dumb"
      return false unless out.respond_to?(:tty?) && out.tty?

      Gem.win_platform? ? WINDOWS_ANSI_HINTS.any? { |name| !env[name].to_s.empty? } : true
    end

    def initialize(enabled:, orange: false)
      @enabled = enabled
      @orange = orange
    end

    def enabled?
      @enabled
    end

    # done — this happened, or is already the state you wanted.
    def done(text)
      wrap(GREEN, "#{DONE_GLYPH} #{text}")
    end

    # warning — something is not as expected, and the run goes on.
    def warning(text)
      wrap(@orange ? ORANGE : YELLOW, "#{WARNING_GLYPH} #{text}")
    end

    # refusal — the run has stopped; the text carries the step to take.
    def refusal(text)
      wrap(RED, "#{REFUSAL_GLYPH} #{text}")
    end

    def bold(text)
      wrap(BOLD, text)
    end

    def dim(text)
      wrap(DIM, text)
    end

    private

    def wrap(code, text)
      return text unless @enabled && !text.empty?

      "#{code}#{text}#{RESET}"
    end
  end
end
