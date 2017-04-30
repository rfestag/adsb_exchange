$stdout.sync = true
require 'adsb_exchange'
require 'celluloid/current'
#require 'celluloid/redis'
require 'celluloid/zmq'
require 'hiredis'
require 'msgpack'
require 'sequel'
require 'redis'
require 'seconds'
require 'set'
require 'ruby-prof'
require 'oj'

class AdsbWorker
  include Celluloid::ZMQ
  include AdsbExchange::SocketFactory

  MAX_POINTS = 100
  BASE_STATION_SQB = File.join(File.dirname(__FILE__), 'BaseStation.sqb').freeze
  STANDING_DATA_SQB = File.join(File.dirname(__FILE__), 'StandingData.sqb').freeze
  MONGOID_YML = File.join(File.dirname(__FILE__), 'mongoid.yml').freeze
  INPUT = {type: Socket::Pull,
           endpoint: 'ipc:///tmp/adsb_stream',
           bind: false}.freeze
  OUTPUT = {type: Socket::Push,
           endpoint: 'ipc:///tmp/adsb_cache',
           bind: false}.freeze

  finalizer :cleanup

  def initialize input: {}, output: {}, base_station_sqb: BASE_STATION_SQB, standing_data_sqb: STANDING_DATA_SQB, mongoid: MONGOID_YML, mongoid_env: :production, **redis_opts
    #Mongoid.load! MONGOID_YML, mongoid_env 
    @base_station = Sequel.connect("sqlite://#{base_station_sqb}")
    @standing_data = Sequel.connect("sqlite://#{standing_data_sqb}")
    @inconf = INPUT.merge input
    @outconf = OUTPUT.merge output
    opts = {driver: :hiredis}.merge! redis_opts
    @redis = ::Redis.new opts
    @aircraft = @base_station[:Aircraft]
    @types = @standing_data[:AircraftTypeNoEnumsView]
    @code_blocks = @standing_data[:CodeBlockView].reverse.order(:SignificantBitMask).to_a
    @cache = {}
    async.run
    every(30) do
      @redis.pipelined do
        @cache.delete_if do |k,(current, track)| 
          rem = current[:PosTime] < 30.seconds.ago.to_i
          if rem
            @redis.del "info.#{current[:Icao]}"
            @redis.del "update.#{current[:Icao]}"
          end
          rem
        end
      end
    end
  end
  def cleanup
    puts "Restarting Worker Subsystem"
    @input.close
    @output.close
    @redis.close
  end
  def process events
    futures = []
    outputs = []
    update_fields = Set.new
    @redis.multi do
      outputs  = events.reduce([]) do |outputs, e|
        #If we don't, initialize with enrichment
        @cache[e[:Icao]] ||= [{}, []]
        current, track = @cache[e[:Icao]]

        if current.empty?
          current.merge! e
          details = @aircraft.where(ModeS: e[:Icao]).first
          if details
            current.merge!(details)
          end
          if current[:ICAOTypeCode]
            type = @types.where(Icao: e[:ICAOTypeCode]).first
            if type
              type.delete :Icao
              current.merge!(type)
            end
          end
          icao24 = current[:Icao].to_i(16)
          cb = @code_blocks.select {|cb| icao24 & cb[:SignificantBitMask] == cb[:BitMask]}.first
          if cb
            current.merge! cb
          end
          current.delete_if {|k,v| v.nil?}
          e = current
          outputs.push current
        else
          current.merge! e
        end

        @redis.set "info.#{e[:Icao]}", Oj.to_json(current)
        @redis.zadd "update.#{e[:Icao]}", e[:PosTime].to_i, Oj.to_json(e)
        @redis.expire "update.#{e[:Icao]}", 60
        outputs
      end
    end
    outputs
  end
  def run
    @input = create_socket @inconf
    @output = create_socket @outconf

    puts "Subscribed to adsb_updates"
    while true
      #RubyProf.start
      msg = @input.read
      start = Time.now
      outputs = process Oj.load(msg, symbol_keys: true)
      @output << msg
      #@output << outputs.to_msgpack unless outputs.empty?
      puts Time.now-start
      #result = RubyProf.stop
      #printer = RubyProf::FlatPrinter.new(result)
      #printer.print(STDOUT)
    end
  end
  private
  def area a,b,c
    ax,ay = a
    bx,by = b
    cx,cy = c
    (ax*by + bx*cy + cx*ay - ax*cy - bx*ay - cx*by).abs
  end
end
AdsbWorker.supervise as: :adsb_worker
sleep
