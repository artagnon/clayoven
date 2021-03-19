require 'rake/testtask'
require 'fileutils'
require 'tmpdir'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/init.rb', 'test/production.rb']
end

task :cpdist do
  dest = File.join(__dir__, *%w[dist])
  Dir.mktmpdir do |tmpdir|
    Dir.chdir(tmpdir) do
      `git clone --depth 1 https://github.com/artagnon/artagnon.com src`
      FileUtils.cp('src/scratch.index.clay', dest)
      FileUtils.cp('src/.htaccess', dest)
      FileUtils.cp('src/package.json', dest)
      FileUtils.cp_r('src/lib/.', "#{dest}/lib")
    end
  end
end

task default: :test
