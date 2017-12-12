require 'spec_helper'
require 'bootic_cli/cli/themes/fs_theme'

describe BooticCli::FSTheme do
  subject { described_class.new('./spec/fixtures/theme') }

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

  def it_is_an_asset(asset, file_name: nil)
    expect(asset.file_name).to eq file_name
  end

  def it_is_a_template(tpl, file_name: nil)
    expect(tpl.file_name).to eq file_name
  end
end
