require 'cztop'
require 'yajl'
require 'msgpack'
require 'celluloid/current'
module AdsbExchange
  class Live
    include Celluloid
    finalizer :stop
    attr_accessor :running

    def initialize host: 'pub-vrs.adsbexchange.com', port: 32010, publish: 'ipc:///tmp/adsb_updates'
      @source = "tcp://#{host}:#{port}"
      @endpoint = publish
      async.run
    end
    def stop
      @stream.close if @stream
      @publish.close if @publish
    end
    def run
      @parser = Yajl::Parser.new
      @parser.on_parse_complete = method(:publish)
      @stream = CZTop::Socket::STREAM.new(@source)
      @publish = CZTop::Socket::PUB.new(@endpoint)
      while true 
        msg = @stream.receive
        @parser << msg[1]
      end
    end
  private
    def publish msg
      now = Time.now.to_i*1000
      selected = msg['acList'].select do |update|
        update['PosTime'] = now
        update.length > 1
      end
      @publish << selected.to_msgpack
    end
  end
end
