require "spec"
require "../src/crystal-mpd"

def handle_client(client)
  client.puts("OK MPD 0.19.0")
ensure
  client.close
end

def with_server(host = "localhost", port = 6600)
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
