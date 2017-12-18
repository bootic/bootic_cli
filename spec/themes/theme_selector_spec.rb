require 'spec_helper'
require 'bootic_cli/themes/theme_selector'

describe BooticCli::Themes::ThemeSelector do
  let(:prod_theme) { double('Prod theme', rels: {theme_preview: double('link', href: 'https://acme.bootic.net')}) }
  let(:dev_theme) { double('Dev theme', rels: {theme_preview: double('link', href: 'https://acme.bootic.net/preview/dev')}) }
  let(:themes) { double('Themes', theme: prod_theme, dev_theme: dev_theme) }
  let(:shop) { double('Shop', subdomain: 'foo', themes: themes, theme: prod_theme) }
  let(:root) { double('Root', has?: true, shops: [shop]) }
  let(:prompt) { double('Prompt', say: true) }

  around do |ex|
    ex.run
    File.unlink File.expand_path('./spec/fixtures/theme/.state')
  end

  before do
    allow(root).to receive(:all_shops)
      .with(subdomains: 'foo').and_return [shop]
    allow(themes).to receive(:has?).with(:dev_theme).and_return true
  end

  describe ".select_theme_pair" do
    it "with subdomain and valid shop" do
      expect(themes).not_to receive(:create_dev_theme)
      a, b = described_class.select_theme_pair('foo', './spec/fixtures/theme', root, prompt: prompt)

      it_is_local_theme a
      it_is_remote_theme b
    end

    it "creates dev theme if not available yet" do
      expect(themes).to receive(:has?).with(:dev_theme).and_return false
      expect(themes).to receive(:can?).with(:create_dev_theme).and_return true
      expect(themes).to receive(:create_dev_theme).and_return dev_theme
      a, b = described_class.select_theme_pair('foo', './spec/fixtures/theme', root, prompt: prompt)

      it_is_local_theme a
      it_is_remote_theme b
    end

    it "without subdomain it infers it from dir" do
      expect(root).to receive(:all_shops)
        .with(subdomains: 'theme').and_return [shop]

      a, b = described_class.select_theme_pair(nil, './spec/fixtures/theme', root, prompt: prompt)

      it_is_local_theme a
      it_is_remote_theme b
    end

    it "stores subdomain in local state the first time" do
      described_class.select_theme_pair('foo', './spec/fixtures/theme', root, prompt: prompt)
      expect(root).to receive(:all_shops)
        .with(subdomains: 'foo').and_return [shop]

      a, b = described_class.select_theme_pair(nil, './spec/fixtures/theme', root, prompt: prompt)

      it_is_local_theme a
      it_is_remote_theme b
    end

    it "defaults to user main shop if no subdomain and dirname doesn't match" do
      expect(root).to receive(:has?).with(:all_shops).and_return false
      expect(root).to receive(:shops).and_return [shop]

      a, b = described_class.select_theme_pair(nil, './spec/fixtures/theme', root, prompt: prompt)

      it_is_local_theme a
      it_is_remote_theme b
    end
  end

  def it_is_local_theme(theme)
    expect(theme).to be_a BooticCli::Themes::FSTheme
    expect(theme.templates.map(&:file_name)).to eq ['layout.html', 'master.css']
  end

  def it_is_remote_theme(theme)
    expect(theme).to be_a BooticCli::Themes::APITheme
  end
end
