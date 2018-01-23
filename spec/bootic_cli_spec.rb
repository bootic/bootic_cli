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

  def assert_login
    allow_ask("Looks like you're already logged in. Do you want to redo this step? [n]", "y")

    allow_ask("Enter your Bootic email:", "joe")
    allow_ask("Enter your Bootic password:", "bloggs", echo: false)

    expect(session).to receive(:login).with("joe", "bloggs", "admin")

    content = capture(:stdout) { described_class.start(%w(login)) }
    expect(content).to match /You're now logged in as joe \(admin\)/
  end

  def assert_setup(env = 'production', &block)
    ENV['ENV'] = env
    ENV['nologin'] = '1' # otherwise we'de be testing the two things
    allow(session).to receive(:setup?).and_return(false)

    auth_host = nil
    api_root = nil

    if env != 'production'
      auth_host = "https://auth-staging.bootic.net"
      api_root = "https://api-staging.bootic.net/v1"
      allow_ask("Enter auth endpoint host (https://auth.bootic.net):", auth_host)
      allow_ask("Enter API root (https://api.bootic.net/v1):", api_root)
    end

    allow_ask("Have you created a Bootic app yet? [n]", "y")
    allow_ask("Enter your application's client_id:", "abc")
    allow_ask("Enter your application's client_secret:", "xyz")

    # allow(session).to receive(:logout!)
    expect(session).to receive(:setup).with("abc", "xyz", auth_host: auth_host, api_root: api_root)

    if block_given?
      content = capture(:stdout) { yield }
      expect(content).to match /Credentials stored/
    end
  end

  before do
    allow(BooticCli::Session).to receive(:new).and_return session
    allow(session).to receive(:client).and_return client
  end

  describe "#setup" do
    it "calls Session#setup(client_id, client_secret)" do
      assert_setup { described_class.start(%w(setup)) }
    end

    it "sets up with custom env" do
      assert_setup('staging') {
        described_class.start(%w(setup))
      }
    end
  end

  describe "#login" do
    context "not setup yet" do
      it "invokes setup" do
        allow(session).to receive(:setup?).and_return false
        assert_setup
        assert_login
      end
    end

    context "already setup" do
      it "calls Session#setup(client_id, client_secret)" do
        allow(session).to receive(:setup?).and_return true
        assert_login
      end
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
