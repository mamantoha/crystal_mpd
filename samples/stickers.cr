require "../src/crystal_mpd"

MPD::Log.level = :debug
MPD::Log.backend = ::Log::IOBackend.new

client = MPD::Client.new

puts "MPD host: #{client.host}"
puts "MPD port: #{client.port}"
puts "MPD version: #{client.version}"

path = "world/ф/Фактично Самі/2004.Kurva Cum Back/04 Сашахуй.ogg"
# path = "world/e/Etwas Unders/2007.Etwas Unders/01 - Коматоз.ogg"

# puts client.listall

# client.sticker_set("song", path, "name1", "value1")
# client.sticker_set("song", path, "name2", "value2")
# client.sticker_set("song", path, "name3", "value3")

client.sticker_inc("song", path, "play_count", 1)
# client.sticker_dec("song", path, "play_count", 1)

# p! client.sticker_get("song", path, "name1")
# p! client.sticker_get("song", path, "play_count")
p! client.sticker_get("song", path, "undefined")

# client.sticker_delete("song", path, "test1")
# client.sticker_delete("song", path)

p! client.sticker_list("song", path)

p! client.sticker_find("song", "world", "play_count")
# p! client.sticker_find("song", "world", "name1", sort: "uri")
# p! client.sticker_find("song", "world", "name1", sort: "uri", window: 1..)

# p! client.sticker_find("song", "world", "name1", "value1")
# p! client.sticker_find("song", "world", "name1", "value", "contains")
# p! client.sticker_find("song", "world", "name1", "value", "contains", window: 1..)

# p! client.stickernames
# p! client.stickertypes
# p! client.stickernamestypes("song")

client.disconnect
