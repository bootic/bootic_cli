require 'spec_helper'
require 'bootic_cli/cli/themes/mem_theme'
require 'bootic_cli/cli/themes/missing_items_theme'

describe BooticCli::MissingItemsTheme do
  let(:source) { BooticCli::MemTheme.new }
  let(:target) { BooticCli::MemTheme.new }

  before do
    # present in source
    source.add_template('layout.html', "aa2")
    source.add_template('product.html', "bb2")
    source.add_asset('icon.gif', StringIO.new('icon'))

    # present in target
    target.add_template('collection.html', "collection", mtime: Time.local(2017, 12, 13, 0, 0, 1))
    target.add_asset('logo.gif', StringIO.new('logo'))

    # present in both
    source.add_template('common.html', "common")
    target.add_template('common.html', "common")
    source.add_asset('common.gif', StringIO.new('commonicon'))
    target.add_asset('common.gif', StringIO.new('commonicon'))
  end

  describe "#templates" do
    it "returns templates in source that are missing in target" do
      theme = described_class.new(source: source, target: target)

      expect(theme.templates.map(&:file_name)).to eq ['layout.html', 'product.html']
    end
  end

  describe "#assets" do
    it "returns assets in source that are missing in target" do
      theme = described_class.new(source: source, target: target)

      expect(theme.assets.map(&:file_name)).to eq ['icon.gif']
    end
  end
end
