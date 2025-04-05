require "../spec_helper"

describe MPD::Filter do
  describe "#eq" do
    it "builds equality filter" do
      filter = MPD::Filter.eq("Artist", "Linkin Park")
      filter.to_s.should eq("(Artist == \"Linkin Park\")")
    end

    it "builds multiple ANDed filters" do
      filter = MPD::Filter.eq("Artist", "Linkin Park").eq("date", "2003")
      filter.to_s.should eq("((Artist == \"Linkin Park\") AND (date == \"2003\"))")
    end
  end

  describe "#not_eq" do
    it "builds inequality filter" do
      filter = MPD::Filter.new.not_eq("Genre", "Pop")
      filter.to_s.should eq("(Genre != \"Pop\")")
    end
  end

  describe "#match" do
    it "builds match filter" do
      filter = MPD::Filter.new.match("Genre", ".* Rock")
      filter.to_s.should eq("(Genre =~ \".* Rock\")")
    end
  end

  describe "#not_match" do
    it "builds not match filter" do
      filter = MPD::Filter.new.not_match("Genre", ".*?Pop.*?")
      filter.to_s.should eq("(Genre !~ \".*?Pop.*?\")")
    end
  end

  describe "#eq_cs and #eq_ci" do
    it "builds case-sensitive equality" do
      filter = MPD::Filter.new.eq_cs("album", "Hybrid Theory")
      filter.to_s.should eq("(album eq_cs \"Hybrid Theory\")")
    end

    it "builds case-insensitive equality" do
      filter = MPD::Filter.new.eq_ci("album", "Hybrid Theory")
      filter.to_s.should eq("(album eq_ci \"Hybrid Theory\")")
    end
  end

  describe "#not_eq_cs and #not_eq_ci" do
    it "builds negated case-sensitive equality" do
      filter = MPD::Filter.new.not_eq_cs("genre", "Rock")
      filter.to_s.should eq("(!(genre eq_cs \"Rock\"))")
    end

    it "builds negated case-insensitive equality" do
      filter = MPD::Filter.new.not_eq_ci("genre", "Rock")
      filter.to_s.should eq("(!(genre eq_ci \"Rock\"))")
    end
  end

  describe "#contains and variants" do
    it "builds contains filter" do
      filter = MPD::Filter.new.contains("album", "live")
      filter.to_s.should eq("(album contains \"live\")")
    end

    it "builds not_contains_ci filter" do
      filter = MPD::Filter.new.not_contains_ci("title", "remix")
      filter.to_s.should eq("(!(title contains_ci \"remix\"))")
    end
  end

  describe "#starts_with and variants" do
    it "builds starts_with_cs filter" do
      filter = MPD::Filter.new.starts_with_cs("title", "Intro")
      filter.to_s.should eq("(title starts_with_cs \"Intro\")")
    end

    it "builds not_starts_with_ci filter" do
      filter = MPD::Filter.new.not_starts_with_ci("file", "/live/")
      filter.to_s.should eq("(!(file starts_with_ci \"/live/\"))")
    end
  end

  describe "#not with nested filter" do
    it "negates a single nested expression" do
      inner = MPD::Filter.new.eq("artist", "Linkin Park")
      outer = MPD::Filter.new.not(inner)
      outer.to_s.should eq("(!(artist == \"Linkin Park\"))")
    end

    it "negates multiple nested expressions" do
      inner = MPD::Filter.eq("artist", "Linkin Park").eq("date", "2003")
      outer = MPD::Filter.new.not(inner)
      outer.to_s.should eq("(!((artist == \"Linkin Park\") AND (date == \"2003\")))")
    end

    it "chains negated filter with another condition" do
      inner = MPD::Filter.contains("title", "intro")
      outer = MPD::Filter.not(inner).eq("genre", "Rock")
      outer.to_s.should eq("((!(title contains \"intro\")) AND (genre == \"Rock\"))")
    end
  end

  describe MPD::Tag do
    it "builds filter with tag as MPD::Tag" do
      filter = MPD::Filter.new.eq(MPD::Tag::Artist, "Linkin Park")
      filter.to_s.should eq("(artist == \"Linkin Park\")")
    end

    it "builds filter with tag as symbol" do
      filter = MPD::Filter.new.eq(:artist, "Linkin Park")
      filter.to_s.should eq("(artist == \"Linkin Park\")")
    end
  end

  describe "#sort" do
    it "builds sort filter" do
      filter = MPD::Filter.new.sort("Track")
      filter.sort.should eq("Track")
    end

    it "builds sort filter with tag as symbol" do
      filter = MPD::Filter.new.sort(:musicbrainz_artistid)
      filter.sort.should eq("musicbrainz_artistid")
    end
  end

  describe "#window" do
    it "builds window filter" do
      filter = MPD::Filter.new.window(..2)
      filter.window.should eq(..2)
    end
  end

  describe "#escape" do
    it "escapes string values for MPD protocol correctly" do
      filter = MPD::Filter.new.eq("Artist", %{foo'bar"})

      expression = %q{(Artist == "foo\'bar\"")}
      filter.to_s.should eq(expression)
    end
  end

  describe "#to_s" do
    it "returns empty string when no filters" do
      MPD::Filter.new.to_s.should eq("")
    end
  end
end
