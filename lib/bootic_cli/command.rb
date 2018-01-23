require 'thor'
require 'bootic_cli/connectivity'

module BooticCli
  class Command < Thor
    include Thor::Actions
    include BooticCli::Connectivity

    # override Thor's help method to print banner and check for keys
    def help(some, arg)
      say "Bootic CLI v#{BooticCli::VERSION}\n\n", :bold
      super

      examples if respond_to?(:examples)
    end

    def self.declare(klass, descr)
      BooticCli::CLI.sub klass, descr
    end
  end
end

