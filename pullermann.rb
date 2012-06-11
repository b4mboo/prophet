#!/usr/bin/env ruby
# TODO: loop through all open pull requests.

# navigate into sub-directory if necessary
`cd /home/jenkins/workspace/glue`

# fetch the merge-commit for the pull request.
# NOTE: this automatically created by GitHub.
`git fetch origin refs/pull/104/merge:`
`git checkout FETCH_HEAD`

# setup project with latest code.
`bundle install`
`rake db:create`
`rake db:migrate`

# setup jenkins and run tests.
`rake -f /usr/lib/ruby/gems/1.9.1/gems/ci_reporter-1.7.0/stub.rake`
`rake ci:setup:testunit`
`rake test:all`

# comment on the pull request on GitHub.
`if [ $? == 0 ]; then
  # GitHub account for success: suse-jenkins-success / galileo224
  curl -d '{ "body": "Well done! All tests are still passing after merging this pull request." }' -u "suse-jenkins-success:galileo224" -X POST 
https://api.github.com/repos/SUSE/happy-customer/issues/104/comments;
else
  # GitHub account for failure: suse-jenkins-fail / galileo224
  curl -d '{ "body": "Unfortunately your tests are failing after merging this pull request." }' -u "suse-jenkins-fail:galileo224" -X POST 
https://api.github.com/repos/SUSE/happy-customer/issues/104/comments;
fi`
