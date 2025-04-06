require "spec"
require "../src/crystal_mpd"
require "./support/mock_mpd_server"

def with_server(host = "localhost", port = 6600, &)
  wants_close = Channel(Nil).new
  server = MockMPDServer.new(host, port)

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

  yield host, port, wants_close
end
