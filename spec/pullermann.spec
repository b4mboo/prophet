$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'pullermann'

describe Pullermann, 'in general' do

  before :each do
    # Stub external dependencies @gitconfig (local file).
    Pullermann.stub(:git_config).and_return(
      'github.login' => 'default_login',
      'github.password' => 'default_password',
      'remote.origin.url' => 'git@github.com:user/project.git'
    )
    # Stub external dependencies @github (remote server).
    @github = mock 'GitHub'
    Octokit::Client.stub(:new).and_return(@github)
    # Variables to use inside the tests.
    @project = 'user/project'
  end

  describe 'for normal runs' do

    before :each do
      @github.should_receive(:login)
      @github.should_receive(:api_version)
      @github.should_receive(:repo).with(@project)
      @github.should_receive(:pulls).with(@project, 'open').and_return([])
      Pullermann.run
    end

    it 'loops through all open pull requests' do
    end

  end


  it 'checks existing comments to determine the last test run' do
    @github.should_receive(:login)
    @github.should_receive(:api_version)
    @github.should_receive(:repo).with(@project)
    @github.should_receive(:pulls).with(@project, 'open').and_return([])
    Pullermann.run
  end

  it 'runs the tests when either source or target branch have changed'

  it 'posts comments to GitHub'

  it 'uses two different users for commenting (success/failure)'

  it 'allows for configuration by the user'

  it 'uses sane fall back values'

end
