# ADS-B Exchange

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/adsb_exchange`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

```bash
openssl req -newkey rsa:2048 -nodes -keyout example/test.key -x509 -days 365 -out example/test.crt
#http://www.virtualradarserver.co.uk/Files/BaseStation.zip
#http://www.virtualradarserver.co.uk/Files/FlightNumberCoverage.csv
#http://www.virtualradarserver.co.uk/Files/StandingData.sqb.gz
#http://registry.faa.gov/database/ReleasableAircraft.zip

echo 1 > /proc/sys/vm/overcommit_memory

#/etc/redis.conf
notify-keyspace-events Ex

top -p `pgrep -d ',' "ruby|redis"`
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'adsb_exchange'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install adsb_exchange

## Usage

                                        REDIS <------------------|
                                          ^                      | All Points
bcast              WORKER 1               |Points                |
STREAM ---PUSH---> WORKER 2 ---PUSH---> CACHE ---PUBLISH---> WEBSOCKET
                   WORKER N               ^bcast                 | 
                                          |                      |
                                          ------------------------              
                                               Pull Summaries  

## Development                 

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Ryan Festag/adsb_exchange. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

