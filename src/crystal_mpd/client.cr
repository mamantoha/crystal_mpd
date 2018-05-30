module MPD
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

    # Creates a new MPD client. Parses the *host*, *port*.
    #
    # ```
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
      @socket = TCPSocket.new(host.not_nil!, port)
      hello
    end

    def hello
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

    UNIMPLEMENTED_METHODS = [
      "add", "addid", "addtagid",
      "channels", "clearerror", "cleartagid", "close",
      "config", "count", "crossfade", "currentsong",
      "decoders", "delete", "deleteid", "disableoutput",
      "enableoutput",
      "idle",
      "kill",
      "listallinfo", "listfiles", "listmounts", "listplaylist",
      "listplaylistinfo", "listplaylists", "load", "lsinfo",
      "mixrampdb", "mixrampdelay", "mount", "move", "moveid",
      "notcommands",
      "outputs",
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

    {% for method in UNIMPLEMENTED_METHODS %}
      # TODO: implement `method`
      def {{method.id}}
        raise  "Method not yet implemented."
      end
    {% end %}

    # Plays next song in the playlist.
    def next
      @socket.try do |socket|
        socket.puts("next")

        return fetch_nothing
      end
    end

    # Toggles pause/resumes playing, *pause* is `true` or `false`.
    def pause(pause : Bool)
      @socket.try do |socket|
        command = "pause #{pause ? "1" : "0"}"
        socket.puts(command)

        return fetch_nothing
      end
    end

    # Plays previous song in the playlist.
    def previous
      @socket.try do |socket|
        socket.puts("previous")

        return fetch_nothing
      end
    end

    # Stops playing.
    def stop
      @socket.try do |socket|
        socket.puts("stop")

        return fetch_nothing
      end
    end

    # Begins playing the playlist at song number *songpos*.
    def play(songpos : Int32? = nil)
      @socket.try do |socket|
        command = "play #{songpos}".chomp
        socket.puts(command)

        return fetch_nothing
      end
    end

    # Begins playing the playlist at song *songid*
    def playid(songid : Int32)
      @socket.try do |socket|
        socket.puts("playid #{songid}")

        return fetch_nothing
      end
    end

    # Seeks to the position *time* within the current song.
    # If prefixed by "+"" or "-", then the time is relative to the current playing position.
    def seekcur(time : String | Int32)
      @socket.try do |socket|
        socket.puts("seekcur #{time}")

        return fetch_nothing
      end
    end

    # Seeks to the position *time* (in seconds) of song *songid*
    def seekid(songid : Int32, time : Int32)
      @socket.try do |socket|
        socket.puts("seekid #{songid} #{time}")

        return fetch_nothing
      end
    end

    # Seeks to the position *time* (in seconds) of entry *songpos* in the playlist.
    def seek(songpos : Int32, time : Int32)
      @socket.try do |socket|
        socket.puts("seek #{songpos} #{time}")

        return fetch_nothing
      end
    end

    # Shows which commands the current user has access to.
    def commands
      @socket.try do |socket|
        socket.puts("commands")

        return fetch_list
      end
    end

    # Shows a list of available song metadata.
    def tagtypes
      @socket.try do |socket|
        socket.puts("tagtypes")

        return fetch_list
      end
    end

    # Lists all tags of the specified *type*. *type* can be any tag supported by MPD or file.
    #
    # *artist* is an optional parameter when *type* is "album", this specifies to list albums by an *artist*.
    def list(type : String, artist : String? = nil)
      @socket.try do |socket|
        command = "list #{type}"
        command = command + %{ "#{artist}"} if artist

        socket.puts(command)

        return fetch_list
      end
    end

    # Lists all songs and directories in *uri*
    def listall(uri : String?)
      @socket.try do |socket|
        command = "listall #{uri}".chomp
        socket.puts(command)

        return fetch_objects(["file", "directory", "playlist"])
      end
    end

    # Clears the current playlist.
    def clear
      @socket.try do |socket|
        socket.puts("clear")

        return fetch_nothing
      end
    end

    # Displays a list of all songs in the playlist, or if the optional argument is given,
    # displays information only for the song **songpos** or the range of songs **START:END**.
    #
    # Range is done in by using two element array.
    #
    # Show info about the first three songs in the playlist:
    #
    # ```
    # client.playlistinfo([1, 3])
    # ```
    #
    # Second element of the `Array` can be omitted. **MPD** will assumes the biggest possible number then:
    #
    # ```
    # client.playlistinfo([10])
    # ```
    def playlistinfo(songpos : Int32 | Array(Int32) | Nil = nil)
      @socket.try do |socket|
        args =
          case songpos
          when Int32
            "#{songpos}"
          when Array
            "#{songpos[0]}:#{songpos[1]?}"
          else
            ""
          end

        command = "playlistinfo #{args}".chomp
        socket.puts(command)

        return fetch_objects(["file"])
      end
    end

    # Searches case-sensitively for partial matches in the current playlist.
    def playlistsearch(tag : String, needle : String)
      @socket.try do |socket|
        socket.puts(%{playlistsearch "#{tag}" "#{needle}"})

        return fetch_objects(["file"])
      end
    end

    # Finds songs in the current playlist with strict matching.
    def playlistfind(tag : String, needle : String)
      @socket.try do |socket|
        socket.puts(%{playlistfind "#{tag}" "#{needle}"})

        return fetch_objects(["file"])
      end
    end

    # Finds songs in the db that are exactly *query*.
    #
    # *type* can be any tag supported by MPD, or one of the two special parameters:
    #
    # * `file` to search by full path (relative to database root)
    # * `any` to match against all available tags.
    #
    # *query* is what to find.
    def find(type : String, query : String) : Objects
      @socket.try do |socket|
        socket.puts(%{find "#{type}" "#{query}"})

        return fetch_objects(["file"])
      end

      return Objects.new
    end

    # Finds songs in the db that are exactly *query* and adds them to current playlist.
    # Parameters have the same meaning as for **find**.
    def findadd(type : String, query : String)
      @socket.try do |socket|
        socket.puts(%{findadd "#{type}" "#{query}"})

        return fetch_nothing
      end
    end

    # Searches for any song that contains *query*.
    #
    # Parameters have the same meaning as for **find**, except that search is not case sensitive.
    def search(type : String, query : String) : Objects
      @socket.try do |socket|
        socket.puts(%{search "#{type}" "#{query}"})

        return fetch_objects(["file"])
      end

      return Objects.new
    end

    # Searches for any song that contains *query* in tag *type* and adds them to current playlist.
    #
    # Parameters have the same meaning as for **find**, except that search is not case sensitive.
    def searchadd(type : String, query : String)
      @socket.try do |socket|
        socket.puts(%{searchadd "#{type}" "#{query}"})

        return fetch_nothing
      end
    end

    def replay_gain_status
      @socket.try do |socket|
        socket.puts("replay_gain_status")

        return fetch_item
      end
    end

    # Updates the music database: find new files, remove deleted files, update modified files.
    #
    # *uri* is a particular directory or song/file to update. If you do not specify it, everything is updated.
    def update(uri : String? = nil)
      @socket.try do |socket|
        command = "update #{uri}".chomp

        socket.puts(command)

        return fetch_item
      end
    end

    # Reports the current status of the player and the volume level.
    #
    # Response:
    # * **volume**: 0-100
    # * **repeat**: 0 or 1
    # * **random**: 0 or 1
    # * **single**: 0 or 1
    # * **consume**: 0 or 1
    # * **playlist**: 31-bit unsigned integer, the playlist version number
    # * **playlistlength**: integer, the length of the playlist
    # * **state**: play, stop, or pause
    # * **song**: playlist song number of the current song stopped on or playing
    # * **songid**: playlist songid of the current song stopped on or playing
    # * **nextsong**: playlist song number of the next song to be played
    # * **nextsongid**: playlist songid of the next song to be played
    # * **time**: total time elapsed (of current playing/paused song)
    # * **elapsed**: Total time elapsed within the current song, but with higher resolution.
    # * **bitrate**: instantaneous bitrate in kbps
    # * **xfade**: crossfade in seconds
    # * **mixrampdb**: mixramp threshold in dB
    # * **mixrampdelay**: mixrampdelay in seconds
    # * **audio**: sampleRate:bits:channels
    # * **updating_db**: job id
    # * **error**: if there is an error, returns message here
    def status
      @socket.try do |socket|
        socket.puts("status")

        return fetch_object
      end
    end

    # Displays statistics.
    #
    # Response:
    # * **artists**: number of artists
    # * **songs**: number of albums
    # * **uptime**: daemon uptime in seconds
    # * **db_playtime**: sum of all song times in the db
    # * **db_update**: last db update in UNIX time
    # * **playtime**: time length of music played
    def stats
      @socket.try do |socket|
        socket.puts("stats")

        return fetch_object
      end
    end

    # Sets consume state to *state*, *state* should be `false` or `true`.
    #
    # When consume is activated, each song played is removed from playlist.
    def consume(state : Bool)
      @socket.try do |socket|
        socket.puts("consume #{boolean(state)}")

        return fetch_nothing
      end
    end

    # Sets random state to *state*, *state* should be `false` or `true`.
    def random(state : Bool)
      @socket.try do |socket|
        socket.puts("random #{boolean(state)}")

        return fetch_nothing
      end
    end

    # Sets repeat state to *state*, *state* should be `false` or `true`.
    def repeat(state : Bool)
      @socket.try do |socket|
        socket.puts("repeat #{boolean(state)}")

        return fetch_nothing
      end
    end

    # Sets single state to *state*, *state* should be `false` or `true`.
    #
    # When single is activated, playback is stopped after current song,
    # or song is repeated if the "repeat" mode is enabled.
    def single(state : Bool)
      @socket.try do |socket|
        socket.puts("single #{boolean(state)}")

        return fetch_nothing
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

      return result
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

      return result
    end

    private def read_pairs : Pairs
      pairs = Pairs.new

      pair = read_pair
      while !pair.empty?
        pairs << pair
        pair = read_pair
      end

      return pairs
    end

    private def read_pair : Pair
      line = read_line
      return Pair.new if line.nil?
      pair = line.split(": ", 2)
      return pair
    end

    private def fetch_item : String
      pairs = read_pairs
      return "" if pairs.size != 1
      return pairs[0][1]
    end

    private def read_line : String?
      @socket.try do |socket|
        line = socket.gets(chomp: true)

        if line.not_nil!.starts_with?(ERROR_PREFIX)
          error = line.not_nil![/#{ERROR_PREFIX}(.*)/, 1].strip
          raise MPD::Error.new(error)
        end

        return if line == SUCCESS

        return line
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
  end
end
