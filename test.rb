require 'adsb_exchange'
q = AdsbExchange::AircraftList.new
start = Time.now
puts q.query(trFmt: 'f')['acList'].length
puts Time.now - start
3.times do 
  start = Time.now
  puts q.query['acList'].length
  puts Time.now-start
end
