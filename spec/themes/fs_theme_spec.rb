require 'spec_helper'
require 'bootic_cli/themes/fs_theme'

describe BooticCli::Themes::FSTheme do
  subject { described_class.new('./spec/fixtures/theme') }

  before :all do
    path = File.expand_path('./spec/fixtures/theme/.state')
    File.unlink path if File.exists?(path)
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

    expect(subject.templates.size).to eq 2
    it_is_a_template(subject.templates.first, file_name: 'layout.html')
    it_is_a_template(subject.templates.last, file_name: 'master.css')
  end

  it "#add_template" do
    subject.add_template 'foo.html', 'Hello!'

    file = File.new('./spec/fixtures/theme/foo.html')
    expect(file.read).to eq 'Hello!'

    expect(subject.templates.size).to eq 3
    expect(subject.templates.map(&:file_name).sort).to eq ['foo.html', 'layout.html', 'master.css']
    tpl = subject.templates.find{|t| t.file_name == 'foo.html' }
    expect(tpl.updated_on).to eq file.mtime.utc

    subject.remove_template 'foo.html'
  end

  it "#remove_template" do
    subject.add_template 'foo.html', 'Hello!'
    subject.remove_template 'foo.html'

    expect(subject.templates.size).to eq 2
    expect(File.exists?('./spec/fixtures/theme/foo.html')).to be false
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
    expect(File.exists?('./spec/fixtures/theme/assets/foo.js')).to be false
  end
end
