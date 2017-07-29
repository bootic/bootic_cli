require 'spec_helper'

describe BooticCli::Store do
  let(:store_dir) {
    path = File.expand_path(File.dirname(__FILE__))
    File.join(path, "store")
  }

  after do
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
end
