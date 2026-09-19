require 'spec_helper'
require 'bootic_cli/session'
require 'bootic_cli/store'
require 'tmpdir'
require 'digest'
require 'base64'

describe BooticCli::Session do
  let(:store_dir) { File.join(Dir.tmpdir, "btc_session_spec_#{Process.pid}") }
  let(:store)     { BooticCli::Store.new(base_dir: store_dir, dir: '') }

  subject(:session) { described_class.new(store) }

  before { session } # force initialization so upgrade! runs before any store writes

  after { FileUtils.rm_rf(store_dir) }

  describe '#setup?' do
    it 'always returns true — no manual setup required' do
      expect(session.setup?).to be true
    end
  end

  describe '#logged_in?' do
    it 'returns falsy when no access token is stored' do
      expect(session.logged_in?).to be_falsy
    end

    it 'returns the token when one is stored' do
      store.transaction { store['access_token'] = 'tok123' }
      expect(session.logged_in?).to eq('tok123')
    end
  end

  describe '#authorization_request' do
    it 'returns [url, state, verifier]' do
      url, state, verifier = session.authorization_request(port: 33100)
      expect(url).to be_a(String)
      expect(state).to be_a(String)
      expect(verifier).to be_a(String)
    end

    it 'builds an authorization URL with the correct client_id' do
      url, _state, _verifier = session.authorization_request(port: 33100)
      parsed = URI.parse(url)
      params = URI.decode_www_form(parsed.query).to_h
      expect(params['client_id']).to eq(BooticCli::Session::CLI_CLIENT_ID)
    end

    it 'includes the port-specific callback as redirect_uri' do
      url, _state, _verifier = session.authorization_request(port: 33105)
      parsed = URI.parse(url)
      params = URI.decode_www_form(parsed.query).to_h
      expect(params['redirect_uri']).to eq('http://localhost:33105/callback')
    end

    it 'includes a non-empty state for CSRF protection' do
      url, state, _verifier = session.authorization_request(port: 33100)
      parsed = URI.parse(url)
      params = URI.decode_www_form(parsed.query).to_h
      expect(params['state']).to eq(state)
      expect(state).not_to be_empty
    end

    it 'includes a valid S256 PKCE code_challenge derived from the verifier' do
      _url, _state, verifier = session.authorization_request(port: 33100)
      _url2, _state2, verifier2 = session.authorization_request(port: 33100)

      # Each call generates a fresh verifier
      expect(verifier).not_to eq(verifier2)
    end

    it 'sends code_challenge_method=S256' do
      url, _state, _verifier = session.authorization_request(port: 33100)
      parsed = URI.parse(url)
      params = URI.decode_www_form(parsed.query).to_h
      expect(params['code_challenge_method']).to eq('S256')
    end

    it 'derives code_challenge correctly from the verifier' do
      url, _state, verifier = session.authorization_request(port: 33100)
      parsed = URI.parse(url)
      params = URI.decode_www_form(parsed.query).to_h

      expected_challenge = Base64.urlsafe_encode64(
        Digest::SHA256.digest(verifier),
        padding: false
      )
      expect(params['code_challenge']).to eq(expected_challenge)
    end
  end

  describe '#setup' do
    it 'stores client_id and client_secret' do
      session.setup('my-id', 'my-secret')
      cfg = session.config
      expect(cfg[:client_id]).to eq('my-id')
      expect(cfg[:client_secret]).to eq('my-secret')
    end

    it 'stores optional auth_host and api_root' do
      session.setup('id', 'secret', auth_host: 'https://auth.example.com', api_root: 'https://api.example.com/v1')
      cfg = session.config
      expect(cfg[:auth_host]).to eq('https://auth.example.com')
      expect(cfg[:api_root]).to eq('https://api.example.com/v1')
    end

    it 'prefers a stored client_id over the bundled CLI_CLIENT_ID in authorization_request' do
      session.setup('custom-app-id', 'secret')
      # Force config to reload from store
      session.instance_variable_set(:@config, nil)
      url, _state, _verifier = session.authorization_request(port: 33100)
      params = URI.decode_www_form(URI.parse(url).query).to_h
      expect(params['client_id']).to eq('custom-app-id')
    end
  end

  describe '#logout!' do
    it 'clears the stored access token' do
      store.transaction { store['access_token'] = 'tok' }
      session.logout!
      expect(session.logged_in?).to be_falsy
    end
  end

  describe '#erase!' do
    it 'calls erase on the store' do
      expect(store).to receive(:erase)
      session.erase!
    end
  end
end
