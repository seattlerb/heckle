lib = File.expand_path("../lib", __FILE__)

Gem::Specification.new do |spec|
  spec.name          = "heckle"
  spec.version       = "2.0.0.b1"
  spec.authors       = ["Ryan Davis", "Pete Higgins", "Eric Hodel", "Kevin Clark"]
  spec.email         = ["ryand-ruby@zenspider.com", "pete@peterhiggins.org",  "drbrain@segment7.net", "kevin.clark@gmail.com"]

  spec.summary       = %q{Heckle is a mutation tester.}
  spec.homepage      = "http://ruby.sadi.st/Heckle.html"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = "1.8.7"

  spec.add_development_dependency "bundler", "1.11.2"
  spec.add_development_dependency "hoe", "2.16.1"
  spec.add_development_dependency "minitest", "3.5.0"
  spec.add_development_dependency "rake", "0.9.6"
  spec.add_development_dependency "ruby2ruby", "1.3.1"
  spec.add_development_dependency "ruby_parser", "2.3.1"
  spec.add_development_dependency "test-unit", "2.5.5"
  spec.add_development_dependency "ZenTest",   "4.7.0"
end
