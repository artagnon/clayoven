require 'helper'
require 'tmpdir'

# Exercise Clayoven::Util.init
class Init < Minitest::Test
  def assert_paths(names)
    names.map { |name| "#{name}.html" }.each do |file|
      assert_path_exists file, "#{file} was not generated"
    end
  end

  def test_init_noarg
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Clayoven::Util.init
        assert_paths %w[index 404 scratch]
      end
    end
  end

  def test_init_arg
    Dir.mktmpdir do |dir|
      Clayoven::Util.init dir
      Dir.chdir(dir) do
        assert_paths %w[index 404 scratch]
      end
    end
  end
end
