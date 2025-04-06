class MockMPDServer
  delegate accept?, to: @server
  delegate close, to: @server

  def self.with(host = "localhost", port = 6600, & : ->)
    wants_close = Channel(Nil).new
    server = new(host, port)

    spawn do
      while client = server.accept?
        spawn server.handle_client(client)
      end
    end

    spawn do
      wants_close.receive
      server.close
    end

    Fiber.yield

    begin
      yield
    ensure
      wants_close.send(nil)
    end
  end

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
          puts_song_object(client)
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
      when .starts_with?("playlistid ")
        song_id = line.split(" ")[1].to_i

        if song_id == 54
          puts_song_object(client)
        else
          client.puts("ACK [50@0] {playlistid} No such song")
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

  def puts_song_object(client)
    client.puts("file: music/foo.mp3")
    client.puts("Last-Modified: 2021-11-17T13:51:39Z")
    client.puts("Added: 2025-03-12T11:50:56Z")
    client.puts("Format: 44100:f:2")
    client.puts("Album: Nevermind")
    client.puts("Artist: Nirvana")
    client.puts("Date: 1991")
    client.puts("Genre: Grunge")
    client.puts("Title: Smells Like Teen Spirit")
    client.puts("Track: 1")
    client.puts("Time: 218")
    client.puts("duration: 218.000")
    client.puts("Pos: 10")
    client.puts("Id: 1")
    client.puts("OK")
  end
end
