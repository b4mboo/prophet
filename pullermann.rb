#!/usr/bin/env ruby

require 'rubygems'
require 'open-uri'
require 'json'


require 'optparse'
username = ""
password = ""
project = ""
dirname = ""

OptionParser.new do |opts|
  opts.banner = "Usage: pullermann.rb  [options]"
  opts.on("-u", "--username USERNAME", "username") do |u|
    username = u
  end
  opts.on("-p", "--password PASSWORD", "password") do |p|
    password = p
  end
  opts.on("-m", "--project PROJECt", "project name, for example foo/bar") do |p|
    project = p
  end
  opts.on("-d", "--dirname DIRNAME", "project dirname where it is already checked out") do |d|
    dirname = d
  end

end.parse!



data = JSON.parse(open("https://github.com/api/v2/json/pulls/#{project}", 
                       :http_basic_authentication=>[username, password]).read)
data["pulls"].each do |pull|
  id = pull["number"]
  # navigate into sub-directory if necessary
  Dir.chdir dirname do

    # fetch the merge-commit for the pull request.
    # NOTE: this automatically created by GitHub.
    `git fetch origin refs/pull/#{id}/merge:`
    `git checkout FETCH_HEAD`

    # setup project with latest code.
    `bundle install`
    `rake db:create`
    `rake db:migrate`

    # setup jenkins and run tests.
    `rake -f /usr/lib/ruby/gems/1.9.1/gems/ci_reporter-1.7.0/stub.rake`
    `rake ci:setup:testunit`
    result = system("rake test:all")

    # comment on the pull request on GitHub.
    if result 
      `curl -d '{ "body": "Well done! All tests are still passing after merging this pull request." }' -u "#{username}:#{password}" -X POST https://api.github.com/repos/#{project}/issues/104/comments;`
    else
      `curl -d '{ "body": "Unfortunately your tests are failing after merging this pull request." }' -u "#{username}:#{password}" -X POST https://api.github.com/repos/#{project}/issues/104/comments;`
    end
  end

end
