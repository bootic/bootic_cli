require 'bootic_cli/store'
require 'bootic_cli/session'

module BooticCli
  module Connectivity

    private

    def session
      @session ||= (
        store = BooticCli::Store.new(base_dir: ENV['HOME'], namespace: options[:environment])
        BooticCli::Session.new(store)
      )
    end

    def root
      @root ||= session.client.root
    end

    def shop
      root.shops.first
    end

    def logged_in_action(&block)
      if session.needs_upgrade?
        say_status "WARNING", "old store data structure, restructuring to support multiple environments"
        session.upgrade!
      end

      if !session.setup?
        say_status "ERROR", "No app credentials. Run btc setup -e #{options[:environment]}", :red
        return
      end

      if !session.logged_in?
        say_status "ERROR", "No access token. Run btc login -e #{options[:environment]}", :red
        return
      end

      yield

    rescue StandardError => e
      say_status "ERROR", e.message, :red
      nil
    end
  end
end
