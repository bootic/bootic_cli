require 'fileutils'
require 'pstore'

module BooticCli

  class Store

    DEFAULT_NAMESPACE = 'production'.freeze
    DIRNAME = '.btc'.freeze
    FILE_NAME = 'store.pstore'.freeze

    def initialize(base_dir: ENV['HOME'], dir: DIRNAME, namespace: DEFAULT_NAMESPACE)
      @base_dir = File.join(base_dir, dir)
      @namespace = namespace
      FileUtils.mkdir_p @base_dir
    end

    def []=(k, v)
      hash = store[namespace] || {}
      hash[k] = v
      store[namespace] = hash
    end

    def [](k)
      hash = store[namespace] || {}
      hash[k]
    end

    def transaction(&block)
      store.transaction(&block)
    end

    def erase
      FileUtils.rm_rf base_dir
    end

    def needs_upgrade?
      transaction do
        store[DEFAULT_NAMESPACE].nil?
      end
    end

    private

    attr_reader :base_dir, :namespace

    def store
      @store ||= PStore.new(File.join(base_dir, FILE_NAME))
    end
  end

end
