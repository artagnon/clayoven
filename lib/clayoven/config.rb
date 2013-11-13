require 'yaml'

module Clayoven
  class ConfigData
    attr_accessor :rootpath, :rcpath, :ignorepath, :rc, :ignore

    def initialize
      @rootpath = '.clayoven'
      Dir.mkdir @rootpath unless Dir.exists? @rootpath

      initialize_ignore
      initialize_rc
    end

    def initialize_ignore
      @ignorepath = "#{rootpath}/ignore"

      # Most common patterns that should sit in .clayoven/ignore.
      # Written to the file when it doesn't exist.
      @ignore = ['\\.html$', '~$', '^.\#', '^\#.*\#$',
                 '^\\.git$', '^\\.gitignore$', '^\\.htaccess$']

      if File.exists? @ignorepath
        @ignore = IO.read(@ignorepath).split("\n")
      else
        File.open(@ignorepath, 'w') do |ignoreio|
          ignoreio.write @ignore.join("\n")
        end
        puts "[NOTE] #{@ignorepath} populated with sane defaults"
      end
    end

    def initialize_rc
      @rcpath = File.expand_path '~/.clayovenrc'
      @rc = nil
      @rc = YAML.load_file @rcpath if File.exists? @rcpath
    end
  end
end
