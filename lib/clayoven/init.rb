# Used by init_test.rb
module Clayoven
  require_relative 'toplevel'

  # For 'clayoven init'
  module Init
    # Location of the dist directory
    def self.dist_location; File.join(__dir__, *%w[.. .. dist]) end

    # The entry point for 'clayoven init'. Does a 'cp -rv dist #{destdir}", 'git init', and 'npm i'.
    def self.init(destdir = '.')
      puts "[#{'INIT'.yellow}]: Populating directory with clayoven starter project"
      FileUtils.mkdir_p "#{destdir}/.clayoven"
      Dir.chdir destdir do
        FileUtils.cp_r "#{dist_location}/.", '.'
        `git init 2>/dev/null`
        fork { exec 'npm i >/dev/null' }
        Process.waitall
        Clayoven::Toplevel.main
      end
      puts "[#{'INIT'.green}]: Initialization finished. Run `clayoven httpd` in #{destdir} to see your website"
    end
  end
end
