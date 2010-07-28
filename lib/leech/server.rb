require 'leech'
require 'leech/handler'

module Leech 
  # This is simple TCP server similar to rack, but designed for asynchronously 
  # handling a short text commands. It can be used for some monitoring purposes
  # or simple communication between few machines. 
  # 
  # ### Creating server instance
  #
  # Server can be created in two ways: 
  #
  #     server = Leech::Server.new :port => 666
  #     server.use :auth
  #     server.run
  #
  # ...or using block style:
  #   
  #     Leech::Server.new do 
  #       port 666
  #       use :auth
  #       run
  #     end
  #
  # ### Complete server example
  #
  # Simple server with authorization and few commands handling can be configured 
  # such like this one: 
  #
  #     server = Leech::Server.new do 
  #       # simple authorization handler, see Leech::AuthHandler for 
  #       # more informations. 
  #       use :auth 
  #     
  #       host 'localhost'
  #       port 666
  #       max_workers 100
  #       timeout 30
  #       logger Logger.new('/var/logs/leech/server.log')
  #     
  #       handle /^SHOW FILE (.*)$/ do |env,params| 
  #         if File.exists?(param[1])
  #           answer(File.open(params[0]).read)
  #         else
  #           answer('NOT FOUND')
  #         end
  #       end
  #       handle /^DELETE FILE (.*)$/ do |env,params| 
  #         answer(File.delete(params[1]))
  #       end
  #
  #       run
  #     end
  #
  #     # Now we have to join server thread with main thread. 
  #     server.join
  class Server
    # Default server error
    class Error < StandardError; end
    
    # Used to stop server via Thread#raise
    class StopServer < Error; end
    
    # Thrown at a thread when it is timed out.
    class TimeoutError < Timeout::Error; end
    
    # Server main thread
    #
    # @return [Thread]
    attr_reader :acceptor
    
    # Server configuration
    #
    # @return [Hash]
    attr_reader :options 
    
    # Server will bind to this host
    #
    # @return [String]
    attr_reader :host
    
    # Server will be listening on this port
    #
    # @return [Int]
    attr_reader :port
    
    # Logging object
    #
    # @return [Logger]
    attr_reader :logger
    
    # The maximum number of concurrent processors to accept, anything over 
    # this is closed immediately to maintain server processing performance.  
    # This may seem mean but it is the most efficient way to deal with overload.  
    # Other schemes involve still parsing the client's request wchich defeats 
    # the point of an overload handling system.
    #
    # @return [Int,Float]
    attr_reader :max_workers
    
    # Maximum idle time 
    #
    # @return [Int,Float] 
    attr_reader :timeout
    
    # A sleep timeout (in hundredths of a second) that is placed between 
    # socket.accept calls in order to give the server a cheap throttle time.  
    # It defaults to 0 and actually if it is 0 then the sleep is not done 
    # at all.
    #
    # @return [Int,Float]
    attr_reader :throttle
    
    # Here we have to define block-style setters for each startup parameter. 
    %w{host port logger throttle timeout max_workers}.each do |meth|
      eval <<-EVAL
        def #{meth}(*args)
          @#{meth} = args.first if args.size > 0
          @#{meth}
        end
      EVAL
    end
    
    # Creates a working server on host:port. Use #run to start the server 
    # and `acceptor.join` to join the thread that's processing incoming requests 
    # on the socket.
    #   
    # @param [Hash] opts see #options
    # @option opts [String] :host ('localhost') see #host 
    # @option opts [Int] :port (9933) see #port 
    # @option opts [Logger] :logger (Logger.new(STDOUT)) see #logger
    # @option opts [Int] :max_workers (100) see #max_workers
    # @option opts [Int,Float] :timeout (30) see #timeout 
    # @option opts [Int,Float] :throttle (0) see #throttle 
    #
    # @see Leech::Server#run
    def initialize(opts={}, &block)
      @handlers    = []
      @workers     = ThreadGroup.new
      @acceptor    = nil
      @mutex       = Mutex.new
      
      @options     = opts
      @host        = opts[:host] || 'localhost'
      @port        = opts[:port] || 9933
      @logger      = opts[:logger] || Logger.new(STDOUT)
      @max_workers = opts[:max_workers] || 100
      @timeout     = opts[:timeout] || 30
      @throttle    = opts[:throttle].to_i / 100.0
      
      @inline_handler = Class.new(Leech::Handler)
      instance_eval(&block) if block_given? 
    end
    
    # Port to acceptor thread #join method.
    #
    # @see Thread#join
    def join
      @acceptor.join if @acceptor
    end
    
    # It registers specified handler for using in this server instance. 
    # Handlers are extending functionality of server by defining custom 
    # command handling callbacks or server instance methods. 
    #
    # @param [Leech::Handler, Symbol] handler 
    #   Handler class or name
    #
    # @raise [Leech::Server::Error,Leech::Handler::Error]
    #   When specified adapter was not found or handler is invalid
    #
    # @see Leech::Handler
    def use(handler)
      case handler
      when Class
        @handlers << handler
        handler.used(self)
      when Symbol, String
        begin
          require "leech/handlers/#{handler.to_s}"
          klass = handler.to_s.gsub(/\/(.?)/) { "::#{$1.upcase}" }.gsub(/(?:^|_)(.)/) { $1.upcase }
          use(eval("Leech::Handlers::#{klass}"))
        rescue LoadError
          raise Error, "Could not find #{handler} handler"
        end
      else
        raise Leech::Handler::Error, "Invalid handler #{handler}"
      end
    end
    
    # It defines matching pattern in @inline_handler. It is similar to 
    # `Leech::Handler#handle` but can be used only in block-style. 
    #
    # @param [Regexp] patern 
    #   Block will be executed for passed command will be maching it. 
    # 
    # @example
    #     Leech::Server.new do 
    #       handle(/^PRINT) (.*)$/ {|env,params| print params[0]}
    #       handle(/^DELETE FILE (.*)$/) {|env,params| File.delete(params[0])}
    #     end
    #  
    # @see Leech::Handler#handle
    def handle(pattern, &block)
      @inline_handler.handle(pattern, &block)
    end
    
    # Used internally to kill off any worker threads that have taken too long
    # to complete processing. Only called if there are too many processors
    # currently servicing. It returns the count of workers still active
    # after the reap is done. It only runs if there are workers to reap.
    #
    # @param [String] reason 
    #   Reason why method was executed
    #
    # @return  [Array<Thread>] 
    #   List of still active workers threads. 
    def reap_dead_workers(reason='unknown')
      if @workers.list.length > 0
        logger.error  "#{Time.now}: Reaping #{@workers.list.length} threads for slow workers because of '#{reason}'"
        error_msg = "Leech timed out this thread: #{reason}"
        mark = Time.now
        @workers.list.each do |worker|
          worker[:started_on] = Time.now if not worker[:started_on]
          if mark - worker[:started_on] > @timeout + @throttle
            logger.error "Thread #{worker.inspect} is too old, killing."
            worker.raise(TimeoutError.new(error_msg))
          end
        end
      end
      return @workers.list.length
    end
    
    # Performs a wait on all the currently running threads and kills any that take
    # too long. It waits by `@timeout seconds`, which can be set in `#initialize`.
    # The `@throttle` setting does extend this waiting period by that much longer.
    def graceful_shutdown
      while reap_dead_workers("shutdown") > 0
        logger.error "Waiting for #{@workers.list.length} requests to finish, could take #{@timeout + @throttle} seconds."
        sleep @timeout / 10
      end
    end
    
    # Stops the acceptor thread and then causes the worker threads to finish
    # off the request queue before finally exiting. It's also reseting freezed 
    # settings.
    def stop
      if running?
        @acceptor.raise(StopServer.new)
        @handlers = Array.new(@handlers)
        @options = Hash.new(@options)
        sleep(0.5) while @acceptor.alive?
      end
    end    
    
    # Starts serving TCP listener on host and port declared in options. 
    # It returns the thread used so you can join it. Each client connection 
    # will be processed in separated thread.    
    #
    # @return [Thread] 
    #   Main thread for this server instance.  
    def run
      use(@inline_handler)
      @socket = TCPServer.new(@host, @port)
      @handlers = @handlers.uniq.freeze
      @options = @options.freeze
      @acceptor = Thread.new do 
        begin
          logger.debug "Starting leech server on tcp://#{@host}:#{@port}"
          loop do 
            begin
              client = @socket.accept 
              worker_list = @workers.list
              
              if worker_list.length >= @max_workers
                logger.error "Server overloaded with #{worker_list.length} workers (#@max_workers max). Dropping connection."
                client.close rescue nil
                reap_dead_workers("max processors")
              else
                thread = Thread.new(client) {|c| process_client(c) }
                thread[:started_on] = Time.now
                @workers.add(thread)
                sleep @throttle if @throttle > 0
              end
            rescue StopServer
              break
            rescue Errno::EMFILE
              reap_dead_workers("too many open files")
              sleep 0.5
            rescue Errno::ECONNABORTED
              client.close rescue nil
            rescue Object => e
              logger.error  "#{Time.now}: Unhandled listen loop exception #{e.inspect}."
              logger.error  e.backtrace.join("\n")
            end
          end
          graceful_shutdown
        ensure
          @socket.close  
          logger.debug "Closing leech server on tcp://#{@host}:#{@port}"
        end
      end
      
      return @acceptor
    end
    
    # It is getting information about client connection and starts conversation
    # with him. Received commands are passed to declared handlers, where will
    # be processed. 
    #
    # @param [TCPSocket] c 
    #   Client socket
    def process_client(c)
      Thread.current[:client] = c
      Thread.current[:info] = {
        :port => client.peeraddr[1],
        :host => client.peeraddr[2],
        :addr => client.peeraddr[3],
        }
      info[:uri] = [info[:host], info[:port]].join(':')
      logger.debug "Processing client from #{info[:uri]}"
      while line = client.gets
        line = line.chomp.strip
        logger.info "Dispatching command (#{info[:uri]}): #{line}"
        @handlers.each do |handler|
          if handler = handler.new(self).match(line.chomp.strip)
            handler.call
            next
          end
        end
      end
    end
    
    # Sends answer to current connected socket. Method should be called only 
    # in worker thread.
    # 
    # @param [String] msg 
    #   Text to send
    def answer(msg)
      logger.debug("Answering to (#{info[:uri]}): #{msg.chomp.strip}")
      client.puts(msg)
    end
    alias_method :say, :answer
        
    # @return [Boolean] 
    #   Actual server state. Returns `true` server acceptor thread is alive.
    def running?
      @acceptor && @acceptor.alive?
    end
    
    private
    
    # Informations about connected client. Method should be called only in 
    # woker thread.
    #
    # @return [Hash] 
    #   Client informations such as host, remote address and port 
    def info
      Thread.current[:info]
    end
    
    # Client socket from. Method should be called only in woker thread.
    #
    # @return [TCPSocket] 
    #   Client socket
    def client
      Thread.current[:client]
    end
  end # Server
end # Leech
