# MPD::Client

![Crystal CI](https://github.com/mamantoha/crystal_mpd/workflows/Crystal%20CI/badge.svg)
[![GitHub release](https://img.shields.io/github/release/mamantoha/crystal_mpd.svg)](https://github.com/mamantoha/crystal_mpd/releases)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://mamantoha.github.io/crystal_mpd/)
[![License](https://img.shields.io/github/license/mamantoha/crystal_mpd.svg)](https://github.com/mamantoha/crystal_mpd/blob/master/LICENSE)

Concurrent [Music Player Daemon](https://www.musicpd.org/) client written entirely in Crystal.

## Main features

- Filtering DSL
- Range support
- Callbacks
- Command lists support
- Binary responses
- Client to client communicate
- Logging
- Handle exceptions

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

Some MPD commands (e.g. `move`, `delete`, `load`, `shuffle`, `playlistinfo`) support integer ranges in the format `START:END`, specifying a slice of songs. This is handled in `crystal_mpd` via `MPD::Range`, which supports both inclusive (`1..10`) and exclusive (`1...10`) ranges.

Note: MPD treats `END` as exclusive, so we internally adjust inclusive ranges to match this behavior.
Also note that in MPD, song indexes start at 0 — the same as in Crystal.

```crystal
# Move first 3 songs to position 10, 11, and 12
client.move(0..2, 10)

# Delete songs 0 and 1 (but NOT 2)
client.delete(0...2)

# Delete songs 0, 1, and 2
client.delete(0..2)
```

End-less ranges also span to the end of the list:

```crystal
# Delete all songs from the playlist starting from index 10
client.delete(10..)
# or using exclusive range (same effect)
client.delete(10...)
```

Begin-less ranges default the start to 0:

```crystal
# Delete songs 0, 1, and 2
client.delete(..2)

# Delete songs 0 and 1
client.delete(...2)
```

### Filters

Filters [documentation](https://mpd.readthedocs.io/en/latest/protocol.html#filters)

All commands which search for songs (`playlistsearch`, `playlistfind`, `searchaddpl`, `searchcount`, `searchplaylist`, `list`, `count`, `find`, `search`, `findadd`, `searchadd`) share a common filter syntax.

The `find` commands are case sensitive, which `search` and related commands ignore case.

```crystal
client.search("(any =~ 'crystal')")
client.searchaddpl("alt_rock", "(genre == 'Alternative Rock')", sort: "-ArtistSort", window: (5..10))
client.list("filename", "((artist == 'Linkin Park') AND (date == '2003'))")
```

#### Build MPD query expressions in Crystal

The `MPD::Filter` class helps you construct complex MPD filter expressions using a fluent and chainable DSL — fully compatible with MPD filter syntax.

You can build expressions using chainable methods like `#eq`, `#contains`, `#not_eq`, and logical `#not`.

```crystal
filter =
  MPD::Filter
    .eq("Artist", "Linkin Park")
    .contains("Album", "Meteora")
    .not_eq("Title", "Numb")
    .sort("Track")
    .window(..10)

client.find(filter)
```

This is equivalent to:

```crystal
expression = "((Artist == 'Linkin Park') AND (Album contains 'Meteora') AND (Title != 'Numb'))"

client.find(expression, sort: "Track", window: ..10)
```

You can also use this block-based filter DSL like:

```crystal
client.search do |filter|
  filter
    .eq(:artist, "Linkin Park")
    .match(:album, "Meteora.*")
    .not_eq(:title, "Numb")
    .sort(:track)
    .window(..10)
end
```

##### Supported methods

| Method                        | MPD Equivalent                    |
| ----------------------------- | --------------------------------- |
| `eq(tag, value)`              | `(tag == 'value')`                |
| `not_eq(tag, value)`          | `(tag != 'value')`                |
| `match(tag, value)`           | `(tag =~ 'value')`                |
| `not_match(tag, value)`       | `(tag !~ 'value')`                |
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
inner = MPD::Filter.eq("Genre", "Pop")
outer = MPD::Filter.not(inner)
# => "(!(Genre == \"Pop\"))"
```

which is equivalent to

```crystal
MPD::Filter.not_eq("Genre", "Pop")
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

- `:partition`
- `:volume`
- `:repeat`
- `:random`
- `:single`
- `:consume`
- `:playlist`
- `:playlistlength`
- `:state`
- `:song`
- `:songid`
- `:nextsong`
- `:nextsongid`
- `:time`
- `:elapsed`
- `:duration`
- `:bitrate`
- `:xfade`
- `:mixrampdb`
- `:mixrampdelay`
- `:audio`
- `:updating_db`
- `:error`
- `:lastloadedplaylist`

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

# Keep the program running
loop { sleep 1.second }
```

The above will connect to the server like normal, but this time it will create a new thread
that loops until you issue an exit. This loop checks the server, then sleeps for 2 seconds, then loops.

In addition to registering individual event listeners using `#on`, the MPD client also supports a global callback listener using `#on_callback`.

This method allows you to handle all events in a single block and react based on the event type.

```crystal
client = MPD::Client.new(with_callbacks: true)

client.on_callback do |event, value|
  case event
  when .state?
    puts "State changed to #{value}"
  when .song?
    puts "Now playing: #{value}"
  when .repeat?
    puts "Repeat mode: #{value == "1" ? "On" : "Off"}"
  else
    puts "[#{event}] → #{value}"
  end
end

# Keep the program running
loop { sleep 1.second }
```

You can combine `#on_callback` with specific `#on` handlers. For example:

```crystal
client.on(:state) { |val| puts "STATE: #{val}" }

client.on_callback do |event, value|
  puts "[ALL EVENTS] #{event} => #{value}"
end
```

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

### Client-to-Client communication

`crystal_mpd` supports MPD's built-in client-to-client messaging system via channels.
This allows clients to exchange messages in real time through the MPD server.

#### Supported Methods

```crystal
client.subscribe("my_channel")          # Subscribes to a channel
client.unsubscribe("my_channel")        # Unsubscribes from a channel
client.channels                         # Returns a list of all existing channels
client.readmessages                     # Reads messages sent to subscribed channels
client.sendmessage("my_channel", "Hi!") # Sends a message to a specific channel
```

#### Example

```crystal
client.subscribe("notifications")

# Somewhere else, another client sends a message
client.sendmessage("notifications", "System update available")

# The first client reads the message
messages = client.readmessages
puts messages
# => [{"channel" => "notifications", "message" => "System update available"}]
```

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
