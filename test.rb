require 'oj'
class Parser < ::Oj::ScHandler
  def hash_start 
    {}
  end

  def hash_set(h,k,v)
    h[k] = v
  end

  def array_start
    puts "Started array"
    []
  end

  def array_append(a,v)
    a << v
  end
  def array_end
    puts "Ended array"
  end

  def add_value v
    v
  end
  def error(message, line, column)
    p "ERROR: #{message}"
  end
end
Oj.sc_parse(Parser.new, %Q{{"a": 1}{"b":2}}) {|a| puts a}
