require 'adsb_exchange'
live = AdsbExchange::Live.new

live.start
sleep 1000
