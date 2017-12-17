require 'spec_helper'
require 'bootic_cli/themes/theme_selector'

describe BooticCli::Themes::ThemeSelector do
  let(:remote_theme) { double('Remote theme') }
  let(:shop) { double('Shop', subdomain: 'foo', theme: remote_theme) }
  let(:root) { double('Root', has?: true, shops: [shop]) }

  around do |ex|
    ex.run
    File.unlink File.expand_path('./spec/fixtures/theme/.state')
  end

  before do
    allow(root).to receive(:all_shops)
      .with(subdomains: 'foo').and_return [shop]
  end

  describe ".select_theme_pair" do
    it "with subdomain and valid shop" do
      a, b = described_class.select_theme_pair('foo', './spec/fixtures/theme', root)

      it_is_local_theme a
      it_is_remote_theme b
    end

    it "without subdomain it infers it from dir" do
      expect(root).to receive(:all_shops)
        .with(subdomains: 'theme').and_return [shop]

      a, b = described_class.select_theme_pair(nil, './spec/fixtures/theme', root)

      it_is_local_theme a
      it_is_remote_theme b
    end

    it "stores subdomain in local state the first time" do
      described_class.select_theme_pair('foo', './spec/fixtures/theme', root)
      expect(root).to receive(:all_shops)
        .with(subdomains: 'foo').and_return [shop]

      a, b = described_class.select_theme_pair(nil, './spec/fixtures/theme', root)

      it_is_local_theme a
      it_is_remote_theme b
    end

    it "defaults to user main shop if no subdomain and dirname doesn't match" do
      expect(root).to receive(:has?).with(:all_shops).and_return false
      expect(root).to receive(:shops).and_return [shop]

      a, b = described_class.select_theme_pair(nil, './spec/fixtures/theme', root)

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
