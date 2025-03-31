require "../src/crystal_mpd"

MPD::Log.level = :debug
MPD::Log.backend = ::Log::IOBackend.new

client = MPD::Client.new

puts "MPD host: #{client.host}"
puts "MPD port: #{client.port}"
puts "MPD version: #{client.version}"

# puts client.status
puts client.currentsong
# puts client.stats
# puts client.config
# puts client.list("Artist")

# https://www.musicpd.org/doc/html/protocol.html#client-to-client
# puts client.subscribe("test")
# puts client.channels
# puts client.sendmessage("test", "Hello from Crystal!")
# puts client.readmessages
# puts client.unsubscribe("test")

# puts client.decoders
# puts client.urlhandlers
# puts client.delete(0..2)
# puts client.delete(..2) # 0:3
# puts client.delete(0...2) # 0:2
# puts client.delete(10..-1) # 10:
# puts client.delete(10..) # 10:
# puts client.delete(10...) # 10:
# puts client.playlistinfo(1)
# puts client.playlistinfo(0..1) # 0:2
# puts client.playlistinfo(0...1) # 0:1
# puts client.playlistinfo(10..-1) # 10:
# puts client.playlistinfo(10...-1) # 10:
# puts client.playlistinfo(1)
# puts client.listall("world/z")
# puts client.listall
# puts client.listallinfo
# puts client.listallinfo("world/z")
# puts client.lsinfo
# puts client.lsinfo("world/z")
# puts client.listfiles
# puts client.listfiles("world/z")
# puts client.commands
# puts client.notcommands
# puts client.rename("test", "new_test")
# puts client.save("test")
# puts client.rm("test")
# puts client.listplaylists
# client.playlistclear("test")
# puts client.playlistlength("test")
# puts client.listplaylist("test")
# puts client.playlistdelete("test", 0)
# puts client.listplaylistinfo("test")
# puts client.searchplaylist("test", "(artist == 'Фактично Самі')", window: 0..2)
# puts client.playlistid
# puts client.playlistid(2121)
# client.playlistadd("test", "world/0-9/5Diez/2009.Пандемия/03 Спрут.ogg")
# puts client.shuffle(1..10)
# puts client.shuffle
# puts client.move(1..3, 10)
# puts client.move(10, 0)
# puts client.outputs
# puts client.tagtypes
# client.protocol_enable("hide_playlists_in_root")
# client.protocol_disable("hide_playlists_in_root")
# puts client.protocol_clear
# puts client.protocol_all
# puts client.protocol
# puts client.protocol_available
# puts client.search("(any =~ 'crystal')")
# client.prioid(100, 10)
# client.prio(255, 1..2)
# puts client.find("(artist == 'Порнофильмы')")
# puts client.clear
# puts client.findadd("(genre == 'Alternative Rock')")
# puts client.add("world/a")
# puts client.repeat(false)
# puts client.random(true)
# puts client.consume(false)
# client.replay_gain_mode("album")
# puts client.replay_gain_status
# puts client.update
# puts client.update("world/z")
# puts client.next
# puts client.previous
# puts client.pause
# puts client.stop
# puts client.single(false)
# puts client.play
# puts client.play(2)
# puts client.playid(13)
# puts client.seekcur(20)
# puts client.seekcur("-10")
# puts client.seekid(13, 45)
# puts client.seek(3, 45)
# puts client.list("album", "(artist == 'Linkin Park')")
# puts client.list("Genre")
# client.searchadd("(artist == 'Otep')")
# puts client.list("Artist")
# puts client.list("filename", "((artist == 'Linkin Park') AND (date == '2003'))")
# puts client.count("((artist == 'Linkin Park') AND (date == '2003'))")
# puts client.count("title", "Echoes")

puts "MPD client status: " + (client.connected? ? "connected" : "disconnected")
puts "MPD version: #{client.version}"

client.disconnect
