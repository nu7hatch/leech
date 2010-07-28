# Leech 

Leech is simple TCP client/server framework. Server is similar to rack, 
but is designed for asynchronously handling a short text commands. It can
be used for some monitoring purposes or simple communication between few 
machines. 

## Installation

You can install Leach directly from rubygems:

    gem install leech 
    
## Gettings started

Leech is using simple TCP client/server architecture. It's a simple processor
for text commands passed through TCP socket. 

### Server

Server can be created in two ways: 

    server = Leech::Server.new :port => 666
    server.use :auth
    server.run

...or using block style:
  
    Leech::Server.new do 
      port 666
      use :auth
      run
    end
    
#### Server configuration

You can pass frew configuration options when you are creating new server, eg:

    Leech::Server.new(port => 666, :host => 'myhost.com', :timeout => 60)
    
For more information about allowed parameters visit 
[This doc page](http://yardoc.org/doc/Leech/Server.html#initialize-instance_method).

#### Handlers

Handlers are extending functionality of server by defining custom 
command handling callbacks or server instance methods. 

For simple commands handling you can use inline handler, which is automatically 
used by server, eg. 

    Leech::Server.new do 
      handle(/^PRINT) (.*)$/ {|env,params| print params[0]}
      handle(/^DELETE FILE (.*)$/) {|env,params| File.delete(params[0])}
    end 

For advanced tasks, you can write own handler, which will add new functionality
to server instance. 

    class CustomHandler < Leech::Handler
      # This method is automaticaaly called when server will use this handler
      def self.used(server)
        server.instance_eval { extend ServerMethods }
      end
      
      module ServerMethods
        def say_hello
          answer("Hello!")
        end
      end
  
      handle /^Hello server!$/, :say_hello
      handle /^Bye!$/ do |env,params|
        env.answer("Take care!")
      end
    end
    
To enable this handler in the server you can simply type: 

    Leech::Server.new do 
      use CustomHandler
    end
    
You should notice that block-style callbacks are passing two arguments: 
**env** - instance of server which is using this handler for processing, 
and **params** - array of strings fetched from matched command. 
    
#### Answering

For sending answers to clients server have the `#answer` method. It can be used
like here: 

    Leech::Server.new do
      handle /^HELLO$/ do |env,params| env.answer("HELLO MY FRIEND!\n")
    end 
    
#### Running / Listening

Server is partialy acting as `Thread`. You can join it's instance so application
will be waiting to interrupt or some unhandled server error: 

    server = Leech::Server.new
    server.run
    server.join # on server.acceptor.join
    
You can also simple use:
    
    server.run.join
    
### Client

Client will be implemented in 0.2.0 version. 

## Links

* [Author blog](http://neverendingcoding.com/)
* [YARD documentation](http://yardoc.org/doc/Leech)
* [Changelog](http://yardoc.org/doc/file:CHANGELOG.md)

## Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2010 Kriss Kowalik. See LICENSE for details.
