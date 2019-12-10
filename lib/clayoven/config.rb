module Clayoven
  class ConfigData
    attr_accessor :rootpath, :ignorepath, :ignore

    def initialize
      @rootpath = ".clayoven"
      Dir.mkdir @rootpath unless Dir.exists? @rootpath

      @ignorepath = "#{rootpath}/ignore"
      @ignore = File.exists?(@ignorepath) ? IO.read(@ignorepath).split("\n") : []
    end
  end
end
