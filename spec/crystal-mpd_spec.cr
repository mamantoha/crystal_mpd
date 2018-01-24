require "./spec_helper"

describe MPD do
  it "have version" do
    (MPD::VERSION).should be_a(String)
  end
end
