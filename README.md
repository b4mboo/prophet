Pullermann
==========
[![Build Status](https://secure.travis-ci.org/b4mboo/pullermann.png)](https://secure.travis-ci.org/b4mboo/pullermann)

Loops through open pull requests on a GitHub hosted repository and runs your code
(i.e. tests) on the merged branch. After the run has finished, Pullermann will
post a comment to the pull request stating whether the execution succeeded or failed.

Installation is quite easy. If you are using bundler (i.e. for a Rails project),
just add the following to your Gemfile:

    gem 'pullermann'

To configure Pullermann for your Rails project, create a new initializer:

    touch config/initializers/pullermann.rb

Inside that file you can set your options like this:

    Pullermann.setup do |config|

      # Setup custom logger.
      config.logger = log = Logger.new(STDOUT)
      log.level = Logger::INFO

      # The GitHub (GH) username/password to use for commenting on a successful run.
      config.username = 'foo-success'
      config.password = 'bar'

      # The GH credentials for commenting on failing runs (can be the same as above).
      # NOTE: If you specify two different accounts with different avatars,
      # it's a lot easier to spot failing runs at first glance.
      config.username_fail = 'foo-fail'
      config.password_fail = 'baz'

      # Specify when to run your code.
      # By default your code will run every time either the pull request or its
      # target (i.e. master) changes.
      config.rerun_on_source_change = true
      config.rerun_on_target_change = true

      # If you need to make some system calls before looping through the pull requests,
      # you specify them here. (Defaults to an empty block.)
      # This block will only be executed once before switching to the merged state.
      config.preparation do
        # Example: Setup jenkins.
        `rake -f /usr/lib/ruby/gems/1.9.1/gems/ci_reporter-1.7.0/stub.rake`
        `rake ci:setup:testunit`
      end

      # Finally, specify which code to run. (Defaults to `rake`.)
      # NOTE: If you don't set config.success manually to a boolean inside this block,
      # Pullermann will try to determine it by looking at whether the last system call
      # returned 0 (= success).
      config.execution do
        log 'Running tests ...'
        `rake test:all`
        config.success = ($? == 0)
        log "Tests are #{self.success ? 'passing' : 'failing'}."
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
told us about this idea at Railsberry 2012 in Krakow.

    http://www.youtube.com/watch?v=YFzloW8F-nE

Pullermann therefore only mimics one of TravisCI's features (to a certain 
degree at least). If you want the full experience, go to

    http://travis-ci.org

and sign in, using your GitHub account.

Pullermann is on getting tested with Travis, too.

    http://travis-ci.org/#!/b4mboo/pullermann

