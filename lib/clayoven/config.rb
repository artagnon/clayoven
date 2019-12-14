module Clayoven
  class ConfigData
    attr_accessor :hidden

    def initialize
      rootpath = ".clayoven"
      Dir.mkdir rootpath unless Dir.exists? rootpath

      path = "#{rootpath}/hidden"
      @hidden = File.exists?(path) ? IO.read(path).split("\n") : []
    end
  end
end
