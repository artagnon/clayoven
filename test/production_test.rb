require 'helper'
require 'tmpdir'
require 'fileutils'
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

  def test_clean_workdir
    Dir.mktmpdir do |tmpdir|
      `git clone https://github.com/artagnon/artagnon.com #{tmpdir}/artagnon.com`
      Dir.chdir("#{tmpdir}/artagnon.com") do
        `yarn install`

        _, err = capture_io { Clayoven::Toplevel.main }
        assert_empty err.strip, "clayoven incremental returned an error: #{err.strip}"
        assert_empty modified_clay_html, "git diff returned non-zero: #{modified_clay_html}"

        _, err = capture_io { Clayoven::Toplevel.main(is_aggressive: true) }
        assert_empty err.strip, "clayoven returned an error: #{err.strip}"
        assert_empty modified_clay_html, "git diff returned non-zero: #{modified_clay_html}"
      end
    end
  end

  def test_incremental
    Dir.mktmpdir do |tmpdir|
      `git clone https://github.com/artagnon/artagnon.com #{tmpdir}/artagnon.com`
      Dir.chdir("#{tmpdir}/artagnon.com") do
        `yarn install`
        File.open('articles/zfc.clay', 'a') { |io| io.write 'foo' }
        File.open('articles/ra.clay', 'a') { |io| io.write 'bar' }
        Clayoven::Toplevel.main
        assert_equal modified_clay_html,
                     ['articles.html', 'articles/ra.clay', 'articles/ra.html', 'articles/zfc.clay',
                      'articles/zfc.html'],
                     "modified files don't correspond to articles, ra, and zfc: #{modified_clay_html}"
      end
    end
  end

  def test_incremental_full
    Dir.mktmpdir do |tmpdir|
      `git clone --depth 1 https://github.com/artagnon/artagnon.com #{tmpdir}/artagnon.com`
      Dir.chdir("#{tmpdir}/artagnon.com") do
        FileUtils.rm_rf '.git'
        FileUtils.rm_rf Dir.glob('**/*.html')
        `git init`
        `yarn install`
        Clayoven::Toplevel.main
        untracked_files = `git ls-files --others --exclude-standard`.split("\n")
        untracked_html = untracked_files.filter { |f| f.end_with? '.html' }
        assert_equal untracked_html.empty?, false, "clayoven incremental didn't build anything"
      end
    end
  end
end
