require 'spec_helper'
require 'bootic_cli/themes/mem_theme'
require 'bootic_cli/themes/workflows'

describe BooticCli::Themes::Workflows do
  let(:local_theme) { BooticCli::Themes::MemTheme.new }
  let(:remote_theme) { BooticCli::Themes::MemTheme.new }
  let(:prompt) { double('Prompt', yes_or_no?: true, notice: '', say: '') }
  subject { described_class.new(prompt: prompt) }

  describe '#pull' do
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
        expect(local_theme).not_to receive(:add_template).with("layout.html", String)
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

  describe '#push' do
    it "copies new local files into remote theme" do
      local_theme.add_template('layout.html', 'aaa')
      local_theme.add_template('master.css', 'bbb')
      local_theme.add_asset('icon.gif', StringIO.new('icon'))
      remote_theme.add_template('removed.css', 'bbb')
      remote_theme.add_asset('removed.gif', StringIO.new('removed'))

      subject.push(local_theme, remote_theme)

      expect(remote_theme.templates.map(&:file_name)).to eq ['layout.html', 'master.css']
      expect(remote_theme.assets.map(&:file_name)).to eq ['icon.gif']
    end

    context 'updating templates updated in local' do
      before do
        remote_theme.add_template('layout.html', "aaa\n", mtime: Time.local(2016))
        local_theme.add_template('layout.html', "bbb\n", mtime: Time.local(2017))
        local_theme.add_template('master.css', 'bbb')
      end

      it "updates templates updated in local, removes others" do
        subject.push(local_theme, remote_theme)
        expect(remote_theme.templates.map(&:file_name)).to eq ['layout.html', 'master.css']
      end

      it "does not update if declined by user" do
        expect(prompt).to receive(:yes_or_no?).with("Update remote layout.html?", true).and_return false
        expect(remote_theme).not_to receive(:add_template).with("layout.html", String)
        subject.push(local_theme, remote_theme)
      end
    end
  end

  describe "#sync" do
    before do
      # new in local
      local_theme.add_template('layout.html', 'aaa')
      local_theme.add_template('master.css', 'bbb')
      local_theme.add_asset('logo.gif', StringIO.new('icon'))
      # new in remote
      remote_theme.add_template('styles.css', 'bbb')
      remote_theme.add_asset('icon.gif', StringIO.new('icon'))
      # updated in local
      remote_theme.add_template('product.html', "aaa\n", mtime: Time.local(2016))
      local_theme.add_template('product.html', "bbb\n", mtime: Time.local(2017))
      # updated in remote
      local_theme.add_template('collection.html', "aaa\n", mtime: Time.local(2016))
      remote_theme.add_template('collection.html', "bbb\n", mtime: Time.local(2017))
    end

    it "syncs up local and remote themes" do
      subject.sync(local_theme, remote_theme)

      remote_templates = remote_theme.templates.map(&:file_name).sort
      local_templates = local_theme.templates.map(&:file_name).sort
      remote_assets = remote_theme.assets.map(&:file_name).sort
      local_assets = local_theme.assets.map(&:file_name).sort

      expect(remote_templates).to eq local_templates
      expect(remote_assets).to eq local_assets

      expect(remote_templates).to eq ['layout.html', 'master.css', 'styles.css', 'product.html', 'collection.html'].sort
      expect(remote_assets).to eq ['icon.gif', 'logo.gif']
    end
  end

  describe "#compare" do
    before do
      # new in local
      local_theme.add_template('layout.html', 'aaa')
      local_theme.add_template('master.css', 'bbb')
      local_theme.add_asset('logo.gif', StringIO.new('icon'))
      # new in remote
      remote_theme.add_template('styles.css', 'bbb')
      remote_theme.add_asset('icon.gif', StringIO.new('icon'))
      # updated in local
      remote_theme.add_template('product.html', "aaa\n", mtime: Time.local(2016))
      local_theme.add_template('product.html', "bbb\n", mtime: Time.local(2017))
      # updated in remote
      local_theme.add_template('collection.html', "aaa\n", mtime: Time.local(2016))
      remote_theme.add_template('collection.html', "bbb\n", mtime: Time.local(2017))
    end

    it "compares" do
      expect(prompt).to receive(:say).with("Updated in remote: collection.html")
      expect(prompt).to receive(:say).with("Remote template not in local dir: styles.css")
      expect(prompt).to receive(:say).with("Remote asset not in local dir: icon.gif")
      expect(prompt).to receive(:say).with("Updated locally: product.html")
      expect(prompt).to receive(:say).with("Local template not in remote: master.css")
      expect(prompt).to receive(:say).with("Local asset not in remote: logo.gif")

      subject.compare(local_theme, remote_theme)
    end
  end

  describe "#watch" do
    it "watches" do
      remote_theme.add_template('collection.html', "aa")
      remote_theme.add_template('product.html', "bb")
      remote_theme.add_asset('icon.gif', StringIO.new("icon"))
      remote_theme.add_asset('logo.gif', StringIO.new("logo"))

      fake_listen = Class.new do
        attr_accessor :block
        def initialize(modified, added, removed)
          @parts = [modified, added, removed]
        end

        def to(dir, &block)
          self.block = block
          self
        end

        def run(modified, added, removed)
          self.block.call(modified, added, removed)
        end

        def start
          self.block.call(*@parts)
        end

        def stop;end
      end

      watcher = fake_listen.new(
        # modified
        ['./spec/fixtures/theme/layout.html'],
        # added
        ['./spec/fixtures/theme/master.css', './spec/fixtures/theme/assets/script.js'],
        # removed
        ['./spec/fixtures/theme/product.html'],
      )

      dir = "./spec/fixtures/theme"

      # silence reloading
      expect(remote_theme).to receive(:reload!).and_return true
      expect(Kernel).to receive(:sleep)
      subject.watch(dir, remote_theme, watcher: watcher)

      expect(remote_theme.templates.map(&:file_name)).to eq ['collection.html', 'layout.html', 'master.css']
    end
  end
end
