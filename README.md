# MPD::Client

[![Build Status](
https://travis-ci.org/mamantoha/crystal_mpd.svg?branch=master)](https://travis-ci.org/mamantoha/crystal_mpd)
[![GitHub release](https://img.shields.io/github/release/mamantoha/crystal_mpd.svg)](https://github.com/mamantoha/crystal_mpd/releases)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://mamantoha.github.io/crystal_mpd/)
[![License](https://img.shields.io/github/license/mamantoha/crystal_mpd.svg)](https://github.com/mamantoha/crystal_mpd/blob/master/LICENSE)

Simple Music Player Daemon (MPD) client written entirely in Crystal

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  crystal_mpd:
    github: mamantoha/crystal_mpd
```

## Usage

```crystal
require "crystal_mpd"
```

All functionality is contained in the `MPD::Client` class.
Creating an instance of this class is as simple as:

```crystal
client = MPD::Client.new("localhost", 6600)
```

You can also omit the `host` and `post`, and it will use the defaults.

```crystal
client = MPD::Client.new("localhost")
client = MPD::Client.new
```

The client library can be used as follows:

```crystal
puts client.mpd_version                # print the mpd version
puts client.search('title', 'crystal') # print the result of the command 'search title crystal'
client.close                           # send the close command
client.disconect                       # disconnect from the server
```

Check `MPD::Client` [source](https://mamantoha.github.io/crystal_mpd/MPD/Client.html) for supported commands.

Tested with mpd `0.21`.

### Command lists

Command lists [documentation](https://www.musicpd.org/doc/html/protocol.html#command-lists).

To facilitate faster adding of files etc. you can pass a list of commands all at once using a command list.
The command list begins with `command_list_ok_begin` and ends with `command_list_end`.

It does not execute any commands until the list has ended.
The return value is whatever the return for a list of commands is. On success for all commands, `OK` is returned.

If a command fails, no more commands are executed and the appropriate ACK error is returned.

If `command_list_ok_begin` is used, `list_OK` is returned for each successful command executed in the command list.

```crystal
client.command_list_ok_begin # start a command list
client.update                # insert the update command into the list
client.status                # insert the status command into the list
client.command_list_end      # result will be a Array with the results
```

### Ranges

Ranges [documentation](https://www.musicpd.org/doc/html/protocol.html#ranges).

Some commands(e.g. `move`, `delete`, `load`, `shuffle`, `playlistinfo`) allow integer ranges(`START:END`) instead of numbers, specifying a range of songs.
This is done by using `MPD::Range`. `crystal_mpd` correctly handles inclusive and exclusive ranges (`1..10` vs `1...10`). Negative range end means that we want the range to span until the end of the list.

```crystal
# move songs 1, 2 and 3 to position 10 (and 11 and 12)
client.move(1..3, 10)

# deleve songs 1, 2 and 3 from playlist
client.delete(0..2)

# deleve songs 1 and 2
client.delete(0...2)
```

With negative range end MPD will assumes the biggest possible number then:

```crystal
# delete all songs from the current playlist, except for the firts ten
client.delete(10..-1)
```

End-less range end MPD will also assumes the biggest possible number then:

```crystal
# delete all songs from the current playlist, except for the firts ten
client.delete(10..)
# or
client.delete(10...)
```

With begin-less range begin is equal to `0`:

```crystal
# delete first 1, 2 and 3 songs from the current playlist
client.delete(..2)

# delete first 1 and 2 songs from the current playlist
client.delete(...2)
```

### Filters

Filters [documentation](https://www.musicpd.org/doc/html/protocol.html#filters).

All commands which search for songs (`find`, `search`, `searchadd`, `searchaddpl`, `findadd`, `list`, and `count`) share a common filter syntax.

The `find` commands are case sensitive, which `search` and related commands ignore case.

```crystal
client.search("(any =~ 'crystal')")
client.findaddpl("alt_rock", "(genre == 'Alternative Rock')")
client.list("filename", "((artist == 'Linkin Park') AND (date == '2003'))")
```

### Callbacks

Callbacks are a simple way to make your client respond to events, rather that have to continuously ask the server for updates. This is done by having a background thread continuously check the server for changes.

To make use of callbacks, you need to:

1. Create a MPD client instance with callbacks enabled.

   ```crystal
   client = MPD::Client.new(with_callbacks: true)
   ```

2. Setup a callback to be called when something happens.

   ```crystal
   client.on :state do |state|
     puts "[#{Time.local}] State was change to #{state}"
   end
   ```

`crystal_mpd` supports callbacks for any of the keys returned by `MPD::Client#status`.

Here's the full list of events:

- :volume
- :repeat
- :random
- :single
- :consume
- :playlist
- :playlistlength
- :mixrampdb
- :state
- :song
- :songid
- :time
- :elapsed
- :bitrate
- :duration
- :audio
- :nextsong
- :nextsongid

```crystal
client = MPD::Client.new(with_callbacks: true)
client.callbacks_timeout = 2.seconds

client.on :state do |state|
  puts "[#{Time.local}] State was change to #{state}"
end

client.on :song do
  if current_song = client.currentsong
    puts "[#{Time.local}] 🎵 #{current_song["Artist"]} - #{current_song["Title"]}"
  end
end

loop do
  sleep 1
end
```

The above will connect to the server like normal, but this time it will create a new thread that loops until you issue an exit. This loop checks the server, then sleeps for 2 seconds, then loops.

### Logging

Sets the logger used by this instance of `MPD::Client`:

```crystal
require "logger"
require "crystal_mpd"

log = Logger.new(STDOUT)
log.level = Logger::DEBUG

client = MPD::Client.new
client.log = log
```

## Development

Install dependencies:

```console
shards
```

To run test:

```console
crystal spec
```

## Contributing

1. Fork it (<https://github.com/mamantoha/crystal_mpd/fork>)
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [mamantoha](<https://github.com/mamantoha>) Anton Maminov - creator, maintainer

## License

Copyright: 2018-2019 Anton Maminov (<anton.maminov@gmail.com>)

This library is distributed under the MIT license. Please see the LICENSE file.
