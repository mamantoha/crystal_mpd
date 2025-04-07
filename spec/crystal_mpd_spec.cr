require "./spec_helper"

describe MPD do
  it "have version" do
    (MPD::VERSION).should be_a(String)
  end

  it "initialize new MPD client without params", tags: "mock_mpd_server" do
    MockMPDServer.with do
      client = MPD::Client.new

      client.host.should eq("localhost")
      client.port.should eq(6600)
      client.connected?.should be_true
    end
  end

  it "initialize new MPD client with params" do
    port = 6601

    MockMPDServer.with("localhost", port) do
      client = MPD::Client.new("localhost", port)
      client.host.should eq("localhost")
      client.port.should eq(port)
    end
  end

  it "initialized MPD client should have version", tags: "mock_mpd_server" do
    MockMPDServer.with do
      client = MPD::Client.new

      (client.version).should eq("0.24.2")
    end
  end

  it "successfully disconnect MPD client", tags: "mock_mpd_server" do
    MockMPDServer.with do
      client = MPD::Client.new
      client.disconnect

      (client.version).should be_nil
      (client.connected?).should be_false
    end
  end

  it "disconnect MPD client 2 times should not raise error", tags: "mock_mpd_server" do
    MockMPDServer.with do
      client = MPD::Client.new
      client.disconnect
      client.disconnect

      (client.version).should be_nil
      (client.connected?).should be_false
    end
  end

  it "sends a status command and receives a response", tags: "mock_mpd_server" do
    MockMPDServer.with do
      client = MPD::Client.new

      client.status.try do |response|
        response["volume"].should eq("100")
      end
    end
  end

  it "nextsong should return a song", tags: "mock_mpd_server" do
    MockMPDServer.with do
      client = MPD::Client.new

      client.nextsong.try do |response|
        response["file"].should eq("music/foo.mp3")
        response["Artist"].should eq("Nirvana")
      end
    end
  end

  it "sends a find command and receives a response", tags: "mock_mpd_server" do
    MockMPDServer.with do
      client = MPD::Client.new
      filter = MPD::Filter.new.eq("Artist", "Nirvana")

      client.find(filter).try do |result|
        result.first["file"].should eq("music/foo.mp3")
        result.first["Artist"].should eq("Nirvana")
      end
    end
  end

  it "sends a find command with a block and receives a response", tags: "mock_mpd_server" do
    MockMPDServer.with do
      client = MPD::Client.new

      client.find(&.eq("Artist", "Nirvana")).try do |result|
        result.first["file"].should eq("music/foo.mp3")
        result.first["Artist"].should eq("Nirvana")
      end
    end
  end

  it "raises an error when sorg not found", tags: "mock_mpd_server" do
    MockMPDServer.with do
      client = MPD::Client.new

      expect_raises(MPD::Error, "[50@0] {playid} No such song") do
        client.playid(2)
      end
    end
  end

  describe "commands", tags: "mock_mpd_server" do
    it "#search" do
      MockMPDServer.with do
        client = MPD::Client.new

        begin
          client.search do |filter|
            filter
              .eq(:artist, "Linkin Park")
              .match(:album, "Meteora.*")
              .not_eq(:title, "Numb")
              .sort(:track)
              .window(..10)
          end
        rescue ex : MPD::Error
          if line = ex.message.not_nil!.match(/`(.*)`/)
            line[1].should eq(
              "search \"((artist == \\\"Linkin Park\\\") AND (album =~ \\\"Meteora.*\\\") AND (title != \\\"Numb\\\"))\" sort track window 0:11"
            )
          end
        end
      end
    end
  end
end
