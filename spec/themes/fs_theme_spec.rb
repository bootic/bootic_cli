require 'spec_helper'
require 'bootic_cli/themes/fs_theme'

describe BooticCli::Themes::FSTheme do
  subject { described_class.new('./spec/fixtures/theme') }

  before :all do
    path = File.expand_path('./spec/fixtures/theme/.state')
    File.unlink path if File.exist?(path)
  end

  describe "#subdomain" do
    it "is nil by default" do
      expect(subject.subdomain).to eq nil
    end

    it "can be initialized and persisted" do
      theme = described_class.new('./spec/fixtures/theme2', subdomain: 'foo')
      expect(theme.subdomain).to eq 'foo'
      theme.write_subdomain

      theme2 = described_class.new('./spec/fixtures/theme2')
      expect(theme2.subdomain).to eq 'foo'

      theme2.reset!
    end
  end

  it "responds to #templates and #assets" do
    expect(subject.assets.size).to eq 1
    it_is_an_asset(subject.assets.first, file_name: 'script.js')

    expect(subject.templates.size).to eq 5
    it_is_a_template(subject.templates[0], file_name: 'layout.html')
    it_is_a_template(subject.templates[1], file_name: 'master.css')
    it_is_a_template(subject.templates[2], file_name: 'strings.en.json')
    it_is_a_template(subject.templates[3], file_name: 'sections/gallery.html')
    it_is_a_template(subject.templates[4], file_name: 'data/test.json')
  end

  it "#add_template" do
    subject.add_template 'foo.html', 'Hello!'

    file = File.new('./spec/fixtures/theme/foo.html')
    expect(file.read).to eq 'Hello!'

    expect(subject.templates.size).to eq 6
    expect(subject.templates.map(&:file_name).sort).to eq ['data/test.json', 'foo.html', 'layout.html', 'master.css', 'sections/gallery.html', 'strings.en.json']
    tpl = subject.templates.find{|t| t.file_name == 'foo.html' }
    expect(tpl.updated_on).to eq file.mtime.utc

    subject.remove_template 'foo.html'
  end

  it "#remove_template" do
    subject.add_template 'foo.html', 'Hello!'
    subject.remove_template 'foo.html'

    expect(subject.templates.size).to eq 5
    expect(File.exist?('./spec/fixtures/theme/foo.html')).to be false
  end

  it "#add_asset" do
    expect(subject.assets.size).to eq 1

    subject.add_asset 'foo.js', StringIO.new("var a = 2")

    file = File.new('./spec/fixtures/theme/assets/foo.js')
    expect(file.read).to eq "var a = 2"

    expect(subject.assets.size).to eq 2
    expect(subject.assets.map(&:file_name).sort).to eq ['foo.js', 'script.js']
    asset = subject.assets.find{|t| t.file_name == 'foo.js' }
    expect(asset.updated_on).to eq file.mtime.utc

    subject.remove_asset 'foo.js'
  end

  it "#remove_asset" do
    subject.add_asset 'foo.js', StringIO.new("var a = 2")
    subject.remove_asset 'foo.js'

    expect(subject.assets.size).to eq 1
    expect(File.exist?('./spec/fixtures/theme/assets/foo.js')).to be false
  end

  describe "v2 theme structure" do
    subject { described_class.new('./spec/fixtures/theme_v2') }

    before :all do
      path = File.expand_path('./spec/fixtures/theme_v2/.state')
      File.unlink path if File.exist?(path)
    end

    it "loads templates from layouts/, templates/, sections/, and strings/" do
      expect(subject.templates.map(&:file_name).sort).to eq [
        'layouts/layout.html',
        'sections/gallery.html',
        'strings/es.json',
        'templates/product.html',
      ]
    end

    it "loads public/ assets with subpath as file_name (no 'public/' prefix)" do
      expect(subject.assets.map(&:file_name).sort).to eq ['css/main.css', 'images/logo.png']
    end

    it "#add_template writes into the correct v2 subdir" do
      subject.add_template 'layouts/layout2.html', '<html>v2</html>'
      expect(File.exist?('./spec/fixtures/theme_v2/layouts/layout2.html')).to be true
      subject.remove_template 'layouts/layout2.html'
    end

    it "#add_asset with subpath writes under public/" do
      subject.add_asset 'css/extra.css', StringIO.new("h1 {}")
      expect(File.exist?('./spec/fixtures/theme_v2/public/css/extra.css')).to be true
      subject.remove_asset 'css/extra.css'
    end

    it "#remove_asset with subpath deletes from public/" do
      subject.add_asset 'css/tmp.css', StringIO.new("p {}")
      subject.remove_asset 'css/tmp.css'
      expect(File.exist?('./spec/fixtures/theme_v2/public/css/tmp.css')).to be false
    end

    describe ".resolve_type" do
      it "resolves layouts/ files as :template" do
        expect(described_class.resolve_type('./spec/fixtures/theme_v2/layouts/layout.html', './spec/fixtures/theme_v2')).to eq :template
      end

      it "resolves templates/ files as :template" do
        expect(described_class.resolve_type('./spec/fixtures/theme_v2/templates/product.html', './spec/fixtures/theme_v2')).to eq :template
      end

      it "resolves strings/ json files as :template" do
        expect(described_class.resolve_type('./spec/fixtures/theme_v2/strings/es.json', './spec/fixtures/theme_v2')).to eq :template
      end

      it "resolves public/ files as :asset" do
        expect(described_class.resolve_type('./spec/fixtures/theme_v2/public/css/main.css', './spec/fixtures/theme_v2')).to eq :asset
      end
    end

    describe ".resolve_file for a public/ asset" do
      it "strips the 'public/' prefix so file_name matches the API convention" do
        item, type = described_class.resolve_file('./spec/fixtures/theme_v2/public/css/main.css', './spec/fixtures/theme_v2')
        expect(type).to eq :asset
        expect(item.file_name).to eq 'css/main.css'
      end
    end
  end
end
