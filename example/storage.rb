$stdout.sync = true
require 'adsb_exchange'
require 'celluloid/current'
require 'celluloid/zmq'
require 'msgpack'
require 'sequel'
require 'redis'
require 'seconds'

class AdsbSaver
  include Celluloid::ZMQ
  finalizer :cleanup

  def initialize subscribe: "ipc:///tmp/adsb_updates", base_station_sqb: File.join(File.dirname(__FILE__), 'BaseStation.sqb'), standing_data_sqb: File.join(File.dirname(__FILE__), 'StandingData.sqb'), **redis_opts
    @base_station = Sequel.connect("sqlite://#{base_station_sqb}")
    @standing_data = Sequel.connect("sqlite://#{standing_data_sqb}")
    opts = {driver: :celluloid}.merge! redis_opts
    @redis = Redis.new opts
    @aircraft = @base_station[:Aircraft]
    @types = @standing_data[:AircraftTypeNoEnumsView]
    @code_blocks = @standing_data[:CodeBlockView].reverse.order(:SignificantBitMask).to_a

    @subscribe_url = subscribe
    async.run
  end
  def cleanup
    puts "Restarting Storage Subsystem"
    @sub.close
    @redis.close
  end
  def run
    @sub = Socket::Sub.new
    @sub.connect @subscribe_url
    @sub.subscribe('')

    puts "Subscribed to adsb_updates"
    while true
      msg = @sub.read
      events = MessagePack.unpack(msg)
      futures = []
      #Step 1: Identify all new/existing elements
      @redis.pipelined do
        events.each do |e|
          futures.push([@redis.exists(e[:Icao]), e])
        end
      end
      #Step 2: Update entries. If this is a new element, enrich the first element with the data from BaseStation.sqb. Otherwise, just add the new update
      @redis.multi do
        events = futures.map do |(future, e)|
          unless future.value
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
          @redis.zadd e[:Icao], e[:PosTime].to_i, e.to_msgpack
          @redis.expire e[:Icao], 60*5
        end
      end
    end
  end
end
AdsbSaver.supervise as: :adsb_saver
sleep
