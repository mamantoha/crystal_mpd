require "socket"
require "log"
require "./crystal_mpd/version"
require "./crystal_mpd/command_list"
require "./crystal_mpd/command_builder"
require "./crystal_mpd/tag"
require "./crystal_mpd/filter"
require "./crystal_mpd/client"
require "./crystal_mpd/error"

module MPD
  Log = ::Log.for("mpd")
end
