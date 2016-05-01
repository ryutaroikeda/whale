require_relative 'lib/whale'

Gem::Specification.new do |s|
  s.name = 'whale'
  s.version = "#{MAJOR_VERSION}.#{MINOR_VERSION}.#{REVISION}"
  s.date = '2016-05-01'
  s.summary = 'An ideas organizer'
  s.description = 'Tag and filter your ideas'
  s.authors = ['Ryutaro Ikeda']
  s.executables << 'whale'
  s.files = ['lib/whale.rb']
  s.homepage =
    'http://rubygems.org/gems/whale'
  s.email = 'ryutaroikeda94@gmail.com'
  s.license = 'MIT'
end
