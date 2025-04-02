# MPD::Client

![Crystal CI](https://github.com/mamantoha/crystal_mpd/workflows/Crystal%20CI/badge.svg)
[![GitHub release](https://img.shields.io/github/release/mamantoha/crystal_mpd.svg)](https://github.com/mamantoha/crystal_mpd/releases)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://mamantoha.github.io/crystal_mpd/)
[![License](https://img.shields.io/github/license/mamantoha/crystal_mpd.svg)](https://github.com/mamantoha/crystal_mpd/blob/master/LICENSE)

Concurrent [Music Player Daemon](https://www.musicpd.org/) client written entirely in Crystal

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

You can also omit the `host` and `port`, and it will use the defaults:

```crystal
client = MPD::Client.new("localhost")
client = MPD::Client.new
```

You can connect to a local socket (UNIX domain socket), specify an absolute path:

```crystal
client = MPD::Client.new("/run/mpd/socket")
```

If a password specified for access to MPD:

```crystal
client = MPD::Client.new("localhost", password: "password")
```

The client library can be used as follows:

```crystal
puts client.version # print the mpd version
client.play(2)      # begins playing the playlist at song number 2
puts client.status  # print the current status of the player and the volume level
client.close        # send the close command
client.disconect    # disconnect from the server
```

Check `MPD::Client` [source](https://mamantoha.github.io/crystal_mpd/MPD/Client.html) for supported commands.

To use all `crystal_mpd` functions you should use the latest stable MPD version (0.24.x).

### Command lists

Command lists [documentation](https://mpd.readthedocs.io/en/latest/protocol.html#command-lists).

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

or

```crystal
client.with_command_list do
  client.update
  client.status
end
```

### Ranges

Ranges [documentation](https://mpd.readthedocs.io/en/latest/protocol.html#ranges).

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

Filters [documentation](https://mpd.readthedocs.io/en/latest/protocol.html#filters)

All commands which search for songs (`find`, `search`, `searchadd`, `searchaddpl`, `findadd`, `list`, and `count`) share a common filter syntax.

The `find` commands are case sensitive, which `search` and related commands ignore case.

```crystal
client.search("(any =~ 'crystal')")
client.searchaddpl("alt_rock", "(genre == 'Alternative Rock')", sort: "-ArtistSort", window: (5..10))
client.list("filename", "((artist == 'Linkin Park') AND (date == '2003'))")
```

#### Build MPD query expressions in Crystal

The `MPD::Filter` class helps you construct complex MPD filter expressions using a fluent and chainable DSL — fully compatible with (MPD) filter syntax.

You can build expressions using chainable methods like `#eq`, `#contains`, `#not_eq`, and logical `#not`.

```crystal
client = MPD::Client.new

filter = MPD::Filter.new
  .eq("Artist", "Linkin Park")
  .contains("Album", "Meteora")
  .not_eq("Title", "Numb")

client.find(filter)
```

This is equivalent to:

```crystal
expression = "((Artist == 'Linkin Park') AND (Album contains 'Meteora') AND (Title != 'Numb'))"

client.find(expression)
```

##### Supported methods

| Method                        | MPD Equivalent                    |
| ----------------------------- | --------------------------------- |
| `eq(tag, value)`              | `(tag == 'value')`                |
| `not_eq(tag, value)`          | `(tag != 'value')`                |
| `eq_cs(tag, value)`           | `(tag eq_cs 'value')`             |
| `eq_ci(tag, value)`           | `(tag eq_ci 'value')`             |
| `not_eq_cs(tag, value)`       | `(!(tag eq_cs 'value'))`          |
| `not_eq_ci(tag, value)`       | `(!(tag eq_ci 'value'))`          |
| `contains(tag, value)`        | `(tag contains 'value')`          |
| `not_contains(tag, value)`    | `(!(tag contains 'value'))`       |
| `contains_cs(tag, value)`     | `(tag contains_cs 'value')`       |
| `contains_ci(tag, value)`     | `(tag contains_ci 'value')`       |
| `not_contains_cs(tag, value)` | `(!(tag contains_cs 'value'))`    |
| `not_contains_ci(tag, value)` | `(!(tag contains_ci 'value'))`    |
| `starts_with(tag, value)`     | `(tag starts_with 'value')`       |
| `not_starts_with(tag, value)` | `(!(tag starts_with 'value'))`    |
| `starts_with_cs(tag, value)`  | `(tag starts_with_cs 'value')`    |
| `starts_with_ci(tag, value)`  | `(tag starts_with_ci 'value')`    |
| `not_starts_with_cs(tag,val)` | `(!(tag starts_with_cs 'value'))` |
| `not_starts_with_ci(tag,val)` | `(!(tag starts_with_ci 'value'))` |
| `not(filter)`                 | `(!...)`                          |

Chaining multiple filters implies logical `AND`.

Negate an expression with `#not`.

```crystal
inner = MPD::Filter.new.eq("Genre", "Pop")
outer = MPD::Filter.new.not(inner)
# => "(!(Genre == \"Pop\"))"
```

which is equivalent to

```crystal
MPD::Filter.new.not_eq("Genre", "Pop")
# => "(Genre != \"Pop\")"
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

- `:volume`
- `:repeat`
- `:random`
- `:single`
- `:consume`
- `:playlist`
- `:playlistlength`
- `:mixrampdb`
- `:state`
- `:song`
- `:songid`
- `:time`
- `:elapsed`
- `:bitrate`
- `:duration`
- `:audio`
- `:nextsong`
- `:nextsongid`

```crystal
client = MPD::Client.new(with_callbacks: true)
client.callbacks_timeout = 2.seconds

client.on :state do |state|
  puts "[#{Time.local}] State was change to #{state}"
end

client.on :song do
  if (current_song = client.currentsong)
    puts "[#{Time.local}] 🎵 #{current_song["Artist"]} - #{current_song["Title"]}"
  end
end

loop { sleep 1 }
```

The above will connect to the server like normal, but this time it will create a new thread
that loops until you issue an exit. This loop checks the server, then sleeps for 2 seconds, then loops.

### Binary responses

Some commands can return binary data.

```crystal
client = MPD::Client.new

if (current_song = client.currentsong)
  if (response = client.albumart(current_song["file"]))
    data, binary = response
    # data # => {"size" => "30219", "type" => "image/jpeg", "binary" => "5643"}

    extension = MIME.extensions(data["type"]).first? || ".png"

    file = File.open("cover#{extension}", "w")
    file.write(binary.to_slice)
  end
end
```

The above will locate album art for the current song and save image to `cover.jpg` file.

### Logging

```crystal
require "crystal_mpd"

client = MPD::Client.new

MPD::Log.level = :debug
MPD::Log.backend = ::Log::IOBackend.new
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

## Who's using `MPD::Client`

If you're using `MPD::Client` and would like to have your application added to this list, just submit a PR!

- [cryMPD](https://github.com/mamantoha/cryMPD) - control MPD audio playing in the browser

## Contributing

1. Fork it (<https://github.com/mamantoha/crystal_mpd/fork>)
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [mamantoha](https://github.com/mamantoha) Anton Maminov - creator, maintainer

## License

Copyright: 2018-2025 Anton Maminov (<anton.maminov@gmail.com>)

This library is distributed under the MIT license. Please see the LICENSE file.
