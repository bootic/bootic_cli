require "spec_helper"
require "thor"
require "bootic_cli/connectivity"

describe BooticCli::Connectivity do
  let(:session) { instance_double(BooticCli::Session, needs_upgrade?: false) }

  let(:subject) do
    Class.new(Thor) do
      include BooticCli::Connectivity

      desc "number", "return a number"
      def number
        logged_in_action do
          5
        end
      end
    end
  end

  before do
    allow(BooticCli::Session).to receive(:new).and_return session
  end

  describe "#logged_in_action" do
    context "not setup" do
      before do
        allow(session).to receive(:setup?).and_return false
      end

      it "returns nil and puts notice" do
        result = "foo"
        content = capture(:stdout) { result = subject.start(%w(number)) }
        expect(content).to match /No app credentials. Run btc setup/
        expect(result).to be nil
      end
    end

    context "not logged in" do
      before do
        allow(session).to receive(:setup?).and_return true
        allow(session).to receive(:logged_in?).and_return false
      end

      it "returns nil and puts notice" do
        result = "foo"
        content = capture(:stdout) { result = subject.start(%w(number)) }
        expect(content).to match /No access token. Run btc login/
        expect(result).to be nil
      end
    end

    context "setup and logged in" do
      before do
        allow(session).to receive(:setup?).and_return true
        allow(session).to receive(:logged_in?).and_return true
      end

      it "returns nil and puts notice" do
        result = "foo"
        content = capture(:stdout) { result = subject.start(%w(number)) }
        expect(content).to eq ""
        expect(result).to eq 5
      end
    end

    context "handling session errors" do
      before do
        allow(session).to receive(:setup?).and_raise "Nope!"
      end

      it "returns nil and puts error message" do
        result = "foo"
        content = capture(:stdout) { result = subject.start(%w(number)) }
        expect(content).to match /Nope!/
        expect(result).to be nil
      end
    end
  end
end
