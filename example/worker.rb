$stdout.sync = true
require 'adsb_exchange'
require 'celluloid/current'
require 'celluloid/zmq'
require 'hiredis'
require 'sequel'
require 'redis'
require 'seconds'
require 'set'
require 'ruby-prof'
require 'oj'

class AdsbWorker < AdsbExchange::Live
  include Celluloid::ZMQ
  include AdsbExchange::SocketFactory

  BASE_STATION_SQB = File.join(File.dirname(__FILE__), 'BaseStation.sqb').freeze
  STANDING_DATA_SQB = File.join(File.dirname(__FILE__), 'StandingData.sqb').freeze
  OUTPUT = {type: Socket::Pub,
            endpoint: 'ipc:///tmp/adsb_updates',
            bind: true}.freeze

  finalizer :cleanup

  def initialize adsb_host: 'pub-vrs.adsbexchange.com', adsb_port: 32010, output: {}, base_station_sqb: BASE_STATION_SQB, standing_data_sqb: STANDING_DATA_SQB, **redis_opts
    super(host: adsb_host, port: adsb_port)
    @base_station = Sequel.connect("sqlite://#{base_station_sqb}")
    @standing_data = Sequel.connect("sqlite://#{standing_data_sqb}")
    @output = create_socket(OUTPUT.merge output)
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
    puts "Cleaning up"
    @stream.close if @stream 
    @output.close if @output
    @redis.close if @redis
  end
  def update events
    start = Time.now
    futures = []
    update_fields = Set.new
    @redis.multi do
      events.each do |e|
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
        else
          current.merge! e
        end

        @redis.set "info.#{e[:Icao]}", Oj.to_json(current)
        @redis.zadd "update.#{e[:Icao]}", e[:PosTime].to_i, Oj.to_json(e)
        @redis.expire "update.#{e[:Icao]}", 60
      end
    end
    @output << Oj.to_json(events)
    puts Time.now - start
  end
end
AdsbWorker.supervise as: :adsb_worker
sleep
