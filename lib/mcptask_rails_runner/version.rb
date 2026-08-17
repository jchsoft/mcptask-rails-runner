# frozen_string_literal: true

module McptaskRailsRunner
  # The gem version names the mcptask_runner binary release it carries (tag
  # v#{VERSION} in jchsoft/mcptask-releases). Bump both together.
  #
  # What it does not name is the binary the host runs at 08:00. That one is
  # installed outside every gem directory, by install and update, and a machine
  # has one of it however many projects and gem versions it carries — see
  # Binary::INSTALL_DIR. So the pin is per project and per foreground rake
  # invocation; the installed copy is per machine, and the newest binary any of
  # those projects offers is the one that stays.
  VERSION = "0.3.2"
end
