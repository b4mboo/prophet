Pullermann
==========
[![Build Status](https://secure.travis-ci.org/b4mboo/pullermann.png)](https://secure.travis-ci.org/b4mboo/pullermann)

Loops through open pull requests on a GitHub hosted repository and runs your code
(i.e. tests) on the merged branch. After the run has finished, Pullermann will
post a comment to the pull request stating whether the execution succeeded or failed.

Ever since GitHub released their awesome commit status API, Pullermann also makes use
of that and sets statuses according to the execution of your code to 'pending',
'failure' or 'success'.
However, keep in mind that the account you are using to run Pullermann needs to have
write access to your GitHub repository, to set statuses.


Rails projects
--------------

Installation is quite easy. If you are using bundler (i.e. for a Rails project),
just add the following to your Gemfile:

    gem 'pullermann'

To configure Pullermann for your Rails project, just create a new initializer:

    touch config/initializers/pullermann.rb

Inside that initializer you can easily change Pullermann's behavior to fit your needs.

    Pullermann.setup do |config|
      # ...
      # Add custom config block.
      # ...
    end

Please read this README's configuration section for further details on
customization.

Finally, to run Pullermann, just call the corresponding rake task either
manually or inside your CI (i.e. Jenkins).

    rake pullermann


Other projects
--------------

Since you are able to run any command inside Pullermann's execution block,
you can use it for any project and programming language. The only requirement
would be to have Ruby and RubyGems installed, such that you can run Pullermann
itself.

Installing the gem manually (without bundler), is simple and straight forward, too.

    gem install pullermann

Afterwards, create an executable file where you require the gem, maybe configure
it and in the end just call Pullermann manually.

    #!/usr/bin/env ruby

    require 'pullermann'

    Pullermann.setup do |config|
      # ...
      # Add custom config block.
      # ...
    end

    Pullermann.run

Please read this README's configuration section for further details on
customization.


Configuration
-------------

Even though you don't really need to configure Pullermann, as it ships with some
default values for everything, there is an easy way to override all these settings
and customize Pullermann to fit your needs perfectly.

Inside your configuration file - either the initializer in your Rails project or the
executable script you manually created for your non-Rails project - you can set
options like this:

    Pullermann.setup do |config|

      # Setup custom logger.
      config.logger = log = Logger.new(STDOUT)
      log.level = Logger::INFO

      # Custom GitHub (GH) username/password to use for commenting on a successful run.
      config.username = 'foo-success'
      config.password = 'bar'

      # Custom GH credentials for commenting on failing runs.
      # NOTE: If you specify two different accounts with different avatars,
      # it's a lot easier to spot failing runs at first glance.
      config.username_fail = 'foo-fail'
      config.password_fail = 'baz'

      # Specify when to run your code.
      # By default your code will run every time either the pull request or its
      # target (i.e. master) changes.
      config.rerun_on_source_change = true
      config.rerun_on_target_change = true

      # Add custom messages for comments and statuses.
      config.comment_success = 'Well Done! Your tests are still passing.'
      config.comment_failure = 'Unfortunately your tests are failing.'
      config.status_pending = 'Tests are still running.'
      config.status_success = 'Tests are passing.'
      config.status_failure = 'Tests are failing.'

      # If you need to make some system calls before looping through the pull requests,
      # you specify them here. This block will only be executed once and defaults to an
      # empty block.
      config.preparation do
        # Example: Setup jenkins.
        `rake -f /usr/lib/ruby/gems/1.9.1/gems/ci_reporter-1.7.0/stub.rake`
        `rake ci:setup:testunit`
      end

      # Finally, specify which code to run. (Defaults to `rake`.)
      # NOTE: If you don't set config.success manually to a boolean value,Pullermann
      # will try to determine it by looking at whether the last system call returned
      # 0 (= success).
      config.execution do
        log 'Running tests ...'
        `rake test:all`
        config.success = ($? == 0)
        log "Tests are #{config.success ? 'passing' : 'failing'}."
      end

    end

If you don't specify anything (or don't even create an initializer), Pullermann
would fall back to its defaults, thereby trying to take the username/password
from git config. To set or change these values you can use the following
commands:

    git config --global github.login your_github_login_1234567890
    git config --global github.password your_github_password_1234567890


Thanks
------

A big "Thank you" goes out to Konstantin Haase (rkh / @konstantinhaase) who
told us about this idea at Railsberry 2012 in Krakow.

    http://www.youtube.com/watch?v=YFzloW8F-nE

If you are using Pullermann to run your tests, it therefore only mimics one of
TravisCI's features (to a certain degree at least). If you want the full
experience, go to

    http://travis-ci.org

and sign in, using your GitHub account.

Pullermann is getting tested with Travis, too.

    https://secure.travis-ci.org/b4mboo/pullermann

