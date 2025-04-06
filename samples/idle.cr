require "../src/crystal_mpd"

# MPD::Log.level = :debug
# MPD::Log.backend = ::Log::IOBackend.new

client = MPD::Client.new

spawn do
  loop do
    # puts client.idle(["message", "subscription"])
    puts client.idle
    sleep 1.second
  end
end

loop { sleep 1.second }
