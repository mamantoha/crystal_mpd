require "../src/crystal_mpd"

client = MPD::Client.new(with_callbacks: true)

client.on :song do
  if current_song = client.currentsong
    puts "🎵 #{current_song["Artist"]} - #{current_song["Title"]}"
  end

  if next_song = client.nextsong
    puts "🔜 #{next_song["Artist"]} - #{next_song["Title"]}"
  end
end

client.on :random do |state|
  puts "Random mode was changed to #{state}"
end

client.on :single do |state|
  puts "Single mode was changed to #{state}"
end

client.on :repeat do |state|
  puts "Repeat mode was changed to #{state}"
end

# client.on :undef do
#   # Error: expected argument #1 to 'MPD::Client#on' to match a member of enum MPD::Client::Event.
# end

# Unified event handler
client.on_callback do |event, state|
  case event
  when .state?
    puts "⏯ Playback state changed to #{state}"
  when .time?, .elapsed?
    # do nothing
  else
    puts "[#{event}] → #{state}"
  end
end

loop do
  sleep 1.second
end
