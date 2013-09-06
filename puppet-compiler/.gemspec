# -*- encoding: utf-8 -*-
#
# PLEASE NOTE
# This gemspec is not intended to be used for building the Puppet gem.  This
# gemspec is intended for use with bundler when Puppet is a dependency of
# another project.  For example, the stdlib project is able to integrate with
# the master branch of Puppet by using a Gemfile path of
# git://github.com/puppetlabs/puppet.git
#
# Please see the [packaging
# repository](https://github.com/puppetlabs/packaging) for information on how
# to build the Puppet gem package.

Gem::Specification.new do |s|
  s.name = "puppet-providers"
  version = '3.3.0'
  mdata = version.match(/(\d+\.\d+\.\d+)/)
  s.version = mdata ? mdata[1] : version

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Puppet Labs"]
  s.date = "2012-08-17"
  s.description = "Standard Library of Puppet Types and Providers"
  s.email = "puppet@puppetlabs.com"
  s.executables = []
  s.files = []
  s.homepage = "http://puppetlabs.com"
  s.require_paths = ["lib"]
  s.rubyforge_project = "puppet-providers"
  s.rubygems_version = "1.8.24"
  s.summary = "Standard Library of Puppet Types and Providers"

  if s.respond_to? :specification_version then
    s.specification_version = 3
  end
end
