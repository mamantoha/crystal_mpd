require "mime"
require "../src/crystal_mpd"

# MPD::Log.level = :debug
# MPD::Log.backend = ::Log::IOBackend.new

mpd = MPD::Client.new

puts mpd.count("(genre != 'Pop')", group: "artist")
puts mpd.count("(genre == 'Rock')")
