require 'spec_helper'
require "bootic_cli/cli"

describe BooticCli::CLI do
  let(:session) { instance_double(BooticCli::Session, setup?: true, logged_in?: true) }

  def allow_ask(question, response, opts = {})
    allow(Thor::LineEditor).to receive(:readline).with("#{question} ", opts).and_return response
  end

  def assert_login
    allow_ask("Enter your Bootic user name:", "joe")
    allow_ask("Enter your Bootic password:", "bloggs", echo: false)

    expect(session).to receive(:login).with("joe", "bloggs", "admin")

    content = capture(:stdout) { described_class.start(%w(login)) }
    expect(content).to match /Logged in as joe \(admin\)/
  end

  def assert_setup(&block)
    allow_ask("Enter your application's client_id:", "abc")
    allow_ask("Enter your application's client_secret:", "xyz")

    expect(session).to receive(:setup).with("abc", "xyz")

    if block_given?
      content = capture(:stdout) { yield }
      expect(content).to match /Credentials stored. client_id: abc/
    end
  end

  before do
    allow(BooticCli::Session).to receive(:new).and_return session
  end

  describe "#setup" do
    it "calls Session#setup(client_id, client_secret)" do
      assert_setup{ described_class.start(%w(setup)) }
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

      expect(content).to match /Logged out/
    end
  end

  describe "#erase" do
    it "calls Session#erase!" do
      expect(session).to receive(:erase!)
      content = capture(:stdout) { described_class.start(%w(erase)) }

      expect(content).to match /all credentials erased from this computer/
    end
  end

  describe "#info" do
    context "not logged in" do
      it "asks user to log in first" do
        allow(session).to receive(:logged_in?).and_return false
        content = capture(:stdout) { described_class.start(%w(info)) }

        expect(content).to match /No access token. Run btc login/
      end
    end

    context "logged in" do
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

      it "prints session info" do
        allow(session).to receive(:client).and_return client

        content = capture(:stdout) { described_class.start(%w(info)) }

        expect(content).to match /username  joe/
        expect(content).to match /email     joe@bloggs.com/
        expect(content).to match /scopes    admin,public/
        expect(content).to match /shop      acme.bootic.net \(acme\)/
        expect(content).to match /OK/
      end
    end
  end
end
