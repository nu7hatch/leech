module Leech
  # Handlers are extending functionality of server by defining custom 
  # command handling callbacks or server instance methods. 
  #
  # @example Writing own handler
  #     class CustomHandler < Leech::Handler
  #       def self.used(server)
  #         server.instance_eval { extend ServerMethods }
  #       end
  #     
  #       module ServerMethods
  #         def say_hello
  #           answer("Hello!")
  #         end
  #       end
  #
  #       handle /^Hello server!$/, :say_hello
  #       handle /^Bye!$/ do |env,params|
  #         env.answer("Take care!")
  #       end
  #     end
  # 
  # @example Enabling handlers by server
  #   Leech::Server.new { use CustomHandler }
  #
  # @abstract
  class Handler
    # Default handler error
    class Error < StandardError; end
     
    # List of declared matchers
    def self.matchers
      @matchers ||= {}
    end
    
    # It defines matching pattern and callback related with. When specified
    # command will match this pattern then callback will be called. 
    #
    # @param [Regexp] patern 
    #   Block will be executed for passed command will be maching it. 
    # @param [Symbol, nil] method
    #   Name of server method, which should be called when pattern will 
    #   match with command
    # 
    # @example
    #     handle(/^PRINT) (.*)$/ {|env,params| print params[0]}
    #     handle(/^DELETE FILE (.*)$/) {|env,params| File.delete(params[0])}
    #     handle(/^HELLO$/, :say_hello)
    #
    # @raise [Leech::Error]
    #   When specified callback is not valid method name or Proc.
    def self.handle(pattern, method=nil, &block)
      if block_given?
        method = block
      end
      if method.is_a?(Proc) || method.is_a?(Symbol)
        self.matchers[pattern] = method
      else
        raise Error, "Invalid handler callback"
      end
    end
    
    # You should implement this method in your handler eg. if you would like
    # to modify server class. 
    def self.used(server)
      # nothing...
    end
    
    # @return [Leecher::Server]
    #   Passed server instance
    attr_reader :env 
    
    # @return [Array<String>]
    #   Parameters matched in passed command
    attr_reader :params
    
    # Constructor. 
    #
    # @param [Leech::Server]
    #   Server instance
    def initialize(env)
      @env = env
    end
    
    # Compare specified command with declared patterns.
    #
    # @param [String] command
    #   Command to handle.
    # 
    # @return [Leech::Handler,nil] 
    #   When command match one of declared patterns then it returns itself, 
    #   otherwise it returns nil. 
    def match(command)
      self.class.matchers.each_pair do |p,m|
        if @params = p.match(command)
          @matcher = m
          return self
        end
      end
      nil
    end
    
    # This method can be called only after #match. It executes callback 
    # related with matched pattern. 
    #
    # @raise [Leech::Error] 
    #   When @matcher is not defined, which means that #match method wasn't 
    #   called before. 
    def call
      case @matcher
      when Proc
        @matcher.call(env, params)
      when String, Symbol 
        env.send(@matcher.to_sym, params)
      else
        raise Error, "Can not call unmatched command"
      end
    end
  end # Handler
end # Leech
