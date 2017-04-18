require 'http'
module AdsbExchange
  class AircraftList
    def initialize url='https://public-api.adsbexchange.com/VirtualRadar/AircraftList.json'
      @url = url
    end
    def query **opts
      opts[:ldv] ||= @ldv if @ldv
      icaos = opts.delete(:icaos) if opts[:icaos]
      args = {}
      args[:params] = opts unless opts.empty? 
      args[:form] = {icaos: icaos.join("-")} if icaos
      response = args.empty? ? HTTP.post(@url) : HTTP.post(@url, args)
      Parser.parse(response.body) do |body|
        @ldv = body[:lastDv]
        return body
      end
    end
  end
end
