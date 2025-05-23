require_relative '../../spec_helper'
require_relative '../../fixtures/classes'

describe :tcpsocket_new, shared: true do
  it "requires a hostname and a port as arguments" do
    -> { TCPSocket.send(@method) }.should raise_error(ArgumentError)
  end

  it "refuses the connection when there is no server to connect to" do
    -> do
      TCPSocket.send(@method, SocketSpecs.hostname, SocketSpecs.reserved_unused_port)
    end.should raise_error(SystemCallError) {|e|
      [Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL].should include(e.class)
    }
  end

  it 'raises IO::TimeoutError with :connect_timeout when no server is listening on the given address' do
    NATFIXME 'Add IO::TimeoutError', exception: NameError, message: 'uninitialized constant IO::TimeoutError' do
      -> {
        TCPSocket.send(@method, "192.0.2.1", 80, connect_timeout: 0)
      }.should raise_error(IO::TimeoutError)
    end
  rescue Errno::ENETUNREACH
    # In the case all network interfaces down.
    # raise_error cannot deal with multiple expected exceptions
  end

  describe "with a running server" do
    before :each do
      @server = SocketSpecs::SpecTCPServer.new
      @hostname = @server.hostname
    end

    after :each do
      if @socket
        @socket.write "QUIT"
        @socket.close
      end
      @server.shutdown
    end

    it "silently ignores 'nil' as the third parameter" do
      @socket = TCPSocket.send(@method, @hostname, @server.port, nil)
      @socket.should be_an_instance_of(TCPSocket)
    end

    it "connects to a listening server with host and port" do
      @socket = TCPSocket.send(@method, @hostname, @server.port)
      @socket.should be_an_instance_of(TCPSocket)
    end

    it "connects to a server when passed local_host argument" do
      @socket = TCPSocket.send(@method, @hostname, @server.port, @hostname)
      @socket.should be_an_instance_of(TCPSocket)
    end

    it "connects to a server when passed local_host and local_port arguments" do
      server = TCPServer.new(SocketSpecs.hostname, 0)
      begin
        available_port = server.addr[1]
      ensure
        server.close
      end
      @socket = TCPSocket.send(@method, @hostname, @server.port,
                               @hostname, available_port)
      @socket.should be_an_instance_of(TCPSocket)
    end

    it "has an address once it has connected to a listening server" do
      @socket = TCPSocket.send(@method, @hostname, @server.port)
      @socket.should be_an_instance_of(TCPSocket)

      # TODO: Figure out how to abstract this. You can get AF_INET
      # from 'Socket.getaddrinfo(hostname, nil)[0][3]' but socket.addr
      # will return AF_INET6. At least this check will weed out clearly
      # erroneous values.
      @socket.addr[0].should =~ /^AF_INET6?/

      case @socket.addr[0]
      when 'AF_INET'
        @socket.addr[3].should == SocketSpecs.addr(:ipv4)
      when 'AF_INET6'
        @socket.addr[3].should == SocketSpecs.addr(:ipv6)
      end

      @socket.addr[1].should be_kind_of(Integer)
      @socket.addr[2].should =~ /^#{@hostname}/
    end

    it "connects to a server when passed connect_timeout argument" do
      @socket = TCPSocket.send(@method, @hostname, @server.port, connect_timeout: 1)
      @socket.should be_an_instance_of(TCPSocket)
    end
  end
end
