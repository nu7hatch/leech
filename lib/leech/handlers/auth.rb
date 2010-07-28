module Leech
  module Handlers
    # Simple authorization handler. It uses password string (passcode) for 
    # authorize client session.  
    #
    # ### Usage
    #     Leech::Server.new { use :auth }
    #
    # ### Supported commands
    #     AUTHORIZE passcode
    #
    # ### Possible Answers
    #     UNAUTHORIZED   
    #     AUTHORIZED 
    class Auth < Handler
      def self.used(server)
        server.instance_eval do 
          extend ServerMethods
        end
      end
      
      module ServerMethods
        # Authorize client session using simple passcode. 
        #
        # @param [String] passcode 
        #   Password sent by client
        def authorize(passcode)
          if options[:passcode].to_s.strip == passcode.to_s.strip
            Thread.current[:authorized] = true
            answer("AUTHORIZED\n")
            logger.info("Client #{info[:uri]} authorized")
          else
            Thread.current[:authorized] = false
            answer("UNAUTHORIZED\n")
            logger.info("Client #{info[:uri]} unauthorized: invalid passcode")
          end
        end
        
        # @return [Boolean] 
        #   Is client session authorized?
        def authorized?
          !!Thread.current[:authorized]
        end
      end # ServerMethods
      
      # Available commands
      
      handle(/^AUTHORIZE[\s+]?(.*)?$/m) {|env,params| env.authorize(params[1])}
    end # AuthHandler
  end # Handlers
end # Leech
