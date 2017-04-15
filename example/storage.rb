$stdout.sync = true
require 'adsb_exchange'
require 'celluloid/current'
require 'celluloid/zmq'
require 'msgpack'
require 'sequel'

class AdsbSaver
  include Celluloid::ZMQ
  finalizer :cleanup

  def initialize subscribe: "ipc:///tmp/adsb_updates"
    db_file = File.join(File.dirname(__FILE__), 'StandingData.sqb')
    @db = Sequel.connect("sqlite://#{db_file}")
    @aircraft = @db[:AircraftTypeNoEnumsView]

    @subscribe_url = subscribe
    async.run
  end
  def cleanup
    puts "Restarting Storage Subsystem"
    @sub.close
  end
  def run
    @sub = Socket::Sub.new
    @sub.connect @subscribe_url
    @sub.subscribe('')

    puts "Subscribed to adsb_updates"
    while true
      msg = @sub.read
      events = MessagePack.unpack(msg)
      events.each do |e|
        icao = e['Icao']
        obj = @aircraft.where(Icao: icao).first
        puts "#{icao} #{e.inspect}"
      end
    end
  end
end
AdsbSaver.supervise as: :adsb_saver
sleep
