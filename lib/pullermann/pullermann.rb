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
      # Loop through all 'open' pull requests.
      pull_requests.each do |request|
        @request_id = request["number"]
        # Jump to next iteration if source and/or target haven't change since last run.
        next unless test_run_neccessary?
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
      github = Octokit::Client.new(:login => username, :password => password)
      begin
        github.repo @project
      rescue
        abort 'Unable to login to github.'
      end
      pulls = github.pulls @project, 'open'
      puts "Found #{pulls.size} pull requests.."
      pulls
    end

    # Determine whether source and/or target haven't change since last run.
    def test_run_neccessary?
      # TODO: Parse comments (looking for comments by 'username' or 'username_fail').
      # TODO: Respect configuration options when determining whether to run again or not.
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
      puts  e.message
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
