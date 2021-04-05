require 'helper'
require 'tmpdir'
require 'clayoven/init'

# Exercise Clayoven::Init.init
class Init < Minitest::Test
  def assert_paths(names)
    names.map { |name| "#{name}.html" }.each do |file|
      assert_path_exists file, "#{file} was not generated"
    end
  end

  def test_noarg
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        Clayoven::Init.init
        assert_paths %w[index 404 scratch]
      end
    end
  end

  def test_arg
    Dir.mktmpdir do |dir|
      Clayoven::Init.init dir
      Dir.chdir dir do
        assert_paths %w[index 404 scratch]
      end
    end
  end
end
