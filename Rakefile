require 'rake/testtask'
require 'rdoc/task'
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
      FileUtils.cp_r('src/.vscode/.', "#{dest}/.vscode")
    end
  end
end

RDoc::Task.new :doc do |rdoc|
  rdoc.main = 'README.md'
  rdoc.title = 'clayoven documentation'
  rdoc.rdoc_files.include('README.md', 'LICENSE', 'lib/clayoven/*.rb')
  rdoc.options << '--all'
  rdoc.options << '--copy-files=assets'
end

task default: :test
