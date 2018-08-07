require "../src/crystal_mpd"

client = MPD::Client.new

puts "MPD host: #{client.host}"
puts "MPD port: #{client.port}"
puts "MPD version: #{client.version}"

# puts client.status
# puts client.stats
# puts client.config
# puts client.subscribe("test")
# puts client.sendmessage("test", "Hello from Crystal!")
# puts client.readmessages
# puts client.unsubscribe("test")
# puts client.channels
# puts client.decoders
# puts client.urlhandlers
# puts client.delete([0, 2])
# puts client.playlistinfo(1)
# puts client.playlistsearch("title", "All Around Me")
# puts client.playlistfind("title", "All Around Me")
# puts client.playlistinfo([10,])
# puts client.playlistinfo(1)
# puts client.listall("world/z")
# puts client.update("world/z")
# puts client.listall
# puts client.listallinfo
# puts client.listallinfo("world/z")
# puts client.lsinfo
# puts client.lsinfo("world/z")
# puts client.listfiles
# puts client.listfiles("world/z")
# puts client.commands
# puts client.rename("test", "new_test")
# puts client.save("test")
# puts client.rm("test")
# puts client.listplaylists
# client.playlistclear("test")
# client.searchaddpl("test", "Artist", "Otep")
# puts client.listplaylist("test")
# puts client.playlistdelete("test", 0)
# puts client.listplaylistinfo("test")
# puts client.playlist
# puts client.playlistid
# puts client.playlistid(158)
# client.playlistadd("test", "world/0-9/5Diez/2009.Пандемия/03 Спрут.ogg")
# puts client.outputs
# puts client.tagtypes
# puts client.search("artist", "Linkin Park").size
# puts client.find("artist", "Порнофильмы")
# puts client.clear
# puts client.findadd("genre", "Alternative Rock")
# puts client.add
# puts client.repeat(false)
# puts client.random(true)
# client.replay_gain_mode("album")
# puts client.replay_gain_status
# puts client.update
# puts client.next
# puts client.previous
# puts client.pause(false)
# puts client.stop
# puts client.play
# puts client.play(2)
# puts client.playid(13)
# puts client.seekcur(20)
# puts client.seekcur("+10")
# puts client.seekid(13, 45)
# puts client.seek(3, 45)
# puts client.list("album", "Linkin Park")
# puts client.list("Genre")
# client.searchadd("Artist", "Otep")

puts "MPD client status: " + (client.connected? ? "connected" : "disconnected")
puts "MPD version: #{client.version}"

client.disconnect
