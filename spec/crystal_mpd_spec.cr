require "./spec_helper"

describe MPD do
  it "have version" do
    (MPD::VERSION).should be_a(String)
  end

  it "initialize new MPD client without params", tags: "network" do
    with_server do |_host, _port, wants_close|
      client = MPD::Client.new

      client.host.should eq("localhost")
      client.port.should eq(6600)
      (client.connected?).should eq(true)
    ensure
      wants_close.send(nil)
    end
  end

  it "initialize new MPD client with params" do
    with_server("localhost", 6601) do |_host, port, wants_close|
      client = MPD::Client.new("localhost", port)
      client.host.should eq("localhost")
      client.port.should eq(port)
    ensure
      wants_close.send(nil)
    end
  end

  it "initialized MPD client should have version", tags: "network" do
    with_server do |_host, _port, wants_close|
      client = MPD::Client.new

      (client.version).should eq("0.21.4")
    ensure
      wants_close.send(nil)
    end
  end

  it "successfully disconnect MPD client", tags: "network" do
    with_server do |_host, _port, wants_close|
      client = MPD::Client.new
      client.disconnect

      (client.version).should eq(nil)
      (client.connected?).should eq(false)
    ensure
      wants_close.send(nil)
    end
  end

  it "disconnect MPD client 2 times should not raise error", tags: "network" do
    with_server do |_host, _port, wants_close|
      client = MPD::Client.new
      client.disconnect
      client.disconnect

      (client.version).should eq(nil)
      (client.connected?).should eq(false)
    ensure
      wants_close.send(nil)
    end
  end
end
