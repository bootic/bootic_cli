require 'spec_helper'
require 'bootic_cli/cli'
require 'bootic_cli/file_runner'

describe BooticCli::CLI do
  let(:session) { instance_double(BooticCli::Session, needs_upgrade?: false, setup?: true, logged_in?: true) }

  let(:shop) { double(:shop, subdomain: "acme", url: "acme.bootic.net") }
  let(:root) {
    double(:root,
            user_name: "joe",
            email: "joe@bloggs.com",
            scopes: "admin,public",
            shops: [shop]
          )
  }

  let(:client) { double(:client, root: root) }

  def allow_ask(question, response, opts = {})
    expect(Thor::LineEditor).to receive(:readline).with("#{question} ", opts).and_return response
  end

  before do
    allow(BooticCli::Session).to receive(:new).and_return session
    allow(session).to receive(:client).and_return client
  end

  describe "#login" do
    let(:state)    { 'deadbeefcafe' }
    let(:verifier) { 'pkce-verifier-abc' }

    before { allow(Launchy).to receive(:open) }

    context "not yet logged in" do
      before { allow(session).to receive(:logged_in?).and_return(false) }

      it "opens browser and exchanges the code for a token" do
        allow(BooticCli::LocalServer).to receive(:wait_for_callback) do |&block|
          block.call(33100)
          { 'code' => 'auth-code-123', 'state' => state }
        end

        expect(session).to receive(:authorization_request).with(port: 33100)
                                                          .and_return(['https://auth.example.com/authorize', state, verifier])
        expect(session).to receive(:login_with_browser).with('auth-code-123', code_verifier: verifier, port: 33100)

        content = capture(:stdout) { described_class.start(%w(login)) }
        expect(content).to match /You're now logged in!/
      end

      it "aborts on state mismatch without exchanging the code" do
        allow(BooticCli::LocalServer).to receive(:wait_for_callback) do |&block|
          block.call(33100)
          { 'code' => 'auth-code-123', 'state' => 'tampered' }
        end
        allow(session).to receive(:authorization_request).and_return(['https://auth.example.com/authorize', state, verifier])
        expect(session).not_to receive(:login_with_browser)

        expect { described_class.start(%w(login)) }.to raise_error(SystemExit)
      end
    end

    context "already logged in" do
      it "exits early when user declines re-authentication" do
        allow_ask("You're already logged in. Re-authenticate? [n]", "n")
        expect { described_class.start(%w(login)) }.to raise_error(SystemExit)
      end
    end
  end

  describe "#setup" do
    before { ENV.delete('ENV') }
    after  { ENV.delete('ENV') }

    it "calls Session#setup(client_id, client_secret)" do
      allow_ask("Client ID:", "abc")
      allow_ask("Client secret:", "xyz")

      expect(session).to receive(:setup).with("abc", "xyz", auth_host: nil, api_root: nil)

      content = capture(:stdout) { described_class.start(%w(setup)) }
      expect(content).to match /Custom app credentials stored/
    end

    it "sets up with custom env" do
      ENV['ENV'] = 'staging'
      allow_ask("Auth endpoint host (https://auth.bootic.net):", "https://auth-staging.bootic.net")
      allow_ask("API root (https://api.bootic.net/v1):", "https://api-staging.bootic.net/v1")
      allow_ask("Client ID:", "abc")
      allow_ask("Client secret:", "xyz")

      expect(session).to receive(:setup).with(
        "abc", "xyz",
        auth_host: "https://auth-staging.bootic.net",
        api_root:  "https://api-staging.bootic.net/v1"
      )

      content = capture(:stdout) { described_class.start(%w(setup)) }
      expect(content).to match /Custom app credentials stored/
    end
  end

  describe "#logout" do
    it "calls Session#logout!" do
      expect(session).to receive(:logout!)
      content = capture(:stdout) { described_class.start(%w(logout)) }
      expect(content).to match /Done. You are now logged out/
    end
  end

  describe "#erase" do
    it "calls Session#erase!" do
      expect(session).to receive(:erase!)
      content = capture(:stdout) { described_class.start(%w(erase)) }
      expect(content).to match /Ok mister. All credentials have been erased/
    end
  end

  describe "#check" do
    context "not logged in" do
      it "asks user to log in first" do
        allow(session).to receive(:setup?).and_return(true)
        allow(session).to receive(:logged_in?).and_return(false)
        content = capture(:stdout) { described_class.start(%w(check)) }
        expect(content).to match /No access token found! Please run `bootic login`/
      end
    end

    context "logged in" do
      it "prints session info" do
        allow(session).to receive(:setup?).and_return true
        allow(session).to receive(:logged_in?).and_return true
        content = capture(:stdout) { described_class.start(%w(check)) }

        expect(content).to match /Email   joe@bloggs.com/
        expect(content).to match /Scopes  admin,public/
        expect(content).to match /Shop    acme.bootic.net \(acme\)/
      end
    end
  end

  describe "#runner" do
    it "uses FileRunner" do
      expect(BooticCli::FileRunner).to receive(:run).with(root, "./foo.rb")
      described_class.start(%w(runner ./foo.rb))
    end
  end
end
