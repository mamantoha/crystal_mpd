require "../spec_helper"

describe MPD::CommandBuilder do
  describe ".build" do
    it "builds a command with no arguments" do
      command = MPD::CommandBuilder.build("status")
      command.should eq("status")
    end

    it "builds a command with a string argument" do
      command = MPD::CommandBuilder.build("single", "oneshot")
      command.should eq("single \"oneshot\"")
    end

    it "builds a command with an integer argument" do
      command = MPD::CommandBuilder.build("setvol", 85)
      command.should eq("setvol 85")
    end

    it "builds a command with multiple arguments" do
      command = MPD::CommandBuilder.build("addid", "foo.mp3", 1)
      command.should eq("addid \"foo.mp3\" 1")
    end

    it "builds a command with a range argument" do
      command = MPD::CommandBuilder.build("status", 0..2)
      command.should eq("status 0:2")
    end

    it "builds a command with a range argument with no end" do
      command = MPD::CommandBuilder.build("status", 0..)
      command.should eq("status 0:-1")
    end

    it "builds a command with a range argument with no start" do
      command = MPD::CommandBuilder.build("status", ..2)
      command.should eq("status 0:2")
    end

    it "builds a command with a range argument with no start and end" do
      command = MPD::CommandBuilder.build("status", ..)
      command.should eq("status 0:-1")
    end

    it "builds a command with a hash argument" do
      # find("(genre != 'Pop')", sort: "-ArtistSort", window: (5..10))
      command = MPD::CommandBuilder.build("find", "(genre != 'Pop')", {"sort" => "-ArtistSort", "window" => (5..10)})
      command.should eq("find \"(genre != 'Pop')\" sort -ArtistSort window 5..10")
    end
  end
end
