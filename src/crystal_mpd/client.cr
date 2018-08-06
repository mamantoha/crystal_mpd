module MPD
  struct CommandList
    property commands = [] of String
    property active : Bool = false

    def add(command : String)
      @commands << command
    end

    def begin
      @active = true
    end

    def reset
      @commands.clear
      @active = false
    end

    def active? : Bool
      @active
    end
  end

  class Client
    alias Object = Hash(String, String)
    alias Objects = Array(Object)
    alias Pair = Array(String)
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
    end

    def process_command_list
      @command_list.commands.each do |command|
        process_command_in_command_list(command)
      end
    end

    def process_command_in_command_list(command : String)
      read_line
    end

    # Adds the file `uri` to the playlist (directories add recursively).
    #
    # `uri` can also be a single file.
    def add(uri : String)
      write_command("add", uri)

      if @command_list.active?
        @command_list.add("fetch_nothing")
        return
      end

      fetch_nothing
    end

    UNIMPLEMENTED_METHODS = [
      "add", "addid", "addtagid",
      "channels", "clearerror", "cleartagid",
      "config", "count", "crossfade",
      "decoders", "delete", "deleteid", "disableoutput",
      "enableoutput",
      "idle",
      "kill",
      "listallinfo", "listfiles", "listmounts", "listplaylist",
      "listplaylistinfo", "listplaylists", "load", "lsinfo",
      "mixrampdb", "mixrampdelay", "mount", "move", "moveid",
      "password", "ping", "playlist", "playlistadd",
      "playlistclear", "playlistdelete", "playlistid",
      "playlistmove", "plchanges", "plchangesposid",
      "prio", "prioid",
      "rangeid", "readcomments", "readmessages", "rename",
      "replay_gain_mode", "rescan", "rm",
      "save", "searchaddpl",
      "sendmessage", "setvol", "shuffle",
      "sticker", "subscribe", "swap", "swapid",
      "toggleoutput",
      "unmount", "unsubscribe", "urlhandlers",
      "volume",
    ]

    # Closes the connection to MPD.
    def close
      write_command("close")
    end

    # Shows information about all outputs.
    def outputs
      write_command("outputs")

      fetch_outputs
    end

    # Plays next song in the playlist.
    def next
      write_command("next")

      fetch_nothing
    end

    # Toggles pause/resumes playing, `pause` is `true` or `false`.
    def pause(pause : Bool)
      write_command("pause", boolean(pause))

      fetch_nothing
    end

    # Plays previous song in the playlist.
    def previous
      write_command("previous")

      fetch_nothing
    end

    # Stops playing.
    def stop
      write_command("stop")

      fetch_nothing
    end

    # Begins playing the playlist at song number `songpos`.
    def play(songpos : Int32? = nil)
      write_command("play", songpos)

      fetch_nothing
    end

    # Begins playing the playlist at song `songid`
    def playid(songid : Int32)
      write_command("playid", songid)

      fetch_nothing
    end

    # Seeks to the position `time` within the current song.
    # If prefixed by `+` or `-`, then the time is relative to the current playing position.
    def seekcur(time : String | Int32)
      write_command("seekcur", time)

      fetch_nothing
    end

    # Seeks to the position `time` (in seconds) of song `songid`
    def seekid(songid : Int32, time : Int32)
      write_command("seekid", songid, time)

      fetch_nothing
    end

    # Seeks to the position `time` (in seconds) of entry `songpos` in the playlist.
    def seek(songpos : Int32, time : Int32)
      write_command("seek", songpos, time)

      fetch_nothing
    end

    # Shows which commands the current user has access to.
    def commands
      write_command("commands")

      fetch_list
    end

    # Shows which commands the current user does not have access to.
    def notcommands
      write_command("notcommands")

      fetch_list
    end

    # Shows a list of available song metadata.
    def tagtypes
      write_command("tagtypes")

      fetch_list
    end

    # Lists all tags of the specified `type`. `type` can be any tag supported by MPD or file.
    #
    # `artist` is an optional parameter when `type` is "album", this specifies to list albums by an `artist`.
    def list(type : String, artist : String? = nil)
      write_command("list", type, artist)

      fetch_list
    end

    # Lists all songs and directories in `uri`
    def listall(uri : String?)
      write_command("listall", uri)

      fetch_objects(["file", "directory", "playlist"])
    end

    # Clears the current playlist.
    def clear
      write_command("clear")

      fetch_nothing
    end

    # Displays a list of all songs in the playlist, or if the optional argument is given,
    # displays information only for the song `songpos` or the range of songs `START:END`.
    #
    # Range is done in by using two element array.
    #
    # Show info about the first three songs in the playlist:
    #
    # ```crystal
    # client.playlistinfo([1, 3])
    # ```
    #
    # Second element of the `Array` can be omitted. `MPD` will assumes the biggest possible number then:
    #
    # ```crystal
    # client.playlistinfo([10])
    # ```
    def playlistinfo(songpos : Int32 | Array(Int32) | Nil = nil)
      write_command("playlistinfo", songpos)

      fetch_objects(["file"])
    end

    # Searches case-sensitively for partial matches in the current playlist.
    def playlistsearch(tag : String, needle : String)
      write_command("playlistsearch", tag, needle)

      fetch_objects(["file"])
    end

    # Finds songs in the current playlist with strict matching.
    def playlistfind(tag : String, needle : String)
      write_command("playlistfind", tag, needle)

      fetch_objects(["file"])
    end

    # Finds songs in the db that are exactly `query`.
    #
    # `type` can be any tag supported by MPD, or one of the two special parameters:
    #
    # * `file` to search by full path (relative to database root)
    # * `any` to match against all available tags.
    #
    # `query` is what to find.
    def find(type : String, query : String)
      write_command("find", type, query)

      fetch_objects(["file"])
    end

    # Finds songs in the db that are exactly `query` and adds them to current playlist.
    # Parameters have the same meaning as for `find`.
    def findadd(type : String, query : String)
      write_command("findadd", type, query)

      fetch_nothing
    end

    # Searches for any song that contains `query`.
    #
    # Parameters have the same meaning as for `find`, except that search is not case sensitive.
    def search(type : String, query : String)
      write_command("search", type, query)

      fetch_objects(["file"])
    end

    # Searches for any song that contains `query` in tag `type` and adds them to current playlist.
    #
    # Parameters have the same meaning as for `find`, except that search is not case sensitive.
    def searchadd(type : String, query : String)
      write_command("searchadd", type, query)

      fetch_nothing
    end

    def replay_gain_status
      write_command("replay_gain_status")

      fetch_item
    end

    # Updates the music database: find new files, remove deleted files, update modified files.
    #
    # `uri` is a particular directory or song/file to update. If you do not specify it, everything is updated.
    def update(uri : String? = nil)
      write_command("update", uri)

      fetch_item
    end

    # Reports the current status of the player and the volume level.
    #
    # Response:
    # * `volume`: 0-100
    # * `repeat`: 0 or 1
    # * `random`: 0 or 1
    # * `single`: 0 or 1
    # * `consume`: 0 or 1
    # * `playlist`: 31-bit unsigned integer, the playlist version number
    # * `playlistlength`: integer, the length of the playlist
    # * `state`: play, stop, or pause
    # * `song`: playlist song number of the current song stopped on or playing
    # * `songid`: playlist songid of the current song stopped on or playing
    # * `nextsong`: playlist song number of the next song to be played
    # * `nextsongid`: playlist songid of the next song to be played
    # * `time`: total time elapsed (of current playing/paused song)
    # * `elapsed`: Total time elapsed within the current song, but with higher resolution.
    # * `bitrate`: instantaneous bitrate in kbps
    # * `xfade`: crossfade in seconds
    # * `mixrampdb`: mixramp threshold in dB
    # * `mixrampdelay`: mixrampdelay in seconds
    # * `audio`: sampleRate:bits:channels
    # * `updating_db`: job id
    # * `error`: if there is an error, returns message here
    def status
      write_command("status")

      fetch_object
    end

    # Displays the song info of the current song (same song that is identified in `status`).
    def currentsong
      write_command("currentsong")

      fetch_object
    end

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

    # Displays statistics.
    #
    # Response:
    # * `artists`: number of artists
    # * `songs`: number of albums
    # * `uptime`: daemon uptime in seconds
    # * `db_playtime`: sum of all song times in the db
    # * `db_update`: last db update in UNIX time
    # * `playtime`: time length of music played
    def stats
      write_command("stats")

      fetch_object
    end

    # Sets consume state to `state`, `state` should be `false` or `true`.
    #
    # When consume is activated, each song played is removed from playlist.
    def consume(state : Bool)
      write_command("consume", boolean(state))

      fetch_nothing
    end

    # Sets random state to `state`, `state` should be `false` or `true`.
    def random(state : Bool)
      write_command("random", boolean(state))

      fetch_nothing
    end

    # Sets repeat state to `state`, `state` should be `false` or `true`.
    def repeat(state : Bool)
      write_command("repeat", boolean(state))

      fetch_nothing
    end

    # Sets single state to `state`, `state` should be `false` or `true`.
    #
    # When single is activated, playback is stopped after current song,
    # or song is repeated if the "repeat" mode is enabled.
    def single(state : Bool)
      write_command("single", boolean(state))

      fetch_nothing
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

    private def fetch_item : String
      pairs = read_pairs
      return "" if pairs.size != 1

      pairs[0][1]
    end

    private def read_line : String?
      @socket.try do |socket|
        line = socket.gets(chomp: true)
        puts line

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

    {% for method in UNIMPLEMENTED_METHODS %}
      # :nodoc:
      def {{method.id}}
        raise NotImplementedError.new("Method {{method.id}} not yet implemented.")
      end
    {% end %}
  end
end
