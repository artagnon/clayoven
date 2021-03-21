require 'colorize'
require 'webrick'
require 'uri'

# The entry point for `clayoven httpd`
#
# Run a simple webrick http server to test on localhost:8000
module Clayoven::Httpd
  # Start the server, and shut it down on `:INT`
  def self.start
    port = 8000
    callback = proc do |req, res|
      # A couple of URL rewriting rules; simple stuff
      if %r{^/$} =~ req.path_info
        res.set_redirect WEBrick::HTTPStatus::Found, 'index.html'
      elsif /^(?<uri>[^.]+)$/ =~ req.path_info
        res.set_redirect WEBrick::HTTPStatus::Found, "#{URI.parse(uri)}.html"
      end
    end

    server = WEBrick::HTTPServer.new(Port: port,
                                     RequestCallback: callback,
                                     DocumentRoot: Dir.pwd)

    puts "[#{'HTTP'.green}]: Serving at: http://localhost:#{port}"

    trap(:INT) { server.shutdown }
    server.start
  end
end
