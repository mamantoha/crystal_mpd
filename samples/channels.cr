require "../src/crystal_mpd"

MPD::Log.level = :debug
MPD::Log.backend = ::Log::IOBackend.new

client = MPD::Client.new

client.subscribe("test1")
client.subscribe("test2")

puts client.channels

client.sendmessage("test1", "Hello world")
client.sendmessage("test2", "Hello world 2")

puts client.readmessages
puts client.readmessages

client.disconnect
