require 'oauth2'
require 'bootic_client'

module Btc

  class Session
    def initialize(store)
      @store = store
    end

    def setup?
      store.transaction do
        store['client_id'] && store['client_secret']
      end
    end

    def logged_in?
      store.transaction{ store['access_token'] }
    end

    def ready?
      setup? && logged_in?
    end

    def setup(client_id, client_secret)
      store.transaction do
        store['client_id'] = client_id
        store['client_secret'] = client_secret
      end
    end

    def login(username, pwd, scope)
      token = oauth_client.password.get_token(username, pwd, 'scope' => scope)

      store.transaction do
        store['access_token'] = token.token
      end
    end

    def logout!
      store.transaction do
        store['access_token'] = nil
      end
    end

    def config
      @config ||= store.transaction do
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
          c.client_id = config[:client_id]
          c.client_secret = config[:client_secret]
          c.logger = Logger.new(STDOUT)
          c.logging = false
        end

        BooticClient.client(:authorized, access_token: config[:access_token]) do |new_token|
          store.transaction{ store['access_token'] = new_token }
        end
      end
    end

    private

    attr_reader :store

    def oauth_client
      @oauth_client ||= OAuth2::Client.new(
        config[:client_id],
        config[:client_secret],
        site: BooticClient.auth_host
      )
    end

  end

end
