require 'helper'
require 'tmpdir'
require 'clayoven/toplevel'

# Exercise Clayoven.main on artagnon.com
class Production < Minitest::Test
  def test_aggressive_clean_workdir
    Dir.mktmpdir do |tmpdir|
      `git clone https://github.com/artagnon/artagnon.com #{tmpdir}/artagnon.com`
      Dir.chdir("#{tmpdir}/artagnon.com") do
        `npm i`
        _, err = capture_subprocess_io { Clayoven::Toplevel.main(is_aggressive: true) }
        assert_empty err.strip
        Clayoven::Toplevel::Util.fork_exec 'git diff --exit-code'
        assert_equal $?.success?, true, "git diff returned non-zero:\n #{`git diff --name-status`}"
      end
    end
  end

  def test_incremental
    Dir.mktmpdir do |tmpdir|
      `git clone https://github.com/artagnon/artagnon.com #{tmpdir}/artagnon.com`
      Dir.chdir("#{tmpdir}/artagnon.com") do
        `npm i`
        File.open('scratch.index.clay', 'a') { |io| io.write 'foo' }
        Clayoven::Toplevel.main
        git_ns = `git diff --name-status @ 2>/dev/null`
        assert_equal git_ns.empty?, false
        git_index = git_ns.split("\n").map { |line| line.split("\t")[0..1] }
        git_mod_index = git_index.select { |idx| idx.first == 'M' }
        modified = git_mod_index.map(&:last)
        assert_equal modified.include?('scratch.html'), true
      end
    end
  end
end
