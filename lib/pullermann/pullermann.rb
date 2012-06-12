class Pullermann::Pullermann

  attr_accessor :username, :username_fail, :password, :password_fail, :project

  def run
    # FIXME: Use Octokit to access GHitHub.
    if @project && @username && @password
      data = JSON.parse(open("https://github.com/api/v2/json/pulls/#{@project}",
                             :http_basic_authentication=>[@username, @password]).read)

      # Loop through all 'open' pull requests.
      data["pulls"].each do |pull|
        id = pull["number"]
        # TODO: Parse comments (looking for comments by 'username' or 'username_fail').
        # TODO: Jump to next iteration if source and/or target haven't change since last run.

        # Fetch the merge-commit for the pull request.
        # NOTE: This commit automatically created by 'GitHub Merge Button'.
        # FIXME: Use cheetah for system calls.
        `git fetch origin refs/pull/#{id}/merge:`
        `git checkout FETCH_HEAD`

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
          `curl -d '{ "body": "Well done! All tests are still passing after merging this pull request." }' -u "#{@username}:#{@password}" -X POST https://api.github.com/repos/#{@project}/issues/104/comments;`
        else
          `curl -d '{ "body": "Unfortunately your tests are failing after merging this pull request." }' -u "#{@username_fail}:#{@password_fail}" -X POST https://api.github.com/repos/#{@project}/issues/104/comments;`
        end
      end
    else
      puts 'Please configure Pullermann before using it.'
    end
  end

end
