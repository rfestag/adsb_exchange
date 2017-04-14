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
      parsed = response.parse
      @ldv = parsed['lastDv']
      return parsed
    end
  end
end
