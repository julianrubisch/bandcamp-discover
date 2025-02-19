# Ensure we require the local version and not one we might have installed already
require File.join([File.dirname(__FILE__),'lib','bandcamp-discover','version.rb'])
spec = Gem::Specification.new do |s|
  s.name = 'bandcamp-discover'
  s.version = BandcampDiscover::VERSION
  s.author = 'Julian RUbisch'
  s.email = 'julian@julianrubisch.at'
  s.homepage = 'https://julianrubisch.at'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Uses Playwright to scrape bandcamp labels'
  s.files = `git ls-files`.split("
")
  s.require_paths << 'lib'
  s.extra_rdoc_files = ['README.rdoc','bandcamp-discover.rdoc']
  s.rdoc_options << '--title' << 'bandcamp-discover' << '--main' << 'README.rdoc' << '-ri'
  s.bindir = 'bin'
  s.executables << 'bandcamp-discover'
  s.add_development_dependency('rake')
  s.add_development_dependency('rdoc')
  s.add_development_dependency('minitest')
  s.add_development_dependency('standard')
  s.add_runtime_dependency('gli','~> 2.21.5')

  s.add_dependency('playwright-ruby-client')
  s.add_dependency('sqlite3')
  s.add_dependency('async')
  s.add_dependency('concurrent-ruby')
  s.add_dependency('base64')
  s.add_dependency('logger')
  s.add_dependency('ostruct')
end
