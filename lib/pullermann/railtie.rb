require 'pullermann'
require 'rails'

module Pullermann

  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/pullermann.rake'
    end
  end

end
