Pullermann
==========

Loops through open pull requests on a GitHub repository and runs your tests on
the merged code. After the test run has finished, Pullermann will post a comment
to the pull request stating whether the tests have all passed or failed.

Installation is quite easy. If you are using bundler (i.e. for a Rails project),
just add the following to your Gemfile:

    gem 'pullermann'

To configure Pullermann for your Rails project, create a new initializer:

    touch config/initializers/pullermann.rb

Inside that file you can set your options like this:

    Pullermann.setup do |config|

      # The GitHub (GH) username/password to use for commenting on a successful run.
      config.username = 'foo-success'
      config.password = 'bar'

      # The GH credentials for commenting on failing runs (can be the same as above).
      # NOTE: If you specify two different accounts with different avatars, it's
      # a lot easier to spot failing test runs at first glance.
      config.username_fail = 'foo-fail'
      config.password_fail = 'baz'

      # Specify when to run tests.
      # By default your tests will run everytime either the pull request or its
      # target (i.e. master) changes.
      config.rerun_on_source_change = true
      config.rerun_on_target_change = true

      # If you need to make some system calls before running your actual tests,
      # you specify them here. (Defaults to an empty block.)
      config.test_preparation do
        # Setup project with latest code.
        `bundle install`
        `rake db:create`
        `rake db:migrate`

        # Setup jenkins.
        `rake -f /usr/lib/ruby/gems/1.9.1/gems/ci_reporter-1.7.0/stub.rake`
        `rake ci:setup:testunit`
      end

      # Finally, specify which tests to run. (Defaults to `rake test:all`.)
      # NOTE: Either ensure the last call in that block runs your tests
      # or manually set @result to a boolean inside this block.
      config.test_execution do
        `echo 'Running tests ...'`
        `rake test:all`
      end

    end

If you don't specify anything (or don't even create an initializer), Pullermann
would fall back to its defaults, thereby trying to take the username/password
from git config. To set or change these values you can use the following
commands:

    git config --global github.login your_github_login_1234567890
    git config --global github.password your_github_password_1234567890

Finally, to run Pullermann, just call the corresponding rake task either
manually or inside your CI (i.e. Jenkins).

    rake pullermann


Non-Rails projects
------------------

If you want to use Pullermann for non-Rails projects the easiest way would
probably be to install the gem manually.

    gem install pullermann

Afterwards, create an executable file where you require the gem, configure it
and in the end just call Pullermann manually.

    #!/usr/bin/env ruby

    require 'pullermann'

    Pullermann.setup do |config|
      # ...
    end

    Pullermann.run

Running this script will do the same as as running the rake task on a Rails
project.


Thanks
------

A big "Thank you" goes out to Konstantin Haase (rkh / @konstantinhaase) who
told us about that idea at Railsberry 2012 in Krakow.

    http://www.youtube.com/watch?v=YFzloW8F-nE
