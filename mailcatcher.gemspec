# frozen_string_literal: true

require File.expand_path('lib/mail_catcher/version', __dir__)

Gem::Specification.new do |s|
  s.name = 'mailcatcher'
  s.version = MailCatcher::VERSION
  s.license = 'MIT'
  s.summary = 'Runs an SMTP server, catches and displays email in a web interface.'
  s.description = <<-DESCRIPTION
    MailCatcher runs a super simple SMTP server which catches any
    message sent to it to display in a web interface. Run
    mailcatcher, set your favourite app to deliver to
    smtp://127.0.0.1:1025 instead of your default SMTP server,
    then check out http://127.0.0.1:1080 to see the mail.
  DESCRIPTION

  s.author = 'Samuel Cochran'
  s.email = 'sj26@sj26.com'
  s.homepage = 'https://mailcatcher.me'

  s.files = Dir[
    'README.md', 'LICENSE', 'VERSION',
    'bin/*',
    'lib/**/*.rb',
    'public/**/*',
    'views/**/*'
  ] - Dir['lib/mail_catcher/web/assets.rb']
  s.require_paths = ['lib']
  s.executables = %w[mailcatcher catchmail]
  s.extra_rdoc_files = ['README.md', 'LICENSE']

  s.required_ruby_version = '>= 3.2'

  s.add_dependency 'eventmachine', '~> 1.2.7'
  s.add_dependency 'faye-websocket', '~> 0.12.0'
  s.add_dependency 'mail', '~> 2.9'
  s.add_dependency 'net-smtp', '~> 0.5.1'
  s.add_dependency 'ostruct', '~> 0.6.3'
  s.add_dependency 'rack', '~> 3.2.4'
  s.add_dependency 'sinatra', '~> 4.2.1'
  s.add_dependency 'sqlite3', '~> 2.9'
  s.add_dependency 'thin', '~> 2.0'

  s.add_development_dependency 'capybara', '~> 3.40'
  s.add_development_dependency 'capybara-screenshot', '~> 1.0', '>= 1.0.26'
  s.add_development_dependency 'coffee-script', '~> 2.4', '>= 2.4.1'
  s.add_development_dependency 'rake', '~> 13.3', '>= 13.3.1'
  s.add_development_dependency 'rdoc', '~> 7.0', '>= 7.0.3'
  s.add_development_dependency 'rspec', '~> 3.13', '>= 3.13.2'
  s.add_development_dependency 'rubocop', '~> 1.82.1'
  s.add_development_dependency 'selenium-webdriver', '~> 4.39'
  s.add_development_dependency 'sprockets'
  s.add_development_dependency 'sprockets-helpers'
  s.add_development_dependency 'uglifier', '~> 4.2', '>= 4.2.1'
end
