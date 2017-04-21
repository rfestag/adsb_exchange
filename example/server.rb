$stdout.sync = true
require 'adsb_exchange'
require 'celluloid/current'
require 'celluloid/redis'
require 'celluloid/zmq'
require "reel"
require 'json'
require 'msgpack'
require 'redis'
require 'seconds'

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
    @redis.close
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

  def initialize(websocket, subscribe: 'inproc://adsb_updates', **redis_opts)
    @socket = websocket
    @subscribe_url = subscribe
    opts = {driver: :celluloid}.merge! redis_opts
    @redis = ::Redis.new opts
    async.run
    puts "Forwarding messages to websocket"
  end
 
  def cleanup
    puts "Cleaning up websocket"
    @sub.close
    @redis.close
  end

  def run
    @sub = Socket::Sub.new
    @sub.connect @subscribe_url
    @sub.subscribe('')
    puts "Sending last 10 points per track"
    scan do |msg|
      @socket << msg.to_json unless msg.empty?
    end
    puts "Sending updates"

    while true
      msg = @sub.read
      @socket << MessagePack.unpack(msg).to_json unless msg.empty?
    end
  rescue Reel::SocketError
    puts "ADSB client disconnected"
    terminate
  end
  private
  def scan cursor='0', **opts, &block
    opts[:count] ||= 1000
    cursor, keys = @redis.scan(cursor, opts)
    futures = []
    start = 2.minutes.ago.utc.to_i*1000
    stop = Time.now.utc.to_i*1000
    pipeline = @redis.pipelined do
      keys.each do |k|
        #futures << [k, @redis.zrangebyscore(k, start, stop)]
        futures << [k, @redis.zrange(k, 0, 0), @redis.zrange(k, -10, -1)]
      end
    end
    values = futures.reduce([]) do |results, (k, init, points)|
      init = MessagePack.unpack(init.value.first)
      points = points.value
      init[:points] = []
      summary = points.reduce(init) do |summary, p|
        p = MessagePack.unpack(p)
        summary[:points] << p
        summary.merge! p
      end
      results << summary unless points.empty?
      results
    end
    block.call values
    scan cursor, opts, &block if cursor != '0'
  end
end
AdsbServer.supervise as: :adsb_server

key = File.read(File.join(File.dirname(__FILE__), 'test.key'))
cert = File.read(File.join(File.dirname(__FILE__), 'test.crt'))
Reel::Server::HTTPS.run("0.0.0.0", 3000, cert: cert, key: key) do |connection|
  connection.each_request do |request|
    if request.websocket?
      AdsbClient.new(request.websocket)
    else
      puts "Client requested: #{request.method} #{request.url}"
      request.respond :ok, "Hello, world!"
    end
  end
end
