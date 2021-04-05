SimpleCov.start do
  enable_coverage :branch
  primary_coverage :branch
  add_filter %r{^/test/}
  enable_for_subprocesses true
  at_fork do |pid|
    start do
      command_name "#{command_name} (subprocess: #{pid})"
      print_error_status false
      formatter SimpleCov::Formatter::SimpleFormatter
      minimum_coverage 0
    end
  end
end
