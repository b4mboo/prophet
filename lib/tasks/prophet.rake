desc 'Test open pull requests'
task :prophet => :environment do
  Prophet.run
end
