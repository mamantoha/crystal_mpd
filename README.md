# crystal_mpd

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

Tested with mpd `0.20`.

### Command lists

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

Some commands(e.g. `move`, `delete`, `load`, `shuffle`, `playlistinfo`) support integer ranges(`START:END`) as argument. This is done in `crystal_mpd` by using two element array:

```crystal
# move the first three songs after the fifth number in the playlist
client.move([0, 3], 5)
```

Second element can be omitted. MPD will assumes the biggest possible number then:

```crystal
# delete all songs from the current playlist, except for the firts ten
client.delete([10,])
```

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

1. Fork it ( https://github.com/mamantoha/crystal_mpd/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [mamantoha](https://github.com/mamantoha) Anton Maminov - creator, maintainer

## License

Copyright: 2018 Anton Maminov (anton.maminov@gmail.com)

This library is distributed under the MIT license. Please see the LICENSE file.
