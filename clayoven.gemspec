Gem::Specification.new do |s|
  s.name                  = "clayoven"
  s.version               = "0.1"
  s.summary               = "Modern website generator with a traditional design"
  s.description           = ""
  s.author                = "Ramkumar Ramachandra"
  s.email                 = "artagnon@gmail.com"
  s.files                 = ["clayoven.rb", "httpd.rb", "imapd.rb"]
  s.homepage              = "https://github.com/artagnon/clayoven"
  s.license               = "MIT"
  s.post_install_message  = "clayoven installed!  Run `clayoven -h` for usage"
  s.required_ruby_version = '>= 1.9.2'

  s.executables << "clayoven"
  s.add_runtime_dependency 'example', '~> 1.1', '>= 1.1.4'
end
