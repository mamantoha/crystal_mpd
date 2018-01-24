require "../src/crystal-mpd"

client = MPD.new
client.connect
puts client.version
