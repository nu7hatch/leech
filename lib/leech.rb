require 'socket'
require 'logger'
require 'timeout'
require 'thread'

begin
  require 'fastthread' 
rescue LoadError
  $stderr.puts("The fastthread gem not found. Using standard ruby threads.")
end

# Leech is simple TCP client/server framework. Server is similar to rack, 
# but is designed for asynchronously handling a short text commands. It can
# be used for some monitoring purposes or simple communication between few 
# machines. 
module Leech
  # Namespace for handlers. 
  module Handlers; end
end # Leech
