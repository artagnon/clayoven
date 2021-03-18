module Clayoven::Config
  TZ_DEFAULT = <<-'EOF'.freeze
  +0000 UTC
  EOF

  SUBTOPIC_DEFAULT = <<-'EOF'.freeze
  [dirname] [displayalias]
  EOF

  SLIM_DEFAULT = <<-'EOF'.freeze
  EOF

  # The data from .clayoven/config
  class Data
    attr_accessor :sitename, :hidden, :tzmap, :stmap, :template

    # Creates file at path, if it doesn't exist, with template text
    def create_template(path, template)
      components = path.split '/'
      Dir.mkdir components[0] if components.length == (2) && !(Dir.exist? components[0])
      if File.exist?(path)
        IO.read(path).split "\n"
      else
        File.open(path, 'w') { |io| io.write template }
        [template]
      end
    end

    def initialize
      @sitename = create_template('.clayoven/sitename', 'clayoven.io').first
      @hidden = create_template '.clayoven/hidden', %w[404 scratch].join("\n")
      @tzmap = (create_template '.clayoven/tz', TZ_DEFAULT).map { |l| l.split(' ', 2) }.to_h
      @stmap = (create_template '.clayoven/subtopic', SUBTOPIC_DEFAULT).map { |l| l.split(' ', 2) }.to_h
      @stmap.default_proc = proc { |h, k| h[k] = k }
      @template = (create_template 'design/template.slim', SLIM_DEFAULT).join "\n"
    end
  end
end
