require 'spec_helper'
require "bootic_cli/store"

describe BooticCli::Store do
  let(:store_dir) {
    path = File.expand_path(File.dirname(__FILE__))
    File.join(path, "store")
  }

  around do |example|
    FileUtils.rm_rf store_dir
    example.run
    FileUtils.rm_rf store_dir
  end

  it "stores in default environment and persists changes" do
    store1 = described_class.new(base_dir: store_dir)
    store1.transaction do
      store1[:foo] = 1
    end

    store2 = described_class.new(base_dir: store_dir)
    result = store2.transaction do
      store2[:foo]
    end

    expect(result).to eq 1
  end

  it "supports multiple namespaces" do
    store1 = described_class.new(base_dir: store_dir)
    store1.transaction do
      store1[:foo] = 1
    end

    store2 = described_class.new(base_dir: store_dir, namespace: 'staging')
    result = store2.transaction do
      store2[:foo]
    end

    store3 = described_class.new(base_dir: store_dir)
    result = store3.transaction do
      store3[:foo]
    end

    expect(result).to be 1
  end

  context 'upgrading' do
    it "upgrades" do
      FileUtils.mkdir_p store_dir
      file = PStore.new(File.join(store_dir, described_class::FILE_NAME))
      file.transaction do
        file[:foo] = 1
      end

      store = described_class.new(base_dir: store_dir)

      expect(store.needs_upgrade?).to be true

      store.upgrade!
      expect(store.needs_upgrade?).to be false

      result = store.transaction do
        store[:foo] = 1
      end

      expect(result).to be 1
    end
  end
end
