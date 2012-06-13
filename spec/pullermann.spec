$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'pullermann'

describe Pullermann do

  before :each do
    Pullermann.log_level = Logger::WARN
    # Variables to use inside the tests.
    @project = 'user/project'
    Pullermann.prepare_block= lambda{}
    Pullermann.test_block = lambda{}
    # Stub external dependency @gitconfig (local file).
    Pullermann.stub(:git_config).and_return(
      'github.login' => 'default_login',
      'github.password' => 'default_password',
      'remote.origin.url' => 'git@github.com:user/project.git'
    )
    # Stub external dependency @github (remote server).
    @github = mock 'GitHub'
    Octokit::Client.stub(:new).and_return(@github)
    @github.stub(:login)
    @github.stub(:api_version).and_return('3')
    @github.stub(:repo).with(@project)
  end

  after :each do
    # Empty all variables on Pullermann after each test.
    # Since we're not working with instances, this hack is necessary.
    Pullermann.instance_variables.each do |variable|
      Pullermann.instance_variable_set variable, nil
    end
  end

  it 'configures variables by default' do
    @github.should_receive(:pulls).with(@project, 'open').and_return([])
    Pullermann.run
    Pullermann.username.should == "default_login"
    Pullermann.password.should == "default_password"
    Pullermann.username_fail.should == "default_login"
    Pullermann.password_fail.should == "default_password"
    Pullermann.rerun_on_source_change.should == true
    Pullermann.rerun_on_target_change.should == true
  end

  it 'configures prepare block' do
    @github.should_receive(:pulls).with(@project, 'open').and_return([])
    Pullermann.setup do |config|
      config.test_preparation do 
        raise "test preparation"
      end
    end
    Pullermann.run
    lambda{Pullermann.prepare_block.call}.should raise_error String "test preparation"
    
  end

  it 'configures execution block' do
    @github.should_receive(:pulls).with(@project, 'open').and_return([])
    Pullermann.setup do |config|
      config.test_preparation do 
        raise "test execution"
      end
    end
    Pullermann.run
    lambda{Pullermann.prepare_block.call}.should raise_error String "test execution"
    
  end

  it 'loops through all open pull requests' do
    @github.should_receive(:pulls).with(@project, 'open').and_return([])
    Pullermann.run
  end

  it 'checks existing comments to determine the last test run' do
    pull_request = mock 'pull request'
    request_id = 42
    pull_request.should_receive(:title).and_return('mock request')
    pull_request.should_receive(:mergeable).and_return(true)
    @github.stub(:pulls).and_return([{'number' => request_id}])
    @github.should_receive(:pull_request).with(@project, request_id).and_return(pull_request)
    # See if we're actually querying for issue comments.
    @github.should_receive(:issue_comments).with(@project, request_id).and_return([])
    # Skip the rest, as we will test this in other tests.
    Pullermann.stub(:switch_branch_to_merged_state)
    Pullermann.stub(:switch_branch_back)
    Pullermann.stub(:comment_on_github)
    Pullermann.run
  end

  it 'runs the tests when either source or target branch have changed'

  it 'posts comments to GitHub'

  it 'uses two different users for commenting (success/failure)'

  it 'updates existing comments to reduce noise'

  it 'deletes obsolete comments whenever the result changes'

  it 'configures variables correctly' do
    @github.should_receive(:pulls).with(@project, 'open').and_return([])
    Pullermann.setup do |configure|
      configure.username = "username"
      configure.password = "password"
      configure.username_fail = "username_fail"
      configure.password_fail = "password_fail"
      configure.rerun_on_source_change = false
      configure.rerun_on_target_change = false
    end
    Pullermann.username.should == "username"
    Pullermann.password.should == "password"
    Pullermann.username_fail.should == "username_fail"
    Pullermann.password_fail.should == "password_fail"
    Pullermann.rerun_on_source_change.should == false
    Pullermann.rerun_on_target_change.should == false
    Pullermann.run
  end


end
