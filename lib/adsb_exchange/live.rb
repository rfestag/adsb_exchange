require 'oj'
module AdsbExchange
  class Live
    include Celluloid
    include Celluloid::IO
    include Celluloid::ZMQ
    include SocketFactory

    OUTPUT = {type: Socket::Push,
              endpoint: 'ipc:///tmp/adsb_stream',
              bind: true}.freeze
    IGNORE = [:Icao, :Sig].freeze

    finalizer :stop
    attr_accessor :running

    def initialize host: 'pub-vrs.adsbexchange.com', port: 32010, output: {}
      @outconf = OUTPUT.merge output
      @host = host
      @port = port
      async.run
    end
    def stop
      @running = false
      @stream.close if @stream rescue nil
      @output.close if @output rescue nil
    end
    def run
      return if @running
      @running = true
      @stream = TCPSocket.new(@host, @port)
      @output = create_socket @outconf

      Parser.parse(@stream) do |msg|
        now = Time.now.to_i
        messages = msg[:acList]
        messages.reject! do |update|
          diff = update.keys - IGNORE
          update[:PosTime] = now
          diff.empty?
        end
        @output << Oj.to_json(messages) unless messages.empty?
      end
    end
  end
end
