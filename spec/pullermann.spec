$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'pullermann'

describe Pullermann, 'in general' do

  before :each do
    # Variables to use inside the tests.
    @project = 'user/project'
    # Stub external dependency @gitconfig (local file).
    Pullermann.stub(:git_config).and_return(
      'github.login' => 'default_login',
      'github.password' => 'default_password',
      'remote.origin.url' => 'git@github.com:user/project.git'
    )
    # Stub external dependency @github (remote server).
    @github = mock 'GitHub'
    Octokit::Client.stub(:new).and_return(@github)
    @github.should_receive(:login)
    @github.should_receive(:api_version)
    @github.should_receive(:repo).with(@project)
    @github.should_receive(:pulls).with(@project, 'open').and_return([])
  end

  after(:each) do
    # Empty all variables on Pullermann after each test.
    # Since we're not working with instances, this hack is necessary.
    Pullermann.instance_variables.each do |variable|
      Pullermann.instance_variable_set variable, nil
    end
  end

  it 'loops through all open pull requests' do
    Pullermann.run
  end

  it 'checks existing comments to determine the last test run'

  it 'runs the tests when either source or target branch have changed'

  it 'posts comments to GitHub'

  it 'uses two different users for commenting (success/failure)'

  it 'allows for configuration by the user'

  it 'uses sane fall back values'

end
