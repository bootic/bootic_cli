require 'spec_helper'
require 'bootic_cli/themes/theme_selector'

describe BooticCli::Themes::ThemeSelector do
  let(:prod_theme) { double('Prod theme', dev?: false, has?: false, rels: { theme_preview: double('link', href: 'https://acme.bootic.net')}) }
  let(:dev_theme) { double('Dev theme', dev?: true, has?: false, rels: { theme_preview: double('link', href: 'https://acme.bootic.net/preview/dev')}) }
  let(:themes) { double('Themes', theme: prod_theme, dev_theme: dev_theme) }
  let(:shop) { double('Shop', subdomain: 'foo', themes: themes, theme: prod_theme) }
  let(:root) { double('Root', has?: true, shops: [shop]) }
  let(:prompt) { double('Prompt', say: true) }
  subject { described_class.new(root, prompt: prompt) }

  before do
    allow(root).to receive(:all_shops).with(subdomains: 'foo').and_return [shop]
    allow(themes).to receive(:has?).with(:dev_theme).and_return true
    allow(themes).to receive(:can?).with(:create_dev_theme).and_return(true)

    allow(prod_theme).to receive(:can?).with(:publish_theme).and_return(false)
    allow(dev_theme).to receive(:can?).with(:publish_theme).and_return(true)
  end

  describe "#setup_theme_pair" do
    it "selects default shop when no subdomain" do
      expect(root).to receive(:shops).and_return [shop]
      a, b = subject.setup_theme_pair(nil, './spec/fixtures/theme')

      expect(a.path).to eq File.expand_path('./spec/fixtures/theme')
      it_is_local_theme a
      it_is_remote_theme b
    end

    it "sets up new dir after shop subdomain if no dir passed" do
      expect(root).to receive(:shops).and_return [shop]
      a, b = subject.setup_theme_pair(nil, nil)

      expect(a.path).to eq File.expand_path(shop.subdomain)
      it_is_remote_theme b
    end

    context 'with production: nil, dev: nil' do
      describe 'no dev theme' do
        before do
          expect(themes).to receive(:has?).with(:dev_theme).and_return(false)
        end

        it 'prompts user if he/she wants to create a new dev theme' do
          expect(prompt).to receive(:yes_or_no?).with('Would you like to create (and work on) a development version of your theme? (recommended)', true)
          a, b = subject.setup_theme_pair(nil, nil)
        end

        context 'if answer is no' do
          it 'returns public theme' do
            allow(prompt).to receive(:yes_or_no?).with('Would you like to create (and work on) a development version of your theme? (recommended)', true).and_return(false)
            # expect(themes).not_to receive(:dev_theme)
            a, b = subject.setup_theme_pair(nil, nil)
            expect(b.dev?).to eq(false)
          end
        end

        context 'if answer is yes' do
          it 'creates and returns dev theme' do
            allow(prompt).to receive(:yes_or_no?).with('Would you like to create (and work on) a development version of your theme? (recommended)', true).and_return(true)
            expect(themes).to receive(:create_dev_theme).and_return(dev_theme)
            a, b = subject.setup_theme_pair(nil, nil)
            expect(b.dev?).to eq(true)
          end
        end

      end

      describe 'with existing dev theme' do
        before do
          expect(themes).to receive(:has?).with(:dev_theme).and_return(true)
        end

        it 'returns dev theme' do
          expect(themes).to receive(:dev_theme)
          a, b = subject.setup_theme_pair(nil, nil)
          expect(b.dev?).to eq(true)
        end
      end
    end

    context 'with production: true, dev: nil' do
      describe 'no dev theme' do
        before do
          # allow(themes).to receive(:has?).with(:dev_theme).and_return false
        end

        it 'returns public theme, without prompting user ' do
          expect(themes).not_to receive(:dev_theme)
          expect(prompt).not_to receive(:yes_or_no?)
          a, b = subject.setup_theme_pair(nil, nil, true)
          expect(b.dev?).to eq(false)
        end
      end

      describe 'with existing dev theme' do
        before do
          allow(themes).to receive(:has?).with(:dev_theme).and_return(true)
        end

        it 'returns public remote theme anyway, without prompting user' do
          expect(themes).not_to receive(:dev_theme)
          expect(prompt).not_to receive(:yes_or_no?)
          a, b = subject.setup_theme_pair(nil, nil, true)
          expect(b.dev?).to eq(false)
        end
      end
    end

    context 'with production: nil, dev: true' do
      describe 'no dev theme' do
        before do
          expect(themes).to receive(:has?).with(:dev_theme).and_return false
        end

        it 'creates and returns dev theme, without prompting user' do
          expect(themes).to receive(:create_dev_theme).and_return(dev_theme)
          expect(prompt).not_to receive(:yes_or_no?)
          a, b = subject.setup_theme_pair(nil, nil, nil, true)
          expect(b.dev?).to eq(true)
        end
      end

      describe 'with existing dev theme' do
        before do
          expect(themes).to receive(:has?).with(:dev_theme).and_return(true)
        end

        it 'returns dev theme' do
          expect(themes).to receive(:dev_theme)
          a, b = subject.setup_theme_pair(nil, nil, nil, true)
          expect(b.dev?).to eq(true)
        end
      end
    end

  end

  describe "#select_theme_pair" do
    it "with subdomain and valid shop" do
      expect(themes).not_to receive(:create_dev_theme)
      a, b = subject.select_theme_pair('foo', './spec/fixtures/theme')

      it_is_local_theme a
      it_is_remote_theme b
    end

    it "does not create dev theme if not present yet" do
      expect(themes).to receive(:has?).with(:dev_theme).and_return false
      expect(themes).not_to receive(:can?).with(:create_dev_theme) #.and_return true
      expect(themes).not_to receive(:create_dev_theme)
      a, b = subject.select_theme_pair('foo', './spec/fixtures/theme')

      it_is_local_theme a
      it_is_remote_theme b
    end

    it "works directly on production theme if option passed" do
      expect(shop).to receive(:theme).and_return prod_theme
      expect(shop).not_to receive(:themes)
      subject.select_theme_pair('foo', './spec/fixtures/theme', true)
    end
  end

  describe "#pair" do
    it "pairs local dir to shop subdomain" do
      dir = "./spec/fixtures/theme"
      theme = instance_double(BooticCli::Themes::FSTheme)
      expect(BooticCli::Themes::FSTheme).
        to receive(:new).
        with(File.expand_path(dir), subdomain: "foo").
        and_return(theme)

      expect(theme).to receive(:write_subdomain)
      expect(subject.pair("foo", dir)).to eq theme
    end

    it "raises if no shop found" do
      allow(root).to receive(:all_shops).with(subdomains: 'foo').and_return []
      expect{
        subject.pair("foo", '.')
      }.to raise_error RuntimeError
    end
  end

  def it_is_local_theme(theme)
    expect(theme).to be_a BooticCli::Themes::FSTheme
    expect(theme.templates.map(&:file_name)).to eq ['layout.html', 'master.css', 'strings.en.json', "sections/gallery.html", "data/test.json"]
  end

  def it_is_remote_theme(theme)
    expect(theme).to be_a BooticCli::Themes::APITheme
  end
end
