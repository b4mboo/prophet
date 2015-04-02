$LOAD_PATH.unshift 'lib'

Gem::Specification.new do |s|
  s.name     = 'prophet'
  s.date     = Time.now.strftime('%F')
  s.version  = open('VERSION').read().strip
  s.homepage = 'http://github.com/b4mboo/prophet'

  s.email    = 'bamboo@suse.com'
  s.authors  = ['Dominik Bamberger', 'Thomas Schmidt', 'Jordi Massaguer Pla']

  s.files    = %w( LICENSE )
  s.files    += Dir.glob('lib/**/*')

  s.summary  = 'An easy way to loop through open pull requests and run code on '
  s.summary  += 'the merged branch.'

  s.license = 'MIT'

  s.description = 'Prophet runs custom code (i.e. your project\'s test suite) '
  s.description += 'on open pull requests on GitHub. Afterwards it posts the '
  s.description += 'result as a comment to the respective request. This should '
  s.description += 'give you an outlook on the future state of your repository '
  s.description += 'in case you accept the request and merge the code.'

  s.add_runtime_dependency 'faraday_middleware', '= 0.9.0'
  s.add_runtime_dependency 'faraday', '= 0.8.8'
  s.add_runtime_dependency 'octokit', '~> 3.8'
end
