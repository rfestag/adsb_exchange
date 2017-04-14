require 'adsb_exchange'
require 'celluloid/current'
require "reel"
require 'json'
require 'msgpack'

class AdsbServer
  include Celluloid
  include Celluloid::Notifications
  finalizer :cleanup

  def initialize
    async.run
  end
  def cleanup
    puts "Restarting Server"
    @sub.close
    @pub.close
  end
  def run
    @sub = CZTop::Socket::SUB.new("ipc:///tmp/adsb_updates")
    @pub = CZTop::Socket::PUB.new("inproc://adsb_updates")
    @sub.subscribe('')
    puts "Subscribed to adsb_updates"
    while true
      msg = @sub.receive
      @pub << msg[0] unless msg.empty?
    end
  end
end
class AdsbClient
  include Celluloid
  include Celluloid::Notifications
  finalizer :cleanup

  def initialize(websocket)
    @socket = websocket
    async.run
    puts "Forwarding messages to websocket"
  end
 
  def cleanup
    puts "Cleaning up websocket"
    @sub.close
  end

  def run
    @sub = CZTop::Socket::SUB.new("inproc://adsb_updates")
    @sub.subscribe('')
    while true
      msg = @sub.receive
      @socket << MessagePack.unpack(msg[0]).to_json unless msg.empty?
    end
  rescue Reel::SocketError
    puts "ADSB client disconnected"
    terminate
  end
end
AdsbServer.supervise as: :adsb_server
AdsbExchange::Live.supervise as: :adsb_source

Reel::Server::HTTP.run("0.0.0.0", 3000) do |connection|
  puts "Started AdsbExchange::Live"
  connection.each_request do |request|
    if request.websocket?
      AdsbClient.new(request.websocket)
    else
      puts "Client requested: #{request.method} #{request.url}"
      request.respond :ok, "Hello, world!"
    end
  end
end
