require 'yaml'

module Clayoven
  class ConfigData
    attr_accessor :rootpath, :rcpath, :ignorepath, :rc, :ignore

    def initialize
      @rootpath = ".clayoven"
      @rcpath = File.expand_path "~/.clayovenrc"
      @ignorepath = "#{rootpath}/ignore"
      @ignore = ["\\.html$", "~$", "^.\#", "^\#.*\#$",
                 "^\\.git$", "^\\.gitignore$", "^\\.htaccess$"]
      @rc = nil

      Dir.mkdir @rootpath if not Dir.exists? @rootpath
      if File.exists? @ignorepath
        @ignore = IO.read(@ignorepath).split("\n")
      else
        File.open(@ignorepath, "w") do |ignoreio|
          ignoreio.write @ignore.join("\n")
        end
        puts "[NOTE] #{@ignorepath} populated with sane defaults"
      end
      @rc = YAML.load_file @rcpath if File.exists? @rcpath
    end
  end
end
