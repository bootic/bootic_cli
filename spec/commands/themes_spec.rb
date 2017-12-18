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

  before do
    allow(BooticCli::Session).to receive(:new).and_return session
    allow(BooticCli::Themes::ThemeSelector).to receive(:select_theme_pair).and_return([local_theme, remote_theme])
    allow(BooticCli::Themes::Workflows).to receive(:new).and_return workflows
  end

  describe '#pull' do
    it "invokes pull workflow, delegates to ThemeSelector correctly" do
      it_selects_dev_theme
      expect(workflows).to receive(:pull).with(local_theme, remote_theme, destroy: true)
      described_class.start(%w(pull foo bar))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      described_class.start(%w(pull -p foo bar))
    end
  end

  describe '#push' do
    it "invokes push workflow" do
      expect(workflows).to receive(:push).with(local_theme, remote_theme, destroy: true)
      described_class.start(%w(push foo bar))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      described_class.start(%w(push -p foo bar))
    end
  end

  describe '#sync' do
    it "invokes sync workflow" do
      expect(workflows).to receive(:sync).with(local_theme, remote_theme)
      described_class.start(%w(sync foo bar))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      described_class.start(%w(sync -p foo bar))
    end
  end

  describe '#compare' do
    it "invokes compare workflow" do
      expect(workflows).to receive(:compare).with(local_theme, remote_theme)
      described_class.start(%w(compare foo bar))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      described_class.start(%w(compare -p foo bar))
    end
  end

  describe '#watch' do
    it "invokes watch workflow" do
      expect(workflows).to receive(:watch).with('bar', remote_theme)
      described_class.start(%w(watch foo bar))
    end

    it "uses production theme if -p option present" do
      it_selects_production_theme
      described_class.start(%w(watch -p foo bar))
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

  def it_selects_dev_theme
    expect(BooticCli::Themes::ThemeSelector).to receive(:select_theme_pair) do |from, to, prompt:, production:|
      expect(from).to eq 'foo'
      expect(to).to eq 'bar'
      expect(prompt).to be_a described_class::Prompt
      expect(production).to be false
    end.and_return [local_theme, remote_theme]
  end

  def it_selects_production_theme
    expect(BooticCli::Themes::ThemeSelector).to receive(:select_theme_pair) do |from, to, prompt:, production:|
      expect(production).to be true
    end.and_return [local_theme, remote_theme]
  end
end
