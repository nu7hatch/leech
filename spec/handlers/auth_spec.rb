require File.join(File.dirname(__FILE__), '../spec_helper')
require 'socket'
require 'leech/server'
require 'leech/handler'
require 'leech/handlers/auth'

describe "An Leech Auth handler" do 
  before do 
    @srv = Leech::Server.new(:logger => Logger.new(StringIO.new))
    @srv.use :auth
  end
  
  it "should append #authorize and #authorized? methods to server instance" do 
    @srv.should respond_to :authorize
    @srv.should respond_to :authorized?
  end
  
  it "should define matcher for AUTHORIZE command" do 
    Leech::Handlers::Auth.matchers.size.should == 1
    pattern = Leech::Handlers::Auth.matchers.keys.first
    'AUTHORIZE'.should =~ pattern
    'AUTHORIZE passcode'.should =~ pattern
  end
  
  context "powered server" do
    it "should authorize client with empty passcode when options[:passcode] is not set" do 
      @srv.run
      sock = TCPSocket.new(@srv.host, @srv.port)
      sleep 1
      sock.puts("AUTHORIZE\n")
      sock.gets.should == "AUTHORIZED\n"
      sock.close
    end
    
    it "should authorize client with valid passcode" do 
      @srv.options[:passcode] = 'secret'
      @srv.run
      sock = TCPSocket.new(@srv.host, @srv.port)
      sleep 1
      sock.puts("AUTHORIZE secret\n")
      sock.gets.should == "AUTHORIZED\n"
      sock.close
    end
    
    it "should not authorize client with invalid passcode" do 
      @srv.options[:passcode] = 'secret'
      @srv.run
      sock = TCPSocket.new(@srv.host, @srv.port)
      sleep 1
      sock.puts("AUTHORIZE not-secret\n")
      sock.gets.should == "UNAUTHORIZED\n"
      sock.close
    end
    
    after do 
      @srv.stop
    end
  end
end
