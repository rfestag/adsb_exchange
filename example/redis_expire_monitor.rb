$stdout.sync = true
require 'adsb_exchange'
require 'celluloid/current'
require 'celluloid/zmq'
require 'celluloid/redis'
require 'msgpack'
require 'sequel'
require 'redis'
require 'seconds'

#Notice: Redis must be configured to send expired notifications - notify-keyspace-events Ex
class RedisExpireMonitor
  include Celluloid::ZMQ
  finalizer :cleanup

  def initialize database: 0, **redis_opts
    opts = {driver: :celluloid, timeout: 0}.merge! redis_opts
    @database = database
    @pubsub = ::Redis.new opts
    @redis = ::Redis.new opts
    async.run
  end
  def cleanup
    puts "Restarting Redis Expire Monitor"
    @redis.close
  end
  def run
    @pubsub.psubscribe "__keyevent@#{@database}__:expired" do |on|
      on.psubscribe do |channel, subscriptions|
        puts "Subscribe #{channel}: #{subscriptions}"
      end
      on.pmessage do |channel, message, value|
        #TODO: Store off track information before deleting
        type, icao = value.split('.', 2)
        if type == 'summary'
          puts "Deleting #{icao}"
          @redis.del "update.#{icao}"
        elsif type == 'update'
          puts "Warning: Missed expiration of #{icao}"
        end
      end
      on.punsubscribe do |channel, subscriptions|
        puts "Unsubscribe #{channel}: #{subscriptions}"
      end
    end
  end
end
RedisExpireMonitor.supervise as: :redis_expire_monitor
sleep
