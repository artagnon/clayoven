require 'webrick'

module Clayoven
  module Httpd
    def self.start
      port = 8000
      callback = proc do |req, res|

        # A couple of URL rewriting rules.  Not real URL rewriting
        # like .htaccess; just a HTTP redirect. / is rewritten to
        # index.html, and anything-that-doesn't-end-in-.html/css/js is
        # rewritten to that-thing.html.
        if %r{^/$} =~ req.path_info
          res.set_redirect WEBrick::HTTPStatus::Found, 'index.html'
        elsif %r{(?<uri>.*)/$} =~ req.path_info
          res.set_redirect WEBrick::HTTPStatus::Found, "#{uri}.html"
        elsif %r{^(?<page>(?!.*[.](html|css|js|ico|png)$).*$)} =~ req.path_info
          res.set_redirect WEBrick::HTTPStatus::Found, "#{page}.html"
        end
      end

      server = WEBrick::HTTPServer.new(Port: port,
                                       RequestCallback: callback,
                                       DocumentRoot: Dir.pwd)

      puts "clayoven serving at: http://localhost:#{port}"

      trap(:INT) { server.shutdown }
      server.start
    end
  end
end
