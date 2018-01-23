require 'fileutils'
require 'pstore'

module BooticCli

  class Store
    VERSION = 1
    DEFAULT_NAMESPACE = 'production'.freeze
    DIRNAME   = '.bootic'.freeze
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
        store['version'].to_i < VERSION
      end
    end

    def upgrade!
      return unless needs_upgrade?

      transaction do
        current_values = {}
        store.roots.each do |r|
          v = store[r]
          store.delete(r)
          current_values[r] = v
        end

        current_values.each do |k, v|
          self[k] = v
        end

        store['version'] = VERSION
      end
    end

    private

    attr_reader :base_dir, :namespace

    def store
      @store ||= PStore.new(File.join(base_dir, FILE_NAME))
    end
  end

end
