require 'spec_helper'
require 'bootic_cli/cli/themes/mem_theme'
require 'bootic_cli/cli/themes/operations'

describe BooticCli::Operations do
  let(:local_theme) { BooticCli::MemTheme.new }
  let(:remote_theme) { BooticCli::MemTheme.new }
  let(:prompt) { double('Prompt', yes_or_no?: true, notice: '', puts: '') }

  describe '#pull' do
    subject { described_class.new(prompt: prompt) }

    it "copies new remote files into local theme" do
      remote_theme.add_template('layout.html', 'aaa')
      remote_theme.add_template('master.css', 'bbb')
      remote_theme.add_asset('icon.gif', StringIO.new('icon'))

      subject.pull(local_theme, remote_theme)

      expect(local_theme.templates.map(&:file_name)).to eq ['layout.html', 'master.css']
      expect(local_theme.assets.map(&:file_name)).to eq ['icon.gif']
    end

    context 'updating templates updated in remote' do
      before do
        local_theme.add_template('layout.html', "aaa\n", mtime: Time.local(2016))
        remote_theme.add_template('layout.html', "bbb\n", mtime: Time.local(2017))
        remote_theme.add_template('master.css', 'bbb')
      end

      it "updates templates updated in remote" do
        subject.pull(local_theme, remote_theme)
        expect(local_theme.templates.map(&:file_name)).to eq ['layout.html', 'master.css']
      end

      it "does not update if declined by user" do
        expect(prompt).to receive(:yes_or_no?).with("Update local layout.html?", true).and_return false
        expect(local_theme).not_to receive(:add_template).with("layout.html", "bbb\n")
        subject.pull(local_theme, remote_theme)
      end
    end

    context "removing files absent in remote" do
      before do
        # these are not removed
        local_theme.add_template('layout.html', "aaa")
        remote_theme.add_template('layout.html', "bbb")
        local_theme.add_asset('icon.gif', StringIO.new('icon'))
        remote_theme.add_asset('icon.gif', StringIO.new('icon'))
        # these are removed
        local_theme.add_template('master.css', 'ccc')
        local_theme.add_template('product.html', 'dd')
        local_theme.add_asset('logo.gif', StringIO.new('logo'))
      end

      it "removes templates and assets absent in remote" do
        subject.pull(local_theme, remote_theme)

        expect(local_theme.templates.map(&:file_name)).to eq ['layout.html']
        expect(local_theme.assets.map(&:file_name)).to eq ['icon.gif']
      end

      it "does not remove if destroy: false" do
        subject.pull(local_theme, remote_theme, destroy: false)

        expect(local_theme.templates.map(&:file_name)).to eq ['layout.html', 'master.css', 'product.html']
        expect(local_theme.assets.map(&:file_name)).to eq ['icon.gif', 'logo.gif']
      end
    end

    context "adding new remote files" do
      before do
        remote_theme.add_template('layout.html', "bbb")
        remote_theme.add_asset('icon.gif', StringIO.new('icon'))
      end

      it "adds new remote templates and assets" do
        subject.pull(local_theme, remote_theme)

        expect(local_theme.templates.map(&:file_name)).to eq ['layout.html']
        expect(local_theme.assets.map(&:file_name)).to eq ['icon.gif']
      end
    end

    context "downloading new templates and assets" do
      before do
        # these are present in both
        remote_theme.add_template 'layout.html', "aa"
        local_theme.add_template 'layout.html', "aa"
        remote_theme.add_asset 'icon.gif', StringIO.new("icon")
        local_theme.add_asset 'icon.gif', StringIO.new("icon")
        # these are new in remote
        remote_theme.add_template 'product.html', "bb"
        remote_theme.add_template 'collection.html', "cc"
        remote_theme.add_asset 'logo.gif', StringIO.new("logo")
      end

      it "downloads new templates and assets, without overwriting existing assets" do
        expect(prompt).to receive(:yes_or_no?).with("Asset exists: icon.gif. Overwrite?", false).and_return false

        expect(local_theme).not_to receive(:add_template).with('layout.html', "aa")
        expect(local_theme).to receive(:add_template).with('product.html', "bb")
        expect(local_theme).to receive(:add_template).with('collection.html', "cc")
        expect(local_theme).not_to receive(:add_asset).with('icon.gif', StringIO)
        expect(local_theme).to receive(:add_asset).with('logo.gif', StringIO)

        subject.pull(local_theme, remote_theme)
      end

      it "does overwrite existing assets if user confirms" do
        expect(prompt).to receive(:yes_or_no?).with("Asset exists: icon.gif. Overwrite?", false).and_return true
        expect(local_theme).to receive(:add_asset).with('icon.gif', StringIO)
        expect(local_theme).to receive(:add_asset).with('logo.gif', StringIO)

        subject.pull(local_theme, remote_theme)
      end
    end
  end
end
