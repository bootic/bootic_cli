require 'oauth2'
require 'bootic_client'

module BooticCli

  class Session
    def initialize(store)
      @store = store
    end

    def needs_upgrade?
      store.needs_upgrade?
    end

    def upgrade!
      store.upgrade!
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

    def setup(client_id, client_secret, auth_host: nil, api_root: nil)
      store.transaction do
        store['client_id'] = client_id
        store['client_secret'] = client_secret
        store['auth_host'] = auth_host if auth_host
        store['api_root'] = api_root if api_root
      end
    end

    def login(username, pwd, scope)
      token = oauth_client.password.get_token(username, pwd, 'scope' => scope)

      store.transaction do
        store['access_token'] = token.token
      end
    end

    def erase!
      store.erase
    end

    def logout!
      store.transaction do
        store['access_token'] = nil
      end
    end

    def config
      @config ||= store.transaction do
        h = {
          client_id: store['client_id'],
          client_secret: store['client_secret'],
          access_token: store['access_token']
        }
        h[:auth_host] = store['auth_host'] if store['auth_host']
        h[:api_root] = store['api_root'] if store['api_root']
        h
      end
    end

    # use a null store instead of the default memory store
    # so in btc console we don't cache resources forever
    class NullCacheStore
      def read(key)
        nil
      end

      def delete(key)
        nil
      end

      def write(key, value)
        value
      end
    end

    def client
      @client ||= begin
        raise "First setup credentials and log in" unless ready?
        BooticClient.configure do |c|
          c.auth_host = config[:auth_host] if config[:auth_host]
          c.api_root = config[:api_root] if config[:api_root]
          c.client_id = config[:client_id]
          c.client_secret = config[:client_secret]
          c.logger = Logger.new(STDOUT)
          c.logging = false
          c.cache_store = NullCacheStore.new
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
        site: (config[:auth_host] || BooticClient.auth_host)
      )
    end

  end

end
