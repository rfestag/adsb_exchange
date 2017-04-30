require 'msgpack'
MessagePack::DefaultFactory.register_type(0x00, Symbol, packer: ->(d){ d.to_s.to_msgpack }, unpacker: ->(d){ MessagePack.unpack(d).to_sym } )
MessagePack::DefaultFactory.register_type(0x01, Time, packer: ->(d){ d.to_i.to_msgpack }, unpacker: ->(d){ Time.at(MessagePack.unpack(d)) } )
MessagePack::DefaultFactory.register_type(0x02, BigDecimal, packer: ->(d){ d.to_s.to_msgpack }, unpacker: ->(d){ BigDecimal.new(MessagePack.unpack(d)) } )
