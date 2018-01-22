require 'bootic_cli/store'
require 'bootic_cli/session'

module BooticCli
  module Connectivity

    private

    def session
      @session ||= (
        store = BooticCli::Store.new(base_dir: ENV['HOME'], namespace: current_env)
        BooticCli::Session.new(store)
      )
    end

    def current_env
      ENV['ENV'] || DEFAULT_ENV
    end

    def root
      @root ||= session.client.root
    end

    def shop
      root.shops.first
    end

    def logged_in_action(&block)
      check_client_keys!
      check_access_token!
      yield
    rescue StandardError => e
      say e.message, :red
      nil
    end

    def check_access_token!
      if !session.logged_in?
        say "No access token found! Please run `bootic login`.", :red
        exit 1
      end
    end

    def check_client_keys!
      if session.needs_upgrade?
        say "Old store data structure, restructuring to support multiple environments...", :cyan
        session.upgrade!
      end

      if !session.setup?
        say "CLI not configured yet! Please run `bootic setup`.", :magenta
        exit 1
      end
    end
  end
end
