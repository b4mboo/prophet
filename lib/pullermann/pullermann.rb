class Pullermann

  attr_accessor :username,
                :password,
                :username_fail,
                :password_fail,
                :rerun_on_source_change,
                :rerun_on_target_change,
                :prepare_block,
                :test_block,
                :log_level

  # Allow configuration blocks being passed to Pullermann.
  def self.setup
    yield main_instance
  end

  def test_preparation(&block)
    self.prepare_block = block
  end

  def test_execution(&block)
    self.test_block = block
  end

  # The main Pullermann task. Call this to start testing.
  def self.run
    main_instance.run
  end

  def run
    # Populate variables and setup environment.
    configure
    # Loop through all 'open' pull requests.
    pull_requests.each do |request|
      @request_id = request['number']
      # Jump to next iteration if source and/or target haven't change since last run.
      next unless test_run_necessary?
      # GitHub always creates a merge commit for its 'Merge Button'.
      switch_branch_to_merged_state
      # Prepare project and CI (e.g. Jenkins) for the test run.
      self.prepare_block.call
      # Run specified tests for the project.
      # NOTE: Either ensure the last call in that block runs your tests
      # or manually set @result to a boolean inside this block.
      self.test_block.call
      # Unless already set, the success/failure is determined by the last
      # command's return code.
      @result ||= $? == 0
      # We need to switch back to the original branch in case we need to test
      # more pull requests.
      switch_branch_back
      comment_on_github
    end
  end


  private

  # Remember the one instance we setup in our application and want to run.
  def self.main_instance
    @main_instance ||= Pullermann.new
  end

  def configure
    @log = Logger.new(STDOUT)
    @log.level = self.log_level || Logger::INFO
    # Set default fall back values for options that aren't set.
    self.username ||= git_config['github.login']
    self.password ||= git_config['github.password']
    self.username_fail ||= self.username
    self.password_fail ||= self.password
    self.rerun_on_source_change = true unless self.rerun_on_source_change == false
    self.rerun_on_target_change = true unless self.rerun_on_target_change == false
    # Find environment (project, tasks, connection, ...).
    set_project
    @prepare_block ||= lambda {}
    @test_block ||= lambda { `rake test` }
    connect_to_github
  end

  def connect_to_github
    @github = Octokit::Client.new(:login => self.username, :password => self.password)
    begin
      @github.login
      @log.info "Successfully logged into github (api v#{@github.api_version}) with user #{self.username}"
      @github.repo @project
    rescue Octokit::Unauthorized => e
      abort "Unable to login to github project with user #{self.username}: #{e.message}"
    end
  end

  def set_project
    remote = git_config['remote.origin.url']
    @project = /:(.*)\.git/.match(remote)[1]
    @log.info "Using github project: #{@project}"
  end

  def pull_requests
    pulls = @github.pulls @project, 'open'
    @log.info "Found #{pulls.size} pull requests in #{@project}.."
    pulls
  end

  # Test runs are necessary if:
  # - the pull request hasn't been tested before.
  # - the pull request has been updated since the last run.
  # - the target (i.e. master) has been updated since the last run.
  def test_run_necessary?
    pull = @github.pull_request @project, @request_id
    @log.info "Checking pull request ##{@request_id}: #{pull.title}"

    unless pull.mergeable
      @log.info 'Pull request not auto-mergeable, skipping... '
      return false
    end

    # get git sha ids of master and branch state during last testrun

    comments = @github.issue_comments(@project, @request_id)
    comments = comments.select{ |c| [username, username_fail].include?(c.user.login) }.reverse

    if comments.empty?
      @log.info "New pull request detected, testrun needed"
      return true
    else
      @master_head_sha ||= @github.commits(@project).first.sha
      @pull_head_sha = pull.head.sha

      shas = nil
      comments.each do |comment|
        shas = /master sha# ([\w]+) ; pull sha# ([\w]+)/.match(comment.body)
        break if shas && shas[1] && shas[2]
      end

      if shas && shas[1] && shas[2]
        @log.info "Last testrun master sha: #{shas[1]}, pull sha: #{shas[2]}"
        @log.info "Current master sha: #{@master_head_sha}, pull sha: #{@pull_head_sha}"
        if self.rerun_on_source_change && (shas[2] != @pull_head_sha)
          @log.info "Re-running test due to new commit in pull request"
          return true
        elsif self.rerun_on_target_change && (shas[1] != @master_head_sha)
          @log.info "Re-running test due to new commit in master"
          return true
        end
      else
        @log.info "New pull request detected, testrun needed"
        return true
      end
    end
    false
  end


  def switch_branch_to_merged_state
    # Fetch the merge-commit for the pull request.
    # NOTE: This commit is automatically created by 'GitHub Merge Button'.
    `git fetch origin refs/pull/#{@request_id}/merge: &> /dev/null`
    `git checkout FETCH_HEAD &> /dev/null`
    abort("Error: Unable to switch to merge branch") unless ($? == 0)
  end

  def switch_branch_back
    # FIXME: For branches other than master, remember the original branch.
    @log.info "Switching back to master branch"
    `git co master &> /dev/null`
  end

  # Output the result to a comment on the pull request on GitHub.
  def comment_on_github
    sha_string = "\n( master sha# #{@master_head_sha} ; pull sha# #{@pull_head_sha} )"
    if @result
      client = Octokit::Client.new(:login => self.username, :password => self.password)
      client.add_comment(@project, @request_id,
                         "Well done! All tests are still passing after merging this pull request. #{sha_string}")
    else
      client = Octokit::Client.new(:login => self.username_fail, :password => self.password_fail)
      client.add_comment(@project, @request_id,
                         "Unfortunately your tests are failing after merging this pull request. #{sha_string}")
    end
  end

  # Collect git config information in a Hash for easy access.
  # Checks '~/.gitconfig' for credentials.
  def git_config
    unless @git_config
      # Read @git_config from local git config.
      @git_config = {}
      `git config --list`.split("\n").each do |line|
        key, value = line.split('=')
        @git_config[key] = value
      end
    end
    @git_config
  end

end
