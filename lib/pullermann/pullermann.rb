class Pullermann

  class << self

    attr_accessor :username,
                  :password,
                  :username_fail,
                  :password_fail,
                  :project


    # Take configuration from Rails application's initializer.
    def setup
      yield self
    end

    def run
      # Loop through all 'open' pull requests.
      pull_requests["pulls"].each do |request|
        @request_id = request["number"]
        # Jump to next iteration if source and/or target haven't change since last run.
        next unless testrun_neccessary?
        fetch
        prepare
        run_tests
        comment
      end
    end


    private

    def pull_requests
      # FIXME: Use Octokit to access GitHub.
      JSON.parse(open("https://github.com/api/v2/json/pulls/#{Pullermann.project}",
                             :http_basic_authentication=>[Pullermann.username, Pullermann.password]).read)
    end

    # Determine whether source and/or target haven't change since last run.
    def testrun_neccessary?
      # TODO: Parse comments (looking for comments by 'username' or 'username_fail').
      # TODO: Respect configuration options when determining whether to run again or not.
    end

    # Fetch the merge-commit for the pull request.
    def fetch
      # NOTE: This commit automatically created by 'GitHub Merge Button'.
      begin
        Cheetah.run("git", "fetch", "origin", "refs/pull/#{@request_id}/merge:")
        Cheetah.run("git", "checkout", "FETCH_HEAD")
      rescue Cheetah::ExecutionFailed => e
        puts "Could not run git #{e.message}"
        puts "Standard output: #{e.stdout}"
        puts "Error output:    #{e.stderr}"
      end
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
      main_task = "rake test:all"
      @result = system(main_task)

    end

    # Output the result to a comment on the pull request on GitHub.
    def comment
      if @result
        `curl -d '{ "body": "Well done! All tests are still passing after merging this pull request." }' -u "#{Pullermann.username}:#{Pullermann.password}" -X POST https://api.github.com/repos/#{Pullermann.project}/issues/#{@request_id}/comments;`
      else
        `curl -d '{ "body": "Unfortunately your tests are failing after merging this pull request." }' -u "#{Pullermann.username_fail}:#{Pullermann.password_fail}" -X POST https://api.github.com/repos/#{Pullermann.project}/issues/#{@request_id}/comments;`
      end
    end

  end

end
