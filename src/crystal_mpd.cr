require "socket"
require "log"
require "./crystal_mpd/version"
require "./crystal_mpd/command_list"
require "./crystal_mpd/client"
require "./crystal_mpd/error"

module MPD
  Log = ::Log.for("mpd")
end
