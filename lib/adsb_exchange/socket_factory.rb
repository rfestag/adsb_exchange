module AdsbExchange
  module SocketFactory
    def create_socket type:, endpoint:, bind:
      socket = type.new
      bind ? socket.bind(endpoint) : socket.connect(endpoint)
      socket
    end
  end
end
