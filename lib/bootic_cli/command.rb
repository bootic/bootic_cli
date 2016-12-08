require 'thor'
require 'bootic_cli/connectivity'

module BooticCli
  class Command < Thor
    include Thor::Actions
    include BooticCli::Connectivity

    def self.declare(klass, descr)
      BooticCli::CLI.sub klass, descr
    end
  end
end

