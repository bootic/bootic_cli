require 'spec_helper'
require 'bootic_cli/cli'
require 'bootic_cli/commands/themes'

describe BooticCli::Commands::Themes do
  let(:local_theme) { double('local theme') }
  let(:remote_theme) { double('remote theme') }
  let(:root) { double('root') }
  let(:client) { double('client', root: root) }
  let(:session) { double('session', client: client, needs_upgrade?: false, setup?: true, logged_in?: true) }
  let(:workflows) { double('workflows', pull: true, push: true, sync: true, compare: true, watch: true) }
  let(:selector) { instance_double(BooticCli::Themes::ThemeSelector, select_theme_pair: [local_theme, remote_theme]) }

  before do
    allow(BooticCli::Themes::ThemeSelector).to receive(:new).and_return selector
    allow(BooticCli::Session).to receive(:new).and_return session
    allow(BooticCli::Themes::Workflows).to receive(:new).and_return workflows
  end

  describe '#clone' do
    it "invokes pull workflow, delegates to ThemeSelector correctly" do
      it_setsup_dev_theme
      expect(workflows).to receive(:pull).with(local_theme, remote_theme, destroy: true)
      described_class.start(%w(clone foo bar))
    end

    it "uses production theme if -p option present" do
      it_setsup_production_theme
      described_class.start(%w(clone -p foo bar))
    end
  end

  describe '#pull' do
    it "invokes pull workflow, delegates to ThemeSelector correctly" do
      it_selects_dev_theme
      expect(workflows).to receive(:pull).with(local_theme, remote_theme, destroy: true)
      described_class.start(%w(pull))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      described_class.start(%w(pull -p))
    end
  end

  describe '#push' do
    it "invokes push workflow" do
      expect(workflows).to receive(:push).with(local_theme, remote_theme, destroy: true)
      described_class.start(%w(push))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      described_class.start(%w(push -p))
    end
  end

  describe '#sync' do
    it "invokes sync workflow" do
      expect(workflows).to receive(:sync).with(local_theme, remote_theme)
      described_class.start(%w(sync))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      described_class.start(%w(sync -p))
    end
  end

  describe '#compare' do
    it "invokes compare workflow" do
      expect(workflows).to receive(:compare).with(local_theme, remote_theme)
      described_class.start(%w(compare))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      described_class.start(%w(compare -p))
    end
  end

  describe '#watch' do
    it "invokes watch workflow" do
      expect(workflows).to receive(:watch).with('.', remote_theme)
      described_class.start(%w(watch))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      described_class.start(%w(watch -p))
    end
  end

  describe '#publish' do
    it "pushes local changes to dev and switches dev to production" do
      expect(workflows).to receive(:publish).with(local_theme, remote_theme)
      described_class.start(%w(publish))
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

  describe "#open" do
    it "opens the remote theme URL" do
      expect(remote_theme).to receive(:path).and_return 'https://acme.bootic.net/preview/dev'
      expect(Launchy).to receive(:open).with 'https://acme.bootic.net/preview/dev'
      described_class.start(%w(open))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      expect(remote_theme).to receive(:path).and_return 'https://acme.bootic.net'
      expect(Launchy).to receive(:open).with 'https://acme.bootic.net'
      described_class.start(%w(open -p))
    end
  end

  def it_setsup_dev_theme
    expect(selector).to receive(:setup_theme_pair) do |from, to, production|
      expect(from).to eq 'foo'
      expect(to).to eq 'bar'
      expect(production).to be false
    end.and_return [local_theme, remote_theme]
  end

  def it_setsup_production_theme
    expect(selector).to receive(:setup_theme_pair) do |from, to, production|
      expect(production).to be true
    end.and_return [local_theme, remote_theme]
  end

  def it_selects_dev_theme
    expect(selector)
      .to receive(:select_theme_pair)
      .with(nil, '.', false)
      .and_return [local_theme, remote_theme]
  end

  def it_selects_production_theme
    expect(selector).to receive(:select_theme_pair) do |from, to, production|
      expect(production).to be true
    end.and_return [local_theme, remote_theme]
  end
end
