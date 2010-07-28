require File.join(File.dirname(__FILE__), 'spec_helper')
require 'socket'
require 'leech/handler'

describe "An Leech server handler" do 
  before do 
    @test_handler = Class.new(Leech::Handler)
  end
  
  it "should receive #used method when it's used by server" do 
    srv = Leech::Server.new
    @test_handler.should_receive(:used).once.with(srv)
    srv.use(@test_handler)
  end
  
  it "saves custom matchers described in #handle method" do
    @test_handler.class_eval do 
      handle(/^TESTING$/, :test)
      handle(/^ANOTHER$/) {|env,params|}
    end
    @test_handler.matchers.keys.size.should == 2
  end  
  
  it "should dispatch command to valid matcher" do 
    @test_handler.class_eval do
      handle /^HELLO$/, :hello
      handle /^SECOND (.*)$/ do |env,params| "Hello"  end
    end
    env = OpenStruct.new
    env.class_eval { define_method(:hello) {|p| }}
    th = @test_handler.new(env)
    th.match('HELLO').should be_kind_of(Leech::Handler)
    env.should_receive(:hello).once.with(an_instance_of(MatchData))
    th.call
    th = @test_handler.new(env)
    @test_handler.matchers[/^SECOND (.*)$/].should_receive(:call).once.with(env, an_instance_of(MatchData))
    th.match('SECOND yadayada')
    th.call
    th = @test_handler.new(env)
    th.match('NOT EXIST').should == nil
    lambda { th.call }.should raise_error(Leech::Handler::Error)
  end
end
