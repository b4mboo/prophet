desc 'Test open pull requests'
task :pullermann => :environment do
  Pullermann.run
end
