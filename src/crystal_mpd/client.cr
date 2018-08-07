module MPD
  class Client
    # :nodoc:
    alias Object = Hash(String, String)
    # :nodoc:
    alias Objects = Array(Object)
    # :nodoc:
    alias Pair = Array(String)
    # :nodoc:
    alias Pairs = Array(Pair)

    @version : String?

    HELLO_PREFIX = "OK MPD "
    ERROR_PREFIX = "ACK "
    SUCCESS      = "OK"
    NEXT         = "list_OK"

    getter host, port, version

    # Creates a new MPD client. Parses the `host`, `port`.
    #
    # ```crystal
    # client = MPD::Client.new("localhost", 6600)
    # puts client.version
    # puts client.status
    # puts client.stats
    # client.disconnect
    # ```
    #
    # This constructor will raise an exception if could not connect to MPD
    def initialize(
      @host : String = "localhost",
      @port : Int32 = 6600
    )
      @command_list = CommandList.new

      connect
    end

    def connect
      reconnect unless connected?
    end

    def reconnect
      @socket = TCPSocket.new(host, port)
      hello
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

    private def hello
      @socket.try do |socket|
        response = socket.gets(chomp: false)
        if response
          raise MPD::Error.new("Connection lost while reading MPD hello") unless response.ends_with?("\n")
          response = response.chomp
          raise MPD::Error.new("Got invalid MPD hello: #{response}") unless response.starts_with?(HELLO_PREFIX)
          @version = response[/#{HELLO_PREFIX}(.*)/, 1]
        end
      end
    end

    # https://www.musicpd.org/doc/protocol/command_lists.html
    def command_list_ok_begin
      write_command("command_list_ok_begin")

      @command_list.begin
    end

    def command_list_end
      write_command("command_list_end")

      process_command_list
      @command_list.reset
      read_line
    end

    def process_command_list
      @command_list.commands.each do |command|
        process_command_in_command_list(command)
      end
    end

    def process_command_in_command_list(command : String)
      {% for command in MPD::RETVALS %}
        if command == {{command}}
          return {{command.id}}
        end
      {% end %}
    end

    {% for command in COMMANDS %}
      {% for line in command["comment"].lines %}
        # {{line.strip.id}}
      {% end %}
      def {{command["name"].id}}(
        {% for arg in command["args"] %}
          {{arg["name"].id}} : {{arg["type"].id}},
        {% end %}
      )
      write_command(
        {{ command["name"] }},
        {% for arg in command["args"] %}
          {% if arg["type"] == "Bool" %}
            boolean({{arg["name"].id}}),
          {% else %}
            {{arg["name"].id}},
          {% end %}
        {% end %}
      )

        if @command_list.active?
          @command_list.add({{command["retval"]}})
          return
        end

        {{command["retval"].id}}
      end
    {% end %}

    private def write_command(command : String, *args)
      parts = [command]

      args.each do |arg|
        line = parse_arg(arg)

        parts << line
      end

      write_line(parts.join(' '))
    end

    private def parse_arg(arg) : String
      case arg
      when Array
        arg.size == 1 ? %{"#{arg[0]}:"} : %{"#{arg[0]}:#{arg[1]}"}
      when String
        %{"#{escape(arg)}"}
      when Int32
        %{"#{escape(arg.to_s)}"}
      else
        ""
      end
    end

    private def write_line(line : String)
      @socket.try do |socket|
        socket.puts(line)
      end
    end

    private def fetch_nothing
      line = read_line
      raise MPD::Error.new("Got unexpected return value: #{line}") unless line.nil?
    end

    private def fetch_list
      result = [] of String
      seen = nil
      read_pairs.each do |item|
        key = item[0]
        value = item[1]

        if key != seen
          if seen != nil
            raise MPD::Error.new("Expected key '#{seen}', got '#{key}'")
          end
          seen = key
        end
        result << value
      end

      result
    end

    private def fetch_object : Object
      fetch_objects.first
    end

    private def fetch_objects(delimiters = [] of String) : Objects
      result = Objects.new
      obj = Object.new

      read_pairs.each do |item|
        key = item[0]
        value = item[1]

        if delimiters.includes?(key)
          result << obj unless obj.empty?
          obj = Object.new
        end

        obj[key] = value
      end

      result << obj unless obj.empty?

      result
    end

    private def fetch_outputs
      fetch_objects(["outputid"])
    end

    private def fetch_songs
      fetch_objects(["file"])
    end

    private def fetch_database
      fetch_objects(["file", "directory", "playlist"])
    end

    def fetch_plugins
      fetch_objects(["plugin"])
    end

    def fetch_messages
      fetch_objects("channel")
    end

    private def fetch_item : String
      pairs = read_pairs
      return "" if pairs.size != 1

      pairs[0][1]
    end

    private def read_pairs : Pairs
      pairs = Pairs.new

      pair = read_pair
      while !pair.empty?
        pairs << pair
        pair = read_pair
      end

      pairs
    end

    private def read_pair : Pair
      line = read_line
      return Pair.new if line.nil?
      pair = line.split(": ", 2)

      pair
    end

    private def read_line : String?
      @socket.try do |socket|
        line = socket.gets(chomp: true)

        if line.not_nil!.starts_with?(ERROR_PREFIX)
          error = line.not_nil![/#{ERROR_PREFIX}(.*)/, 1].strip
          raise MPD::Error.new(error)
        end

        if @command_list.active?
          return if line == NEXT
          raise "Got unexpected '#{SUCCESS}' in command list" if line == SUCCESS
        end

        return if line == SUCCESS

        line
      end
    end

    private def reset
      @socket = nil
      @version = nil
    end

    private def boolean(value : Bool)
      value ? "1" : "0"
    end

    private def escape(str : String)
      str.gsub(%{\\}, %{\\\\}).gsub(%{"}, %{\\"})
    end

    {% for method in UNIMPLEMENTED_COMMANDS %}
      # :nodoc:
      def {{method.id}}
        raise NotImplementedError.new("Method {{method.id}} not yet implemented.")
      end
    {% end %}
  end
end
