$stdout.sync = true
require 'adsb_exchange'
require 'celluloid/current'
require 'celluloid/redis'
require 'celluloid/zmq'
require 'msgpack'
require 'sequel'
require 'redis'
require 'seconds'
require 'set'

class AdsbWorker
  include Celluloid::ZMQ
  include AdsbExchange::SocketFactory

  BASE_STATION_SQB = File.join(File.dirname(__FILE__), 'BaseStation.sqb').freeze
  STANDING_DATA_SQB = File.join(File.dirname(__FILE__), 'StandingData.sqb').freeze
  INPUT = {type: Socket::Pull,
           endpoint: 'ipc:///tmp/adsb_stream',
           bind: false}.freeze
  OUTPUT = {type: Socket::Push,
           endpoint: 'ipc:///tmp/adsb_cache',
           bind: false}.freeze

  finalizer :cleanup

  def initialize input: {}, output: {}, base_station_sqb: BASE_STATION_SQB, standing_data_sqb: STANDING_DATA_SQB, **redis_opts
    @base_station = Sequel.connect("sqlite://#{base_station_sqb}")
    @standing_data = Sequel.connect("sqlite://#{standing_data_sqb}")
    @inconf = INPUT.merge input
    @outconf = OUTPUT.merge output
    opts = {driver: :celluloid}.merge! redis_opts
    @redis = ::Redis.new opts
    @aircraft = @base_station[:Aircraft]
    @types = @standing_data[:AircraftTypeNoEnumsView]
    @code_blocks = @standing_data[:CodeBlockView].reverse.order(:SignificantBitMask).to_a
    @cache = {}
    async.run
    every(30) do
      @cache.delete_if {|k,v| v[:PosTime] < 3.minutes.ago.to_i*1000}
    end
  end
  def cleanup
    puts "Restarting Worker Subsystem"
    @input.close
    @output.close
    @redis.close
  end
  def run
    @input = create_socket @inconf
    @output = create_socket @outconf

    puts "Subscribed to adsb_updates"
    while true
      msg = @input.read
      start = Time.now
      events = MessagePack.unpack(msg)
      futures = []
      outputs = []
      update_fields = Set.new
      #Step 2: Update entries.
      @redis.multi do
        outputs  = events.map do |e|
          #If we don't, initialize with enrichment
          current = @cache[e[:Icao]] || {}

          if current.empty?
            details = @aircraft.where(ModeS: e[:Icao]).first
            if details
              e.merge!(details)
            end
            if e[:ICAOTypeCode]
              type = @types.where(Icao: e[:ICAOTypeCode]).first
              if type
                type.delete :Icao
                e.merge!(type)
              end
            end
            icao24 = e[:Icao].to_i(16)
            cb = @code_blocks.select {|cb| icao24 & cb[:SignificantBitMask] == cb[:BitMask]}.first
            if cb
              e.merge! cb
            end
            e.delete_if {|k,v| v.nil?}
          end
          @cache[e[:Icao]] = e
          #@redis.hmset "summary.#{e[:Icao]}", *e.to_a.flatten
          @redis.zadd "update.#{e[:Icao]}", e[:PosTime].to_i, e.to_msgpack
          #@redis.expire "summary.#{e[:Icao]}", 60*3
          @redis.expire "update.#{e[:Icao]}", 30
          e
        end
      end
      @output << outputs.to_msgpack
      puts Time.now-start
    end
  end
end
AdsbWorker.supervise as: :adsb_worker
sleep
