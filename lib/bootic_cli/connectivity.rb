require 'bootic_cli/store'
require 'bootic_cli/session'

module BooticCli
  module Connectivity

    private

    def session
      @session ||= (
        store = BooticCli::Store.new(ENV['HOME'])
        BooticCli::Session.new(store)
      )
    end

    def root
      @root ||= session.client.root
    end

    def shop
      root.shops.first
    end

  end
end
