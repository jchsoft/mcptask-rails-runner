# frozen_string_literal: true

module McptaskRailsRunner
  # Colour for the lines this gem prints before it hands the process over.
  #
  # `rake mcptask_runner:update` opens with Binary.install!'s line, and
  # everything after it comes from the Go binary, which since 0.3.18 colours its
  # own output by meaning: green when there was nothing to do, yellow when
  # something moved, red when something is waiting on a decision. A grey first
  # line in front of that wall reads as the least important thing on the screen,
  # when it is in fact the only one that replaced a binary.
  #
  # The rules here are copied from internal/install/color.go in the Go repo
  # rather than invented — same colours, same two environment levers, same "a
  # terminal and nowhere else". Two halves of one command that disagreed about
  # what NO_COLOR means would be a puzzle, not a feature.
  class Palette
    RESET  = "\e[0m"
    GREEN  = "\e[32m"
    YELLOW = "\e[33m"

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
      new(enabled: enabled?(out, env))
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

    def initialize(enabled:)
      @enabled = enabled
    end

    def enabled?
      @enabled
    end

    # ok — this is the state you wanted; nothing to read closely.
    def ok(text)
      wrap(GREEN, text)
    end

    # changed — something moved, or what you assumed would happen did not.
    def changed(text)
      wrap(YELLOW, text)
    end

    private

    def wrap(code, text)
      return text unless @enabled && !text.empty?

      "#{code}#{text}#{RESET}"
    end
  end
end
