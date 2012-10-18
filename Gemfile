source :rubygems

# This is a fake version just to make bundler happy during development
FAKE_VERSION = '9999.0.0'

def location_for(place)
  if place =~ /^(git:[^#]*)#(.*)/
    [{ :git => $1, :branch => $2, :require => false }]
  elsif place =~ /^file:\/\/(.*)/
    [FAKE_VERSION, { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

group(:development, :test) do
  gem "puppet", *location_for('file://.')
  gem "facter", *location_for(ENV['FACTER_LOCATION'] || '~> 1.6.4')
  gem "hiera", *location_for(ENV['HIERA_LOCATION'] || '~> 1.0.0')
  gem "rack", "~> 1.4.1", :require => false
  gem "rake", "~> 0.9.2", :require => false
  gem "rspec", "~> 2.10.0", :require => false
  gem "mocha", "~> 0.10.5", :require => false
end

platforms :mswin, :mingw do
  # See http://jenkins.puppetlabs.com/ for current Gem listings for the Windows
  # CI Jobs.
  gem "sys-admin", "~> 1.5.6", :require => false
  gem "win32-api", "~> 1.4.8", :require => false
  gem "win32-dir", "~> 0.3.7", :require => false
  gem "win32-eventlog", "~> 0.5.3", :require => false
  gem "win32-process", "~> 0.6.5", :require => false
  gem "win32-security", "~> 0.1.2", :require => false
  gem "win32-service", "~> 0.7.2", :require => false
  gem "win32-taskscheduler", "~> 0.2.2", :require => false
  gem "win32console", "~> 1.3.2", :require => false
  gem "windows-api", "~> 0.4.1", :require => false
  gem "windows-pr", "~> 1.2.1", :require => false
end

if File.exists? "#{__FILE__}.local"
  eval(File.read("#{__FILE__}.local"), binding)
end

# vim:filetype=ruby
