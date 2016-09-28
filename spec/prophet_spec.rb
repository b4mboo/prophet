$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'prophet'

describe Prophet do

  before :each do
    @prophet = Prophet.new
    @prophet.logger = Logger.new STDOUT
    @prophet.logger.level = Logger::FATAL
    # Variables to use inside the tests.
    @request_id = 42
    @api_response = double 'api response'
    @api_response.stub(:number).and_return(@request_id)
    @api_response.stub_chain(:head, :sha).and_return('pull_head_sha')
    @request = PullRequest.new @api_response
    @project = 'user/project'
    @prophet.prepare_block = lambda { }
    @prophet.exec_block = lambda { }
    # Stub external dependency @gitconfig (local file).
    @prophet.stub(:git_config).and_return(
      'github.login' => 'default_login',
      'github.password' => 'default_password',
      'remote.origin.url' => 'git@github.com:user/project.git'
    )
    # Stub external dependency @github (remote server).
    @github = double 'GitHub'
    Octokit::Client.stub(:new).and_return(@github)
    @github.stub :login
    @github.stub(:api_version).and_return('3')
    @github.stub(:repo).with(@project)
  end

  it 'loops through all open pull requests' do
    @github.should_receive(:pulls).with(@project, {state: "open"}).and_return([@api_response])
    @github.should_receive(:pull_request).with(@project, @api_response.number).and_return(@api_response)
    PullRequest.should_receive(:new).with(@api_response).and_return(@request)
    @prophet.stub :run_necessary?
    @prophet.run
  end

  it 'checks existing status to determine whether a new run is necessary' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @api_response.should_receive :title
    @api_response.should_receive(:mergeable).and_return(true)
    # See if we're actually querying for issue comments.
    @github.should_receive(:issue_comments).with(@project, @request_id).and_return([])
    statuses = double(statuses: [])
    @github.should_receive(:status).with(@project, @request.head_sha).and_return(statuses)
    @github.stub_chain(:commits, :first, :sha).and_return('master_sha')
    # Skip the rest, as we test this in other tests.
    @prophet.stub :switch_branch_to_merged_state
    @prophet.stub :switch_branch_back
    @prophet.stub :comment_on_github
    @prophet.stub :set_status_on_github
    @prophet.run
  end

  it 'runs your code on the merged branch' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.stub :abort
    @prophet.should_receive(:'`').with("git fetch origin refs/pull/#{@request_id}/merge: &> /dev/null")
    @prophet.should_receive(:'`').with('git checkout FETCH_HEAD &> /dev/null')
    @prophet.should_receive(:'`').with('git checkout master &> /dev/null')
    @prophet.should_receive(:'`').with('git gc &> /dev/null')
    @prophet.stub :comment_on_github
    @prophet.stub :set_status_on_github
    @prophet.run
  end

  it 'runs your code when either source or target branch have changed' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @api_response.should_receive :title
    @api_response.should_receive(:mergeable).and_return(true)
    comment = double 'comment'
    @github.should_receive(:issue_comments).with(@project, @request_id).and_return([comment])
    # Ensure that we take a look at the comment and compare shas.
    comment.stub_chain(:user, :login).and_return('default_login')

    statuses = double(
      statuses: [
        double(context: "prophet/default", description: 'Well done! (Merged old_sha into target_head_sha)')
      ]
    )
    @github.should_receive(:status).with(@project, @request.head_sha).and_return(statuses)

    @github.stub_chain(:commits, :first, :sha).and_return('master_sha')
    comment.should_receive(:body).and_return('old_sha')
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive :comment_on_github
    @prophet.should_receive(:set_status_on_github).twice
    @prophet.run
  end

  it 'sets the pull request\'s status on GitHub' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive :comment_on_github
    @prophet.should_receive(:set_status_on_github).twice
    @prophet.run
  end

  it 'sets statuses of all requests which need an execution to :pending' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @github.should_receive(:create_status).with(
      @project, @request.head_sha, :pending, {
        "description" => "Prophet is still running.",
        "context" => "prophet/default",
        "target_url" => nil
      }
    ).twice
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive :comment_on_github
    @prophet.run
  end

  it 'allows for custom messages for pending statuses' do
    @prophet.status_pending = 'custom pending'
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @github.should_receive(:create_status).with(
      @project, @request.head_sha, :pending, {
        "description" => "custom pending",
        "context" => "prophet/default",
        "target_url" => nil
      }
    ).twice
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive :comment_on_github
    @prophet.run
  end

  it 'sets the status to :success if execution is successful' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive :comment_on_github
    @prophet.stub(:success).and_return(true)
    @github.should_receive(:create_status).with(
      @project, @request.head_sha, :success, {
        "description" => "Prophet reports success. (Merged pull_head_sha into )",
        "context" => "prophet/default",
        "target_url" => nil
      }
    ).twice
    @prophet.run
  end

  it 'allows for custom messages for successful statuses' do
    @prophet.status_success = 'custom success'
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive :comment_on_github
    @prophet.stub(:success).and_return(true)
    @github.should_receive(:create_status).with(
      @project, @request.head_sha, :success, {
        "description" => "custom success (Merged pull_head_sha into )",
        "context" => "prophet/default",
        "target_url" => nil
      }
    ).twice
    @prophet.run
  end

  it 'sets the status to :failure if execution is not successful' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive :comment_on_github
    @prophet.stub(:success).and_return(false)
    @github.should_receive(:create_status).with(
      @project, @request.head_sha, :failure, {
        "description" => "Prophet reports failure. (Merged pull_head_sha into )",
        "context" => "prophet/default",
        "target_url" => nil
      }
    ).twice
    @prophet.run
  end

  it 'allows for custom messages for failing statuses' do
    @prophet.status_failure = 'custom failure'
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive :comment_on_github
    @prophet.stub(:success).and_return(false)
    @github.should_receive(:create_status).with(
      @project, @request.head_sha, :failure, {
        "description" => "custom failure (Merged pull_head_sha into )",
        "context" => "prophet/default",
        "target_url" => nil
      }
    ).twice
    @prophet.run
  end

  it 'allows for setting status target URLs' do
    @prophet.status_target_url = 'http://example.com/details'
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive :comment_on_github
    @prophet.stub(:success).and_return(false)
    @github.should_receive(:create_status).with(
      @project, @request.head_sha, :failure, {
        "description" => "Prophet reports failure. (Merged pull_head_sha into )",
        "context" => "prophet/default",
        "target_url" => "http://example.com/details"
      }
    ).twice
    @prophet.run
  end

  it 'posts comments to GitHub' do
    @prophet.reuse_comments = false
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive(:set_status_on_github).twice
    @github.should_receive :add_comment
    @prophet.run
  end

  it 'does not post comments to GitHub if disble_comments = true' do
    @prophet.reuse_comments = false
    @prophet.disable_comments = true
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive(:set_status_on_github).twice
    @github.should_not_receive :add_comment
    @prophet.run
  end

  it 'uses two different users for commenting (success/failure)' do
    config_block = lambda do |config|
      config.username = 'username'
      config.username_fail = 'username_fail'
    end
    config_block.call @prophet
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive(:set_status_on_github).twice
    @prophet.stub(:success).and_return(false)
    @prophet.should_receive(:connect_to_github).twice.and_return(@github)
    @github.should_receive :add_comment
    @prophet.run
  end

  it 'allows to update existing comments to reduce noise' do
    @prophet.reuse_comments = true
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive(:set_status_on_github).twice
    @prophet.success = true
    @request.comment = double 'comment'
    @request.comment.should_receive :id
    @prophet.should_receive(:old_comment_success?).and_return(true)
    @github.should_receive :update_comment
    @prophet.run
  end

  it 'deletes obsolete comments whenever the result changes' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive(:set_status_on_github).twice
    @prophet.stub(:success).and_return(false)
    @request.comment = double 'comment'
    @request.comment.should_receive :id
    @prophet.should_receive(:old_comment_success?).and_return(true)
    @github.should_receive :delete_comment
    @github.should_receive :add_comment
    @prophet.run
  end

  it 'deletes obsolete comments if reuse is disabled' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.stub(:success).and_return(true)
    @prophet.should_receive(:set_status_on_github).twice
    @prophet.should_receive :remove_comment
    @request.comment = double 'comment'
    @request.comment.should_receive :id
    @github.should_receive :delete_comment
    @github.should_receive :add_comment
    @prophet.run
  end

  it 'deletes obsolete comments whenever the request is no longer mergeable' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @api_response.should_receive :title
    @api_response.should_receive(:mergeable).twice.and_return(false)
    @github.stub_chain(:commits, :first, :sha).and_return('target_head_sha')
    comment = double 'comment'
    @github.should_receive(:issue_comments).with(@project, @request_id).and_return([comment])
    # Ensure that we take a look at the comment and compare shas.
    comment.stub_chain(:user, :login).and_return('default_login')
    comment.should_receive(:body).twice.and_return('Well done! ( Merged head_sha into target_head_sha )')
    comment_id = 23
    comment.should_receive(:id).and_return(comment_id)
    statuses = double(
      statuses: [
        double(context: "prophet/default", description: 'Well done! (Merged head_sha into target_head_sha)', state: 'success')
      ]
    )
    @github.should_receive(:status).with(@project, @request.head_sha).and_return(statuses)

    @github.should_receive(:create_status).with(@project, @request.head_sha, :error, anything).and_return(statuses)
    @github.should_receive(:delete_comment).with(@project, comment_id)
    @prophet.should_not_receive :switch_branch_to_merged_state
    @prophet.should_not_receive :switch_branch_back
    @prophet.should_not_receive :comment_on_github
    @prophet.should_not_receive :set_status_on_github
    @prophet.run
  end

  it 'tries to determine whether the request is mergeable if GitHub won\'t tell' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @api_response.should_receive :title
    @api_response.should_receive(:mergeable).twice.and_return(nil)
    @github.stub_chain(:commits, :first, :sha).and_return('target_head_sha')
    comment = double 'comment'
    @github.should_receive(:issue_comments).with(@project, @request_id).and_return([comment])
    # Ensure that we take a look at the comment and compare shas.
    comment.stub_chain(:user, :login).and_return('default_login')
    comment.should_receive(:body).twice.and_return('Well done! ( Merged head_sha into target_head_sha )')
    comment_id = 23
    comment.should_receive(:id).and_return(comment_id)
    @github.should_receive(:delete_comment).with(@project, comment_id)
    statuses = double(
      statuses: [
        double(context: "prophet/default", description: 'Well done! (Merged head_sha into target_head_sha', state: 'success')
      ]
    )
    @github.should_receive(:status).with(@project, @request.head_sha).and_return(statuses)
    @github.should_receive(:create_status).with(@project, @request.head_sha, :error, anything).and_return(statuses)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_not_receive :switch_branch_back
    @prophet.should_not_receive :comment_on_github
    @prophet.should_not_receive :set_status_on_github
    @prophet.run
  end

  it 'allows for custom messages for successful comments' do
    @prophet.comment_success = 'custom success'
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive(:set_status_on_github).twice
    @prophet.stub(:success).and_return(true)
    @github.should_receive(:add_comment).with(@project, @request_id, include('custom success'))
    @prophet.run
  end

  it 'allows for custom messages for failing comments' do
    @prophet.comment_failure = 'custom failure'
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive(:set_status_on_github).twice
    @prophet.stub(:success).and_return(false)
    @github.should_receive(:add_comment).with(@project, @request_id, include('custom failure'))
    @prophet.run
  end

  it 'populates configuration variables with default values' do
    @github.should_receive(:pulls).with(@project, {state: "open"}).and_return([])
    @prophet.run
    @prophet.username.should == 'default_login'
    @prophet.password.should == 'default_password'
    @prophet.username_fail.should == 'default_login'
    @prophet.password_fail.should == 'default_password'
    @prophet.rerun_on_source_change.should be(true)
    @prophet.rerun_on_target_change.should be(true)
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
    config_block.call @prophet
    @prophet.username.should == 'username'
    @prophet.password.should == 'password'
    @prophet.username_fail.should == 'username_fail'
    @prophet.password_fail.should == 'password_fail'
    @prophet.rerun_on_source_change.should be(false)
    @prophet.rerun_on_target_change.should be(false)
  end

  it 'allows custom commands for preparation' do
    config_block = lambda do |config|
      config.preparation { raise 'preparation' }
    end
    config_block.call @prophet
    lambda { @prophet.prepare_block.call }.should raise_error 'preparation'
  end

  it 'catches exceptions thrown in preparation block' do
    @prophet.prepare_block = lambda { raise 'foo' }
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive(:set_status_on_github).twice
    @prophet.stub(:success).and_return(false)
    @github.should_receive(:add_comment).with(@project, @request_id, include('failure'))
    @prophet.logger.should_receive(:error).with(include('Preparation'))
    @prophet.run
  end

  it 'allows custom commands for execution' do
    config_block = lambda do |config|
      config.execution { raise 'execution' }
    end
    config_block.call @prophet
    lambda { @prophet.exec_block.call }.should raise_error 'execution'
  end

  it 'reports failure if your code raises an exception' do
    @prophet.exec_block = lambda { raise 'foo' }
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.should_receive :switch_branch_to_merged_state
    @prophet.should_receive :switch_branch_back
    @prophet.should_receive(:set_status_on_github).twice
    @github.should_receive(:add_comment).with(@project, @request_id, include('failure'))
    @prophet.logger.should_receive(:error).with(include('Execution'))
    @prophet.run
  end

  it 'resets the success flag after each iteration' do
    @prophet.should_receive(:pull_requests).and_return([@request])
    @prophet.should_receive(:run_necessary?).and_return(true)
    @prophet.stub :set_status_on_github
    @prophet.stub :switch_branch_to_merged_state
    @prophet.stub_chain(:exec_block, :call)
    @prophet.stub :switch_branch_back
    @prophet.stub :comment_on_github
    @prophet.success = true
    @prophet.run
    @prophet.success.should be_nil
  end

  it 'should read URL from .git/config even with protocol notation' do
    @prophet.stub(:git_config).and_return(
      'github.login' => 'default_login',
      'github.password' => 'default_password',
      'remote.origin.url' => 'ssh://git@github.com:user/project.git'
    )
    @github.should_receive(:pulls).with(@project, {state: "open"}).and_return([])
    @prophet.run
  end

  it 'should read https URLs from .git/config' do
    @prophet.stub(:git_config).and_return(
      'github.login' => 'default_login',
      'github.password' => 'default_password',
      'remote.origin.url' => 'https://github.com/user/project.git'
    )
    @github.should_receive(:pulls).with(@project, {state: "open"}).and_return([])
    @prophet.run
  end

end
