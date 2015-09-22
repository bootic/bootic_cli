require 'btc/store'
require 'oauth2'
require 'bootic_client'

module Btc
  module Connectivity

    private

    def setup?
      store.transaction do
        store['client_id'] && store['client_secret']
      end
    end

    def has_token?
      store.transaction{ store['access_token'] }
    end

    def ready?
      setup? && has_token?
    end

    def store
      @store ||= Btc::Store.new(ENV['HOME'])
    end

    def credentials
      @credentials ||= store.transaction do
        {
          client_id: store['client_id'],
          client_secret: store['client_secret'],
          access_token: store['access_token']
        }
      end
    end

    def client
      @client ||= begin
        raise "First setup credentials and log in" unless ready?
        BooticClient.configure do |c|
          c.client_id = credentials[:client_id]
          c.client_secret = credentials[:client_secret]
          c.logger = Logger.new(STDOUT)
          c.logging = false
        end

        BooticClient.client(:authorized, access_token: credentials[:access_token]) do |new_token|
          store.transaction{ store['access_token'] = new_token }
        end
      end
    end

    def root
      @root ||= client.root
    end

    def shop
      root.shops.first
    end

    def oauth_client
      @oauth_client ||= OAuth2::Client.new(
        credentials[:client_id],
        credentials[:client_secret],
        site: BooticClient.auth_host
      )
    end

  end
end
