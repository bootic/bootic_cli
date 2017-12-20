require 'spec_helper'
require 'bootic_cli/cli'
require 'bootic_cli/commands/themes'

describe BooticCli::Commands::Themes do
  let(:local_theme) { double('local theme') }
  let(:remote_theme) { double('remote theme') }
  let(:root) { double('root') }
  let(:client) { double('client', root: root) }
  let(:session) { double('session', client: client, needs_upgrade?: false, setup?: true, logged_in?: true) }
  let(:workflows) { double('workflows') }

  before do
    allow(BooticCli::Session).to receive(:new).and_return session

    allow(BooticCli::Themes::ThemeSelector)
      .to receive(:select_theme_pair)
      .with('foo', 'bar', root)
      .and_return([local_theme, remote_theme])

    allow(BooticCli::Themes::Workflows).to receive(:new).and_return workflows
  end

  describe '#pull' do
    it "invokes pull workflow" do
      expect(workflows).to receive(:pull).with(local_theme, remote_theme, destroy: true)
      described_class.start(%w(pull foo bar))
    end
  end

  describe '#push' do
    it "invokes push workflow" do
      expect(workflows).to receive(:push).with(local_theme, remote_theme, destroy: true)
      described_class.start(%w(push foo bar))
    end
  end

  describe '#sync' do
    it "invokes sync workflow" do
      expect(workflows).to receive(:sync).with(local_theme, remote_theme)
      described_class.start(%w(sync foo bar))
    end
  end

  describe '#compare' do
    it "invokes compare workflow" do
      expect(workflows).to receive(:compare).with(local_theme, remote_theme)
      described_class.start(%w(compare foo bar))
    end
  end

  describe '#watch' do
    it "invokes watch workflow" do
      expect(workflows).to receive(:watch).with('bar', remote_theme)
      described_class.start(%w(watch foo bar))
    end
  end

  describe BooticCli::Commands::Themes::Prompt do
    it "#yes_or_no?" do
      shell = double('Thor Shell')
      prompt = described_class.new(shell)

      expect(shell).to receive(:ask).with("\nfoo? [n]").and_return ''
      expect(prompt.yes_or_no?("foo?", false)).to be false
    end
  end
end
