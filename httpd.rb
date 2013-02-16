require 'webrick'

class Httpd
  def self.start
    port = 8000
    callback = Proc.new { |req, res|
      if %r{^/$} =~ req.path_info
        res.set_redirect WEBrick::HTTPStatus::Found, "index.html"
      end
      if %r{^/([^.]*)$} =~ req.path_info
        res.set_redirect WEBrick::HTTPStatus::Found, "#{$1}.html"
      end
    }

    server = WEBrick::HTTPServer.new(:Port            => port,
                                     :RequestCallback => callback,
                                     :DocumentRoot    => Dir.pwd)

    puts "clayoven serving at: http://localhost:#{port}"

    trap(:INT) { server.shutdown }
    server.start
  end
end
