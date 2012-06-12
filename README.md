Pullermann
==========

Loops through open pull requests on a GitHub repository and runs the tests on the merged code.

To configure Pullermann for your Rails project, create a new initializer:

  config/initializers/pullermann.rb

Inside that file you can set your options like this:

  Pullermann.setup do |config|
    # The GitHub (GH) username/password to use for commenting on a successful run.
    config.username = 'foo-success'
    config.password = 'bar'
    # The GH credentials for commenting on failing runs (might be the same as above).
    # NOTE: If you specify two different accounts with different avatars, it's
    # a lot easier to spot failing test runs at first glance.
    config.username_fail = 'foo-fail'
    config.password_fail = 'baz'

    # Specify when to run tests (defaults to true).
    config.rerun_on_source_change = true
    config.rerun_on_target_change = true
  end

If you don't specify anything (or not even create an initializer), Pullermann would
fall back to its defaults, thereby trying to take the username/password from git config.
