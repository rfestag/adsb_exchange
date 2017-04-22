$stdout.sync = true
require 'adsb_exchange'
require 'celluloid/current'
require 'celluloid/redis'
require 'celluloid/zmq'
require 'msgpack'
require 'sequel'
require 'redis'
require 'seconds'

class AdsbCache
  include Celluloid::ZMQ
  include AdsbExchange::SocketFactory
  INPUT = {type: Socket::Pull,
           endpoint: 'ipc:///tmp/adsb_cache',
           bind: true}.freeze
  OUTPUT = {type: Socket::Pub,
            endpoint: 'ipc:///tmp/adsb_updates',
            bind: true}.freeze

  def initialize input: {}, output: {}
    @inconf = INPUT.merge input
    @outconf = OUTPUT.merge input
    @cache = {}
    every(30) do
      @cache.delete_if {|k,v| v[:PosTime] < 3.minutes.ago.to_i*1000}
    end
    async.run
  end
  def cleanup
    puts "Restarting Cache Subsystem"
    @sub.close
    @redis.close
  end
  def run
    @input = create_socket @inconf
    @output = create_socket @outconf

    puts "Waiting for updates"
    while true
      #Step 1: Simply forward. We do this to simplify connection between subscribers
      msg = @input.read
      @output << msg
      events = MessagePack.unpack(msg)
      events.each do |e|
        summary = (@cache[e[:Icao]] || {}).merge! e
        #TODO: Simplify up to N points. Make available upon request
        @cache[e[:Icao]] = summary
      end
    end
  end
end
AdsbCache.supervise as: :adsb_cache
sleep
