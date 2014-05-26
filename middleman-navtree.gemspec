# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "middleman-navtree"
  s.version     = "0.1.2"
  s.licenses    = ['MIT']
  s.date        = Date.today.to_s

  s.summary     = "For building navigation trees with Middleman"
  s.description = "This extension copies the site structure to tree.yml and provides helpers for printing parts of the tree in your middleman templates."

  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bryan Braun"]
  s.email       = ["bbraun7@gmail.com"]
  s.homepage    = "https://github.com/bryanbraun/middleman-navtree"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # The version of middleman-core this extension depends on.
  s.add_runtime_dependency("middleman-core", ["~> 3.3"])
  s.add_runtime_dependency("titleize", ["~> 1.3"])
end
