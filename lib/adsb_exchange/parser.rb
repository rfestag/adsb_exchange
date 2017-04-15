require 'oj'
module AdsbExchange
  class Parser < ::Oj::ScHandler
    def self.parse io
      Oj.sc_parse(new, io) do |msg|
        yield msg
      end
    end
    def hash_start 
      {}
    end

    def hash_set(h,k,v)
      h[k] = v
    end

    def array_start
      []
    end

    def array_append(a,v)
      a << v
    end

    def add_value v
      v
    end
  end
end
