require "../src/crystal_mpd"

client = MPD::Client.new(with_callbacks: true)

client.on :state do |state|
  puts "[#{Time.local}] State was change to #{state}"
end

client.on :song do
  if current_song = client.currentsong
    puts "[#{Time.local}] 🎵 #{current_song["Artist"]} - #{current_song["Title"]}"
  end

  if next_song = client.nextsong
    puts "[#{Time.local}] 🔜 #{next_song["Artist"]} - #{next_song["Title"]}"
  end
end

client.on :random do |state|
  puts "[#{Time.local}] Random mode was changed to #{state}"
end

client.on :single do |state|
  puts "[#{Time.local}] Single mode was changed to #{state}"
end

client.on :repeat do |state|
  puts "[#{Time.local}] Repeat mode was changed to #{state}"
end

# client.on :undef do
#   # Error: expected argument #1 to 'MPD::Client#on' to match a member of enum MPD::Client::Event.
# end

loop do
  sleep 1.second
end
