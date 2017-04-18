require 'msgpack'
MessagePack::DefaultFactory.register_type(0x00, Symbol)
MessagePack::DefaultFactory.register_type(0x01, Time, packer: ->(t){ t.to_i.to_msgpack }, unpacker: ->(d){ Time.at(MessagePack.unpack(d)) } )
MessagePack::DefaultFactory.register_type(0x02, BigDecimal, packer: ->(t){ t.to_s.to_msgpack }, unpacker: ->(d){ BigDecimal.new(MessagePack.unpack(d)) } )
