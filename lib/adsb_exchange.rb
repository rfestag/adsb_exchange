require 'oj'
require 'msgpack'
require 'celluloid/current'
require 'celluloid/io'
require 'celluloid/zmq'
require "adsb_exchange/version"
require "adsb_exchange/parser"
require "adsb_exchange/msgpack"
require "adsb_exchange/aircraft_list"
require "adsb_exchange/live"
Celluloid::ZMQ.init
