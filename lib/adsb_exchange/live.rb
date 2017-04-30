require 'oj'
module AdsbExchange
  class Live
    include Celluloid
    include Celluloid::IO

    IGNORE = [:Icao, :Sig].freeze

    finalizer :cleanup

    def initialize host: 'pub-vrs.adsbexchange.com', port: 32010
      @host = host
      @port = port
    end
    def stop
      @stream.close if @stream rescue nil
    end
    def run
      @stream = TCPSocket.new(@host, @port)

      Parser.parse(@stream) do |msg|
        now = Time.now.to_i
        messages = msg[:acList]
        messages.reject! do |update|
          diff = update.keys - IGNORE
          update[:PosTime] = now
          diff.empty?
        end
        update messages unless messages.empty?
      end
    end
    def update
      #Override this method
    end
  end
end
