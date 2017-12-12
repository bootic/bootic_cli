require 'spec_helper'
require 'bootic_cli/cli/themes/fs_theme'

describe BooticCli::FSTheme do
  it "responds to #templates and #assets" do
    fs = described_class.new('./spec/fixtures/theme')
    expect(fs.assets.size).to eq 1
    it_is_an_asset(fs.assets.first, file_name: 'script.js')

    expect(fs.templates.size).to eq 2
    it_is_a_template(fs.templates.first, file_name: 'layout.html')
    it_is_a_template(fs.templates.last, file_name: 'master.css')
  end

  it "#add_template" do
    fs = described_class.new('./spec/fixtures/theme')

    fs.add_template 'foo.html', 'Hello!'

    tpl = File.new('./spec/fixtures/theme/foo.html')
    expect(tpl.read).to eq 'Hello!'

    expect(fs.templates.size).to eq 3
    expect(fs.templates.map(&:file_name).sort).to eq ['foo.html', 'layout.html', 'master.css']

    fs.remove_template 'foo.html'
  end

  it "#remove_template" do
    fs = described_class.new('./spec/fixtures/theme')

    fs.add_template 'foo.html', 'Hello!'
    fs.remove_template 'foo.html'

    expect(fs.templates.size).to eq 2
    expect(File.exists?('./spec/fixtures/theme/foo.html')).to be false
  end

  it "#add_asset" do
    fs = described_class.new('./spec/fixtures/theme')

    expect(fs.assets.size).to eq 1

    fs.add_asset 'foo.js', StringIO.new("var a = 2")

    file = File.new('./spec/fixtures/theme/assets/foo.js')
    expect(file.read).to eq "var a = 2"

    expect(fs.assets.size).to eq 2
    expect(fs.assets.map(&:file_name).sort).to eq ['foo.js', 'script.js']

    File.unlink './spec/fixtures/theme/assets/foo.js'
  end

  it "#remove_asset" do
    fs = described_class.new('./spec/fixtures/theme')

    fs.add_asset 'foo.js', StringIO.new("var a = 2")
    fs.remove_asset 'foo.js'

    expect(fs.assets.size).to eq 1
    expect(File.exists?('./spec/fixtures/theme/assets/foo.js')).to be false
  end

  def it_is_an_asset(asset, file_name: nil)
    expect(asset.file_name).to eq file_name
  end

  def it_is_a_template(tpl, file_name: nil)
    expect(tpl.file_name).to eq file_name
  end
end
