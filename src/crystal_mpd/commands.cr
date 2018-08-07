module MPD
  # :nodoc:
  RETVALS = [
    "fetch_nothing", "fetch_list", "fetch_object", "fetch_objects",
    "fetch_songs", "fetch_outputs", "fetch_database", "fetch_plugins",
  ]

  # :nodoc:
  UNIMPLEMENTED_COMMANDS = [
    "addid", "addtagid",
    "clearerror", "cleartagid",
    "count", "crossfade",
    "deleteid", "disableoutput",
    "enableoutput",
    "idle",
    "kill",
    "listallinfo", "listfiles", "listmounts",
    "lsinfo",
    "mixrampdb", "mixrampdelay", "mount", "move", "moveid",
    "password", "ping",
    "plchanges", "plchangesposid",
    "prio", "prioid",
    "rangeid", "readcomments",
    "replay_gain_mode", "rescan",
    "searchaddpl",
    "setvol", "shuffle",
    "sticker", "swap", "swapid",
    "toggleoutput",
    "unmount",
    "volume",
  ]

  # :nodoc:
  COMMANDS = [
    {
      "name"    => "add",
      "retval"  => "fetch_nothing",
      "comment" => "
        Adds the file `uri` to the playlist (directories add recursively).

        `uri` can also be a single file.
      ",
      "args" => [
        {
          "name" => "uri",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "delete",
      "retval"  => "fetch_nothing",
      "comment" => "Deletes a song from the playlist.",
      "args"    => [
        {
          "name" => "songpos",
          "type" => "Int32 | Array(Int32)",
        },
      ],
    },
    {
      "name"    => "config",
      "retval"  => "fetch_item",
      "comment" => "
        Dumps configuration values that may be interesting for the client.

        This command is only permitted to `local` clients (connected via UNIX domain socket).",
      "args" => [] of Nil,
    },
    {
      "name"    => "clear",
      "retval"  => "fetch_nothing",
      "comment" => "Clears the current playlist.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "close",
      "retval"  => "",
      "comment" => "Closes the connection to MPD.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "commands",
      "retval"  => "fetch_list",
      "comment" => "Shows which commands the current user has access to.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "notcommands",
      "retval"  => "fetch_list",
      "comment" => "Shows which commands the current user does not have access to.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "decoders",
      "retval"  => "fetch_plugins",
      "comment" => "Print a list of decoder plugins, followed by their supported suffixes and MIME types.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "urlhandlers",
      "retval"  => "fetch_list",
      "comment" => "Gets a list of available URL handlers.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "channels",
      "retval"  => "fetch_list",
      "comment" => "Obtain a list of all channels. The response is a list of `channel:` lines.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "channels",
      "retval"  => "fetch_list",
      "comment" => "Obtain a list of all channels. The response is a list of `channel:` lines.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "subscribe",
      "retval"  => "fetch_nothing",
      "comment" => "
        Subscribe to a channel.

        The channel is created if it does not exist already.
        The `name` may consist of alphanumeric ASCII characters plus underscore, dash, dot and colon.
      ",
      "args" => [
        {
          "name" => "name",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "unsubscribe",
      "retval"  => "fetch_nothing",
      "comment" => "Unsubscribe from a channel.",
      "args"    => [
        {
          "name" => "name",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "sendmessage",
      "retval"  => "fetch_nothing",
      "comment" => "Send a message to the specified channel.",
      "args"    => [
        {
          "name" => "channel",
          "type" => "String",
        },
        {
          "name" => "text",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "readmessages",
      "retval"  => "fetch_messages",
      "comment" => "Reads messages for this client. The response is a list of `channel:` and `message:` lines.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "listall",
      "retval"  => "fetch_database",
      "comment" => "Lists all songs and directories in `uri`.",
      "args"    => [
        {
          "name" => "uri",
          "type" => "String?",
        },
      ],
    },
    {
      "name"    => "consume",
      "retval"  => "fetch_nothing",
      "comment" => "
        Sets consume state to `state`, `state` should be `false` or `true`.

        When consume is activated, each song played is removed from playlist.
      ",
      "args" => [
        {
          "name" => "state",
          "type" => "Bool",
        },
      ],
    },
    {
      "name"    => "random",
      "retval"  => "fetch_nothing",
      "comment" => "Sets random state to `state`, `state` should be `false` or `true`.",
      "args"    => [
        {
          "name" => "state",
          "type" => "Bool",
        },
      ],
    },
    {
      "name"    => "repeat",
      "retval"  => "fetch_nothing",
      "comment" => "Sets repeat state to `state`, `state` should be `false` or `true`.",
      "args"    => [
        {
          "name" => "state",
          "type" => "Bool",
        },
      ],
    },
    {
      "name"    => "single",
      "retval"  => "fetch_nothing",
      "comment" => "
        Sets single state to `state`, `state` should be `false` or `true`.

        When single is activated, playback is stopped after current song,
        or song is repeated if the `repeat` mode is enabled.
      ",
      "args" => [
        {
          "name" => "state",
          "type" => "Bool",
        },
      ],
    },
    {
      "name"    => "play",
      "retval"  => "fetch_nothing",
      "comment" => "Begins playing the playlist at song number `songpos`.",
      "args"    => [
        {
          "name" => "songpos",
          "type" => "Int32? = nil",
        },
      ],
    },
    {
      "name"    => "playid",
      "retval"  => "fetch_nothing",
      "comment" => "Begins playing the playlist at song `songid`.",
      "args"    => [
        {
          "name" => "songid",
          "type" => "Int32",
        },
      ],
    },
    {
      "name"    => "seekcur",
      "retval"  => "fetch_nothing",
      "comment" => "
        Seeks to the position `time` within the current song.
        If prefixed by `+` or `-`, then the time is relative to the current playing position.
      ",
      "args" => [
        {
          "name" => "time",
          "type" => "String | Int32",
        },
      ],
    },
    {
      "name"    => "seekid",
      "retval"  => "fetch_nothing",
      "comment" => "Seeks to the position `time` (in seconds) of song `songid`.",
      "args"    => [
        {
          "name" => "songid",
          "type" => "Int32",
        },
        {
          "name" => "time",
          "type" => "Int32",
        },
      ],
    },
    {
      "name"    => "seek",
      "retval"  => "fetch_nothing",
      "comment" => "Seeks to the position `time` (in seconds) of entry `songpos` in the playlist.",
      "args"    => [
        {
          "name" => "songpos",
          "type" => "Int32",
        },
        {
          "name" => "time",
          "type" => "Int32",
        },
      ],
    },
    {
      "name"    => "stop",
      "retval"  => "fetch_nothing",
      "comment" => "Stops playing.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "next",
      "retval"  => "fetch_nothing",
      "comment" => "Plays next song in the playlist.",
      "args"    => [
        {
          "name" => "state",
          "type" => "Bool",
        },
      ],
    },
    {
      "name"    => "previous",
      "retval"  => "fetch_nothing",
      "comment" => "Plays previous song in the playlist.",
      "args"    => [
        {
          "name" => "state",
          "type" => "Bool",
        },
      ],
    },
    {
      "name"    => "pause",
      "retval"  => "fetch_nothing",
      "comment" => "Toggles pause/resumes playing, `pause` is `true` or `false`.",
      "args"    => [
        {
          "name" => "state",
          "type" => "Bool",
        },
      ],
    },
    {
      "name"    => "search",
      "retval"  => "fetch_songs",
      "comment" => "
        Searches for any song that contains `query`.

        Parameters have the same meaning as for `find`, except that search is not case sensitive.
      ",
      "args" => [
        {
          "name" => "type",
          "type" => "String",
        },
        {
          "name" => "query",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "find",
      "retval"  => "fetch_songs",
      "comment" => "
        Finds songs in the db that are exactly `query`.

        `type` can be any tag supported by MPD, or one of the two special parameters:

        * `file` to search by full path (relative to database root)
        * `any` to match against all available tags.

        `query` is what to find.
      ",
      "args" => [
        {
          "name" => "type",
          "type" => "String",
        },
        {
          "name" => "query",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "findadd",
      "retval"  => "fetch_nothing",
      "comment" => "
        Finds songs in the db that are exactly `query` and adds them to current playlist.

        Parameters have the same meaning as for `find`.
      ",
      "args" => [
        {
          "name" => "type",
          "type" => "String",
        },
        {
          "name" => "query",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "searchadd",
      "retval"  => "fetch_nothing",
      "comment" => "
        Searches for any song that contains `query` in tag `type` and adds them to current playlist.

        Parameters have the same meaning as for `find`, except that search is not case sensitive.
      ",
      "args" => [
        {
          "name" => "type",
          "type" => "String",
        },
        {
          "name" => "query",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "playlistfind",
      "retval"  => "fetch_songs",
      "comment" => "Finds songs in the current playlist with strict matching.",
      "args"    => [
        {
          "name" => "tag",
          "type" => "String",
        },
        {
          "name" => "needle",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "playlistsearch",
      "retval"  => "fetch_songs",
      "comment" => "Searches case-sensitively for partial matches in the current playlist.",
      "args"    => [
        {
          "name" => "tag",
          "type" => "String",
        },
        {
          "name" => "needle",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "playlistinfo",
      "retval"  => "fetch_songs",
      "comment" => "
        Displays a list of all songs in the playlist, or if the optional argument is given,
        displays information only for the song `songpos` or the range of songs `START:END`.

        Range is done in by using two element array.

         Show info about the first three songs in the playlist:

         ```crystal
         client.playlistinfo([1, 3])
         ```

         Second element of the `Array` can be omitted. `MPD` will assumes the biggest possible number then:

         ```crystal
         client.playlistinfo([10])
         ```
      ",
      "args" => [
        {
          "name" => "songpos",
          "type" => "Int32 | Array(Int32) | Nil = nil",
        },
      ],
    },
    {
      "name"    => "playlistclear",
      "retval"  => "fetch_nothing",
      "comment" => "Clears the playlist `name`.m3u.",
      "args"    => [
        {
          "name" => "name",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "load",
      "retval"  => "fetch_nothing",
      "comment" => "
        Loads the playlist `name` into the current queue.

        Playlist plugins are supported.
        A range `songpos` may be specified to load only a part of the playlist.
      ",
      "args"    => [
        {
          "name" => "name",
          "type" => "String",
        },
        {
          "name" => "songpos",
          "type" => "Int32 | Array(Int32) | Nil = nil",
        },
      ],
    },
    {
      "name"    => "rename",
      "retval"  => "fetch_nothing",
      "comment" => "Renames the playlist `name`.m3u to `new_name`.m3u",
      "args"    => [
        {
          "name" => "name",
          "type" => "String",
        },
        {
          "name" => "new_name",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "rm",
      "retval"  => "fetch_nothing",
      "comment" => "Removes the playlist `name`.m3u from the playlist directory.",
      "args" => [
        {
          "name" => "name",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "save",
      "retval"  => "fetch_nothing",
      "comment" => "Saves the current playlist to `name`.m3u in the playlist directory",
      "args" => [
        {
          "name" => "name",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "playlist",
      "retval"  => "fetch_songs",
      "comment" => "Get current playlist",
      "args"    => [] of Nil,
    },
    {
      "name"    => "playlistid",
      "retval"  => "fetch_songs",
      "comment" => "
        Displays a list of songs in the playlist.

        `songid` is optional and specifies a single song to display info for.
      ",
      "args" => [
        {
          "name" => "songid",
          "type" => "Int32? = nil",
        },
      ],
    },
    {
      "name"    => "listplaylists",
      "retval"  => "fetch_playlists",
      "comment" => "
        Prints a list of the playlist directory.

        After each playlist name the server sends its last modification time
        as attribute `Last-Modified` in ISO 8601 format.
        To avoid problems due to clock differences between clients and the server,
        clients should not compare this value with their local clock.
      ",
      "args" => [] of Nil,
    },
    {
      "name"    => "playlistadd",
      "retval"  => "fetch_nothing",
      "comment" => "
        Adds `uri` to the playlist `name`.m3u.

        `name`.m3u will be created if it does not exist.
      ",
      "args" => [
        {
          "name" => "name",
          "type" => "String",
        },
        {
          "name" => "uri",
          "type" => "String",
        },

      ],
    },
    {
      "name"    => "playlistdelete",
      "retval"  => "fetch_nothing",
      "comment" => "Deletes `songpos` from the playlist `name`.m3u.",
      "args"    => [
        {
          "name" => "name",
          "type" => "String",
        },
        {
          "name" => "songpos",
          "type" => "Int32",
        },

      ],
    },
    {
      "name"    => "playlistmove",
      "retval"  => "fetch_nothing",
      "comment" => "Moves `songid` in the playlist `name`.m3u to the position `songpos`",
      "args"    => [
        {
          "name" => "name",
          "type" => "String",
        },
        {
          "name" => "songid",
          "type" => "Int32",
        },
        {
          "name" => "songpos",
          "type" => "Int32",
        },

      ],
    },
    {
      "name"    => "listplaylist",
      "retval"  => "fetch_list",
      "comment" => "
        Lists the songs in the playlist.

        Playlist plugins are supported.
      ",
      "args" => [
        {
          "name" => "name",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "listplaylistinfo",
      "retval"  => "fetch_songs",
      "comment" => "
        Lists the songs with metadata in the playlist.

        Playlist plugins are supported.
      ",
      "args" => [
        {
          "name" => "name",
          "type" => "String",
        },
      ],
    },
    {
      "name"    => "status",
      "retval"  => "fetch_object",
      "comment" => "
        Reports the current status of the player and the volume level.

        Response:
        * `volume`: 0-100
        * `repeat`: 0 or 1
        * `random`: 0 or 1
        * `single`: 0 or 1
        * `consume`: 0 or 1
        * `playlist`: 31-bit unsigned integer, the playlist version number
        * `playlistlength`: integer, the length of the playlist
        * `state`: play, stop, or pause
        * `song`: playlist song number of the current song stopped on or playing
        * `songid`: playlist songid of the current song stopped on or playing
        * `nextsong`: playlist song number of the next song to be played
        * `nextsongid`: playlist songid of the next song to be played
        * `time`: total time elapsed (of current playing/paused song)
        * `elapsed`: Total time elapsed within the current song, but with higher resolution.
        * `bitrate`: instantaneous bitrate in kbps
        * `xfade`: crossfade in seconds
        * `mixrampdb`: mixramp threshold in dB
        * `mixrampdelay`: mixrampdelay in seconds
        * `audio`: sampleRate:bits:channels
        * `updating_db`: job id
        * `error`: if there is an error, returns message here
      ",
      "args" => [] of Nil,
    },
    {
      "name"    => "stats",
      "retval"  => "fetch_object",
      "comment" => "
        Displays statistics.

        Response:
        * `artists`: number of artists
        * `songs`: number of albums
        * `uptime`: daemon uptime in seconds
        * `db_playtime`: sum of all song times in the db
        * `db_update`: last db update in UNIX time
        * `playtime`: time length of music played
      ",
      "args" => [] of Nil,
    },
    {
      "name"    => "replay_gain_status",
      "retval"  => "fetch_item",
      "comment" => "",
      "args"    => [] of Nil,
    },
    {
      "name"    => "update",
      "retval"  => "fetch_item",
      "comment" => "
        Updates the music database: find new files, remove deleted files, update modified files.

        `uri` is a particular directory or song/file to update. If you do not specify it, everything is updated.
      ",
      "args" => [
        {
          "name" => "uri",
          "type" => "String? = nil",
        },
      ],
    },
    {
      "name"    => "currentsong",
      "retval"  => "fetch_object",
      "comment" => "Displays the song info of the current song (same song that is identified in `status`).",
      "args"    => [] of Nil,
    },
    {
      "name"    => "tagtypes",
      "retval"  => "fetch_list",
      "comment" => "Shows a list of available song metadata.",
      "args"    => [] of Nil,
    },
    {
      "name"    => "outputs",
      "retval"  => "fetch_outputs",
      "comment" => "Shows information about all outputs.",
      "args"    => [] of Nil,
    },
  ]
end
