require 'yajl'
require 'msgpack'
require 'celluloid/current'
require 'celluloid/io'
require 'celluloid/zmq'
Celluloid::ZMQ.init
module AdsbExchange
  class Live
    include Celluloid::IO
    include Celluloid::ZMQ

    finalizer :stop
    attr_accessor :running

    def initialize host: 'pub-vrs.adsbexchange.com', port: 32010, publish: 'ipc:///tmp/adsb_updates'
      @host = host
      @port = port
      @endpoint = publish
      async.run
    end
    def stop
      @running = false
      @stream.close if @stream
      @publish.close if @publish
      @parser = nil
    end
    def run
      return if @running
      @running = true
      @parser = Yajl::Parser.new
      @parser.on_parse_complete = method(:on_data)
      @stream = TCPSocket.new(@host, @port)
      @publish =Socket::Pub.new
      @publish.bind(@endpoint)

      while true 
        @parser << @stream.recv(1024)
      end
    end
  private
    def on_data msg
      now = Time.now.to_i*1000
      selected = msg['acList'].select do |update|
        update['PosTime'] = now
        update.length > 1
      end
      @publish << selected.to_msgpack
    end
  end
end
