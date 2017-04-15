$stdout.sync = true
require 'adsb_exchange'
require 'celluloid/current'
require 'celluloid/zmq'
require "reel"
require 'json'
require 'msgpack'

class AdsbServer
  include Celluloid::ZMQ
  finalizer :cleanup

  def initialize subscribe: "ipc:///tmp/adsb_updates", publish: "inproc://adsb_updates"
    @subscribe_url = subscribe
    @publish_url = publish
    async.run
  end
  def cleanup
    puts "Restarting Server"
    @sub.close
    @pub.close
  end
  def run
    @sub = Socket::Sub.new
    @sub.connect @subscribe_url
    @sub.subscribe('')
    @pub = Socket::Pub.new
    @pub.bind @publish_url

    puts "Subscribed to adsb_updates"
    while true
      msg = @sub.read
      @pub << msg unless msg.empty?
    end
  end
end
class AdsbClient
  include Celluloid::ZMQ
  finalizer :cleanup

  def initialize(websocket, subscribe: 'inproc://adsb_updates')
    @socket = websocket
    @subscribe_url = subscribe
    async.run
    puts "Forwarding messages to websocket"
  end
 
  def cleanup
    puts "Cleaning up websocket"
    @sub.close
  end

  def run
    @sub = Socket::Sub.new
    @sub.connect @subscribe_url
    @sub.subscribe('')
    while true
      msg = @sub.read
      @socket << MessagePack.unpack(msg).to_json unless msg.empty?
    end
  rescue Reel::SocketError
    puts "ADSB client disconnected"
    terminate
  end
end
AdsbServer.supervise as: :adsb_server
#AdsbExchange::Live.supervise as: :adsb_source

key = File.read(File.join(File.dirname(__FILE__), 'test.key'))
cert = File.read(File.join(File.dirname(__FILE__), 'test.crt'))
Reel::Server::HTTPS.run("0.0.0.0", 3000, cert: cert, key: key) do |connection|
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
