# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'adsb_exchange/version'

Gem::Specification.new do |spec|
  spec.name          = "adsb_exchange"
  spec.version       = AdsbExchange::VERSION
  spec.authors       = ["Ryan Festag"]
  spec.email         = ["rfestag@gmail.com"]

  spec.summary       = %q{Summary}
  spec.homepage      = "https://github.com"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "reel"
  spec.add_development_dependency "ruby-prof"
  spec.add_development_dependency "activesupport"
  spec.add_development_dependency "foreman"
  spec.add_dependency 'http'
  spec.add_dependency "msgpack"
  spec.add_dependency 'celluloid-zmq'
  spec.add_dependency 'celluloid-redis'
  spec.add_dependency 'hiredis'
  spec.add_dependency 'oj'
  spec.add_dependency 'redis'
  spec.add_dependency 'sequel'
  spec.add_dependency 'sqlite3'
  spec.add_dependency 'seconds'
end
