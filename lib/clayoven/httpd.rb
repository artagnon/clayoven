require 'webrick'

module Clayoven
  module Httpd
    def self.start
      port = 8000
      callback = Proc.new do |req, res|
        if %r{^/$} =~ req.path_info
          res.set_redirect WEBrick::HTTPStatus::Found, "index.html"
        end
        if %r{^/([^.]*)$} =~ req.path_info
          res.set_redirect WEBrick::HTTPStatus::Found, "#{$1}.html"
        end
      end

      server = WEBrick::HTTPServer.new(:Port            => port,
                                       :RequestCallback => callback,
                                       :DocumentRoot    => Dir.pwd)

      puts "clayoven serving at: http://localhost:#{port}"

      trap(:INT) { server.shutdown }
      server.start
    end
  end
end
