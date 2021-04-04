require 'helper'
require 'tmpdir'
require 'clayoven/toplevel'

# Exercise Clayoven.main on artagnon.com
class Production < Minitest::Test
  def modified_clay_html
    git_ns = `git diff --name-status @ 2>/dev/null`
    return [] if git_ns.empty?

    git_index = git_ns.split("\n").map { |line| line.split("\t")[0..1] }
    git_mod_index = git_index.select { |idx| idx.first == 'M' }
    git_mod_index.map(&:last).select { |f| f.end_with?('.clay') || f.end_with?('.html') }
  end

  def test_aggressive_clean_workdir
    Dir.mktmpdir do |tmpdir|
      `git clone https://github.com/artagnon/artagnon.com #{tmpdir}/artagnon.com`
      Dir.chdir("#{tmpdir}/artagnon.com") do
        `npm i`
        _, err = capture_subprocess_io { Clayoven::Toplevel.main(is_aggressive: true) }
        assert_empty err.strip, "clayoven returned an error: #{err.strip}"
        assert_empty modified_clay_html, "git diff returned non-zero: #{modified_clay_html}"
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
        assert_equal modified_clay_html == ['scratch.html', 'scratch.index.clay'], true,
                     "modified files don't correspond to scratch: #{modified_clay_html}"
      end
    end
  end
end
