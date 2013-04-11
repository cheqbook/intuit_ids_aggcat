# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "intuit_ids_aggcat/version"

Gem::Specification.new do |s|
  s.name        = "intuit_ids_aggcat"
  s.version     = IntuitIdsAggcat::VERSION
  s.authors     = ["Chris Hart"]
  s.email       = ["chris@rewardsummit.com"]
  s.homepage    = ""
  s.summary     = %q{Integration for Intuit's aggregation and categorization services}
  s.description = %q{Provides a wrapped for the IPP AggCat interfaces}

  s.rubyforge_project = "intuit_ids_aggcat"

  s.files = [
    'README.markdown',
    'LICENSE.txt'
  ]
  s.files += Dir['lib/**/*.rb']
  s.files += Dir['lib/**/*.yml']
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "rspec", "~> 2.11"
  s.add_development_dependency "vcr", "~> 2.2"
  s.add_development_dependency "fakeweb", "~> 1.3"
  s.add_runtime_dependency "oauth", "~> 0.4"
  s.add_runtime_dependency "nokogiri", "~> 1.5"
  s.add_runtime_dependency "xml-mapping"
  s.add_runtime_dependency "activesupport"
end
