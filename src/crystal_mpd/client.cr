module MPD
  alias Object = Hash(String, String)
  alias Objects = Array(MPD::Object)
  alias Pair = Array(String)
  alias Pairs = Array(MPD::Pair)
  alias Range = ::Range(Int32, Int32) | ::Range(Nil, Int32) | ::Range(Int32, Nil) | ::Range(Nil, Nil)

  # An MPD Client.
  #
  # ### One-shot usage
  #
  # ```
  # require "crystal_mpd"
  #
  # mpd = MPD::Client.new("localhost", 6600)
  # puts mpd.version
  # puts mpd.status
  # puts mpd.stats
  # mpd.disconnect
  # ```
  class Client
    @version : String?

    HELLO_PREFIX = "OK MPD "
    ERROR_PREFIX = "ACK "
    SUCCESS      = "OK\n"
    NEXT         = "list_OK\n"

    EVENTS_LIST = [
      :volume, :repeat, :random, :single, :consume, :playlist, :playlistlength, :mixrampdb, :state,
      :song, :songid, :time, :elapsed, :bitrate, :duration, :audio, :nextsong, :nextsongid,
    ]

    getter host, port, version
    property callbacks_timeout : Time::Span = 1.second

    # Creates a new MPD client. Parses the `host`, `port`.
    #
    # This constructor will raise an exception if could not connect to MPD
    def initialize(
      @host : String = "localhost",
      @port : Int32 = 6600,
      *,
      @with_callbacks = false,
      @password : String? = nil,
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
      password
      callback_thread if @with_callbacks
    end

    # Disconnect from the MPD daemon.
    def disconnect
      @socket.try &.close
      reset
    end

    # This will register a block callback that will trigger whenever
    # that specific event happens.
    #
    # ```
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

      @callbacks[event].each(&.call(arg))
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
              next if val.nil? || val == old_status[key]?

              emit(key, val)
            end

            old_status = new_status
          end
        end
      end

      Fiber.yield
    end

    private def get_status(status : Hash(String, String)) : Hash(Symbol, String?)
      EVENTS_LIST.each_with_object({} of Symbol => String | Nil) do |event, hash|
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
        if response = socket.gets(chomp: false)
          raise MPD::Error.new("Connection lost while reading MPD hello") unless response.ends_with?("\n")

          response = response.chomp

          raise MPD::Error.new("Got invalid MPD hello: #{response}") unless response.starts_with?(HELLO_PREFIX)

          @version = response[/#{HELLO_PREFIX}(.*)/, 1]
        end
      end
    end

    # This is used for authentication with the server.
    private def password
      return unless @password

      synchronize do
        write_command("password", @password)
        execute("fetch_nothing")
      end
    end

    private def synchronize(&)
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

    # https://mpd.readthedocs.io/en/latest/protocol.html#command-lists
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

    def with_command_list(&)
      command_list_ok_begin

      yield
    ensure
      command_list_end
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

    # Shows which commands the current user has access to.
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

    # Displays the song info of the current song (same song that is identified in `#status`).
    def currentsong
      synchronize do
        write_command("currentsong")
        execute("fetch_object")
      end
    end

    # Show the currently queued (next) song.
    def nextsong : Object?
      if _status = status
        if nextsongid = _status["nextsongid"]?
          if songs = playlistid(nextsongid.to_i)
            songs.first
          end
        end
      end
    end

    # Same as `#update`, but also rescans unmodified files.
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

    # Displays a list of all songs in the playlist,
    #
    # or if the optional argument is given, displays information only for
    # the song `songpos` or the range of songs `START:END`.
    #
    # Range is done in by using `MPD::Range`.
    #
    # Show info about the first three songs in the playlist:
    #
    # ```
    # mpd.playlistinfo
    # mpd.playlistinfo(1..3)
    # mpd.playlistinfo(..3)
    # mpd.playlistinfo(10..)
    # ```
    #
    # With negative range end MPD will assumes the biggest possible number then
    #
    # ```
    # mpd.playlistinfo(10..-1)
    # ```
    def playlistinfo(songpos : Int32 | MPD::Range | Nil = nil)
      synchronize do
        write_command("playlistinfo", songpos)
        execute("fetch_songs")
      end
    end

    # Search the queue for songs matching `filter`.
    # Parameters have the same meaning as for `find`, except that search is not case sensitive.
    def playlistsearch(filter : String, *, sort : String? = nil, window : MPD::Range? = nil)
      synchronize do
        hash = {} of String => String

        sort.try { hash["sort"] = sort }
        window.try { hash["window"] = parse_range(window) }

        write_command("playlistsearch", filter, hash)
        execute("fetch_songs")
      end
    end

    # :ditto:
    def playlistsearch(filter : MPD::Filter, *, sort : String? = nil, window : MPD::Range? = nil)
      playlistsearch(filter.to_s, sort: sort, window: window)
    end

    # Search the queue for songs matching `filter`.
    #
    # `sort` sorts the result by the specified tag.
    # The sort is descending if the tag is prefixed with a minus ('-').
    # Only the first tag value will be used, if multiple of the same type exist.
    # To sort by "Title", "Artist", "Album", "AlbumArtist" or "Composer",
    # you should specify "TitleSort", "ArtistSort", "AlbumSort", "AlbumArtistSort" or "ComposerSort" instead.
    # These will automatically fall back to the former if "*Sort" doesn’t exist.
    # "AlbumArtist" falls back to just "Artist".
    # The type "Last-Modified" can sort by file modification time, and "prio" sorts by queue priority.
    #
    # `window` can be used to query only a portion of the real response.
    def playlistfind(filter : String, *, sort : String? = nil, window : MPD::Range? = nil)
      synchronize do
        hash = {} of String => String

        sort.try { hash["sort"] = sort }
        window.try { hash["window"] = parse_range(window) }

        write_command("playlistfind", filter, hash)
        execute("fetch_songs")
      end
    end

    # :ditto
    def playlistfind(filter : MPD::Filter, *, sort : String? = nil, window : MPD::Range? = nil)
      playlistfind(filter.to_s, sort: sort, window: window)
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

    # Delete all playlist entries except the one currently playing
    def crop
      curren_song = currentsong

      return unless curren_song

      if songs = playlistinfo
        with_command_list do
          songs.each do |song|
            next if song["file"] == curren_song["file"]

            deleteid(song["Id"].to_i)
          end
        end
      end
    end

    # Moves the song at `from` or range of songs at `from` to `to` in the playlist.
    def move(from : Int32 | MPD::Range, to : Int32)
      synchronize do
        write_command("move", from, to)
        execute("fetch_nothing")
      end
    end

    # Moves the song with `from` (songid) to `to` (playlist index) in the playlist.
    #
    # If `to` starts with "+" or "-", then it is relative to the current song;
    # e.g. "+0" moves to right after the current song
    # and "-0" moves to right before the current song (i.e. zero songs between the current song and the moved song).
    def moveid(from : Int32, to : Int32 | String)
      synchronize do
        write_command("moveid", from, to)
        execute("fetch_nothing")
      end
    end

    # Loads the playlist `name` into the current queue.
    #
    # Playlist plugins are supported.
    # A range `songpos` may be specified to load only a part of the playlist.
    #
    # The `position` parameter specifies where the songs will be inserted into the queue;
    # it can be relative as described in `addid`.
    # (This requires specifying the range as well;
    # the special value 0: can be used if the whole playlist shall be loaded at a certain queue position.)
    def load(name : String, songpos : Int32 | MPD::Range | Nil = nil, position : Int32 | String | Nil = nil)
      synchronize do
        write_command("load", name, songpos, position)
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
    #
    # `mode` is optional argument. One of "create", "append", or "replace".
    #
    # - "create": The default. Create a new playlist. Fail if a playlist with name `name` already exists.
    # - "append", "replace": Append or replace an existing playlist. Fail if a playlist with name `name` doesn't already exist.
    def save(name : String, mode : String? = nil)
      synchronize do
        write_command("save", name, mode)
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

    # Count the number of songs and their total playtime (seconds) in the playlist.
    def playlistlength(name : String)
      synchronize do
        write_command("playlistlength", name)
        execute("fetch_object")
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

    # Search the database for songs matching `filter` and add them to the queue.
    #
    # If a playlist by that `name` doesn't exist it is created.
    #
    # Parameters have the same meaning as for `search`.
    #
    # The `position` parameter specifies where the songs will be inserted.
    # It can be relative to the current song as in `addid`.
    def searchaddpl(name : String, filter : String, *, sort : String? = nil, window : MPD::Range? = nil, position : Int32 | String | Nil = nil)
      synchronize do
        hash = {} of String => String

        sort.try { hash["sort"] = sort }
        window.try { hash["window"] = parse_range(window) }
        position.try { hash["position"] = position }

        write_command("searchaddpl", name, filter, hash)
        execute("fetch_nothing")
      end
    end

    # :ditto:
    def searchaddpl(name : String, filter : MPD::Filter, *, sort : String? = nil, window : MPD::Range? = nil, position : Int32 | String | Nil = nil)
      searchaddpl(name, filter.to_s, sort: sort, window: window, position: position)
    end

    # Count the number of songs and their total playtime in the database matching `filter`.
    # Parameters have the same meaning as for `count` except the search is not case sensitive.
    def searchcount(filter : String, *, group : String? = nil)
      synchronize do
        hash = {} of String => String

        group.try { hash["group"] = group }

        write_command("searchcount", filter, hash)

        execute("fetch_counts")
      end
    end

    # :ditto:
    def searchcount(filter : MPD::Filter, *, group : String? = nil)
      searchcount(filter.to_s, group: group)
    end

    # Lists the songs in the playlist `name`.
    #
    # Playlist plugins are supported.
    # A `range` may be specified to list only a part of the playlist
    def listplaylist(name : String, range : MPD::Range? = nil)
      synchronize do
        if range
          write_command("listplaylist", name, parse_range(range))
        else
          write_command("listplaylist", name)
        end

        execute("fetch_list")
      end
    end

    # Lists the songs with metadata in the playlist.
    #
    # Playlist plugins are supported.
    # A `range` may be specified to list only a part of the playlist.
    def listplaylistinfo(name : String, range : MPD::Range? = nil)
      synchronize do
        if range
          write_command("listplaylistinfo", name, parse_range(range))
        else
          write_command("listplaylistinfo", name)
        end

        execute("fetch_songs")
      end
    end

    # Search the playlist for songs matching `filter`.
    # A range may be specified to list only a part of the playlist.
    def searchplaylist(name : String, filter : String | Nil = nil, *, window : MPD::Range? = nil)
      synchronize do
        hash = {} of String => String

        window.try { hash["window"] = parse_range(window) }

        write_command("searchplaylist", name, filter, hash)
        execute("fetch_songs")
      end
    end

    # :ditto:
    def searchplaylist(name : String, filter : MPD::Filter | Nil = nil, *, window : MPD::Range? = nil)
      searchplaylist(name, filter, window: window)
    end

    # Adds `uri` to the playlist `name`.m3u.
    #
    # `name`.m3u will be created if it does not exist.
    #
    # The `position` parameter specifies where the songs will be inserted into the playlist.
    def playlistadd(name : String, uri : String, position : Int32 | String | Nil = nil)
      synchronize do
        write_command("playlistadd", name, uri, position)
        execute("fetch_nothing")
      end
    end

    # Moves the song at position `from` in the playlist `name`.m3u to the position `to`.
    def playlistmove(name : String, from : Int32 | MPD::Range, to : Int32)
      synchronize do
        write_command("playlistmove", name, from, to)
        execute("fetch_nothing")
      end
    end

    # Set the priority of the specified songs.
    #
    # A higher priority means that it will be played first when “random” mode is enabled.
    #
    # A `priority` is an integer between 0 and 255. The default priority of new songs is 0.
    def prio(priority : Int32, range : MPD::Range)
      synchronize do
        write_command("prio", priority, parse_range(range))
        execute("fetch_nothing")
      end
    end

    # Same as `prio`, but address the songs with their id.
    def prioid(priority : Int32, songid : Int32)
      synchronize do
        write_command("prioid", priority, songid)
        execute("fetch_nothing")
      end
    end

    # Deletes `songpos` from the playlist `name`.m3u.
    #
    # The `songpos` parameter can be a range.
    def playlistdelete(name : String, songpos : Int32 | MPD::Range)
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

    # Pause or resume playback.
    # Pass `state` `true` to pause playback or `false` to resume playback.
    # Without the parameter, the pause state is toggled.
    def pause(state : Bool? = nil)
      synchronize do
        if state
          write_command("pause", boolean(state))
        else
          write_command("pause")
        end

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
    # `window` works like in `find`. In this command, it affects only the top-most tag type.
    # `group` keyword may be used to group the results by tags.
    #
    # ```
    # mpd.list("Artist")
    # ```
    #
    # Additional arguments may specify a `filter`.
    # The following example lists all file names by their respective artist and date:
    #
    # ```
    # mpd.list("Artist")
    # mpd.list("filename", "((artist == 'Linkin Park') AND (date == '2003'))")
    # ```
    def list(type : String, filter : String | Nil = nil, *, group : String? = nil, window : MPD::Range? = nil)
      synchronize do
        hash = {} of String => String

        group.try { hash["group"] = group }
        window.try { hash["window"] = parse_range(window) }

        write_command("list", type, filter, hash)
        execute("fetch_list")
      end
    end

    # :ditto:
    def list(type : String, filter : MPD::Filter | Nil = nil, *, group : String? = nil, window : MPD::Range? = nil)
      list(type, filter.to_s, group: group, window: window)
    end

    # Locate album art for the given song
    def albumart(uri : String)
      fetch_binary(IO::Memory.new, 0, "albumart", uri)
    end

    # Locate a picture for the given song
    def readpicture(uri : String)
      fetch_binary(IO::Memory.new, 0, "readpicture", uri)
    end

    # Count the number of songs and their total playtime in the database matching `filter`.
    #
    # ```
    # mpd.count("(genre == 'Rock')")
    # => {"songs" => "11", "playtime" => "2496"}
    # ```
    #
    # The `group` keyword may be used to group the results by a tag.
    # The first following example prints per-artist counts
    # while the next prints the number of songs whose title matches "Echoes" grouped by artist:
    #
    # ```
    # mpd.count("(genre != 'Pop')", group: "artist")
    # => [{"Artist" => "Artist 1", "songs" => "11", "playtime" => "2388"}, {"Artist" => "Artist 2", "songs" => "12", "playtime" => "2762"}]
    # ```
    def count(filter : String, *, group : String? = nil)
      synchronize do
        hash = {} of String => String

        group.try { hash["group"] = group }

        write_command("count", filter, hash)

        execute("fetch_counts")
      end
    end

    # :ditto:
    def count(filter : MPD::Filter, *, group : String? = nil)
      count(filter, group: group)
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

    # Changes volume by amount `change`.
    def volume(change : Int)
      synchronize do
        write_command("volume", change)
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

    # Read the volume.
    # The result is a `{"volume" => "100"}` like in `status`.
    def getvol
      synchronize do
        write_command("getvol")
        execute("fetch_object")
      end
    end

    # Sets single state to `state`, `state` should be `false`, `true` or `"oneshot"`.
    #
    # When single is activated, playback is stopped after current song,
    # or song is repeated if the `repeat` mode is enabled.
    def single(state : Bool | String)
      synchronize do
        state = state.is_a?(String) ? state : boolean(state)

        write_command("single", state)
        execute("fetch_nothing")
      end
    end

    # Sets consume state to `state`, `state` should be `false`, `true` or `"oneshot"`.
    #
    # When consume is activated, each song played is removed from playlist.
    def consume(state : Bool | String)
      synchronize do
        state = state.is_a?(String) ? state : boolean(state)

        write_command("consume", state)
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
    #
    # The `position` parameter is the same as in `addid`.
    def add(uri : String, position : Int32 | String | Nil = nil)
      synchronize do
        write_command("add", uri, position)
        execute("fetch_nothing")
      end
    end

    # Adds a song to the playlist (non-recursive) and returns the song id.
    # `uri` is always a single file or URL.
    #
    # If the `position` is given, then the song is inserted at the specified position.
    # If the parameter is string and starts with "+" or "-", then it is relative to the current song;
    # e.g. "+0" inserts right after the current song
    # and "-0" inserts right before the current song (i.e. zero songs between the current song and the newly added song).
    def addid(uri : String, position : Int32 | String | Nil = nil)
      synchronize do
        write_command("addid", uri, position)
        execute("fetch_object")
      end
    end

    # Search the database for songs matching `filter`.
    #
    # `sort` sorts the result by the specified tag.
    # The sort is descending if the tag is prefixed with a minus (`-`).
    # Without `sort`, the order is undefined.
    # Only the first tag value will be used, if multiple of the same type exist.
    # To sort by "Artist", "Album" or "AlbumArtist", you should specify "ArtistSort", "AlbumSort" or "AlbumArtistSort" instead.
    # These will automatically fall back to the former if "*Sort" doesn't exist.
    # "AlbumArtist" falls back to just "Artist".
    # The type "Last-Modified" can sort by file modification time.
    #
    # `window` can be used to query only a portion of the real response.
    # The parameter is two zero-based record numbers; a start number and an end number.
    #
    # ```
    # mpd.find("(genre != 'Pop')", sort: "-ArtistSort", window: (5..10))
    # mpd.find("(genre starts_with 'Indie')")
    # mpd.find("(genre starts_with_ci 'inDIE')")
    # mpd.find("(genre contains 'Rock')")
    # mpd.find("(genre contains_ci 'RocK')")
    # ```
    def find(filter : String, *, sort : String? = nil, window : MPD::Range? = nil)
      synchronize do
        hash = {} of String => String

        sort.try { hash["sort"] = sort }
        window.try { hash["window"] = parse_range(window) }

        write_command("find", filter, hash)
        execute("fetch_songs")
      end
    end

    # :ditto:
    def find(filter : MPD::Filter, *, sort : String? = nil, window : MPD::Range? = nil)
      find(filter.to_s, sort: sort, window: window)
    end

    # Search the database for songs matching `filter`.
    #
    # Parameters have the same meaning as for `#find`, except that search is not case sensitive.
    #
    # ```
    # mpd.search("(any =~ 'crystal')")
    # ```
    def search(filter : String, *, sort : String? = nil, window : MPD::Range? = nil)
      synchronize do
        hash = {} of String => String

        sort.try { hash["sort"] = sort }
        window.try { hash["window"] = parse_range(window) }

        write_command("search", filter, hash)
        execute("fetch_songs")
      end
    end

    # :ditto:
    def search(filter : MPD::Filter, *, sort : String? = nil, window : MPD::Range? = nil)
      search(filter.to_s, sort: sort, window: window)
    end

    # Search the database for songs matching `filter` and add them to the queue.
    #
    # Parameters have the same meaning as for `#find` and `#searchadd`.
    #
    # ```
    # mpd.findadd("(genre == 'Alternative Rock')")
    # ```
    def findadd(filter : String, *, sort : String? = nil, window : MPD::Range? = nil, position : Int32 | String | Nil = nil)
      synchronize do
        hash = {} of String => String

        sort.try { hash["sort"] = sort }
        window.try { hash["window"] = parse_range(window) }
        position.try { hash["position"] = position }

        write_command("findadd", filter, hash)
        execute("fetch_nothing")
      end
    end

    # :ditto:
    def findadd(filter : MPD::Filter, *, sort : String? = nil, window : MPD::Range? = nil, position : Int32 | String | Nil = nil)
      findadd(filter.to_s, sort: sort, window: window, position: position)
    end

    # Search the database for songs matching `filter` and add them to the queue.
    #
    # Parameters have the same meaning as for `#search`.
    #
    # The `position` parameter specifies where the songs will be inserted.
    # It can be relative to the current song as in `#addid`.
    def searchadd(filter : String, *, sort : String? = nil, window : MPD::Range? = nil, position : Int32 | String | Nil = nil)
      synchronize do
        hash = {} of String => String

        sort.try { hash["sort"] = sort }
        window.try { hash["window"] = parse_range(window) }
        position.try { hash["position"] = position }

        write_command("searchadd", filter, hash)
        execute("fetch_nothing")
      end
    end

    # :ditto:
    def searchadd(filter : MPD::Filter, *, sort : String? = nil, window : MPD::Range? = nil, position : Int32 | String | Nil = nil)
      searchadd(filter.to_s, sort: sort, window: window, position: position)
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
    # This behavior is deprecated; use `#listplaylists` instead.
    #
    # Clients that are connected via UNIX domain socket may use this command
    # to read the tags of an arbitrary local file (`uri` beginning with `file:///`).
    def lsinfo(uri : String? = nil)
      synchronize do
        write_command("lsinfo", uri)
        execute("fetch_database")
      end
    end

    # Same as `#listall`, except it also returns metadata info in the same format as `#lsinfo`.
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

    # Shows a list of available tag types.
    def tagtypes
      synchronize do
        write_command("tagtypes")
        execute("fetch_list")
      end
    end

    # Shows a list of enabled protocol features.
    #
    # Available features:
    #
    # "hide_playlists_in_root": disables the listing of stored playlists for the `lsinfo`.
    def protocol
      synchronize do
        write_command("protocol")
        execute("fetch_list")
      end
    end

    # Lists all available protocol features.
    def protocol_available
      synchronize do
        write_command("protocol available")
        execute("fetch_list")
      end
    end

    # Enables a `feature`.
    def protocol_enable(feature : String)
      synchronize do
        write_command("protocol enable #{feature}")
        execute("fetch_nothing")
      end
    end

    # Disables a `feature`.
    def protocol_disable(feature : String)
      synchronize do
        write_command("protocol disable #{feature}")
        execute("fetch_nothing")
      end
    end

    # Disables all protocol features.
    def protocol_clear
      synchronize do
        write_command("protocol clear")
        execute("fetch_nothing")
      end
    end

    # Enables all protocol features.
    def protocol_all
      synchronize do
        write_command("protocol all")
        execute("fetch_nothing")
      end
    end

    # Reads a sticker value for the specified object.
    def sticker_get(type : String, uri : String, name : String) : String?
      synchronize do
        write_command("sticker get", type, uri, name)
        item = execute("fetch_item")

        item.split("=", 2)[1]
      end
    end

    # Adds a sticker value to the specified object.
    # If a sticker item with that name already exists, it is replaced.
    def sticker_set(type : String, uri : String, name : String, value : String)
      synchronize do
        write_command("sticker set", type, uri, name, value)
        execute("fetch_nothing")
      end
    end

    # Adds a sticker value to the specified object.
    # If a sticker item with that name already exists, it is incremented by supplied value.
    def sticker_inc(type : String, uri : String, name : String, value : Int32)
      synchronize do
        write_command("sticker inc", type, uri, name, value)
        execute("fetch_nothing")
      end
    end

    # Adds a sticker value to the specified object.
    # If a sticker item with that name already exists, it is decremented by supplied value.
    def sticker_dec(type : String, uri : String, name : String, value : Int32)
      synchronize do
        write_command("sticker dec", type, uri, name, value)
        execute("fetch_nothing")
      end
    end

    # Deletes a sticker value from the specified object.
    #
    # If you do not specify a sticker name, all sticker values are deleted.
    def sticker_delete(type : String, uri : String, name : String? = nil)
      synchronize do
        write_command("sticker delete", type, uri, name)
        execute("fetch_nothing")
      end
    end

    # Lists the stickers for the specified object.
    def sticker_list(type : String, uri : String) : Hash(String, String)?
      synchronize do
        write_command("sticker list", type, uri)
        list = execute("fetch_sticker_list")

        list.map(&.["sticker"]).map(&.split("=", 2)).to_h
      end
    end

    # Searches the sticker database for stickers with the specified `name`, below the specified directory (`uri`).
    # For each matching song, it prints the URI and that one sticker’s value.
    #
    # `sort` sorts the result by "uri", "value" or "value_int" (casts the sticker value to an integer).
    #
    # Returns:
    #
    # ```
    # client.sticker_find("song", "path/to/folder", "name1")
    # # => [{"file" => "path/to/folder/file1.ogg", "sticker" => "name1=value1"}, ...]
    # ```
    def sticker_find(type : String, uri : String, name : String,
                     *, sort : String? = nil, window : MPD::Range? = nil)
      synchronize do
        hash = {} of String => String

        sort.try { hash["sort"] = sort }
        window.try { hash["window"] = parse_range(window) }

        write_command("sticker find", type, uri, name, hash)
        execute("fetch_songs")
      end
    end

    # Searches for stickers with the given value.
    #
    # Other supported operators are: "<", ">", "contains", "starts_with" for strings
    # and "eq", "lt", "gt" to cast the value to an integer.
    def sticker_find(type : String, uri : String, name : String, value : String, operator : String = "=",
                     *, sort : String? = nil, window : MPD::Range? = nil)
      synchronize do
        hash = {} of String => String

        sort.try { hash["sort"] = sort }
        window.try { hash["window"] = parse_range(window) }

        write_command("sticker find", type, uri, name, hash)
        execute("fetch_songs")
      end
    end

    # Gets a list of uniq sticker names.
    def stickernames
      synchronize do
        write_command("stickernames")
        execute("fetch_list")
      end
    end

    # Shows a list of available sticker types.
    def stickertypes
      synchronize do
        write_command("stickertypes")
        execute("fetch_list")
      end
    end

    # Gets a list of uniq sticker names and their types.
    def stickernamestypes(type : String)
      synchronize do
        write_command("stickernamestypes", type)
        execute("fetch_stickernamestypes")
      end
    end

    # :nodoc:
    private def write_command(command : String, *args)
      line = MPD::CommandBuilder.build(command, *args)
      write_line(line)
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
    private def parse_range(range : MPD::Range) : String
      start = range.begin || 0
      end_ = range.end || -1
      end_ += 1 unless range.exclusive?
      "#{start}:#{end_}"
    end

    # :nodoc:
    private def write_line(line : String)
      @socket.try do |socket|
        if line.starts_with?("password")
          Log.debug { "request: `password \"******\"`" }
        else
          Log.debug { "request: `#{line}`" }
        end

        socket.puts(line)
      end
    rescue RuntimeError
      reconnect

      @socket.try &.puts(line)
    end

    # :nodoc:
    private def fetch_nothing
      line = read_line

      raise MPD::Error.new("Got unexpected return value: #{line}") unless line.nil?
    end

    # :nodoc:
    private def fetch_list : Array(String)
      seen = nil

      read_pairs.reduce([] of String) do |result, item|
        key = item[0]
        value = item[1]

        if key != seen
          raise MPD::Error.new("Expected key '#{seen}', got '#{key}'") unless seen.nil?

          seen = key
        end

        result << value.chomp
      end
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
    private def fetch_binary(io : IO::Memory, offset = 0, *args) : Tuple(Hash(String, String), IO::Memory)
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

      return {data, io} if next_offset >= size

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
    private def fetch_counts : Object | Objects
      result = MPD::Objects.new
      obj = MPD::Object.new

      read_pairs.each do |item|
        key = item[0]
        value = item[1].chomp

        if obj.has_key?(key)
          result << obj unless obj.empty?
          obj = MPD::Object.new
        end

        obj[key] = value
      end

      result << obj unless obj.empty?

      result.one? ? result.first : result
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
    def fetch_sticker_list
      fetch_objects("sticker")
    end

    # :nodoc:
    def fetch_stickernamestypes
      fetch_objects("name")
    end

    # :nodoc:
    private def fetch_item : String
      pairs = read_pairs

      return "" unless pairs.one?

      pairs[0][1].chomp
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

      line.split(": ", 2)
    end

    # :nodoc:
    private def read_line : String?
      @socket.try do |socket|
        if line = socket.gets(chomp: false)
          Log.debug { "response: #{line.inspect}" }

          if line.starts_with?(ERROR_PREFIX)
            error = line[/#{ERROR_PREFIX}(.*)/, 1].strip

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
    end

    # :nodoc:
    private def reset
      @socket = nil
      @version = nil
    end

    # :nodoc:
    private def boolean(value : Bool)
      value ? 1 : 0
    end

    # :nodoc:
    private def escape(str : String)
      str.gsub(%{\\}, %{\\\\}).gsub(%{"}, %{\\"})
    end
  end
end
