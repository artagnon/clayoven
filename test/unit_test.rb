require 'helper'
require 'tmpdir'
require 'clayoven/init'
require 'clayoven/httpd'

# Exercise Clayoven::Toplevel.main and Clayoven::Httpd
class Unit < Minitest::Test
  def msg_not_found(msgs, out)
    msgs.each do |msg|
      assert_match msg, out, "#{msg} operation message not found in output: #{out}"
    end
  end

  def test_main_output
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        Clayoven::Init.init
        out, = capture_subprocess_io { Clayoven::Toplevel.main }
        # TeX message cannot be captured, because it's another shell-out to clay
        msg_not_found(%w[GIT CLAY YARN XML], out)
      end
    end
  end

  def test_noinit
    Dir.mktmpdir do |dir|
      Dir.chdir dir do
        fork { Clayoven::Toplevel.main }
        Process.waitall
        assert_equal $?.success?, false, 'clayoven did not abort with non-zero exit status'
      end
    end
  end

  def test_no_body
    Dir.mktmpdir do |dir|
      Clayoven::Init.init dir
      Dir.chdir dir do
        File.open('no_body.index.clay', 'w') { |io| io.write 'heading\n' }
        Clayoven::Toplevel.main
        assert_path_exists 'no_body.html', 'no_body.html was not generated'
      end
    end
  end

  def test_stray_file
    Dir.mktmpdir do |dir|
      Clayoven::Init.init dir
      Dir.chdir dir do
        File.open('foo.clay', 'w') { |io| io.write 'bar\n' }
        _, err = capture_io { Clayoven::Toplevel.main }
        assert_match 'foo.clay is a stray file or directory; ignored', err,
                     "stderr did not contain warning about stray files: #{err}"
      end
    end
  end

  def test_httpd
    Dir.mktmpdir do |dir|
      Clayoven::Init.init dir
      Dir.chdir dir do
        pid = fork { Clayoven::Httpd.start }
        sleep 1
        out, = capture_subprocess_io { system 'curl http://localhost:8000/index.html' }
        Process.kill 'INT', pid
        Process.waitall
        assert_match 'Enjoy using clayoven!', out, "generated html did not match: #{out}"
      end
    end
  end
end
