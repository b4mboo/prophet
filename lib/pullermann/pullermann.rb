class Pullermann

  class << self
    attr_accessor :username, :username_fail, :password, :password_fail, :project
  end

  # Take configuration from Rails application's initializer.
  def self.setup
    yield self
  end

  def run
    # FIXME: Use Octokit to access GHitHub.
    data = JSON.parse(open("https://github.com/api/v2/json/pulls/#{Pullermann.project}",
                           :http_basic_authentication=>[Pullermann.username, Pullermann.password]).read)

    # Loop through all 'open' pull requests.
    data["pulls"].each do |pull|
      id = pull["number"]
      # TODO: Parse comments (looking for comments by 'username' or 'username_fail').
      # TODO: Jump to next iteration if source and/or target haven't change since last run.

      # Fetch the merge-commit for the pull request.
      # NOTE: This commit automatically created by 'GitHub Merge Button'.
      begin
        Cheetah.run("git", "fetch", "origin", "refs/pull/#{id}/merge:")
        Cheetah.run("git", "checkout", "FETCH_HEAD")
      rescue Cheetah::ExecutionFailed => e
        puts "Could not run git #{e.message}"
        puts "Standard output: #{e.stdout}"
        puts "Error ouptut:    #{e.stderr}"
      end

      # FIXME: Move this to configurable 'setup' block.
        # Setup project with latest code.
        `bundle install`
        `rake db:create`
        `rake db:migrate`

        # Setup jenkins.
        `rake -f /usr/lib/ruby/gems/1.9.1/gems/ci_reporter-1.7.0/stub.rake`
        `rake ci:setup:testunit`

      # Run tests.
      # FIXME: Move to a configurable 'run' block.
      main_task = "rake test:all"
      result = system(main_task)

      # Output the result to a comment on the pull request on GitHub.
      if result
        `curl -d '{ "body": "Well done! All tests are still passing after merging this pull request." }' -u "#{Pullermann.username}:#{Pullermann.password}" -X POST https://api.github.com/repos/#{Pullermann.project}/issues/104/comments;`
      else
        `curl -d '{ "body": "Unfortunately your tests are failing after merging this pull request." }' -u "#{Pullermann.username_fail}:#{Pullermann.password_fail}" -X POST https://api.github.com/repos/#{Pullermann.project}/issues/104/comments;`
      end
    end
  end

end
