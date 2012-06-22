$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name     = 'pullermann'
  s.date     = Time.now.strftime('%F')
  s.version  = open('VERSION').read().strip
  s.homepage = 'http://github.com/b4mboo/pullermann'

  s.email    = 'bamboo@suse.com'
  s.authors  = ['Dominik Bamberger', 'Thomas Schmidt', 'Jordi Massaguer Pla']

  s.files    = %w( LICENSE )
  s.files    += Dir.glob('lib/**/*')

  s.summary  = 'An easy way to loop through open pull requests and run code on the merged branch.'
  s.description = 'Pullermann runs custom code (i.e. your project\'s test suite) on open pull requests on GitHub. Afterwards it posts the result as a comment to the respective request. This should give you an outlook on the future state of your repository in case you accept the request and merge the code.'

  s.add_runtime_dependency 'octokit'
  s.add_runtime_dependency 'rspec'
end
