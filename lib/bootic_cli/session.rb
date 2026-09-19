require 'oauth2'
require 'bootic_client'
require 'bootic_cli/local_server'
require 'securerandom'
require 'digest'
require 'base64'

module BooticCli

  class Session
    # Public client_id for the first-party Bootic CLI OAuth app.
    # This is NOT a secret — the security comes from PKCE, not a client_secret.
    # Override with BOOTIC_CLI_CLIENT_ID for development or self-hosted setups.
    CLI_CLIENT_ID = ENV.fetch('BOOTIC_CLI_CLIENT_ID', 'bootic-cli-dev')

    def initialize(store)
      @store = store
      upgrade!
    end

    def needs_upgrade?
      store.needs_upgrade?
    end

    def upgrade!
      store.upgrade!
      self
    end

    # Always true — no manual setup required; PKCE handles auth without a secret.
    # setup() is still provided for users who want a custom OAuth app.
    def setup?
      true
    end

    def logged_in?
      store.transaction { store['access_token'] }
    end

    def ready?
      logged_in?
    end

    # Optional: configure a custom OAuth app (for non-production environments or
    # self-hosted setups). Not required for normal use.
    def setup(client_id, client_secret, auth_host: nil, api_root: nil)
      store.transaction do
        store['client_id']     = client_id
        store['client_secret'] = client_secret
        store['auth_host']     = auth_host if auth_host
        store['api_root']      = api_root  if api_root
      end
    end

    # Build a [url, code_verifier] pair to start a PKCE authorization flow.
    # The caller must pass code_verifier back to login_with_browser() after the
    # callback arrives.
    def authorization_request(port:)
      verifier  = pkce_verifier
      challenge = pkce_challenge(verifier)
      state     = SecureRandom.hex(16)

      params = URI.encode_www_form(
        client_id:             effective_client_id,
        redirect_uri:          LocalServer.callback_url(port),
        response_type:         'code',
        scope:                 'admin',
        state:                 state,
        code_challenge:        challenge,
        code_challenge_method: 'S256'
      )

      url = "https://#{effective_auth_host}/oauth/authorize?#{params}"
      [url, state, verifier]
    end

    # Exchange an authorization code (plus the PKCE verifier) for an access token.
    def login_with_browser(code, code_verifier:, port:)
      # PKCE exchange: send code_verifier in place of client_secret
      response = Net::HTTP.post_form(
        URI("https://#{effective_auth_host}/oauth/token"),
        grant_type:    'authorization_code',
        client_id:     effective_client_id,
        code:          code,
        redirect_uri:  LocalServer.callback_url(port),
        code_verifier: code_verifier
      )

      body = JSON.parse(response.body)
      raise "Token exchange failed: #{body['error_description'] || body['error'] || response.body}" unless response.is_a?(Net::HTTPSuccess)

      store.transaction { store['access_token'] = body['access_token'] }
    end

    # Legacy password-based login — kept for CI / headless environments.
    def login(username, pwd, scope = 'admin')
      token = oauth2_client.password.get_token(username, pwd, 'scope' => scope)
      store.transaction { store['access_token'] = token.token }
    end

    def erase!
      store.erase
    end

    def logout!
      store.transaction { store['access_token'] = nil }
    end

    def config
      @config ||= store.transaction do
        {
          client_id:     store['client_id'],
          client_secret: store['client_secret'],
          access_token:  store['access_token'],
          auth_host:     store['auth_host'],
          api_root:      store['api_root']
        }
      end
    end

    class NullCacheStore
      def read(key)     = nil
      def delete(key)   = nil
      def write(key, v) = v
    end

    def client
      @client ||= begin
        raise "Not logged in. Please run `bootic login`." unless logged_in?

        BooticClient.configure do |c|
          c.auth_host     = config[:auth_host] if config[:auth_host]
          c.api_root      = config[:api_root]  if config[:api_root]
          c.client_id     = effective_client_id
          c.client_secret = config[:client_secret].to_s
          c.logger        = Logger.new(STDOUT)
          c.logging       = false
          c.cache_store   = NullCacheStore.new
        end

        BooticClient.client(:authorized, access_token: config[:access_token]) do |new_token|
          store.transaction { store['access_token'] = new_token }
        end
      end
    end

    private

    attr_reader :store

    def effective_client_id
      config[:client_id] || CLI_CLIENT_ID
    end

    def effective_auth_host
      config[:auth_host] || BooticClient.configuration.auth_host
    end

    def pkce_verifier
      SecureRandom.urlsafe_base64(32) # 43 chars, within the 43-128 range
    end

    def pkce_challenge(verifier)
      Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    end

    def oauth2_client
      OAuth2::Client.new(
        effective_client_id,
        config[:client_secret].to_s,
        site: "https://#{effective_auth_host}"
      )
    end
  end

end
