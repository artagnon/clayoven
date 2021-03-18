require 'clayoven'
require 'fileutils'

require 'minitest/autorun'

# Exercise Clayoven::Util.init
class Init < Minitest::Test
  def test_init
    Dir.mktmpdir do |dir|
      FileUtils.cd dir
      Clayoven::Util.init
      assert_path_exists 'index.html', 'index.html was not generated'
      assert_path_exists '404.html', '404.html was not generated'
      assert_path_exists 'scratch.html', 'scratch.html was not generated'
    end
  end
end
