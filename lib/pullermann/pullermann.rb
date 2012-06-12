class Pullermann

  class << self

    attr_accessor :username,
                  :password,
                  :username_fail,
                  :password_fail,
                  :rerun_on_source_change,
                  :rerun_on_target_change


    # Set default values for options.
    def initialize
      self.username = git_config['github.login']
      self.password = git_config['github.password']
      self.username_fail = self.username
      self.password_fail = self.password
      self.rerun_on_source_change = true
      self.rerun_on_target_change = true
      @project = set_project
    end

    # Take configuration from Rails application's initializer.
    def setup
      yield self
    end

    def run
      @github = Octokit::Client.new(:login => self.username, :password => self.password)
      begin
        @github.repo @project
      rescue
        abort 'Unable to login to github.'
      end

      # Loop through all 'open' pull requests.
      pull_requests.each do |request|
        @request_id = request["number"]
        # Jump to next iteration if source and/or target haven't change since last run.
        next unless test_run_neccessary?(@request_id)
        fetch
        prepare
        # Determine if all tests pass.
        @result = run_tests
        comment_on_github
      end
    end


    private

    def set_project
      remote = git_config['remote.origin.url']
      @project = /:(.*)\.git/.match(remote)[1]
      puts "Using github project: #{@project}"
    end

    def pull_requests
      pulls = @github.pulls @project, 'open'
      pulls.select! { |p| p.mergeable }
      puts "Found #{pulls.size} auto-mergeable pull requests.."
      pulls
    end

    def test_run_neccessary? pull_id
      pull = @github.pull_request @project, pull_id

      # get git sha ids of master and branch state during last testrun

      comments = pull.discussion.select { |c| c.type == "IssueComment" &&
          [username, username_fail].include?(c.user.login)}.reverse

      if comments.empty?
        puts "New pull request detected, testrun needed"
        return true
      else
        # TODO: find a better way to get the master sha
        master_ref = `git log origin/master -n 1`
        master_ref = /commit (.+)/.match(master_ref)[1]
        pull_ref = pull.head.sha

        refs = nil
        comments.each do |comment|
          refs = /master ref#(.+); pull ref#(.+)/.match(comment.body)
          break if refs && refs[1] && refs[2]
        end

        if refs && refs[1] && refs[2]
          puts "Last testrun master ref: #{refs[1]}, pull ref: #{refs[2]}"
          puts "Current master ref: #{master_ref}, pull ref: #{pull_ref}"
          if self.rerun_on_source_change && (refs[2] != pull_ref)
            puts "Re-running test due to new commit in pull request"
            return true
          elsif self.rerun_on_target_change && (refs[1] != master_ref)
            puts "Re-running test due to new commit in master"
            return true
          end
        else
          puts "No git refs found in pullermann comments..."
        end
      end
      return false
    end


    # Fetch the merge-commit for the pull request.
    def fetch
      # NOTE: This commit automatically created by 'GitHub Merge Button'.
      cheetah_run "git fetch origin refs/pull/#{@request_id}/merge:"
      cheetah_run "git checkout FETCH_HEAD"
    end

    # Wrapper for Cheetah calls, that ensure always full output on any errors.
    def cheetah_run(command)
      @last_output = Cheetah.run command.split
      true
    rescue Cheetah::ExecutionFailed => e
      puts "Could not run #{command}:"
      puts e.message
      puts "Standard output: #{e.stdout}"
      puts "Error output:    #{e.stderr}"
      false
    end

    # Prepare project and CI (e.g. Jenkins) for the test run.
    def prepare
      # FIXME: Move this to configurable 'setup' block.
      # Setup project with latest code.
      `bundle install`
      `rake db:create`
      `rake db:migrate`

      # Setup jenkins.
      `rake -f /usr/lib/ruby/gems/1.9.1/gems/ci_reporter-1.7.0/stub.rake`
      `rake ci:setup:testunit`
    end

    # Run specified tests for the project.
    def run_tests
      # FIXME: Move to a configurable 'run' block.
      tests_to_run = "echo 'running tests ...'\nrake test:all;echo 'done'"
      tests_to_run = tests_to_run.split(%r{\n|;})
      tests_to_run.each do |task|
        return false unless cheetah_run(task)
      end
      true
    end

    # Output the result to a comment on the pull request on GitHub.
    def comment_on_github
      if @result
        `curl -d '{ "body": "Well done! All tests are still passing after merging this pull request." }' -u "#{self.username}:#{self.password}" -X POST https://api.github.com/repos/#{@project}/issues/#{@request_id}/comments;`
      else
        `curl -d '{ "body": "Unfortunately your tests are failing after merging this pull request." }' -u "#{self.username_fail}:#{self.password_fail}" -X POST https://api.github.com/repos/#{@project}/issues/#{@request_id}/comments;`
      end
    end


    # Collect git config information in a Hash for easy access.
    # Checks '~/.gitconfig' for credentials.
    def git_config
      unless @git_config
        # Read @git_config from local git config.
        @git_config = {}
        return [] unless cheetah_run 'git config --list'
        config_list = @last_output
        config_list.split("\n").each do |line|
          key, value = line.split('=')
          @git_config[key] = value
        end
      end
      @git_config
    end
  end

end
