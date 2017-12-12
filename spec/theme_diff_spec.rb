require 'spec_helper'
require 'time'
require 'bootic_cli/cli/themes/mem_theme'
require 'bootic_cli/cli/themes/theme_diff'

describe BooticCli::ThemeDiff do
  let(:source_theme) { BooticCli::MemTheme.new }
  let(:target_theme) { BooticCli::MemTheme.new }

  subject { described_class.new(source: source_theme, target: target_theme) }

  context "updated templates" do
    it "#templates_updated_in_source" do
      # these 2 are the same
      Timecop.freeze Time.local(2017) do
        source_theme.add_template 'layout.html', "aaa"
        target_theme.add_template 'layout.html', "aaa"
      end

      # this one is newest in source
      Timecop.freeze Time.local(2017, 12, 12, 0, 0, 1) do
        source_theme.add_template 'master.css', "body { background: red; }"
      end
      Timecop.freeze Time.local(2017, 12, 12, 0, 0, 0) do
        target_theme.add_template 'master.css', "body { background: green;}"
      end

      expect(subject.templates_updated_in_source.size).to eq 1
      expect(subject.templates_updated_in_source.first.file_name).to eq 'master.css'
      expect(subject.templates_updated_in_source.first.diff).to be_a Diffy::Diff
      expect(subject.templates_updated_in_source.first.body).to eq "body { background: red; }"
    end

    it "#templates_updated_in_target" do
      # this one is newest in target
      Timecop.freeze Time.local(2017, 12, 12, 0, 0, 1) do
        target_theme.add_template 'foo.css', "body { background: red; }"
      end
      Timecop.freeze Time.local(2017, 12, 12, 0, 0, 0) do
        source_theme.add_template 'foo.css', "body { background: green;}"
      end

      expect(subject.templates_updated_in_target.first.file_name).to eq 'foo.css'
    end
  end

  context "missing templates" do
    before do
      source_theme.add_template 'foo.css', "body { background: green;}"
      source_theme.add_template 'layout.html', "hello"
      source_theme.add_template 'common.html', "bye"

      target_theme.add_template 'common.html', "bye"
      target_theme.add_template 'targetonly.html', "wat"
    end

    it "#source_templates_not_in_target" do
      expect(subject.source_templates_not_in_target.size).to eq 2
      expect(subject.source_templates_not_in_target.first.file_name).to eq 'foo.css'
      expect(subject.source_templates_not_in_target.last.file_name).to eq 'layout.html'
    end

    it "#target_templates_not_in_source" do
      expect(subject.target_templates_not_in_source.size).to eq 1
      expect(subject.target_templates_not_in_source.first.file_name).to eq 'targetonly.html'
    end
  end

  context "missing assets" do
    before do
      source_theme.add_asset 'foo.css', StringIO.new("body { background: green;}")
      source_theme.add_asset 'layout.html', StringIO.new("hello")
      source_theme.add_asset 'common.html', StringIO.new("bye")

      target_theme.add_asset 'common.html', StringIO.new("bye")
      target_theme.add_asset 'targetonly.html', StringIO.new("wat")
    end

    it "#source_assets_not_in_target" do
      expect(subject.source_assets_not_in_target.size).to eq 2
      expect(subject.source_assets_not_in_target.first.file_name).to eq 'foo.css'
      expect(subject.source_assets_not_in_target.last.file_name).to eq 'layout.html'
    end

    it "#target_assets_not_in_source" do
      expect(subject.target_assets_not_in_source.size).to eq 1
      expect(subject.target_assets_not_in_source.first.file_name).to eq 'targetonly.html'
    end
  end
end
