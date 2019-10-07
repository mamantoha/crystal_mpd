require "../src/crystal_mpd"
require "option_parser"
require "logger"

options = {} of String => String | Bool
options["verbose"] = false
options["host"] = "localhost"

optparse = OptionParser.new do |parser|
  parser.banner = "Usage: salute [arguments]"
  parser.on("-v", "--verbose", "Show verbose output") { options["verbose"] = true }
  parser.on("-h HOST", "--host=NAME", "Specifies the MPD host") { |name| options["host"] = name }
  parser.on("-t NAME", "--type=NAME", "Specifies the type") { |name| options["type"] = name }
  parser.on("-q NAME", "--query=NAME", "Specifies the query") { |name| options["query"] = name }
  parser.on("-h", "--help", "Show this help") { puts parser }
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
  parser.missing_option do |flag|
    STDERR.puts "ERROR: #{flag} expects an argument."
    STDERR.puts parser
    exit(1)
  end
end

begin
  optparse.parse
  mandatory = ["type", "query"]
  missing = mandatory.select { |param| options[param]?.nil? }
  unless missing.empty?
    raise OptionParser::MissingOption.new(missing.join(", "))
  end
rescue ex : OptionParser::MissingOption
  STDERR.puts "ERROR: #{ex.to_s}"
  STDERR.puts optparse
  exit(1)
end

client = MPD::Client.new(options["host"].as(String))

if options["verbose"]
  log = Logger.new(STDOUT)
  log.level = Logger::DEBUG
  client.log = log
end

client.stop
client.clear

songs = client.search(options["type"].as(String), options["query"].as(String))

client.command_list_ok_begin

songs.not_nil!.each do |song|
  client.add(song["file"]) if song["file"]?
end

client.command_list_end

client.play

puts client.currentsong

client.close
client.disconnect
