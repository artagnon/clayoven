# :nodoc:
module Clayoven
  require_relative 'toplevel'

  # Entry point for `clayoven init`
  #
  # It copies the `dist` directory from the source tree to the new project, invokes `git init`
  # and `npm i`. Having node.js installed is a prerequisite.
  module Init
    # Location of the dist directory
    def self.dist_location; File.join(__dir__, *%w[.. .. dist]) end

    # The entry point for 'clayoven \init'. Does a 'cp -rv #{distdir} #{destdir}", 'git \init', and 'yarn install'.
    def self.init(destdir = '.')
      puts "[#{'INIT'.yellow}]: Populating directory with clayoven starter project"
      FileUtils.mkdir_p "#{destdir}/.clayoven"
      Dir.chdir destdir do
        FileUtils.cp_r "#{dist_location}/.", '.'
        `git init 2>/dev/null`
        system 'yarn install >/dev/null'
        Process.waitall
        Clayoven::Toplevel.main(is_aggressive: true)
      end
      puts "[#{'INIT'.green}]: Initialization finished. Run `clayoven httpd` in #{destdir} to see your website"
    end
  end
end
