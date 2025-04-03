require "spec"
require "../src/crystal_mpd"

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
    else
      # for debug purposes
      client.puts("ACK [5@0] {} unknown command `#{line}`")
    end
  end
ensure
  client.close
end

def with_server(host = "localhost", port = 6600, &)
  wants_close = Channel(Nil).new
  server = TCPServer.new(host, port)

  spawn do
    while client = server.accept?
      spawn handle_client(client)
    end
  end

  spawn do
    wants_close.receive
    server.close
  end

  Fiber.yield

  yield host, port, wants_close
end
