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

  s.summary  = 'An easy way to test pull requests.'
  s.description = 'Test open pull requests on GitHub hosted projects and comments on them whether tests pass or fail if the request is accepted and code is merged.'

  s.add_runtime_dependency 'cheetah'
  s.add_runtime_dependency 'octokit', '= 0.6.5'
end
