require 'pullermann'
require 'rails'

class Railtie < Rails::Railtie
  rake_tasks do
    load 'tasks/pullermann.rake'
  end
end
