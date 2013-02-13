Gem::Specification.new do |s|
  s.name                 = "clayoven"
  s.version              = "0.1"
  s.summary              = "Extremely simple website generator"
  s.description          = "Generates html files from a git repository, where files use a special markup.  Email posting supported."
  s.author               = "Ramkumar Ramachandra"
  s.email                = "artagnon@gmail.com"
  s.files                = ["clayoven.rb", "httpd.rb", "imapd.rb"]
  s.homepage             = "https://github.com/artagnon/clayoven"
  s.license              = "MIT"
  s.require_path         = "."
  s.bindir               = "."
  s.post_install_message = "clayoven installed!  Run `clayoven -h` for usage"

  s.executables << "clayoven"
  s.add_runtime_dependency 'example', '~> 1.1', '>= 1.1.4'
end
