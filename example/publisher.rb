$stdout.sync = true
require 'adsb_exchange'
AdsbExchange::Live.supervise as: :adsb_source
sleep
