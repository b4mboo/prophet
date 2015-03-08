require 'prophet'
require 'rails'

class Railtie < Rails::Railtie
  rake_tasks do
    load 'tasks/prophet.rake'
  end
end
