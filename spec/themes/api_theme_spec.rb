require 'spec_helper'
require 'bootic_cli/themes/api_theme'

describe BooticCli::Themes::APITheme do
  let(:theme) { double("API Theme", has?: false, rels: {theme_preview: double(href: 'http://www.foo.bar')}) }
  subject { described_class.new(theme) }

  it "#path" do
    expect(subject.path).to eq 'http://www.foo.bar'
  end

  it "responds to #templates and #assets" do
    allow(theme).to receive(:assets).and_return([
      double('API asset', file_name: 'script.js', updated_on: '2017-02-03T12:12:12Z')
    ])
    allow(theme).to receive(:templates).and_return([
      double('API template', file_name: 'layout.html', updated_on: '2017-01-02T00:10:10Z'),
      double('API template', file_name: 'master.css', updated_on: '2017-02-02T11:11:11Z'),
    ])

    expect(subject.assets.size).to eq 1
    expect(subject.assets.first.updated_on.iso8601).to eq '2017-02-03T12:12:12Z'
    it_is_an_asset(subject.assets.first, file_name: 'script.js')

    expect(subject.templates.size).to eq 2
    expect(subject.templates.first.updated_on.iso8601).to eq '2017-01-02T00:10:10Z'
    it_is_a_template(subject.templates.first, file_name: 'layout.html')
    it_is_a_template(subject.templates.last, file_name: 'master.css')
  end

  it "#add_template" do
    api_template = double('API Template', file_name: 'foo.html', updated_on: '2017-01-01T00:10:10Z', has?: false)
    allow(theme).to receive(:templates).and_return([api_template])

    expect(theme).to receive(:create_template).with({
      file_name: 'foo.html',
      body: 'Hello!',
      last_updated_on: Time.parse('2017-01-01T00:10:10Z').to_i
    }).and_return api_template

    expect(subject.add_template('foo.html', 'Hello!')).to eq api_template
  end

  it "#remove_template" do
    api_template = double('API template', file_name: 'foo.html', can?: true)
    allow(theme).to receive(:templates).and_return([
      api_template
    ])
    expect(api_template).to receive(:delete_template).and_return(double('API response', status: 200, has?: false))
    subject.remove_template 'foo.html'
  end

  it "#add_asset" do
    api_asset = double('API Asset', file_name: 'foo.js', has?: false)
    expect(theme).to receive(:create_theme_asset) do |opts|
      expect(opts[:file_name]).to eq 'foo.js'
      expect(opts[:data]).to be_a StringIO
    end.and_return api_asset

    expect(subject.add_asset('foo.js', StringIO.new("var a = 2"))).to eq api_asset
  end

  it "#remove_asset" do
    api_asset = double('API Asset', file_name: 'foo.js', can?: true)
    allow(theme).to receive(:assets).and_return([
      api_asset
    ])
    expect(api_asset).to receive(:delete_theme_asset).and_return(double('API response', status: 200, has?: false))
    subject.remove_asset 'foo.js'
  end

  describe "#publish (not part of Theme interface" do
    it "publishes if API theme supports it" do
      expect(theme).to receive(:can?).with(:publish_theme).and_return true
      expect(theme).to receive(:publish_theme).and_return theme
      expect(theme).not_to receive(:create_dev_theme)

      expect(subject.publish).to be_a described_class
    end
  end
end
