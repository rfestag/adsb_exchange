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
    end
    def run
      return if @running
      @running = true
      @stream = TCPSocket.new(@host, @port)
      @publish = Socket::Pub.new
      @publish.bind(@endpoint)

      Parser.parse(@stream) do |msg|
        now = Time.now.to_i*1000
        selected = msg[:acList].select do |update|
          update[:PosTime] = now
          update.length > 1
        end
        @publish << selected.to_msgpack
      end
    end
  end
end
