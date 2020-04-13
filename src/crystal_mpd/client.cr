module MPD
  alias Object = Hash(String, String)
  alias Objects = Array(MPD::Object)
  alias Pair = Array(String)
  alias Pairs = Array(MPD::Pair)
  alias Range = ::Range(Int32, Int32) | ::Range(Nil, Int32) | ::Range(Int32, Nil)

  class Client
    @version : String?

    HELLO_PREFIX = "OK MPD "
    ERROR_PREFIX = "ACK "
    SUCCESS      = "OK\n"
    NEXT         = "list_OK\n"

    getter host, port, version
    property callbacks_timeout : Time::Span | Int32 = 1.second

    # Creates a new MPD client. Parses the `host`, `port`.
    #
    # ```crystal
    # mpd = MPD::Client.new("localhost", 6600)
    # puts mpd.version
    # puts mpd.status
    # puts mpd.stats
    # mpd.disconnect
    # ```
    #
    # This constructor will raise an exception if could not connect to MPD
    def initialize(
      @host : String = "localhost",
      @port : Int32 = 6600,
      @with_callbacks = false
    )
      @command_list = CommandList.new
      @mutex = Mutex.new
      @callbacks = {} of Symbol => Array(String -> Nil)

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
      @socket = if host.starts_with?('/')
                  UNIXSocket.new(host)
                else
                  TCPSocket.new(host, port)
                end

      hello
      callback_thread if @with_callbacks
    end

    # Disconnect from the MPD daemon.
    def disconnect
      @socket.try do |socket|
        socket.close
      end

      reset
    end

    # This will register a block callback that will trigger whenever
    # that specific event happens.
    #
    # ```crystal
    # mpd.on :state do |state|
    #   puts "State was change to #{state}"
    # end
    # ```
    def on(event : Symbol, &block : String -> _)
      (@callbacks[event] ||= [] of Proc(String, Nil)).push(block)
    end

    # Triggers an event, running it's callbacks.
    private def emit(event : Symbol, arg : String)
      return unless @callbacks[event]?

      @callbacks[event].each { |handle| handle.call(arg) }
    end

    # Constructs a callback loop
    private def callback_thread
      spawn do
        old_status = {} of Symbol => String

        if status = self.status
          old_status = get_status(status)
        end

        loop do
          sleep @callbacks_timeout

          if status = self.status
            new_status = get_status(status)

            new_status.each do |key, val|
              next unless val
              next if val == old_status[key]?
              emit(key, val)
            end

            old_status = new_status
          end
        end
      end

      Fiber.yield
    end

    def events_list
      @events_list ||= [
        :volume, :repeat, :random, :single, :consume,
        :playlist, :playlistlength, :mixrampdb, :state,
        :song, :songid, :time, :elapsed, :bitrate,
        :duration, :audio, :nextsong, :nextsongid,
      ]
    end

    private def get_status(status : Hash(String, String)) : Hash(Symbol, String?)
      events_list.each_with_object({} of Symbol => String | Nil) do |event, hash|
        hash[event] = status[event.to_s]?
      end
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

    private def synchronize
      @mutex.synchronize do
        begin
          yield
        ensure
          @socket.try &.flush
        end
      end
    rescue ex : IO::Error
      Log.error { ex.message }
      reconnect
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
      synchronize do
        @command_list.commands.each do |command|
          process_command_in_command_list(command)
        end
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
      else
        nil
      end
    end

    # Closes the connection to MPD.
    def close
      synchronize do
        write_command("close")
      end
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
      synchronize do
        write_command("status")
        execute("fetch_object")
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
      synchronize do
        write_command("stats")
        execute("fetch_object")
      end
    end

    # Dumps configuration values that may be interesting for the client.
    #
    # This command is only permitted to `local` clients (connected via UNIX domain socket).
    #
    # The following response attributes are available:
    #
    # * `music_directory`: The absolute path of the music directory.
    def config
      synchronize do
        write_command("config")
        execute("fetch_object")
      end
    end

    # "Shows which commands the current user has access to.
    def commands
      synchronize do
        write_command("commands")
        execute("fetch_list")
      end
    end

    # Shows which commands the current user does not have access to.
    def notcommands
      synchronize do
        write_command("notcommands")
        execute("fetch_list")
      end
    end

    # Shows a list of available song metadata.
    def tagtypes
      synchronize do
        write_command("tagtypes")
        execute("fetch_list")
      end
    end

    # Obtain a list of all channels. The response is a list of `channel:` lines.
    def channels
      synchronize do
        write_command("channels")
        execute("fetch_list")
      end
    end

    # Gets a list of available URL handlers.
    def urlhandlers
      synchronize do
        write_command("urlhandlers")
        execute("fetch_list")
      end
    end

    # Print a list of decoder plugins, followed by their supported suffixes and MIME types.
    def decoders
      synchronize do
        write_command("decoders")
        execute("fetch_plugins")
      end
    end

    # Shows information about all outputs.
    def outputs
      synchronize do
        write_command("outputs")
        execute("fetch_outputs")
      end
    end

    # Updates the music database: find new files, remove deleted files, update modified files.
    #
    # `uri` is a particular directory or song/file to update.
    # If you do not specify it, everything is updated.
    def update(uri : String? = nil)
      synchronize do
        write_command("update", uri)
        execute("fetch_list")
      end
    end

    # Displays the song info of the current song (same song that is identified in `status`).
    def currentsong
      synchronize do
        write_command("currentsong")
        execute("fetch_object")
      end
    end

    # Same as `update`, but also rescans unmodified files.
    def rescan(uri : String? = nil)
      synchronize do
        write_command("rescan", uri)
        execute("fetch_item")
      end
    end

    # Prints a list of the playlist directory.
    #
    # After each playlist name the server sends its last modification time
    # as attribute `Last-Modified` in ISO 8601 format.
    # To avoid problems due to clock differences between clients and the server,
    # clients should not compare this value with their local clock.
    def listplaylists
      synchronize do
        write_command("listplaylists")
        execute("fetch_playlists")
      end
    end

    # Get current playlist
    def playlist
      synchronize do
        write_command("playlist")
        execute("fetch_songs")
      end
    end

    # Displays a list of all songs in the playlist,
    #
    # or if the optional argument is given, displays information only for
    # the song `songpos` or the range of songs `START:END`.
    #
    # Range is done in by using `MPD::Range`.
    #
    # Show info about the first three songs in the playlist:
    #
    # ```crystal
    # mpd.playlistinfo(1..3)
    # mpd.playlistinfo(..3)
    # mpd.playlistinfo(10..)
    # ```
    #
    # With negative range end MPD will assumes the biggest possible number then
    #
    # ```crystal
    # mpd.playlistinfo(10..-1)
    # ```
    def playlistinfo(songpos : Int32 | MPD::Range | Nil = nil)
      synchronize do
        write_command("playlistinfo", songpos)
        execute("fetch_songs")
      end
    end

    # Searches case-sensitively for partial matches in the current playlist.
    def playlistsearch(tag : String, needle : String)
      synchronize do
        write_command("playlistsearch", tag, needle)
        execute("fetch_songs")
      end
    end

    # Finds songs in the current playlist with strict matching.
    def playlistfind(tag : String, needle : String)
      synchronize do
        write_command("playlistfind", tag, needle)
        execute("fetch_songs")
      end
    end

    # Deletes a song from the playlist.
    def delete(songpos : Int32 | MPD::Range)
      synchronize do
        write_command("delete", songpos)
        execute("fetch_nothing")
      end
    end

    # Deletes the song `singid` from the playlist.
    def deleteid(songid : Int32)
      synchronize do
        write_command("deleteid", songid)
        execute("fetch_nothing")
      end
    end

    # Moves the song at `from` or range of songs at `from` to `to` in the playlist.
    def move(from : Int32 | MPD::Range, to : Int32)
      synchronize do
        write_command("move", from, to)
        execute("fetch_nothing")
      end
    end

    # Loads the playlist `name` into the current queue.
    #
    # Playlist plugins are supported.
    # A range `songpos` may be specified to load only a part of the playlist.
    def load(name : String, songpos : Int32 | MPD::Range | Nil = nil)
      synchronize do
        write_command("load", name, songpos)
        execute("fetch_nothing")
      end
    end

    # Shuffles the current playlist. `range` is optional and specifies a range of songs.
    def shuffle(range : MPD::Range | Nil = nil)
      synchronize do
        write_command("shuffle", range)
        execute("fetch_nothing")
      end
    end

    # Saves the current playlist to `name`.m3u in the playlist directory.
    def save(name : String)
      synchronize do
        write_command("save", name)
        execute("fetch_nothing")
      end
    end

    # Clears the playlist `name`.m3u.
    def playlistclear(name : String)
      synchronize do
        write_command("playlistclear", name)
        execute("fetch_nothing")
      end
    end

    # Removes the playlist `name`.m3u from the playlist directory.
    def rm(name : String)
      synchronize do
        write_command("rm", name)
        execute("fetch_nothing")
      end
    end

    # Renames the playlist `name`.m3u to `new_name`.m3u.
    def rename(name : String, new_name : String)
      synchronize do
        write_command("rename", name, new_name)
        execute("fetch_nothing")
      end
    end

    # Displays a list of songs in the playlist.
    #
    # `songid` is optional and specifies a single song to display info for.
    def playlistid(songid : Int32? = nil)
      synchronize do
        write_command("playlistid", songid)
        execute("fetch_songs")
      end
    end

    # Searches for any song that contains `what` in tag `type` and adds them to the playlist named `name`.
    #
    # If a playlist by that name doesn't exist it is created.
    # Parameters have the same meaning as for `find`, except that search is not case sensitive.
    def searchaddpl(name : String, type : String, query : String)
      synchronize do
        write_command("searchaddpl", name, type, query)
        execute("fetch_nothing")
      end
    end

    # Search the database for songs matching `filter` and add them to the playlist named `name`.
    #
    # If a playlist by that name doesn’t exist it is created.
    # Parameters have the same meaning as for `search `.
    def searchaddpl(name : String, filler : String)
      synchronize do
        write_command("searchaddpl", name, type, query)
        execute("fetch_nothing")
      end
    end

    # Lists the songs in the playlist `name`.
    #
    # Playlist plugins are supported.
    def listplaylist(name : String)
      synchronize do
        write_command("listplaylist", name)
        execute("fetch_list")
      end
    end

    # Lists the songs with metadata in the playlist.
    #
    # Playlist plugins are supported.
    def listplaylistinfo(name : String)
      synchronize do
        write_command("listplaylistinfo", name)
        execute("fetch_songs")
      end
    end

    # Adds `uri` to the playlist `name`.m3u.
    #
    # `name`.m3u will be created if it does not exist.
    def playlistadd(name : String, uri : String)
      synchronize do
        write_command("playlistadd", name, uri)
        execute("fetch_nothing")
      end
    end

    # Moves `songid` in the playlist `name`.m3u to the position `songpos`
    def playlistmove(name : String, songid : Int32, songpos : Int32)
      synchronize do
        write_command("playlistmove", name, songid, songpos)
        execute("fetch_nothing")
      end
    end

    # Deletes `songpos` from the playlist `name`.m3u.
    def playlistdelete(name : String, songpos : Int32)
      synchronize do
        write_command("playlistdelete", name, songpos)
        execute("fetch_nothing")
      end
    end

    # Begins playing the playlist at song number `songpos`.
    def play(songpos : Int32? = nil)
      synchronize do
        write_command("play", songpos)
        execute("fetch_nothing")
      end
    end

    # Toggles pause/resumes playing.
    def pause
      synchronize do
        write_command("pause")
        execute("fetch_nothing")
      end
    end

    # Stops playing.
    def stop
      synchronize do
        write_command("stop")
        execute("fetch_nothing")
      end
    end

    # Seeks to the position `time` within the current song.
    #
    # If prefixed by `+` or `-`, then the time is relative to the current playing position.
    def seekcur(time : String | Int32)
      synchronize do
        write_command("seekcur", time)
        execute("fetch_nothing")
      end
    end

    # Seeks to the position `time` (in seconds) of song `songid`.
    def seekid(songid : Int32, time : String | Int32)
      synchronize do
        write_command("seekid", songid, time)
        execute("fetch_nothing")
      end
    end

    # Seeks to the position `time` (in seconds) of entry `songpos` in the playlist.
    def seek(songid : Int32, time : Int32)
      synchronize do
        write_command("seek", songid, time)
        execute("fetch_nothing")
      end
    end

    # Plays next song in the playlist.
    def next
      synchronize do
        write_command("next")
        execute("fetch_nothing")
      end
    end

    # Plays previous song in the playlist.
    def previous
      synchronize do
        write_command("previous")
        execute("fetch_nothing")
      end
    end

    # Begins playing the playlist at song `songid`.
    def playid(songnid : Int32? = nil)
      synchronize do
        write_command("playid", songnid)
        execute("fetch_nothing")
      end
    end

    # Lists unique tags values of the specified `type`.
    #
    # `type` can be any tag supported by MPD or file.
    #
    # ```crystal
    # mpd.list("Artist")
    # ```
    #
    # Additional arguments may specify a `filter`.
    # The following example lists all file names by their respective artist and date:
    #
    # ```crystal
    # mpd.list("Artist")
    # mpd.list("filename", "((artist == 'Linkin Park') AND (date == '2003'))")
    # ```
    def list(type : String, filter : String | Nil = nil)
      synchronize do
        write_command("list", type, filter)
        execute("fetch_list")
      end
    end

    # Locate album art for the given song
    def albumart(uri : String) : IO
      fetch_binary(IO::Memory.new, 0, "albumart", uri)
    end

    # Count the number of songs and their total playtime in the database
    # that `type` is `query`
    #
    # The following prints the number of songs whose title matches "Echoes"
    #
    # ```crystal
    # mpd.count("title", "Echoes")
    # ```
    def count(type : String, query : String)
      synchronize do
        write_command("count", type, query)
        execute("fetch_object")
      end
    end

    # Count the number of songs and their total playtime in the database matching `filter`
    def count(filter : String)
      synchronize do
        write_command("count", filter)
        execute("fetch_object")
      end
    end

    # Sets random state to `state`, `state` should be `false` or `true`.
    def random(state : Bool)
      synchronize do
        write_command("random", boolean(state))
        execute("fetch_nothing")
      end
    end

    # Sets repeat state to `state`, `state` should be `false` or `true`.
    def repeat(state : Bool)
      synchronize do
        write_command("repeat", boolean(state))
        execute("fetch_nothing")
      end
    end

    # Sets volume to `vol`, the range of volume is 0-100.
    def setvol(vol : Int)
      synchronize do
        write_command("setvol", vol)
        execute("fetch_nothing")
      end
    end

    # Sets single state to `state`, `state` should be `false` or `true`.
    #
    # When single is activated, playback is stopped after current song,
    # or song is repeated if the `repeat` mode is enabled.
    def single(state : Bool)
      synchronize do
        write_command("single", boolean(state))
        execute("fetch_nothing")
      end
    end

    # Sets consume state to `state`, `state` should be `false` or `true`.
    #
    # When consume is activated, each song played is removed from playlist.
    def consume(state : Bool)
      synchronize do
        write_command("consume", boolean(state))
        execute("fetch_nothing")
      end
    end

    # Sets the replay gain mode.
    #
    # One of `off`, `track`, `album`, `auto`.
    # Changing the mode during playback may take several seconds, because the new settings does not affect the buffered data.
    # This command triggers the options idle event.
    def replay_gain_mode(mode : String)
      synchronize do
        write_command("replay_gain_mode", mode)
        execute("fetch_nothing")
      end
    end

    # Prints replay gain options.
    #
    # Currently, only the variable `replay_gain_mode` is returned.
    def replay_gain_status
      synchronize do
        write_command("replay_gain_status")
        execute("fetch_item")
      end
    end

    # Clears the current playlist.
    def clear
      synchronize do
        write_command("clear")
        execute("fetch_nothing")
      end
    end

    # Adds the file `uri` to the playlist (directories add recursively).
    #
    # `uri` can also be a single file.
    def add(uri : String)
      synchronize do
        write_command("add", uri)
        execute("fetch_nothing")
      end
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
      synchronize do
        write_command("find", type, query)
        execute("fetch_songs")
      end
    end

    # Search the database for songs matching `filter`
    def find(filter : String)
      synchronize do
        write_command("find", filter)
        execute("fetch_songs")
      end
    end

    # Searches for any song that contains `query`.
    #
    # Parameters have the same meaning as for `find`, except that search is not case sensitive.
    #
    # ```crystal
    # mpd.search("title", "crystal")
    # ```
    def search(type : String, query : String)
      synchronize do
        write_command("search", type, query)
        execute("fetch_songs")
      end
    end

    # Search the database for songs matching `filter` (see Filters).
    #
    # Parameters have the same meaning as for `find`, except that search is not case sensitive.
    #
    # ```crystal
    # mpd.search("(any =~ 'crystal')")
    # ```
    def search(filter : String)
      synchronize do
        write_command("search", filter)
        execute("fetch_songs")
      end
    end

    # Search the database for songs matching `filter` and add them to the queue.
    #
    # Parameters have the same meaning as for `find`.
    #
    # ```crystal
    # mpd.findadd("(genre == 'Alternative Rock')")
    # ```
    def findadd(filter : String)
      synchronize do
        write_command("findadd", filter)
        execute("fetch_nothing")
      end
    end

    # Search the database for songs matching `filter` and add them to the queue.
    #
    # Parameters have the same meaning as for `search`.
    def searchadd(filter : String)
      synchronize do
        write_command("searchadd", filter)
        execute("fetch_nothing")
      end
    end

    # Lists all songs and directories in `uri`.
    def listall(uri : String? = nil)
      synchronize do
        write_command("listall", uri)
        execute("fetch_database")
      end
    end

    # Lists the contents of the directory `uri`.
    #
    # When listing the root directory, this currently returns the list of stored playlists.
    # This behavior is deprecated; use `listplaylists` instead.
    #
    # Clients that are connected via UNIX domain socket may use this command
    # to read the tags of an arbitrary local file (`uri` beginning with `file:///`).
    def lsinfo(uri : String? = nil)
      synchronize do
        write_command("lsinfo", uri)
        execute("fetch_database")
      end
    end

    # Same as `listall`, except it also returns metadata info in the same format as `lsinfo`.
    def listallinfo(uri : String? = nil)
      synchronize do
        write_command("listallinfo", uri)
        execute("fetch_database")
      end
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
      synchronize do
        write_command("listfiles", uri)
        execute("fetch_database")
      end
    end

    # Subscribe to a channel `name`.
    #
    # The channel is created if it does not exist already.
    # The `name` may consist of alphanumeric ASCII characters plus underscore, dash, dot and colon.
    def subscribe(name : String)
      synchronize do
        write_command("subscribe", name)
        execute("fetch_nothing")
      end
    end

    # Unsubscribe from a channel `name`.
    def unsubscribe(name : String)
      synchronize do
        write_command("unsubscribe", name)
        execute("fetch_nothing")
      end
    end

    # Send a `message` to the specified `channel`.
    def sendmessage(channel : String, message : String)
      synchronize do
        write_command("sendmessage", channel, message)
        execute("fetch_nothing")
      end
    end

    # Reads messages for this client. The response is a list of `channel:` and `message:` lines.
    def readmessages
      synchronize do
        write_command("readmessages")
        execute("fetch_messages")
      end
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
      when MPD::Range
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
    private def parse_range(range : MPD::Range) : String
      range_start = range.begin
      range_end = range.end

      range_start = 0 if range_start.nil? || range_start < 0
      range_end = -1 if range_end.nil?
      range_end += 1 unless range.exclusive?
      range_end = nil if range_end <= 0

      "#{range_start}:#{range_end}"
    end

    # :nodoc:
    private def write_line(line : String)
      @socket.try do |socket|
        Log.debug { "request: `#{line}`" }

        socket.puts(line)
      end
    rescue RuntimeError
      reconnect

      @socket.try do |socket|
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
    private def fetch_object : MPD::Object?
      fetch_objects.first?
    end

    # Some commands can return binary data.
    # This is initiated by a line containing `binary: 1234` (followed as usual by a newline).
    # After that, the specified number of bytes of binary data follows, then a newline, and finally the `OK` line.
    #
    # If the object to be transmitted is large, the server may choose a reasonable chunk size.
    # Usually, the response also contains a `size` line which specifies the total (uncropped) size,
    # and the command usually has a way to specify an offset into the object
    #
    # Example:
    #
    # ```
    # albumart foo/bar.ogg 0
    # size: 1024768
    # binary: 8192
    # <8192 bytes>
    # OK
    # ```
    private def fetch_binary(io : IO::Memory, offset = 0, *args)
      data = {} of String => String

      synchronize do
        write_command(*args, offset)

        binary = false

        read_pairs.each do |item|
          if binary
            io << item.join(": ")
            next
          end

          key = item[0]
          value = item[1].chomp

          binary = true if key == "binary"

          data[key] = value
        end
      end

      size = data["size"].to_i
      binary = data["binary"].to_i

      next_offset = offset + binary

      return io if next_offset >= size

      io.seek(-1, IO::Seek::Current)
      fetch_binary(io, next_offset, *args)
    end

    # :nodoc:
    private def fetch_objects(delimiters = [] of String) : Objects
      result = MPD::Objects.new
      obj = MPD::Object.new

      read_pairs.each do |item|
        key = item[0]
        value = item[1].chomp

        if delimiters.includes?(key)
          result << obj unless obj.empty?
          obj = MPD::Object.new
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
    private def read_pairs : MPD::Pairs
      pairs = MPD::Pairs.new

      pair = read_pair
      while !pair.empty?
        pairs << pair
        pair = read_pair
      end

      pairs
    end

    # :nodoc:
    private def read_pair : MPD::Pair
      line = read_line
      return MPD::Pair.new if line.nil?
      pair = line.split(": ", 2)

      pair
    end

    # :nodoc:
    private def read_line : String?
      @socket.try do |socket|
        line = socket.gets(chomp: false)

        Log.debug { "response: `#{line}`" }

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
