$:.unshift(File.dirname(__FILE__) + '/lib')
require 'knife-test/version'

Gem::Specification.new do |s|
  s.name = "knife-test"
  s.version = Knife::Test::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Dheeraj Dubey"]
  s.summary = "A test plugin to the Chef knife tool for bootstrapping a virtual machine"
  s.description = s.summary
  s.email = "dheeraj1857@gmail.com"
  s.licenses = ["Apache 2.0"]
  s.extra_rdoc_files = [
    "LICENSE"
  ]
  s.files = %w(LICENSE README.md) + Dir.glob("lib/**/*")
  s.homepage = "https://github.com/dheerajd88/knife-test"
  s.require_paths = ["lib"]
  s.add_development_dependency 'chef',  '~> 12.7.2', '>= 12.2.1'
  s.add_dependency "knife-windows", "~> 1.0"
  s.add_dependency "knife-azure", "~> 1.6.0.rc.0"
end
