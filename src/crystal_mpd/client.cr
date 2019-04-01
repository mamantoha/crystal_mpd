require "logger"

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
    property log : Logger?

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

    # Connect to the MPD daemon unless conected.
    #
    # Connect using the `#reconnect` method.
    def connect
      reconnect unless connected?
    end

    # Attempts to reconnect to the MPD daemon.
    def reconnect
      @socket = TCPSocket.new(host, port)
      hello
    end

    # Disconnect from the MPD daemon.
    def disconnect
      @socket.try do |socket|
        socket.close
      end

      reset
    end

    # Check if the client is connected.
    def connected?
      @socket.is_a?(Socket)
    end

    # Ping the server.
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

    # https://www.musicpd.org/doc/html/protocol.html#command-lists
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

    private def process_command_list
      @command_list.commands.each do |command|
        process_command_in_command_list(command)
      end
    end

    private def process_command_in_command_list(command : String)
      case command
      when "fetch_nothing"  then fetch_nothing
      when "fetch_list"     then fetch_list
      when "fetch_object"   then fetch_object
      when "fetch_objects"  then fetch_objects
      when "fetch_songs"    then fetch_songs
      when "fetch_outputs"  then fetch_outputs
      when "fetch_database" then fetch_database
      when "fetch_plugins"  then fetch_plugins
      end
    end

    # Closes the connection to MPD.
    def close
      write_command("close")
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
      execute("fetch_object")
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
      execute("fetch_object")
    end

    # Dumps configuration values that may be interesting for the client.
    #
    # This command is only permitted to `local` clients (connected via UNIX domain socket).
    def config
      write_command("stats")
      execute("fetch_item")
    end

    # "Shows which commands the current user has access to.
    def commands
      write_command("commands")
      execute("fetch_list")
    end

    # Shows which commands the current user does not have access to.
    def notcommands
      write_command("notcommands")
      execute("fetch_list")
    end

    # Shows a list of available song metadata.
    def tagtypes
      write_command("tagtypes")
      execute("fetch_list")
    end

    # Obtain a list of all channels. The response is a list of `channel:` lines.
    def channels
      write_command("channels")
      execute("fetch_list")
    end

    # Gets a list of available URL handlers.
    def urlhandlers
      write_command("urlhandlers")
      execute("fetch_list")
    end

    # Print a list of decoder plugins, followed by their supported suffixes and MIME types.
    def decoders
      write_command("decoders")
      execute("fetch_plugins")
    end

    # Shows information about all outputs.
    def outputs
      write_command("outputs")
      execute("fetch_outputs")
    end

    # Updates the music database: find new files, remove deleted files, update modified files.
    #
    # `uri` is a particular directory or song/file to update.
    # If you do not specify it, everything is updated.
    def update(uri : String? = nil)
      write_command("update", uri)
      execute("fetch_list")
    end

    # Displays the song info of the current song (same song that is identified in `status`).
    def currentsong
      write_command("currentsong")
      execute("fetch_object")
    end

    # Same as `update`, but also rescans unmodified files.
    def rescan(uri : String? = nil)
      write_command("rescan", uri)
      execute("fetch_item")
    end

    # Prints a list of the playlist directory.
    #
    # After each playlist name the server sends its last modification time
    # as attribute `Last-Modified` in ISO 8601 format.
    # To avoid problems due to clock differences between clients and the server,
    # clients should not compare this value with their local clock.
    def listplaylists
      write_command("listplaylists")
      execute("fetch_playlists")
    end

    # Get current playlist
    def playlist
      write_command("playlist")
      execute("fetch_songs")
    end

    # Displays a list of all songs in the playlist,
    #
    # or if the optional argument is given, displays information only for
    # the song `songpos` or the range of songs `START:END`.
    #
    # Range is done in by using `Range`.
    #
    # Show info about the first three songs in the playlist:
    #
    # ```crystal
    # client.playlistinfo(1..3)
    # ```
    #
    # With negative range end MPD will assumes the biggest possible number then
    #
    # ```crystal
    # client.playlistinfo(10..-1)
    # ```
    def playlistinfo(songpos : Int32 | Range(Int32, Int32) | Nil = nil)
      write_command("playlistinfo", songpos)
      execute("fetch_songs")
    end

    # Searches case-sensitively for partial matches in the current playlist.
    def playlistsearch(tag : String, needle : String)
      write_command("playlistsearch", tag, needle)
      execute("fetch_songs")
    end

    # Finds songs in the current playlist with strict matching.
    def playlistfind(tag : String, needle : String)
      write_command("playlistfind", tag, needle)
      execute("fetch_songs")
    end

    # Deletes a song from the playlist.
    def delete(songpos : Int32 | Range(Int32, Int32))
      write_command("delete", songpos)
      execute("fetch_nothing")
    end

    # Deletes the song `singid` from the playlist.
    def deleteid(songid : Int32)
      write_command("deleteid", songid)
      execute("fetch_nothing")
    end

    # Moves the song at `from` or range of songs at `from` to `to` in the playlist.
    def move(from : Int32 | Range(Int32, Int32), to : Int32)
      write_command("move", from, to)
      execute("fetch_nothing")
    end

    # Loads the playlist `name` into the current queue.
    #
    # Playlist plugins are supported.
    # A range `songpos` may be specified to load only a part of the playlist.
    def load(name : String, songpos : Int32 | Range(Int32, Int32) | Nil = nil)
      write_command("load", name, songpos)
      execute("fetch_nothing")
    end

    # Shuffles the current playlist. `range` is optional and specifies a range of songs.
    def shuffle(range : Range(Int32, Int32) | Nil = nil)
      write_command("shuffle", range)
      execute("fetch_nothing")
    end

    # Saves the current playlist to `name`.m3u in the playlist directory.
    def save(name : String)
      write_command("save", name)
      execute("fetch_nothing")
    end

    # Clears the playlist `name`.m3u.
    def playlistclear(name : String)
      write_command("playlistclear", name)
      execute("fetch_nothing")
    end

    # Removes the playlist `name`.m3u from the playlist directory.
    def rm(name : String)
      write_command("rm", name)
      execute("fetch_nothing")
    end

    # Renames the playlist `name`.m3u to `new_name`.m3u.
    def rename(name : String, new_name : String)
      write_command("rename", name, new_name)
      execute("fetch_nothing")
    end

    # Displays a list of songs in the playlist.
    #
    # `songid` is optional and specifies a single song to display info for.
    def playlistid(songid : Int32? = nil)
      write_command("playlistid", songid)
      execute("fetch_songs")
    end

    # Searches for any song that contains `what` in tag `type` and adds them to the playlist named `name`.
    #
    # If a playlist by that name doesn't exist it is created.
    # Parameters have the same meaning as for `find`, except that search is not case sensitive.
    def searchaddpl(name : String, type : String, query : String)
      write_command("searchaddpl", name, type, query)
      execute("fetch_nothing")
    end

    # Search the database for songs matching `filter` and add them to the playlist named `name`.
    #
    # If a playlist by that name doesn’t exist it is created.
    # Parameters have the same meaning as for `search `.
    def searchaddpl(name : String, filler : String)
      write_command("searchaddpl", name, type, query)
      execute("fetch_nothing")
    end

    # Lists the songs in the playlist `name`.
    #
    # Playlist plugins are supported.
    def listplaylist(name : String)
      write_command("listplaylist", name)
      execute("fetch_list")
    end

    # Lists the songs with metadata in the playlist.
    #
    # Playlist plugins are supported.
    def listplaylistinfo(name : String)
      write_command("listplaylistinfo", name)
      execute("fetch_songs")
    end

    # Adds `uri` to the playlist `name`.m3u.
    #
    # `name`.m3u will be created if it does not exist.
    def playlistadd(name : String, uri : String)
      write_command("playlistadd", name, uri)
      execute("fetch_nothing")
    end

    # Moves `songid` in the playlist `name`.m3u to the position `songpos`
    def playlistmove(name : String, songid : Int32, songpos : Int32)
      write_command("playlistmove", name, songid, songpos)
      execute("fetch_nothing")
    end

    # Deletes `songpos` from the playlist `name`.m3u.
    def playlistdelete(name : String, songpos : Int32)
      write_command("playlistdelete", name, songpos)
      execute("fetch_nothing")
    end

    # Begins playing the playlist at song number `songpos`.
    def play(songpos : Int32? = nil)
      write_command("play", songpos)
      execute("fetch_nothing")
    end

    # Toggles pause/resumes playing.
    def pause
      write_command("pause")
      execute("fetch_nothing")
    end

    # Stops playing.
    def stop
      write_command("stop")
      execute("fetch_nothing")
    end

    # Seeks to the position `time` within the current song.
    #
    # If prefixed by `+` or `-`, then the time is relative to the current playing position.
    def seekcur(time : String | Int32)
      write_command("seekcur", time)
      execute("fetch_nothing")
    end

    # Seeks to the position `time` (in seconds) of song `songid`.
    def seekid(songid : Int32, time : String | Int32)
      write_command("seekid", songid, time)
      execute("fetch_nothing")
    end

    # Seeks to the position `time` (in seconds) of entry `songpos` in the playlist.
    def seek(songid : Int32, time : Int32)
      write_command("seek", songid, time)
      execute("fetch_nothing")
    end

    # Plays next song in the playlist.
    def next
      write_command("next")
      execute("fetch_nothing")
    end

    # Plays previous song in the playlist.
    def previous
      write_command("previous")
      execute("fetch_nothing")
    end

    # Begins playing the playlist at song `songid`.
    def playid(songnid : Int32? = nil)
      write_command("playid", songnid)
      execute("fetch_nothing")
    end

    # Lists unique tags values of the specified `type`.
    #
    # `type` can be any tag supported by MPD or file.
    #
    # ```crystal
    # client.list("Artist")
    # ```
    #
    # Additional arguments may specify a `filter`.
    # The following example lists all file names by their respective artist and date:
    #
    # ```crystal
    # client.list("Artist")
    # client.list("filename", "((artist == 'Linkin Park') AND (date == '2003'))")
    # ```
    def list(type : String, filter : String | Nil = nil)
      write_command("list", type, filter)
      execute("fetch_list")
    end

    # Count the number of songs and their total playtime in the database
    # that `type` is `query`
    #
    # The following prints the number of songs whose title matches "Echoes"
    #
    # ```crystal
    # client.count("title", "Echoes")
    # ```
    def count(type : String, query : String)
      write_command("count", type, query)
      execute("fetch_object")
    end

    # Count the number of songs and their total playtime in the database matching `filter`
    def count(filter : String)
      write_command("count", filter)
      execute("fetch_object")
    end

    # Sets random state to `state`, `state` should be `false` or `true`.
    def random(state : Bool)
      write_command("random", boolean(state))
      execute("fetch_nothing")
    end

    # Sets repeat state to `state`, `state` should be `false` or `true`.
    def repeat(state : Bool)
      write_command("repeat", boolean(state))
      execute("fetch_nothing")
    end

    # Sets single state to `state`, `state` should be `false` or `true`.
    #
    # When single is activated, playback is stopped after current song,
    # or song is repeated if the `repeat` mode is enabled.
    def single(state : Bool)
      write_command("single", boolean(state))
      execute("fetch_nothing")
    end

    # Sets consume state to `state`, `state` should be `false` or `true`.
    #
    # When consume is activated, each song played is removed from playlist.
    def consume(state : Bool)
      write_command("consume", boolean(state))
      execute("fetch_nothing")
    end

    # Sets the replay gain mode.
    #
    # One of `off`, `track`, `album`, `auto`.
    # Changing the mode during playback may take several seconds, because the new settings does not affect the buffered data.
    # This command triggers the options idle event.
    def replay_gain_mode(mode : String)
      write_command("replay_gain_mode", mode)
      execute("fetch_nothing")
    end

    # Prints replay gain options.
    #
    # Currently, only the variable `replay_gain_mode` is returned.
    def replay_gain_status
      write_command("replay_gain_status")
      execute("fetch_item")
    end

    # Clears the current playlist.
    def clear
      write_command("clear")
      execute("fetch_nothing")
    end

    # Adds the file `uri` to the playlist (directories add recursively).
    #
    # `uri` can also be a single file.
    def add(uri : String)
      write_command("add", uri)
      execute("fetch_nothing")
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
      execute("fetch_songs")
    end

    # Search the database for songs matching `filter`
    def find(filter : String)
      write_command("find", filter)
      execute("fetch_songs")
    end

    # Searches for any song that contains `query`.
    #
    # Parameters have the same meaning as for `find`, except that search is not case sensitive.
    #
    # ```crystal
    # client.search("title", "crystal")
    # ```
    def search(type : String, query : String)
      write_command("search", type, query)
      execute("fetch_songs")
    end

    # Search the database for songs matching `filter` (see Filters).
    #
    # Parameters have the same meaning as for `find`, except that search is not case sensitive.
    #
    # ```crystal
    # client.search("(any =~ 'crystal')")
    # ```
    def search(filter : String)
      write_command("search", filter)
      execute("fetch_songs")
    end

    # Search the database for songs matching `filter` and add them to the queue.
    #
    # Parameters have the same meaning as for `find`.
    #
    # ```crystal
    # client.findadd("(genre == 'Alternative Rock')")
    # ```
    def findadd(filter : String)
      write_command("findadd", filter)
      execute("fetch_nothing")
    end

    # Search the database for songs matching `filter` and add them to the queue.
    #
    # Parameters have the same meaning as for `search`.
    def searchadd(filter : String)
      write_command("searchadd", filter)
      execute("fetch_nothing")
    end

    # Lists all songs and directories in `uri`.
    def listall(uri : String? = nil)
      write_command("listall", uri)
      execute("fetch_database")
    end

    # Lists the contents of the directory `uri`.
    #
    # When listing the root directory, this currently returns the list of stored playlists.
    # This behavior is deprecated; use `listplaylists` instead.
    #
    # Clients that are connected via UNIX domain socket may use this command
    # to read the tags of an arbitrary local file (`uri` beginning with `file:///`).
    def lsinfo(uri : String? = nil)
      write_command("lsinfo", uri)
      execute("fetch_database")
    end

    # Same as `listall`, except it also returns metadata info in the same format as `lsinfo`.
    def listallinfo(uri : String? = nil)
      write_command("listallinfo", uri)
      execute("fetch_database")
    end

    # Lists the contents of the directory `URI`, including files are not recognized by `MPD`.
    #
    # `uri` can be a path relative to the music directory or an `uri` understood by one of the storage plugins.
    # The response contains at least one line for each directory entry with the prefix `file: ` or  `directory: `,
    # and may be followed by file attributes such as `Last-Modified` and `size`.
    #
    # For example, `smb://SERVER` returns a list of all shares on the given SMB/CIFS server;
    # `nfs://servername/path` obtains a directory listing from the NFS server.
    def listfiles(uri : String? = nil)
      write_command("listfiles", uri)
      execute("fetch_database")
    end

    # Subscribe to a channel `name`.
    #
    # The channel is created if it does not exist already.
    # The `name` may consist of alphanumeric ASCII characters plus underscore, dash, dot and colon.
    def subscribe(name : String)
      write_command("subscribe", name)
      execute("fetch_nothing")
    end

    # Unsubscribe from a channel `name`.
    def unsubscribe(name : String)
      write_command("unsubscribe", name)
      execute("fetch_nothing")
    end

    # Send a `message` to the specified `channel`.
    def sendmessage(channel : String, message : String)
      write_command("sendmessage", channel, message)
      execute("fetch_nothing")
    end

    # Reads messages for this client. The response is a list of `channel:` and `message:` lines.
    def readmessages
      write_command("readmessages")
      execute("fetch_messages")
    end

    # :nodoc:
    private def write_command(command : String, *args)
      parts = [command]

      args.each do |arg|
        line = parse_arg(arg)

        parts << line
      end

      write_line(parts.join(' '))
    end

    # :nodoc:
    macro execute(retval)
      if @command_list.active?
        @command_list.add({{retval}})
        return
      end

      {{retval.id}}
    end

    # :nodoc:
    private def parse_arg(arg) : String
      case arg
      when Range
        parse_range(arg)
      when Hash
        arg.reduce([] of String) do |acc, (key, value)|
          acc << "#{key} \"#{escape(value)}\""
        end.join(" ")
      when String
        %{"#{escape(arg)}"}
      when Int32
        %{"#{escape(arg.to_s)}"}
      else
        ""
      end
    end

    # :nodoc:
    private def parse_range(range) : String
      range_start = range.begin
      range_end = range.end

      range_start = 0 if range_start < 0
      range_end += 1 unless range.exclusive?
      range_end = nil if range_end <= 0

      "#{range_start}:#{range_end}"
    end

    # :nodoc:
    private def write_line(line : String)
      @socket.try do |socket|
        @log.try do |log|
          log.debug("MPD request: `#{line}`")
        end

        socket.puts(line)
      end
    end

    # :nodoc:
    private def fetch_nothing
      line = read_line
      raise MPD::Error.new("Got unexpected return value: #{line}") unless line.nil?
    end

    # :nodoc:
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

    # :nodoc:
    private def fetch_object : Object
      fetch_objects.first
    end

    # :nodoc:
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

    # :nodoc:
    private def fetch_outputs
      fetch_objects(["outputid"])
    end

    # :nodoc:
    private def fetch_songs
      fetch_objects(["file"])
    end

    # :nodoc:
    private def fetch_database
      fetch_objects(["file", "directory", "playlist"])
    end

    # :nodoc:
    def fetch_playlists
      fetch_objects(["playlist"])
    end

    # :nodoc:
    def fetch_plugins
      fetch_objects(["plugin"])
    end

    # :nodoc:
    def fetch_messages
      fetch_objects("channel")
    end

    # :nodoc:
    private def fetch_item : String
      pairs = read_pairs
      return "" if pairs.size != 1

      pairs[0][1]
    end

    # :nodoc:
    private def read_pairs : Pairs
      pairs = Pairs.new

      pair = read_pair
      while !pair.empty?
        pairs << pair
        pair = read_pair
      end

      pairs
    end

    # :nodoc:
    private def read_pair : Pair
      line = read_line
      return Pair.new if line.nil?
      pair = line.split(": ", 2)

      pair
    end

    # :nodoc:
    private def read_line : String?
      @socket.try do |socket|
        line = socket.gets(chomp: true)

        @log.try do |log|
          log.debug("MPD response: `#{line}`")
        end

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

    # :nodoc:
    private def reset
      @socket = nil
      @version = nil
    end

    # :nodoc:
    private def boolean(value : Bool)
      value ? "1" : "0"
    end

    # :nodoc:
    private def escape(str : String)
      str.gsub(%{\\}, %{\\\\}).gsub(%{"}, %{\\"})
    end
  end
end
