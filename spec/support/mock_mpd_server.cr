class MockMPDServer
  forward_missing_to @server

  def initialize(host, port)
    @server = TCPServer.new(host, port)
  end

  def handle_client(client : TCPSocket)
    client.puts("OK MPD 0.24.2")

    while line = client.gets
      case line
      when .starts_with?("find ")
        expression = line.split(" ", 2)[1]

        if expression == "\"(Artist == \\\"Nirvana\\\")\" "
          client.puts("file: music/foo.mp3")
          client.puts("Title: Smells Like Teen Spirit")
          client.puts("Artist: Nirvana")
          client.puts("OK")
        else
          client.puts("OK")
        end
      when .starts_with?("playid ")
        song_id = line.split(" ")[1].to_i

        if song_id == 1
          client.puts("OK")
        else
          client.puts("ACK [50@0] {playid} No such song")
        end
      when .starts_with?("status")
        client.puts("volume: 100")
        client.puts("repeat: 0")
        client.puts("random: 0")
        client.puts("single: 0")
        client.puts("consume: 0")
        client.puts("partition: default")
        client.puts("playlist: 88")
        client.puts("playlistlength: 27")
        client.puts("mixrampdb: 0")
        client.puts("lastloadedplaylist: ")
        client.puts("song: 7")
        client.puts("songid: 37")
        client.puts("time: 15:237")
        client.puts("elapsed: 14.690")
        client.puts("bitrate: 128")
        client.puts("duration: 237.253")
        client.puts("audio: 44100:f:2")
        client.puts("nextsong: 24")
        client.puts("nextsongid: 54")
        client.puts("OK")
      else
        # for debug purposes
        client.puts("ACK [5@0] {} unknown command `#{line}`")
      end
    end
  ensure
    client.close
  end
end
