require "../src/crystal-mpd"

client = MPD::Client.new

puts "MPD host: #{client.host}"
puts "MPD port: #{client.port}"
puts "MPD version: #{client.version}"

# puts client.status
# puts client.stats
# puts client.playlistinfo
# puts client.listall
# puts client.commands
puts client.search("artist", "Linkin Park").size
# puts client.add
# puts client.repeat(false)
puts client.replay_gain_status
# puts client.update

client.disconnect
puts "MPD client status: " + (client.connected? ? "connected" : "disconnected")
puts "MPD version: #{client.version}"
