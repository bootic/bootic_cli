# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bootic_cli/version'

Gem::Specification.new do |spec|
  spec.name          = "bootic_cli"
  spec.version       = BooticCli::VERSION
  spec.authors       = ["Ismael Celis", "Tomás Pollak"]
  spec.email         = ["ismael@bootic.io", "tomas@bootic.io"]

  spec.summary       = %q{Bootic command-line client.}
  spec.description   = %q{Bootic command-line client.}
  spec.homepage      = "http://www.bootic.io"
  spec.license       = "MPLv2"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'thor', '~> 0'
  spec.add_dependency 'bootic_client', "~> 0.0.24"
  spec.add_dependency 'diffy', "~> 3.2"
  spec.add_dependency 'listen', "~> 3.1"
  spec.add_dependency 'launchy', "~> 2.4"

  if Gem.win_platform?
    spec.add_dependency 'diff-lcs'
    spec.add_dependency 'wdm', '>= 0.1.0'
  end

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_development_dependency "byebug", "~> 9"

  spec.post_install_message = <<-END
   -------------------------------------------------------------
    Woot! You've just installed the Bootic command-line client!
    Please run `bootic setup` to configure your credentials.
   -------------------------------------------------------------
END

end
