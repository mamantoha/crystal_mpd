require "socket"
require "./crystal-mpd/version"

class MPD
  @host : String?
  @port : Int32?
  @version : String?

  HELLO_PREFIX = "OK MPD "
  ERROR_PREFIX = "ACK "
  SUCCESS = "OK"
  NEXT = "list_OK"

  getter host, port, version

  def initialize

  end

  def connect(@host = "localhost", @port = 6600)
    reconnect
  end

  def reconnect
    @host.try do |host|
      @socket = TCPSocket.new(host, port)
      hello
    end
  end

  def hello
    @socket.try do |socket|
      response = socket.gets(chomp: false)
      if response
        raise "Connection lost while reading MPD hello" unless response.ends_with?("\n")
        response = response.chomp
        raise "Got invalid MPD hello: #{response}" unless response.starts_with?(HELLO_PREFIX)
        @version = response[/#{HELLO_PREFIX}(.*)/, 1]
      end
    end
  end
end
