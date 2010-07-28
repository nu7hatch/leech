require File.join(File.dirname(__FILE__), 'spec_helper')
require 'socket'
require 'leech/server'

NULL_LOGGER = Logger.new(StringIO.new)

describe "An new Leech server" do
  it "should properly store passed arguments" do 
    srv = Leech::Server.new(:host => "host", :port => 111, 1 => 2)
    srv.host.should == "host"
    srv.port.should == 111
    srv.options[1] = 2
  end
  
  it "should recognize max_workers option in passed arguments" do 
    srv = Leech::Server.new(:host => "host.com", :port => 111, :max_workers => 10)
    srv.max_workers.should == 10
  end
  
  it "should recognize timeout option in passed arguments" do 
    srv = Leech::Server.new(:host => "host.com", :port => 111, :timeout => 100)
    srv.timeout.should == 100
  end
  
  it "should recognize max_workers option in passed arguments" do 
    srv = Leech::Server.new(:host => "host.com", :port => 111, :max_workers => 10)
    srv.max_workers.should == 10
  end
  
  it "should recognize logger option in passed arguments" do 
    srv = Leech::Server.new(:host => "host.com", :port => 111, :logger => "logger")
    srv.logger.should == "logger"
  end
  
  it "should recognize throttle option in passed arguments" do 
    srv = Leech::Server.new(:host => "host.com", :port => 111, :throttle => 10)
    srv.throttle.should == 10 / 100.0
  end
  
  it "should allow to pass arguments in block" do
    srv = Leech::Server.new do 
      use(Leech::Handler)
      host 'myhost.com'
      port 12345
    end
    srv.host.should == 'myhost.com'
    srv.port.should == 12345
  end 
end

describe "An instnace of Leech server" do 
  before do
    @srv = Leech::Server.new(:port => 'localhost', :port => 1234, :timeout => 3, 
      :max_workers => 5, :logger => NULL_LOGGER)
  end

  it "should allow to use additional handlers" do 
    @srv.use(handler = Class.new(Leech::Handler))
    @srv.instance_variable_get('@handlers').should include(handler)
  end
  
  it "should provide inline handler" do 
    @srv.handle(/^TEST$/) {|env,params| }
    inline_handler = @srv.instance_variable_get('@inline_handler')
    inline_handler.matchers.keys.size.should == 1
    inline_handler.matchers.should have_key(/^TEST$/)
  end
  
  context "on run" do
    before do
      @srv.run
    end
  
    it "should freeze handlers list" do 
      @srv.instance_variable_get('@handlers').frozen?.should == true
    end
    
    it "should change it's running state" do 
      @srv.running?.should == true
    end
    
    after do 
      @srv.stop
    end
  end
  
  context "on stop" do 
    before do 
      @srv.run
    end
    
    it "should change it's running state" do 
      @srv.stop
      @srv.running?.should == false
    end
    
    it "should unfreeze handlers list" do
      frozen = @srv.instance_variable_get('@handlers')
      @srv.stop if @srv.running?
      unfrozen = @srv.instance_variable_get('@handlers')
      unfrozen.frozen?.should == false
      unfrozen.should == frozen
    end
  end
  
  context "on client connection" do  
    before do
      @srv.handle(/^TEST MESSAGE$/) {|env,params| env.answer("HELLO\n") }
      @srv.run
      @sock = TCPSocket.new(@srv.host, @srv.port)
    end
    
    it "should create new worker for it" do 
      sleep 1
      @srv.instance_variable_get('@workers').list.size.should == 1
    end
    
    it "should get client informations" do 
      sleep 1
      info = @srv.instance_variable_get('@workers').list.first[:info]
      info.should be_kind_of(Hash)
      info.should have_key(:host)
      info.should have_key(:port)
      info.should have_key(:addr)
      info.should have_key(:uri)
    end
    
    context "when command is received" do
      it "should handle it by matching handler" do 
        @sock.puts("TEST MESSAGE\n")
        answer = @sock.gets
        answer.should == "HELLO\n"
      end
    end
    
    after do 
      @sock.close
      @srv.stop
    end
  end
  
  it "should handle multiple connections" do 
    @srv.handle(/^MESSAGE FROM (.*)$/) {|env,params| env.answer("HELLO #{params[1]}\n") }
    @srv.run
    sock1 = TCPSocket.new(@srv.host, @srv.port)
    sock2 = TCPSocket.new(@srv.host, @srv.port)
    sock3 = TCPSocket.new(@srv.host, @srv.port)
    sleep 1
    @srv.instance_variable_get('@workers').list.size.should == 3
    sock1.close
    sock2.close
    sock3.close
    @srv.stop
  end
  
  it "should handle multiple connections" do 
    @srv.run
    sock1 = TCPSocket.new(@srv.host, @srv.port)
    sock2 = TCPSocket.new(@srv.host, @srv.port)
    sock3 = TCPSocket.new(@srv.host, @srv.port)
    sleep 1
    @srv.instance_variable_get('@workers').list.size.should == 3
    sock1.close
    sock2.close
    sock3.close
    @srv.stop
  end
  
  it "should respect :max_workers option" do 
    @srv.run
    sockets = []
    8.times { sockets << TCPSocket.new(@srv.host, @srv.port) }
    sleep 1
    @srv.instance_variable_get('@workers').list.size.should == 5
    sockets.each {|s| s.close }
    @srv.stop
  end
end
