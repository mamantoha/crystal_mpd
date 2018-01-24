require "socket"
require "./crystal-mpd/version"

class MPD
  @version : String?

  HELLO_PREFIX = "OK MPD "
  ERROR_PREFIX = "ACK "
  SUCCESS      = "OK"
  NEXT         = "list_OK"

  getter host, port, version

  def initialize(
    @host : String = "localhost",
    @port : Int32 = 6600
  )
    connect
  end

  def connect
    reconnect unless connected?
  end

  def disconnect
    @socket.try do |socket|
      socket.close
    end

    reset
  end

  def connected?
    @socket.is_a?(Socket)
  end

  def reconnect
    @host.try do |host|
      @socket = TCPSocket.new(host, port)
      hello
    end
  end

  def reset
    @socket = nil
    @version = nil
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
