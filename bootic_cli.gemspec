# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bootic_cli/version'

Gem::Specification.new do |spec|
  spec.name          = "bootic_cli"
  spec.version       = BooticCli::VERSION
  spec.authors       = ["Ismael Celis"]
  spec.email         = ["ismaelct@gmail.com"]

  spec.summary       = %q{Bootic command line.}
  spec.description   = %q{Bootic command line.}
  spec.homepage      = "http://www.bootic.net"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'thor'
  spec.add_dependency 'bootic_client', "~> 0.0.17"

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"

  spec.post_install_message = <<-END
Bootic client installed.
Try running:
    btc help
END

end
