$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'pullermann'

describe Pullermann, 'in general' do

  before(:each) do
    @github = mock('GitHub')
    Octokit::Client.stub!(:new).and_return(@github)
  end

  it 'loops through all open pull requests'

  it 'checks existing comments to determine the last test run'

  it 'runs the tests when either source or target branch have changed'

  it 'posts comments to GitHub'

  it 'uses two different users for commenting (success/failure)'

  it 'allows for configuration by the user'

  it 'uses sane fall back values'

end
