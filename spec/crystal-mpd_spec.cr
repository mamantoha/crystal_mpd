require "./spec_helper"

describe MPD do
  it "have version" do
    (MPD::VERSION).should be_a(String)
  end

  it "initialize new MPD client without params" do
    with_server do |host, port, wants_close|
      client = MPD.new

      client.host.should eq("localhost")
      client.port.should eq(6600)
    ensure
      wants_close.send(nil)
    end
  end

  it "initialize new MPD client with params" do
    with_server("localhost", 6661) do |host, port, wants_close|
      client = MPD.new("localhost", port)
      client.host.should eq("localhost")
      client.port.should eq(port)
    ensure
      wants_close.send(nil)
    end
  end

  it "initialized MPD client should have version" do
    with_server do |host, port, wants_close|
      client = MPD.new

      (client.version).should eq("0.19.0")
    ensure
      wants_close.send(nil)
    end
  end
end
