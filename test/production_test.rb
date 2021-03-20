require 'helper'
require 'clayoven/toplevel'

# Exercise Clayoven.main on artagnon.com
class Production < Minitest::Test
  def test_aggressive_noerr
    Dir.mktmpdir do |tmpdir|
      `git clone --depth 1 https://github.com/artagnon/artagnon.com #{tmpdir}/artagnon.com`
      Dir.chdir("#{tmpdir}/artagnon.com") do
        `npm i`
        _, err = capture_io do
          Clayoven::Toplevel.main(is_aggressive: true)
        end
        assert_empty err
      end
    end
  end
end
