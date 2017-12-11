require 'spec_helper'
require 'time'
require 'bootic_cli/cli/themes/theme_diff'

describe BooticCli::ThemeDiff do
  before do
    local_layout = local_file('layout.html')
    local_css = local_file('master.css')
    templates = [
      double('Template', file_name: 'layout.html', body: '<h1>nuevo!</h1>', updated_on: (local_layout.mtime + 10).iso8601),
      double('Template', file_name: 'master.css', body: 'body {}', updated_on: (local_css.mtime - 10).iso8601),
      double('Template', file_name: 'product.html', body: 'Hi!', updated_on: (local_css.mtime + 10).iso8601),
    ]
    assets = [
      double('Asset', file_name: 'logo.gif')
    ]

    @theme = double('Theme', templates: templates, assets: assets)
  end

  subject { described_class.new('./spec/fixtures/theme', @theme) }

  describe "#templates_updated_in_remote" do
    it "lists updated remote templates" do
      expect(subject.templates_updated_in_remote.size).to eq 1
      expect(subject.templates_updated_in_remote.first.file_name).to eq 'layout.html'
    end
  end

  describe "#templates_updated_locally" do
    it "lists updated local templates" do
      expect(subject.templates_updated_locally.size).to eq 1
      expect(subject.templates_updated_locally.first.file_name).to eq 'master.css'
    end
  end

  describe "#remote_templates_not_in_dir" do
    it "list remote remplates not in local dir" do
      expect(subject.remote_templates_not_in_dir.size).to eq 1
      expect(subject.remote_templates_not_in_dir.first.file_name).to eq 'product.html'
    end
  end

  describe "#remote_assets_not_in_dir" do
    it "list remote assets not in local dir" do
      expect(subject.remote_assets_not_in_dir.size).to eq 1
      expect(subject.remote_assets_not_in_dir.first.file_name).to eq 'logo.gif'
    end
  end

  describe "#local_templates" do
    it "lists local templates" do
      expect(subject.local_templates.size).to eq 2
      expect(subject.local_templates.map(&:file_name)).to eq ['layout.html', 'master.css']
    end
  end

  describe "#local_assets" do
    it "lists local assets" do
      expect(subject.local_assets.size).to eq 1
      expect(subject.local_assets.map(&:file_name)).to eq ['script.js']
    end
  end

  def local_file(name)
    File.new(File.join('.', 'spec', 'fixtures', 'theme', name))
  end
end
