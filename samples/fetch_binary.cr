require "mime"
require "../src/crystal_mpd"

# MPD::Log.level = :debug
# MPD::Log.backend = ::Log::IOBackend.new

client = MPD::Client.new

if (song = client.currentsong)
  if (response = client.readpicture(song["file"]))
    data, binary = response

    puts data

    extension = MIME.extensions(data["type"]).first? || ".png"

    file = File.new("cover#{extension}", "w")
    file.write(binary.to_slice)
  end
end

client.disconnect
