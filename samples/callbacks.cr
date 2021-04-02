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

loop do
  sleep 1
end
