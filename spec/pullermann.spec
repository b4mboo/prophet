$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'pullermann'

describe Pullermann do

  before :each do
    @pullermann = Pullermann.new
    @pullermann.log_level = Logger::FATAL
    # Variables to use inside the tests.
    @request_id = 42
    @project = 'user/project'
    @pullermann.prepare_block= lambda { }
    @pullermann.test_block = lambda { }
    # Stub external dependency @gitconfig (local file).
    @pullermann.stub(:git_config).and_return(
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

  it 'loops through all open pull requests' do
    pull_requests = mock 'pull requests'
    @github.should_receive(:pulls).with(@project, 'open').and_return(pull_requests)
    pull_requests.should_receive(:size).and_return(0)
    pull_requests.should_receive(:each)
    @pullermann.run
  end

  it 'checks existing comments to determine whether a test run is necessary' do
    pull_request = mock 'pull request'
    pull_request.should_receive(:title).and_return('mock request')
    pull_request.should_receive(:mergeable).and_return(true)
    @github.stub(:pulls).and_return([{'number' => @request_id}])
    @github.should_receive(:pull_request).with(@project, @request_id).and_return(pull_request)
    # See if we're actually querying for issue comments.
    @github.should_receive(:issue_comments).with(@project, @request_id).and_return([])
    @github.stub_chain(:commits, :first, :sha).and_return('master sha')
    pull_request.stub_chain(:head, :sha)
    # Skip the rest, as we test this in other tests.
    @pullermann.stub(:switch_branch_to_merged_state)
    @pullermann.stub(:switch_branch_back)
    @pullermann.stub(:comment_on_github)
    @pullermann.run
  end

  it 'runs the tests on the merged code' do
    @pullermann.should_receive(:pull_requests).and_return([{'number' => @request_id}])
    @pullermann.should_receive(:test_run_necessary?).and_return(true)
    @pullermann.stub(:abort)
    @pullermann.should_receive(:'`').with("git fetch origin refs/pull/#{@request_id}/merge: &> /dev/null")
    @pullermann.should_receive(:'`').with('git checkout FETCH_HEAD &> /dev/null')
    @pullermann.should_receive(:'`').with('git co master &> /dev/null')
    @pullermann.stub(:comment_on_github)
    @pullermann.run
  end

  it 'runs the tests when either source or target branch have changed' do
    @pullermann.should_receive(:pull_requests).and_return([{'number' => @request_id}])
    pull_request = mock 'pull request'
    @github.should_receive(:pull_request).with(@project, @request_id).and_return(pull_request)
    pull_request.should_receive(:title).and_return('mock request')
    pull_request.should_receive(:mergeable).and_return(true)
    comment = mock 'comment'
    @github.should_receive(:issue_comments).with(@project, @request_id).and_return([comment])
    # Ensure that we take a look at the comment and compare shas.
    comment.stub_chain(:user, :login).and_return('default_login')
    @github.stub_chain(:commits, :first, :sha).and_return('master sha')
    pull_request.stub_chain(:head, :sha)
    comment.should_receive(:body).and_return('old_sha')
    @pullermann.should_receive(:rerun_on_source_change)
    @pullermann.should_receive(:rerun_on_target_change)
    @pullermann.should_receive(:switch_branch_to_merged_state)
    @pullermann.should_receive(:switch_branch_back)
    @pullermann.should_receive(:comment_on_github)
    @pullermann.run
  end

  it 'posts comments to GitHub' do
    @pullermann.should_receive(:pull_requests).and_return([{'number' => @request_id}])
    @pullermann.should_receive(:test_run_necessary?).and_return(true)
    @pullermann.should_receive(:switch_branch_to_merged_state)
    @pullermann.should_receive(:switch_branch_back)
    @github.should_receive(:add_comment)
    @pullermann.run
  end

  it 'uses two different users for commenting (success/failure)' do
    config_block = lambda do |config|
      config.username = 'username'
      config.username_fail = 'username_fail'
    end
    config_block.call @pullermann
    @pullermann.should_receive(:pull_requests).and_return([{'number' => @request_id}])
    @pullermann.should_receive(:test_run_necessary?).and_return(true)
    @pullermann.should_receive(:switch_branch_to_merged_state)
    @pullermann.should_receive(:switch_branch_back)
    @pullermann.instance_variable_set(:@test_success, false)
    @pullermann.should_receive(:connect_to_github).exactly(2).times.and_return(@github)
    @github.should_receive(:add_comment)
    @pullermann.run
  end

  it 'updates existing comments to reduce noise' do
    @pullermann.should_receive(:pull_requests).and_return([{'number' => @request_id}])
    @pullermann.should_receive(:test_run_necessary?).and_return(true)
    @pullermann.should_receive(:switch_branch_to_merged_state)
    @pullermann.should_receive(:switch_branch_back)
    @pullermann.instance_variable_set(:@test_success, true)
    comment = mock 'comment'
    @pullermann.instance_variable_set(:@comment, comment)
    comment.should_receive(:[])
    @pullermann.should_receive(:old_comment_success?).and_return(true)
    @github.should_receive(:update_comment)
    @pullermann.run
  end

  it 'deletes obsolete comments whenever the result changes' do
    @pullermann.should_receive(:pull_requests).and_return([{'number' => @request_id}])
    @pullermann.should_receive(:test_run_necessary?).and_return(true)
    @pullermann.should_receive(:switch_branch_to_merged_state)
    @pullermann.should_receive(:switch_branch_back)
    @pullermann.instance_variable_set(:@test_success, false)
    comment = mock 'comment'
    @pullermann.instance_variable_set(:@comment, comment)
    comment.should_receive(:[])
    @pullermann.should_receive(:old_comment_success?).and_return(true)
    @github.should_receive(:delete_comment)
    @github.should_receive(:add_comment)
    @pullermann.run
  end

  it 'deletes old comment whenever the pull is not mergeable' do
    pull_request = mock 'pull request'
    pull_request.should_receive(:title).and_return('mock request')
    pull_request.should_receive(:mergeable).and_return(false)
    @github.should_receive(:pull_request).with(@project, @request_id).and_return(pull_request)
    @pullermann.should_receive(:pull_requests).and_return([{'number' => @request_id}])
    @pullermann.instance_variable_set(:@test_success, false)
    comment = mock 'comment'
    @pullermann.instance_variable_set(:@comment, comment)
    comment.should_receive(:[])
    @pullermann.should_receive(:old_comment_success?).and_return(true)
    @github.should_receive(:delete_comment)
    @pullermann.run
  end

  it 'deletes obsolete comments whenever the request is no longer mergeable' do
    @pullermann.should_receive(:pull_requests).and_return([{'number' => @request_id}])
    pull_request = mock 'pull request'
    @github.should_receive(:pull_request).with(@project, @request_id).and_return(pull_request)
    pull_request.should_receive(:title).and_return('mock request')
    pull_request.should_receive(:mergeable).and_return(false)
    comment = mock 'comment'
    @github.should_receive(:issue_comments).with(@project, @request_id).and_return([comment])
    # Ensure that we take a look at the comment and compare shas.
    comment.stub_chain(:user, :login).and_return('default_login')
    @github.stub_chain(:commits, :first, :sha).and_return('foo')
    pull_request.stub_chain(:head, :sha).and_return('bar')
    comment.should_receive(:body).twice.and_return('Well done! ( master sha# foo ; pull sha# bar )')
    comment_id = 23
    comment.should_receive(:id).and_return(comment_id)
    @github.should_receive(:delete_comment).with(@project, comment_id)
    @pullermann.should_receive(:rerun_on_source_change).once
    @pullermann.should_not_receive(:rerun_on_target_change).once
    @pullermann.should_not_receive(:switch_branch_to_merged_state)
    @pullermann.should_not_receive(:switch_branch_back)
    @pullermann.should_not_receive(:comment_on_github)
    @pullermann.run
  end

  it 'populates configuration variables with default values' do
    @github.should_receive(:pulls).with(@project, 'open').and_return([])
    @pullermann.run
    @pullermann.username.should == 'default_login'
    @pullermann.password.should == 'default_password'
    @pullermann.username_fail.should == 'default_login'
    @pullermann.password_fail.should == 'default_password'
    @pullermann.rerun_on_source_change.should == true
    @pullermann.rerun_on_target_change.should == true
  end

  it 'respects configuration values if set manually' do
    config_block = lambda do |config|
      config.username = 'username'
      config.password = 'password'
      config.username_fail = 'username_fail'
      config.password_fail = 'password_fail'
      config.rerun_on_source_change = false
      config.rerun_on_target_change = false
    end
    config_block.call @pullermann
    @pullermann.username.should == 'username'
    @pullermann.password.should == 'password'
    @pullermann.username_fail.should == 'username_fail'
    @pullermann.password_fail.should == 'password_fail'
    @pullermann.rerun_on_source_change.should == false
    @pullermann.rerun_on_target_change.should == false
  end

  it 'allows custom commands for test preparation' do
    config_block = lambda do |config|
      config.test_preparation { raise 'test preparation' }
    end
    config_block.call @pullermann
    lambda { @pullermann.prepare_block.call }.should raise_error 'test preparation'
  end

  it 'allows custom commands for test execution' do
    config_block = lambda do |config|
      config.test_preparation { raise 'test execution' }
    end
    config_block.call @pullermann
    lambda { @pullermann.prepare_block.call }.should raise_error 'test execution'
  end

end
