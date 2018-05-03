require 'English'
require 'open3'

class Prophet

  attr_accessor :username,
                :password,
                :username_fail,
                :password_fail,
                :rerun_on_source_change,
                :rerun_on_target_change,
                :prepare_block,
                :exec_block,
                :logger,
                :success,
                :status_pending,
                :status_failure,
                :status_success,
                :comment_failure,
                :comment_success,
                :disable_comments,
                :reuse_comments,
                :status_context,
                :status_target_url

  # Allow configuration blocks being passed to Prophet.
  # See the README.md for examples on how to call this method.
  def self.setup
    yield main_instance
  end

  def preparation(&block)
    self.prepare_block = block
  end

  def execution(&block)
    self.exec_block = block
  end

  # The main Prophet task. Call this to run your code.
  def self.run
    main_instance.run
  end

  def run
    # Populate variables and setup environment.
    configure
    begin
      self.prepare_block.call
    rescue Exception => e
      logger.error "Preparation block raised an exception: #{e}"
    end
    # Loop through all 'open' pull requests.
    selected_requests = pull_requests.select do |request|
      @request = request
      # Jump to next iteration if source and/or target didn't change since last run.
      next unless run_necessary?
      set_status_on_github
      remove_comment unless self.reuse_comments
      true
    end

    # Run code on all selected requests.
    selected_requests.each do |request|
      @request = request
      logger.info "Running for request ##{@request.id}."
      # GitHub always creates a merge commit for its 'Merge Button'.
      # Prophet reuses that commit to run the code on it.
      if switch_branch_to_merged_state
        # Run specified code (i.e. tests) for the project.
        begin
          self.exec_block.call
          # Unless self.success has already been set (to true/false) manually,
          # the success/failure is determined by the last command's return code.
          self.success = ($CHILD_STATUS && $CHILD_STATUS.exitstatus == 0) if self.success.nil?
        rescue Exception => e
          logger.error "Execution block raised an exception: #{e}"
          self.success = false
        end
        switch_branch_back
        comment_on_github
        set_status_on_github
      end
      self.success = nil
    end
  end

  def logger
    @logger ||= Logger.new(STDOUT).tap do |log|
      log.level = Logger::INFO
    end
  end


  private

  # Remember the one instance we setup in our application and want to run.
  def self.main_instance
    @main_instance ||= Prophet.new
  end

  def configure
    # Set default fall back values for options that aren't set.
    self.username ||= git_config['github.login']
    self.password ||= git_config['github.password']
    self.username_fail ||= self.username
    self.password_fail ||= self.password
    self.rerun_on_source_change = true if self.rerun_on_source_change.nil?
    self.rerun_on_target_change = true if self.rerun_on_target_change.nil?
    self.reuse_comments = false if self.reuse_comments.nil?
    self.disable_comments = false if self.disable_comments.nil?
    # Allow for custom messages.
    self.status_pending ||= 'Prophet is still running.'
    self.status_failure ||= 'Prophet reports failure.'
    self.status_success ||= 'Prophet reports success.'
    self.comment_failure ||= 'Prophet reports failure.'
    self.comment_success ||= 'Prophet reports success.'
    self.status_context ||= 'prophet/default'
    # Find environment (tasks, project, ...).
    self.prepare_block ||= lambda {}
    self.exec_block ||= lambda { `rake` }
    @github = connect_to_github
    @github_fail = if self.username == self.username_fail
      @github
    else
      connect_to_github self.username_fail, self.password_fail
    end
  end

  def connect_to_github(user = self.username, pass = self.password)
    github = Octokit::Client.new(
      :login => user,
      :password => pass
    )
    # Check user login to GitHub.
    github.login
    logger.info "Successfully logged into GitHub with user '#{user}'."
    # Ensure the user has access to desired project.
    # NOTE: All three variants should work:
    # 'ssh://git@github.com:user/project.git'
    # 'git@github.com:user/project.git'
    # 'https://github.com/user/project.git'
    @project ||= /github\.com[\/:](.*)\.git$/.match(git_config['remote.origin.url'])[1]
    begin
      github.repo @project
      logger.info "Successfully accessed GitHub project '#{@project}'"
      github
    rescue Octokit::Unauthorized => e
      logger.error "Unable to access GitHub project with user '#{user}':\n#{e.message}"
      abort
    end
  end

  def pull_requests
    request_list = @github.pulls @project, state: 'open'
    requests = request_list.collect do |request|
      PullRequest.new(@github.pull_request @project, request.number)
    end
    logger.info "Found #{requests.size > 0 ? requests.size : 'no'} open pull requests in '#{@project}'."
    requests
  end

  # (Re-)runs are necessary if:
  # - the pull request hasn't been used for a run before.
  # - the pull request has been updated since the last run.
  # - the target (i.e. master) has been updated since the last run.
  # - the pull request does not originate from a fork (to avoid malicious code execution on CI machines)
  def run_necessary?
    logger.info "Checking pull request ##{@request.id}: #{@request.content.title}"
    unless @request.from_fork
      # Compare current sha ids of target and source branch with those from the last test run.
      @request.target_head_sha = @github.commits(@project).first.sha
      comments = @github.issue_comments(@project, @request.id)
      comments = comments.select { |c| [username, username_fail].include?(c.user.login) }.reverse
      comments.each do |comment|
        @request.comment = comment if /Merged ([\w]+) into ([\w]+)/.match(comment.body)
      end

      statuses = @github.status(@project, @request.head_sha).statuses.select { |s| s.context == self.status_context }
      # Only run if it's mergeable.
      if @request.content.mergeable
        if statuses.empty?
          # If there is no status yet, it has to be a new request.
          logger.info 'New pull request detected, run needed.'
          return true
        elsif !self.disable_comments && !@request.comment
          logger.info 'Rerun forced.'
          return true
        end
      else
        # Sometimes GitHub doesn't have a proper boolean value stored.
        if @request.content.mergeable.nil? && switch_branch_to_merged_state
          # Pull request is mergeable after all.
          switch_branch_back
        else
          logger.info 'Pull request not auto-mergeable. Not running.'
          if @request.comment
            logger.info 'Deleting existing comment.'
            call_github(old_comment_success?).delete_comment(@project, @request.comment.id)
          end
          create_status(:error, "Pull request not auto-mergeable. Not running.") if statuses.first.state != 'error'
          return false
        end
      end

      # Initialize shas to ensure it will live on after the 'each' block.
      shas = nil
      statuses.each do |status|
        shas = /Merged ([\w]+) into ([\w]+)/.match(status.description)
        break if shas && shas[1] && shas[2]
      end

      if shas
        logger.info "Current target sha: '#{@request.target_head_sha}', pull sha: '#{@request.head_sha}'."
        logger.info "Last test run target sha: '#{shas[2]}', pull sha: '#{shas[1]}'."
        if self.rerun_on_source_change && (shas[1] != @request.head_sha)
          logger.info 'Re-running due to new commit in pull request.'
          return true
        elsif self.rerun_on_target_change && (shas[2] != @request.target_head_sha)
          logger.info 'Re-running due to new commit in target branch.'
           return true
        end
      else
        # If there are no SHAs yet, it has to be a new request.
        logger.info 'New pull request detected, run needed.'
        return true
      end
    end

    logger.info "Pull request comes from a fork." if @request.from_fork
    logger.info "Not running for request ##{@request.id}."
    false
  end

  def switch_branch_to_merged_state
    # Fetch the merge-commit for the pull request.
    # NOTE: This commit is automatically created by 'GitHub Merge Button'.
    # FIXME: Use cheetah to pipe to logger.debug instead of that /dev/null hack.
    `git fetch origin refs/pull/#{@request.id}/merge: &> /dev/null`
    _output, status = Open3.capture2 'git checkout FETCH_HEAD &> /dev/null'
    if status != 0
      logger.error 'Unable to switch to merge branch.'
      return false
    end
    true
  end

  def switch_branch_back
    # FIXME: Use cheetah to pipe to logger.debug instead of that /dev/null hack.
    logger.info 'Switching back to original branch.'
    # FIXME: For branches other than master, remember the original branch.
    `git checkout master &> /dev/null`
    # Clean up potential remains and run garbage collector.
    `git gc &> /dev/null`
  end

  def old_comment_success?
    return unless @request.comment
    # Analyze old comment to see whether it was a successful or a failing one.
    @request.comment.body.include? '( Success: '
  end

  def remove_comment
    if @request.comment
      # Remove old comment and reset variable.
      call_github(old_comment_success?).delete_comment(@project, @request.comment.id)
      @request.comment = nil
    end
  end

  def comment_on_github
    return if self.disable_comments

    # Determine comment message.
    message = if self.success
      logger.info 'Successful run.'
      self.comment_success
    else
      logger.info 'Failing run.'
      self.comment_failure
    end
    message += status_string
    if self.reuse_comments && old_comment_success? == self.success
      # Replace existing comment's body with the correct connection.
      logger.info "Updating existing #{notion(self.success)} comment."
      call_github(self.success).update_comment(@project, @request.comment.id, message)
    else
      if @request.comment
        logger.info "Deleting existing #{notion(!self.success)} comment."
        # Delete old comment with correct connection (if @request.comment exists).
        call_github(!self.success).delete_comment(@project, @request.comment.id)
      end
      # Create new comment with correct connection.
      logger.info "Adding new #{notion(self.success)} comment."
      call_github(self.success).add_comment(@project, @request.id, message)
    end
  end

  def status_string
    case self.success
      when true
        " (Merged #{@request.head_sha} into #{@request.target_head_sha})"
      when false
        " (Merged #{@request.head_sha} into #{@request.target_head_sha})"
      else
        ""
    end
  end

  def create_status(state, description)
    logger.info "Setting status '#{state}': '#{description}'"
    @github.create_status(
      @project,
      @request.head_sha,
      state,
      {
        "description" => description,
        "context" => status_context,
        "target_url" => self.status_target_url
      }
    )
  end

  def set_status_on_github
    logger.info 'Updating status on GitHub.'
    case self.success
    when true
      state_symbol = :success
      state_message = self.status_success
    when false
      state_symbol = :failure
      state_message = self.status_failure
    else
      state_symbol = :pending
      state_message = self.status_pending
    end
    create_status(state_symbol, state_message + status_string)
  end

  def notion(success)
    success ? 'positive' : 'negative'
  end

  # Determine which connection to GitHub should be used for the call.
  def call_github(use_default_user = true)
    use_default_user ? @github : @github_fail
  end

  # Collect git config information in a Hash for easy access.
  # Checks '~/.gitconfig' for credentials.
  def git_config
    unless @git_config
      @git_config = {}
      `git config --list`.split("\n").each do |line|
        key, value = line.split('=')
        @git_config[key] = value
      end
    end
    @git_config
  end

end
