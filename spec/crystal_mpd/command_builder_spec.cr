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
      command.should eq("status 0:3")
    end

    it "builds a command with a hash argument" do
      command = MPD::CommandBuilder.build("find", "(genre != 'Pop')", {"sort" => "-ArtistSort", "window" => (5..10)})
      command.should eq("find \"(genre != 'Pop')\" sort -ArtistSort window 5:11")
    end

    describe ".parse_range" do
      it "an inclusive range" do
        MPD::CommandBuilder.parse_range(0..3).should eq("0:4")
      end

      it "an exclusive range" do
        MPD::CommandBuilder.parse_range(0...3).should eq("0:3")
      end

      it "an endless range" do
        MPD::CommandBuilder.parse_range(..3).should eq("0:4")
      end

      it "a beginless inclusive range" do
        MPD::CommandBuilder.parse_range(..3).should eq("0:4")
      end

      it "a beginless exclusive range" do
        MPD::CommandBuilder.parse_range(...3).should eq("0:3")
      end

      it "a beginless and an endless inclusive range" do
        MPD::CommandBuilder.parse_range(..).should eq("0:")
      end

      it "a beginless and an endless exclusive range" do
        MPD::CommandBuilder.parse_range(..).should eq("0:")
      end
    end

    it "escapes string values" do
      # https://mpd.readthedocs.io/en/latest/protocol.html#escaping-string-values
      #
      # Example expression which matches an artist named `foo'bar"`:
      # (Artist == "foo\'bar\"")
      #
      # At the protocol level, the command must look like this:
      # find "(Artist == \"foo\\'bar\\\"\")"

      # client.find(%q{(Artist == "foo\'bar\"")})
      # DEBUG - mpd: request: `find "(Artist == \"foo\\'bar\\\"\")" `

      expression = %q{(Artist == "foo\'bar\"")}
      result = MPD::CommandBuilder.build("find", expression)

      command = %q{find "(Artist == \"foo\\'bar\\\"\")"}
      result.should eq command
    end
  end
end
