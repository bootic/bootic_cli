require 'spec_helper'
require 'bootic_cli/themes/mem_theme'
require 'bootic_cli/themes/updated_theme'

describe BooticCli::Themes::UpdatedTheme do
  let(:source) { BooticCli::Themes::MemTheme.new }
  let(:target) { BooticCli::Themes::MemTheme.new }

  before do
    # newer in source
    source.add_template('layout.html', "aa2\n", mtime: Time.local(2017, 12, 13, 0, 0, 1))
    target.add_template('layout.html', "aa1\n", mtime: Time.local(2017, 12, 13, 0, 0, 0))
    source.add_template('product.html', "bb2\n", mtime: Time.local(2017, 12, 13, 0, 2, 1))
    target.add_template('product.html', "bb1\n", mtime: Time.local(2017, 12, 13, 0, 0, 1))
    # this one is newer in source, but content is the same
    source.add_template('nodiff.html', "content", mtime: Time.local(2017, 12, 13, 0, 2, 1))
    target.add_template('nodiff.html', "content", mtime: Time.local(2017, 12, 13, 0, 0, 1))
    source.add_asset('icon.gif', StringIO.new("bb"), mtime: Time.local(2017, 12, 13, 0, 0, 1))
    target.add_asset('icon.gif', StringIO.new("bb"), mtime: Time.local(2017, 11, 13, 0, 0, 1))

    # missing in source
    target.add_template('collection.html', "collection", mtime: Time.local(2017, 12, 13, 0, 0, 1))

    # newer in target
    source.add_template('page.html', "aa", mtime: Time.local(2017, 12, 13, 0, 0, 1))
    target.add_template('page.html', "aa", mtime: Time.local(2017, 12, 13, 0, 3, 0))
  end

  describe "#templates" do
    let(:theme) { described_class.new(source: source, target: target) }

    it 'returns templates that are newer in source and content is different' do
      expect(theme.templates.map(&:file_name)).to eq ['layout.html', 'product.html']
    end

    it 'includes diff object' do
      expect(theme.templates.first.diff).to be_a Diffy::Diff
      expect(theme.templates.first.diff.to_s).to eq "-aa1\n+aa2\n"
    end
  end

  describe "#assets" do
    it 'returns assets that are newer in source' do
      theme = described_class.new(source: source, target: target)
      expect(theme.assets.map(&:file_name)).to eq ['icon.gif']
    end
  end
end
